// Authentication. Email + password for now (DECISIONS D-022); the rest of the
// app only sees AuthRepository, so switching to Google later touches this file.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';

enum SignUpOutcome { signedIn, confirmEmail }

abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> changes();
  Future<void> signIn(String email, String password);
  Future<SignUpOutcome> signUp(String email, String password);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);
  final sb.SupabaseClient _client;

  AuthUser? _map(sb.User? u) => u == null ? null : AuthUser(id: u.id, email: u.email);

  @override
  AuthUser? get currentUser => _map(_client.auth.currentUser);

  @override
  Stream<AuthUser?> changes() => _client.auth.onAuthStateChange.map((s) => _map(s.session?.user));

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
  Future<void> signOut() => _client.auth.signOut();

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
  Future<void> signOut() async {}
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseAuthRepository(sb.Supabase.instance.client) : OfflineAuthRepository();
});

/// Current user, live. Watched (not read once) so it never freezes on the
/// value before login (vault, flutter-ui point 12).
final authUserProvider = StreamProvider<AuthUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentUser;
  yield* repo.changes();
});
