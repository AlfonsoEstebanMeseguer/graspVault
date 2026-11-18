// Profile tab and account settings: stats, recordings, entitlement, profile
// edits (RLS + column grants) and account deletion (`account-delete`).
import '../../domain/feedback/peer_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/account/account.dart';
import '../auth/auth_repository.dart';
import '../auth/oauth_sign_in.dart';
import '../../domain/exam/models.dart';

class RecordingItem {
  const RecordingItem({required this.sessionId, required this.level, required this.partnerId, required this.startedAt, required this.duration, required this.expiresAt});
  final String sessionId;
  final Level level;
  final String? partnerId;
  final DateTime startedAt;
  final Duration duration;
  final DateTime expiresAt;

  /// "28 días": whole days left, rounded up so the last day still shows 1.
  int daysLeft(DateTime now) => (expiresAt.difference(now).inMinutes / (60 * 24)).ceil().clamp(0, 30);
}

class Entitlement {
  const Entitlement({required this.status, this.periodEnd, this.trialUsedAt, this.plan = 'standard'});
  final String? status; // RevenueCat status, null = never subscribed
  final DateTime? periodEnd;
  final DateTime? trialUsedAt;

  /// 'standard' (8 €) or 'pro' (10 €, exam control, D-037).
  final String plan;
  bool active(DateTime now) => status == 'active' && (periodEnd == null || periodEnd!.isAfter(now));
  bool isPro(DateTime now) => active(now) && plan == 'pro';
}

abstract class AccountRepository {
  Future<int> examsDone();
  Future<List<RecordingItem>> recordings();
  Future<Entitlement?> entitlement();
  Future<void> updateProfile({required String username, required List<String> languages, required Level targetLevel});
  Future<String> recordingUrl(String sessionId);

  /// What partners said about me in the rubric (D-042), averaged.
  Future<FeedbackSummary> feedbackReceived();

  /// Re-authenticates with the account's own method (fresh session, the server
  /// wants < 5 min): the password for email accounts, the provider's sheet for
  /// Google and Apple (D-062). Then deletes.
  Future<void> deleteAccount({String? password, required String phrase});
}

class SupabaseAccountRepository implements AccountRepository {
  SupabaseAccountRepository(this._c, this._oauth);
  final sb.SupabaseClient _c;
  final OAuthSignIn _oauth;
  String get _me => _c.auth.currentUser!.id;

  Future<Map<String, dynamic>> _invoke(String fn, Map<String, Object?> body) async {
    try {
      final r = await _c.functions.invoke(fn, body: body);
      return (r.data as Map).cast<String, dynamic>();
    } on sb.FunctionException catch (e) {
      final d = e.details;
      throw AppFailure(d is Map && d['error'] is String ? d['error'] as String : 'server_error');
    }
  }

  @override
  Future<FeedbackSummary> feedbackReceived() async {
    final rows = await _c
        .from('peer_ratings')
        .select('grammar, discourse, pronunciation, interaction')
        .eq('ratee_id', _me)
        .order('created_at', ascending: false)
        .limit(50);
    return FeedbackSummary.of([for (final r in rows) PeerRating.fromRow(r)]);
  }

  @override
  Future<int> examsDone() async {
    final r = await _c.from('exam_history').select('session_id').eq('user_id', _me).eq('completed', true).count(sb.CountOption.exact);
    return r.count;
  }

  @override
  Future<List<RecordingItem>> recordings() async {
    final rows = await _c
        .from('exam_sessions')
        .select('id, level, user_a, user_b, exam_started_at, ended_at, recording_expires_at')
        .gt('recording_expires_at', DateTime.now().toUtc().toIso8601String())
        .order('recording_expires_at', ascending: false);
    return [
      for (final r in rows)
        if (r['exam_started_at'] != null)
          RecordingItem(
            sessionId: r['id'] as String,
            level: LevelCode.parse(r['level'] as String),
            partnerId: r['user_a'] == _me ? r['user_b'] as String? : r['user_a'] as String?,
            startedAt: DateTime.parse(r['exam_started_at'] as String),
            duration: r['ended_at'] == null
                ? Duration.zero
                : DateTime.parse(r['ended_at'] as String).difference(DateTime.parse(r['exam_started_at'] as String)),
            expiresAt: DateTime.parse(r['recording_expires_at'] as String),
          ),
    ];
  }

  @override
  Future<Entitlement?> entitlement() async {
    final r = await _c.from('entitlements').select('subscription_status, current_period_end, trial_used_at, plan').eq('user_id', _me).maybeSingle();
    if (r == null) return null;
    DateTime? t(String k) => r[k] == null ? null : DateTime.parse(r[k] as String);
    return Entitlement(
      status: r['subscription_status'] as String?,
      periodEnd: t('current_period_end'),
      trialUsedAt: t('trial_used_at'),
      plan: r['plan'] as String? ?? 'standard',
    );
  }

  @override
  Future<void> updateProfile({required String username, required List<String> languages, required Level targetLevel}) async {
    try {
      await _c.from('profiles').update({'username': username, 'languages': languages, 'target_level': targetLevel.code}).eq('id', _me);
    } on sb.PostgrestException catch (e) {
      throw AppFailure(e.code == '23505' ? 'username_taken' : 'server_error');
    }
  }

  @override
  Future<String> recordingUrl(String sessionId) async =>
      (await _invoke('media-view-url', {'kind': 'recording', 'sessionId': sessionId}))['url'] as String;

  @override
  Future<void> deleteAccount({String? password, required String phrase}) async {
    final me = SupabaseAuthRepository.map(_c.auth.currentUser);
    if (me == null) throw const AppFailure('server_error');
    String? appleCode;
    switch (me.method) {
      case SignInMethod.email:
        if (me.email == null || password == null || password.isEmpty) throw const AppFailure('invalid_credentials');
        try {
          await _c.auth.signInWithPassword(email: me.email!, password: password);
        } on sb.AuthException {
          throw const AppFailure('invalid_credentials');
        }
      case SignInMethod.google:
        if (!_oauth.googleAvailable) throw const AppFailure('reauth_unavailable');
        await _oauth.google();
      case SignInMethod.apple:
        if (!_oauth.appleAvailable) throw const AppFailure('reauth_unavailable');
        appleCode = await _oauth.apple();
    }
    // The provider sheet may sign in ANOTHER account (a second Google account
    // on the phone): never delete whoever happens to be signed in now.
    if (_c.auth.currentUser?.id != me.id) throw const AppFailure('reauth_mismatch');
    await _invoke('account-delete', {'confirmation': phrase, 'appleAuthorizationCode': ?appleCode});
    // The user no longer exists: a failing remote sign-out still clears the local session.
    try {
      await _c.auth.signOut();
    } catch (_) {}
  }
}

final accountRepositoryProvider = Provider<AccountRepository?>((ref) {
  final oauth = ref.watch(oauthSignInProvider);
  return oauth != null ? SupabaseAccountRepository(sb.Supabase.instance.client, oauth) : null;
});
