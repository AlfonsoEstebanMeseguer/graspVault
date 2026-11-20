// Reporting and blocking (D-044): what both stores require in an app where
// strangers talk. Everything goes through SQL functions that check the caller.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';

enum ReportReason {
  harassment, sexual, hate, spam, minorSafety, noShow, other,
  // Sabotaging the exam (D-051): only with a session, which the server checks.
  silent, mocking, noise, quit, controlAbuse,
}

enum ReportContext { chat, lobby, exam, feedback, offer, profile }

extension ReportReasonWire on ReportReason {
  String get wire => switch (this) {
        ReportReason.minorSafety => 'minor_safety',
        ReportReason.noShow => 'no_show',
        ReportReason.controlAbuse => 'control_abuse',
        _ => name,
      };
}

abstract class SafetyRepository {
  Future<void> report(String userId, ReportReason reason, {String? details, required ReportContext context, String? sessionId, String? chatId});
  Future<void> block(String userId);
  Future<void> unblock(String userId);

  /// The people I have blocked, newest first.
  Future<List<String>> blocked();
}

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._c);
  final sb.SupabaseClient _c;

  Future<void> _rpc(String fn, Map<String, Object?> params) async {
    try {
      await _c.rpc(fn, params: params);
    } on sb.PostgrestException catch (e) {
      throw AppFailure(const {'rate_limited', 'bad_user'}.contains(e.message) ? e.message : 'server_error');
    }
  }

  @override
  Future<void> report(String userId, ReportReason reason, {String? details, required ReportContext context, String? sessionId, String? chatId}) =>
      _rpc('report_user', {
        'p_user': userId,
        'p_reason': reason.wire,
        'p_details': details,
        'p_context': context.name,
        'p_session': sessionId,
        'p_chat': chatId,
      });

  @override
  Future<void> block(String userId) => _rpc('block_user', {'p_user': userId});

  @override
  Future<void> unblock(String userId) => _rpc('unblock_user', {'p_user': userId});

  @override
  Future<List<String>> blocked() async {
    final rows = await _c.from('user_blocks').select('blocked_id, created_at').order('created_at', ascending: false);
    return [for (final r in rows) r['blocked_id'] as String];
  }
}

final safetyRepositoryProvider = Provider<SafetyRepository?>(
  (ref) => Env.fromDefines.hasBackend ? SupabaseSafetyRepository(sb.Supabase.instance.client) : null,
);

final blockedUsersProvider = FutureProvider.autoDispose<List<String>>((ref) async => await ref.watch(safetyRepositoryProvider)?.blocked() ?? const []);
