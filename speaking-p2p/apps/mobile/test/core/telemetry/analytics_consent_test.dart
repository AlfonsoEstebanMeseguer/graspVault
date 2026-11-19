import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/core/telemetry/analytics_consent.dart';
import 'package:speaking_p2p/core/telemetry/telemetry.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/data/account/account_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';

import '../../features/profile_settings_test.dart' show FakeAccount;

Future<(ProviderContainer, SharedPreferences)> _container(FakeAccount? repo, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(p),
    accountRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return (c, p);
}

void main() {
  test('activado por defecto (interés legítimo con opt-out)', () async {
    final (c, _) = await _container(FakeAccount());
    expect(c.read(analyticsConsentProvider), isTrue);
  });

  test('desactivarlo lo guarda en el móvil y en el servidor', () async {
    final repo = FakeAccount();
    final (c, p) = await _container(repo);
    await c.read(analyticsConsentProvider.notifier).set(false);
    expect(c.read(analyticsConsentProvider), isFalse);
    expect(p.getBool(Telemetry.optOutPrefKey), isTrue);
    expect(repo.optOuts, [true]);
    expect(Telemetry.instance.analyticsEnabled, isFalse);
  });

  test('si el servidor falla, el interruptor vuelve atrás y no miente', () async {
    final repo = FakeAccount()..failWith = 'server_error';
    final (c, p) = await _container(repo);
    await expectLater(c.read(analyticsConsentProvider.notifier).set(false), throwsA(isA<AppFailure>()));
    expect(c.read(analyticsConsentProvider), isTrue);
    expect(p.getBool(Telemetry.optOutPrefKey), isFalse);
  });

  test('sin sesión solo existe la copia del móvil', () async {
    final (c, p) = await _container(null);
    await c.read(analyticsConsentProvider.notifier).set(false);
    expect(p.getBool(Telemetry.optOutPrefKey), isTrue);
  });

  test('al iniciar sesión gana la elección del servidor; si no se puede leer, se conserva la del móvil', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await applyServerAnalyticsChoice(p, () async => true);
    expect(analyticsAllowedOnDevice(p), isFalse);
    await applyServerAnalyticsChoice(p, () async => throw StateError('offline'));
    expect(analyticsAllowedOnDevice(p), isFalse);
    await applyServerAnalyticsChoice(p, () async => false);
    expect(analyticsAllowedOnDevice(p), isTrue);
  });
}
