// Live exam session: the server is the authority (CLAUDE.md §6). The app reads
// the row through RLS + Realtime and acts through `session-actions`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';

class SessionRow {
  const SessionRow({
    required this.id,
    required this.level,
    required this.examId,
    required this.userA,
    required this.userB,
    required this.state,
    this.lobbyDeadline,
    this.readyA = false,
    this.readyB = false,
    this.preloadedA = false,
    this.preloadedB = false,
    this.recordingA = false,
    this.recordingB = false,
    this.examStartedAt,
    this.abortedBy,
    this.abortReason,
  });

  final String id;
  final Level level;
  final String examId;
  final String? userA;
  final String? userB;
  final SessionState state;
  final DateTime? lobbyDeadline;
  final bool readyA, readyB, preloadedA, preloadedB, recordingA, recordingB;
  final DateTime? examStartedAt;
  final String? abortedBy;
  final String? abortReason;

  Role? roleOf(String userId) => userId == userA ? Role.a : (userId == userB ? Role.b : null);
  String? userOf(Role r) => r == Role.a ? userA : userB;
  bool readyOf(Role r) => r == Role.a ? readyA : readyB;
  bool recordingOf(Role r) => r == Role.a ? recordingA : recordingB;

  factory SessionRow.fromJson(Map<String, dynamic> j) {
    DateTime? t(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return SessionRow(
      id: j['id'] as String,
      level: LevelCode.parse(j['level'] as String),
      examId: j['exam_id'] as String,
      userA: j['user_a'] as String?,
      userB: j['user_b'] as String?,
      state: SessionState.values.byName(j['state'] as String),
      lobbyDeadline: t('lobby_deadline'),
      readyA: j['ready_a'] as bool? ?? false,
      readyB: j['ready_b'] as bool? ?? false,
      preloadedA: j['preloaded_a'] as bool? ?? false,
      preloadedB: j['preloaded_b'] as bool? ?? false,
      recordingA: j['recording_consent_a'] as bool? ?? false,
      recordingB: j['recording_consent_b'] as bool? ?? false,
      examStartedAt: t('exam_started_at'),
      abortedBy: j['aborted_by'] as String?,
      abortReason: j['abort_reason'] as String?,
    );
  }
}

class JoinResult {
  const JoinResult({required this.token, required this.url, required this.role, required this.serverNow});
  final String token;
  final String url;
  final Role role;
  final DateTime serverNow;
}

class PublicProfile {
  const PublicProfile({required this.id, required this.username, required this.languages, this.avatarKey});
  final String id;
  final String username;
  final List<String> languages;
  final String? avatarKey;
}

abstract class SessionRepository {
  Stream<SessionRow> watch(String sessionId);
  Future<JoinResult> join(String sessionId);
  Future<DateTime> tick(String sessionId);
  Future<void> setFlag(String sessionId, String flag, bool value);
  Future<void> abort(String sessionId, {String reason = 'left'});
  Future<PublicProfile?> publicProfile(String userId);
}

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._c);
  final sb.SupabaseClient _c;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    try {
      final r = await _c.functions.invoke('session-actions', body: body);
      return (r.data as Map).cast<String, dynamic>();
    } on sb.FunctionException catch (e) {
      final d = e.details;
      throw AppFailure(d is Map && d['error'] is String ? d['error'] as String : 'server_error');
    }
  }

  static DateTime _serverNow(Map<String, dynamic> body) =>
      DateTime.parse(((body['tick'] as Map)['server_now']) as String);

  @override
  Stream<SessionRow> watch(String sessionId) => _c
      .from('exam_sessions')
      .stream(primaryKey: ['id'])
      .eq('id', sessionId)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => SessionRow.fromJson(rows.first));

  @override
  Future<JoinResult> join(String sessionId) async {
    final b = await _call({'action': 'join', 'sessionId': sessionId});
    return JoinResult(
      token: b['token'] as String,
      url: b['url'] as String,
      role: b['role'] == 'A' ? Role.a : Role.b,
      serverNow: _serverNow(b),
    );
  }

  @override
  Future<DateTime> tick(String sessionId) async => _serverNow(await _call({'action': 'tick', 'sessionId': sessionId}));

  @override
  Future<void> setFlag(String sessionId, String flag, bool value) =>
      _call({'action': 'flag', 'sessionId': sessionId, 'flag': flag, 'value': value});

  @override
  Future<void> abort(String sessionId, {String reason = 'left'}) =>
      _call({'action': 'abort', 'sessionId': sessionId, 'reason': reason});

  @override
  Future<PublicProfile?> publicProfile(String userId) async {
    final r = await _c.from('public_profiles').select('id, username, languages, avatar_key').eq('id', userId).maybeSingle();
    if (r == null) return null;
    return PublicProfile(
      id: r['id'] as String,
      username: r['username'] as String,
      languages: (r['languages'] as List<dynamic>).cast<String>(),
      avatarKey: r['avatar_key'] as String?,
    );
  }
}

final sessionRepositoryProvider = Provider<SessionRepository?>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseSessionRepository(sb.Supabase.instance.client) : null;
});
