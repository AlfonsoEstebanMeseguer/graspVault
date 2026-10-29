import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/router/router.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';

void main() {
  group('edad minima 14 (mismo criterio que el trigger de la base)', () {
    final today = DateTime(2026, 10, 15);
    test('cumple 14 hoy: entra', () => expect(Validators.isOldEnough(DateTime(2012, 10, 15), today), isTrue));
    test('cumple 14 manana: no entra', () => expect(Validators.isOldEnough(DateTime(2012, 10, 16), today), isFalse));
  });

  test('fechas imposibles no se convierten en otra fecha', () {
    expect(Validators.date(31, 2, 2000), isNull);
    expect(Validators.date(29, 2, 2000), DateTime(2000, 2, 29));
    expect(Validators.date(1, 13, 2000), isNull);
    expect(Validators.date(1, 1, 1899), isNull);
  });

  test('username y telefono con las mismas reglas que los CHECK', () {
    expect(Validators.username.hasMatch('laura_m'), isTrue);
    expect(Validators.username.hasMatch('Laura'), isFalse);
    expect(Validators.username.hasMatch('ab'), isFalse);
    expect(Validators.phone.hasMatch('+34612345678'), isTrue);
    expect(Validators.phone.hasMatch('612345678'), isFalse);
  });

  test('el JSON del onboarding es el que espera la Edge Function', () {
    final j = OnboardingData(
      username: 'laura_m', languages: ['es', 'en'], targetLevel: Level.c1,
      birthDate: DateTime(2004, 3, 12), phone: null, termsVersion: 'v1',
    ).toJson();
    expect(j, {'username': 'laura_m', 'languages': ['es', 'en'], 'targetLevel': 'C1', 'birthDate': '2004-03-12', 'phone': null, 'termsVersion': 'v1'});
  });

  group('puerta de sesion', () {
    String? gate(AsyncValue<Object?> user, AsyncValue<Object?> profile, String at, {bool backend = true}) =>
        gateRedirect(hasBackend: backend, user: user, profile: profile, location: at);
    const someone = AsyncData<Object?>('u');
    const nobody = AsyncData<Object?>(null);

    test('sin backend no hay puerta (modo practica)', () => expect(gate(nobody, nobody, '/', backend: false), isNull));
    test('sin sesion -> login', () => expect(gate(nobody, nobody, '/agenda'), '/login'));
    test('con sesion y sin perfil -> onboarding', () => expect(gate(someone, nobody, '/'), '/onboarding'));
    test('con perfil, el login y el onboarding llevan al inicio', () {
      expect(gate(someone, someone, '/login'), '/');
      expect(gate(someone, someone, '/onboarding'), '/');
      expect(gate(someone, someone, '/agenda'), isNull);
    });
    test('mientras carga, pantalla de carga', () {
      expect(gate(const AsyncLoading<Object?>(), nobody, '/'), '/loading');
      expect(gate(someone, const AsyncLoading<Object?>(), '/'), '/loading');
    });
  });
}
