import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/config/env.dart';
import 'package:speaking_p2p/data/auth/oauth_sign_in.dart';

const _url = 'https://abc.supabase.co';
const _key = 'sb_publishable_x';
const _web = '123-web.apps.googleusercontent.com';
const _ios = '123-ios.apps.googleusercontent.com';

void main() {
  test('Google: el cliente web basta en Android; iOS necesita además el suyo', () {
    const onlyWeb = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '', googleWebClientId: _web);
    expect(onlyWeb.googleConfigured(ios: false), isTrue);
    expect(onlyWeb.googleConfigured(ios: true), isFalse);
    const both = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '', googleWebClientId: _web, googleIosClientId: _ios);
    expect(both.googleConfigured(ios: true), isTrue);
    const offline = Env(supabaseUrl: '', supabaseAnonKey: '', contentCdnUrl: '', googleWebClientId: _web, googleIosClientId: _ios);
    expect(offline.googleConfigured(ios: true), isFalse);
  });

  test('Apple: solo iOS y solo con el interruptor encendido', () {
    const on = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '', appleSignIn: true);
    expect(on.appleConfigured(ios: true), isTrue);
    expect(on.appleConfigured(ios: false), isFalse);
    const off = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '');
    expect(off.appleConfigured(ios: true), isFalse);
  });

  test('se niega a arrancar con el client secret pegado en lugar del client ID', () {
    const bad = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '', googleWebClientId: 'GOCSPX-abc');
    expect(bad.assertSafe, throwsStateError);
    const good = Env(supabaseUrl: _url, supabaseAnonKey: _key, contentCdnUrl: '', googleWebClientId: _web, googleIosClientId: _ios);
    expect(good.assertSafe, returnsNormally);
  });

  test('nonce: aleatorio, URL-safe, y el proveedor recibe su SHA-256', () {
    final a = randomNonce(Random(1));
    final b = randomNonce(Random(2));
    expect(a, isNot(b));
    expect(a, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    // Known vector: Supabase compares sha256(raw) with the token's nonce claim.
    expect(sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });
}
