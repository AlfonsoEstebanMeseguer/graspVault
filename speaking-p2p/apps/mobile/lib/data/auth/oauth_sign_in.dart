// Native Google / Apple sign-in -> Supabase session with signInWithIdToken
// (D-062). No browser redirect: the provider's SDK returns an ID token and
// Supabase verifies its audience and nonce. Shared by the login and by the
// re-authentication before deleting the account.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';

/// Random nonce: the raw value goes to Supabase, its SHA-256 to the provider,
/// which embeds it in the ID token. Supabase hashes the raw one and compares.
String randomNonce([Random? random]) {
  final r = random ?? Random.secure();
  return base64Url.encode(List<int>.generate(32, (_) => r.nextInt(256))).replaceAll('=', '');
}

String sha256Hex(String s) => sha256.convert(utf8.encode(s)).toString();

class OAuthSignIn {
  OAuthSignIn(this._client, {Env? env, TargetPlatform? platform})
      : _env = env ?? Env.fromDefines,
        _ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;

  final sb.SupabaseClient _client;
  final Env _env;
  final bool _ios;

  bool get googleAvailable => _env.googleConfigured(ios: _ios);
  bool get appleAvailable => _env.appleConfigured(ios: _ios);

  // google_sign_in 7 must be initialised exactly once per process, and the
  // nonce is fixed there, so it lives for the whole process.
  static Future<void>? _googleInit;
  static String? _googleNonce;

  Future<void> _ensureGoogle() => _googleInit ??= () async {
        final nonce = randomNonce();
        try {
          await GoogleSignIn.instance.initialize(
            serverClientId: _env.googleWebClientId,
            clientId: _ios ? _env.googleIosClientId : null,
            nonce: sha256Hex(nonce),
          );
          _googleNonce = nonce;
        } catch (_) {
          _googleInit = null; // a failed init may be retried on the next tap
          rethrow;
        }
      }();

  /// Throws AppFailure: `sign_in_cancelled` (silent in the UI), `provider_unavailable`,
  /// `provider_failed` (SDK/config) or `auth_failed` (Supabase rejected the token).
  Future<void> google() async {
    if (!googleAvailable) throw const AppFailure('provider_unavailable');
    try {
      await _ensureGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AppFailure('provider_failed');
      // Only if already granted (no extra consent screen). Supabase uses it to
      // check the token's at_hash when present.
      final authz = await account.authorizationClient.authorizationForScopes(const ['email', 'profile']).catchError((_) => null);
      await _client.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: authz?.accessToken,
        nonce: _googleNonce,
      );
    } on GoogleSignInException catch (e) {
      throw AppFailure(switch (e.code) {
        GoogleSignInExceptionCode.canceled || GoogleSignInExceptionCode.interrupted => 'sign_in_cancelled',
        _ => 'provider_failed',
      });
    } on sb.AuthException {
      throw const AppFailure('auth_failed');
    }
  }

  /// Returns Apple's one-time `authorizationCode`: the server needs it to
  /// revoke the Apple token when the account is deleted (guideline 5.1.1(v)).
  Future<String> apple() async {
    if (!appleAvailable) throw const AppFailure('provider_unavailable');
    final raw = randomNonce();
    try {
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: sha256Hex(raw),
      );
      final idToken = cred.identityToken;
      if (idToken == null) throw const AppFailure('provider_failed');
      await _client.auth.signInWithIdToken(provider: sb.OAuthProvider.apple, idToken: idToken, nonce: raw);
      return cred.authorizationCode;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AppFailure(e.code == AuthorizationErrorCode.canceled ? 'sign_in_cancelled' : 'provider_failed');
    } on sb.AuthException {
      throw const AppFailure('auth_failed');
    }
  }

  /// Forget the Google account picked, so the next login offers the chooser.
  Future<void> signOutProviders() async {
    if (_googleInit == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
