// Live exam session: the server is the authority (CLAUDE.md §6). The app reads
// the row through RLS + Realtime and acts through `session-actions`.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';
import '../../domain/feedback/peer_rating.dart';

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
    this.schedule,
    this.feedbackEndsAt,
    this.leaderId,
    this.proA = false,
    this.proB = false,
    this.pausedAt,
    this.pauseReason,
    this.controlVersion = 0,
    this.lastControl,
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

  /// The session's own timeline: the leader may have changed durations (D-039).
  final Map<String, Object?>? schedule;
  final DateTime? feedbackEndsAt;

  /// Pro exam control (D-038): who leads, who has Pro, the frozen clock.
  final String? leaderId;
  final bool proA, proB;
  final DateTime? pausedAt;
  final String? pauseReason;
  final int controlVersion;

  /// {op, by, at, args}: the last thing the leader did (for the toast).
  final Map<String, Object?>? lastControl;

  bool proOf(Role r) => r == Role.a ? proA : proB;

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
      schedule: (j['schedule'] as Map?)?.cast<String, Object?>(),
      feedbackEndsAt: t('feedback_ends_at'),
      leaderId: j['leader_id'] as String?,
      proA: j['pro_a'] as bool? ?? false,
      proB: j['pro_b'] as bool? ?? false,
      pausedAt: t('paused_at'),
      pauseReason: j['pause_reason'] as String?,
      controlVersion: j['control_version'] as int? ?? 0,
      lastControl: (j['last_control'] as Map?)?.cast<String, Object?>(),
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
  /// [contentVersion] = this build's content, so the leader never switches
  /// to an exam this phone does not have (D-040).
  Future<JoinResult> join(String sessionId, {int? contentVersion});
  Future<DateTime> tick(String sessionId);
  Future<void> setFlag(String sessionId, String flag, bool value);
  Future<void> abort(String sessionId, {String reason = 'left'});

  /// Debug builds only: jump to the next boundary of the exam (D-031).
  Future<void> skip(String sessionId);

  /// Pro exam control (D-039). [expectedVersion] = the control_version this
  /// phone saw; the server refuses a stale one (`stale_control`).
  Future<void> control(String sessionId, {required String op, Map<String, Object?> args, required int expectedVersion});
  Future<PublicProfile?> publicProfile(String userId);

  /// The private feedback rubric for the partner (D-042); upserts.
  Future<void> rate(String sessionId, PeerRating rating);
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

  /// Only the columns `authenticated` may read (column grants, vault ADR 0038).
  /// `.stream()` selects `*` and is refused because recording_key stays private.
  static const _columns = 'id, level, exam_id, user_a, user_b, state, lobby_deadline, ready_a, ready_b, '
      'preloaded_a, preloaded_b, recording_consent_a, recording_consent_b, exam_started_at, aborted_by, abort_reason, '
      'schedule, feedback_ends_at, leader_id, pro_a, pro_b, paused_at, pause_reason, control_version, last_control';

  Future<SessionRow?> _fetch(String sessionId) async {
    final r = await _c.from('exam_sessions').select(_columns).eq('id', sessionId).maybeSingle();
    return r == null ? null : SessionRow.fromJson(r);
  }

  /// Realtime only says "this row changed"; the row is re-read by columns, so
  /// the change payload is never trusted for content.
  @override
  Stream<SessionRow> watch(String sessionId) {
    late final StreamController<SessionRow> out;
    sb.RealtimeChannel? channel;
    var closed = false;
    Future<void> refresh() async {
      try {
        final row = await _fetch(sessionId);
        if (row != null && !closed) out.add(row);
      } catch (e, st) {
        if (!closed) out.addError(e, st);
      }
    }

    out = StreamController<SessionRow>(
      onListen: () {
        channel = _c
            .channel('exam_session:$sessionId')
            .onPostgresChanges(
              event: sb.PostgresChangeEvent.update,
              schema: 'public',
              table: 'exam_sessions',
              filter: sb.PostgresChangeFilter(type: sb.PostgresChangeFilterType.eq, column: 'id', value: sessionId),
              callback: (_) => refresh(),
            )
            .subscribe((status, _) {
              // (Re)subscribed: catch up with anything missed while offline.
              if (status == sb.RealtimeSubscribeStatus.subscribed) refresh();
            });
        refresh();
      },
      onCancel: () async {
        closed = true;
        final ch = channel;
        if (ch != null) await _c.removeChannel(ch);
      },
    );
    return out.stream;
  }

  @override
  Future<JoinResult> join(String sessionId, {int? contentVersion}) async {
    final b = await _call({'action': 'join', 'sessionId': sessionId, 'contentVersion': ?contentVersion});
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
  Future<void> skip(String sessionId) => _call({'action': 'skip', 'sessionId': sessionId});

  @override
  Future<void> control(String sessionId, {required String op, Map<String, Object?> args = const {}, required int expectedVersion}) =>
      _call({
        'action': 'control',
        'sessionId': sessionId,
        'expectedVersion': expectedVersion,
        'control': {'op': op, if (args.isNotEmpty) 'args': args},
      });

  @override
  Future<void> rate(String sessionId, PeerRating rating) async {
    try {
      await _c.rpc('rate_partner', params: {
        'p_session': sessionId,
        for (final MapEntry(:key, :value) in rating.toRow().entries) 'p_$key': value,
      });
    } on sb.PostgrestException catch (e) {
      throw AppFailure(const {'not_participant', 'not_started', 'partner_gone'}.contains(e.message) ? e.message : 'server_error');
    }
  }

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
