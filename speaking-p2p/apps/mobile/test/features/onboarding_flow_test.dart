import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/l10n/l10n.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/data/auth/auth_repository.dart';
import 'package:speaking_p2p/data/profile/profile_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/onboarding/onboarding_screen.dart';

class FakeProfiles implements ProfileRepository {
  final taken = {'ocupado'};
  OnboardingData? submitted;
  String? failWith;
  @override
  Future<bool> isUsernameAvailable(String u) async => !taken.contains(u);
  @override
  Future<MyProfile?> loadMine(String userId) async => null;
  @override
  Future<void> completeOnboarding(OnboardingData data) async {
    if (failWith != null) throw AppFailure(failWith!);
    submitted = data;
  }
}

Future<FakeProfiles> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final fake = FakeProfiles();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(fake),
      authUserProvider.overrideWith((ref) => Stream.value(const AuthUser(id: 'u1', email: 'laura@example.com'))),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: OnboardingScreen(today: DateTime(2026, 10, 15)),
    ),
  ));
  await tester.pump();
  return fake;
}

bool nextEnabled(WidgetTester t) => t.widget<FilledButton>(find.byKey(const Key('onboarding-next'))).onPressed != null;

Future<void> typeUsername(WidgetTester tester, String v) async {
  await tester.enterText(find.byKey(const Key('onboarding-username')), v);
  await tester.pump(const Duration(milliseconds: 450)); // debounce
  await tester.pump();
}

void main() {
  testWidgets('flujo completo: los tres pasos envian lo que pide el servidor', (tester) async {
    final fake = await pump(tester);
    expect(nextEnabled(tester), isFalse);

    await typeUsername(tester, 'ocupado');
    expect(find.text('Ese nombre de usuario ya está cogido'), findsOneWidget);
    await typeUsername(tester, 'ab');
    expect(find.textContaining('minúsculas'), findsOneWidget);
    await typeUsername(tester, 'laura_m');
    expect(find.text('Disponible'), findsOneWidget);
    expect(nextEnabled(tester), isFalse, reason: 'falta al menos un idioma');
    await tester.tap(find.text('Español'));
    await tester.tap(find.text('Inglés'));
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();

    // paso 2: menor de 14 bloqueado, fecha imposible rechazada
    await tester.enterText(find.byKey(const Key('onboarding-day')), '16');
    await tester.enterText(find.byKey(const Key('onboarding-month')), '10');
    await tester.enterText(find.byKey(const Key('onboarding-year')), '2012');
    await tester.pump();
    expect(find.text('Debes tener al menos 14 años'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byKey(const Key('onboarding-day')), '31');
    await tester.enterText(find.byKey(const Key('onboarding-month')), '02');
    await tester.pump();
    expect(find.text('Fecha no válida'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboarding-day')), '12');
    await tester.enterText(find.byKey(const Key('onboarding-month')), '03');
    await tester.enterText(find.byKey(const Key('onboarding-year')), '2004');
    await tester.enterText(find.byKey(const Key('onboarding-phone')), '612 345 678');
    await tester.pump();
    expect(find.text('laura@example.com'), findsOneWidget, reason: 'email de la sesion, solo lectura');
    expect(nextEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();

    // paso 3: nivel + terminos obligatorios
    await tester.tap(find.byKey(const Key('onboarding-level-C1')));
    await tester.pump();
    expect(nextEnabled(tester), isFalse, reason: 'sin aceptar terminos');
    await tester.tap(find.byKey(const Key('onboarding-terms')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();

    final d = fake.submitted!;
    expect(d.username, 'laura_m');
    expect(d.languages.toSet(), {'es', 'en'});
    expect(d.targetLevel, Level.c1);
    expect(d.birthDate, DateTime(2004, 3, 12));
    expect(d.phone, '+34612345678');
    expect(d.termsVersion, termsVersion);
  });

  testWidgets('si el servidor dice username_taken, vuelve al paso 1 con el aviso', (tester) async {
    final fake = await pump(tester);
    fake.failWith = 'username_taken';
    await typeUsername(tester, 'laura_m');
    await tester.tap(find.text('Español'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('onboarding-day')), '12');
    await tester.enterText(find.byKey(const Key('onboarding-month')), '03');
    await tester.enterText(find.byKey(const Key('onboarding-year')), '2004');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-level-B2')));
    await tester.tap(find.byKey(const Key('onboarding-terms')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pump();
    expect(find.byKey(const Key('onboarding-username')), findsOneWidget, reason: 'de vuelta al paso 1');
    expect(find.byKey(const Key('onboarding-error')), findsOneWidget);
  });
}
