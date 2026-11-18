// Authentication: Google and Apple (native, D-062) plus email + password
// (D-022, kept for App Review's demo account). The rest of the app only sees
// AuthRepository.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';
import 'oauth_sign_in.dart';

enum SignUpOutcome { signedIn, confirmEmail }

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> changes();
  Future<void> signIn(String email, String password);
  Future<SignUpOutcome> signUp(String email, String password);

  /// Whether the build has the provider configured (client IDs / capability).
  bool get googleAvailable;
  bool get appleAvailable;

  /// Sign in or sign up in one step: a new user lands in the onboarding.
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._oauth);
  final sb.SupabaseClient _client;
  final OAuthSignIn _oauth;

  static AuthUser? map(sb.User? u) => u == null
      ? null
      : AuthUser(id: u.id, email: u.email, method: SignInMethod.fromProvider(u.appMetadata['provider'] as String?));

  @override
  AuthUser? get currentUser => map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> changes() => _client.auth.onAuthStateChange.map((s) => map(s.session?.user));

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
    } on sb.AuthException catch (e) {
      throw AppFailure(_authCode(e));
    }
  }

  @override
  Future<SignUpOutcome> signUp(String email, String password) async {
    try {
      final r = await _client.auth.signUp(email: email.trim(), password: password);
      return r.session == null ? SignUpOutcome.confirmEmail : SignUpOutcome.signedIn;
    } on sb.AuthException catch (e) {
      throw AppFailure(_authCode(e));
    }
  }

  @override
  bool get googleAvailable => _oauth.googleAvailable;
  @override
  bool get appleAvailable => _oauth.appleAvailable;

  @override
  Future<void> signInWithGoogle() => _oauth.google();

  @override
  Future<void> signInWithApple() => _oauth.apple();

  @override
  Future<void> signOut() async {
    await _oauth.signOutProviders();
    await _client.auth.signOut();
  }

  static String _authCode(sb.AuthException e) => switch (e.code) {
        'invalid_credentials' => 'invalid_credentials',
        'email_not_confirmed' => 'email_not_confirmed',
        'user_already_exists' || 'email_exists' => 'email_exists',
        'weak_password' => 'weak_password',
        'over_email_send_rate_limit' || 'over_request_rate_limit' => 'rate_limited',
        _ => 'auth_failed',
      };
}

/// Without backend configuration the app runs in offline practice mode.
class OfflineAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> changes() => const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async => throw const AppFailure('offline');
  @override
  Future<SignUpOutcome> signUp(String email, String password) async => throw const AppFailure('offline');
  @override
  bool get googleAvailable => false;
  @override
  bool get appleAvailable => false;
  @override
  Future<void> signInWithGoogle() async => throw const AppFailure('offline');
  @override
  Future<void> signInWithApple() async => throw const AppFailure('offline');
  @override
  Future<void> signOut() async {}
}

final oauthSignInProvider = Provider<OAuthSignIn?>((ref) {
  return Env.fromDefines.hasBackend ? OAuthSignIn(sb.Supabase.instance.client) : null;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final oauth = ref.watch(oauthSignInProvider);
  return oauth != null ? SupabaseAuthRepository(sb.Supabase.instance.client, oauth) : OfflineAuthRepository();
});

/// Current user, live. Watched (not read once) so it never freezes on the
/// value before login (vault, flutter-ui point 12).
final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentUser;
  yield* repo.changes();
});
