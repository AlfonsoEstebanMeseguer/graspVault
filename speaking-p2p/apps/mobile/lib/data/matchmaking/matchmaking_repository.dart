import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/models.dart';

class EnqueueResult {
  const EnqueueResult({required this.matchedSessionId, required this.hasOpenMeeting});
  final String? matchedSessionId;
  final bool hasOpenMeeting;
}

abstract class MatchmakingRepository {
  Future<EnqueueResult> enqueue(Level level, int contentVersion);
  Future<void> cancel();
}

class SupabaseMatchmakingRepository implements MatchmakingRepository {
  SupabaseMatchmakingRepository(this._c);
  final sb.SupabaseClient _c;

  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    try {
      return ((await _c.functions.invoke('matchmaking', body: body)).data as Map).cast<String, dynamic>();
    } on sb.FunctionException catch (e) {
      final d = e.details;
      throw AppFailure(d is Map && d['error'] is String ? d['error'] as String : 'server_error');
    }
  }

  @override
  Future<EnqueueResult> enqueue(Level level, int contentVersion) async {
    final b = await _call({'action': 'enqueue', 'level': level.code, 'contentVersion': contentVersion});
    return EnqueueResult(
      matchedSessionId: b['status'] == 'matched' ? b['session_id'] as String? : null,
      hasOpenMeeting: b['hasOpenMeeting'] as bool? ?? false,
    );
  }

  @override
  Future<void> cancel() => _call({'action': 'cancel'});
}

final matchmakingRepositoryProvider = Provider<MatchmakingRepository?>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseMatchmakingRepository(sb.Supabase.instance.client) : null;
});
