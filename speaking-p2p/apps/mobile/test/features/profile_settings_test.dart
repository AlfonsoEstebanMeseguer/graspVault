import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/core/l10n/l10n.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/data/account/account_repository.dart';
import 'package:speaking_p2p/data/profile/profile_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/agenda/agenda_common.dart';
import 'package:speaking_p2p/features/profile/profile_screen.dart';
import 'package:speaking_p2p/features/settings/settings_screen.dart';

final now = DateTime(2026, 10, 15, 16);

class FakeAccount implements AccountRepository {
  final deletes = <(String, String)>[];
  String? failWith;
  ({String username, List<String> languages, Level level})? saved;

  @override
  Future<int> examsDone() async => 7;
  @override
  Future<List<RecordingItem>> recordings() async => [
        RecordingItem(
          sessionId: 's1',
          level: Level.c1,
          partnerId: null,
          startedAt: DateTime(2026, 10, 12, 19),
          duration: const Duration(minutes: 19),
          expiresAt: DateTime(2026, 11, 11, 19, 30),
        ),
      ];
  @override
  Future<Entitlement?> entitlement() async => Entitlement(status: 'active', periodEnd: DateTime.utc(2100));
  @override
  Future<void> updateProfile({required String username, required List<String> languages, required Level targetLevel}) async =>
      saved = (username: username, languages: languages, level: targetLevel);
  @override
  Future<String> recordingUrl(String sessionId) async => 'https://example.invalid';
  @override
  Future<void> deleteAccount({required String password, required String phrase}) async {
    if (failWith != null) throw AppFailure(failWith!);
    deletes.add((password, phrase));
  }
}

Future<FakeAccount> pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final fake = FakeAccount();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      accountRepositoryProvider.overrideWithValue(fake),
      sharedPreferencesProvider.overrideWithValue(prefs),
      agendaClockProvider.overrideWithValue(() => now),
      myProfileProvider.overrideWith((ref) async => const MyProfile(id: 'me', username: 'laura_m', languages: ['es', 'en'], targetLevel: Level.c1)),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: home,
    ),
  ));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return fake;
}

void main() {
  testWidgets('perfil: nivel, exámenes hechos y días que le quedan a la grabación', (tester) async {
    await pump(tester, const ProfileScreen());
    expect(find.text('laura_m'), findsOneWidget);
    expect(find.text('C1 Advanced'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('C1 con Usuario eliminado'), findsOneWidget);
    expect(find.text('28 días'), findsOneWidget);
  });

  testWidgets('perfil: editar envía username, idiomas y nivel', (tester) async {
    final fake = await pump(tester, const ProfileScreen());
    await tester.tap(find.text('Editar perfil'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Laura M');
    await tester.pump();
    expect(find.textContaining('minúsculas'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'laura.m');
    await tester.tap(find.text('B2').last);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(fake.saved?.username, 'laura.m');
    expect(fake.saved?.level, Level.b2);
    expect(fake.saved?.languages.toSet(), {'es', 'en'});
  });

  testWidgets('ajustes: el modo "todos pagan" no inventa una fecha de pago', (tester) async {
    await pump(tester, const SettingsScreen());
    expect(find.text('Activa'), findsOneWidget);
    expect(find.textContaining('Próximo pago'), findsNothing);
  });

  testWidgets('eliminar cuenta: exige contraseña y la frase ELIMINAR', (tester) async {
    final fake = await pump(tester, const Scaffold(body: DeleteAccountDialog()));
    FilledButton button() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar para siempre'));
    expect(button().onPressed, isNull);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'secreto123');
    await tester.enterText(fields.at(1), 'borrar');
    await tester.pump();
    expect(button().onPressed, isNull);
    await tester.enterText(fields.at(1), 'eliminar');
    await tester.pump();
    expect(button().onPressed, isNotNull);

    fake.failWith = 'invalid_credentials';
    await tester.tap(find.text('Eliminar para siempre'));
    await tester.pump();
    expect(find.text('Email o contraseña incorrectos'), findsOneWidget);
    fake.failWith = null;
    await tester.tap(find.text('Eliminar para siempre'));
    await tester.pump();
    expect(fake.deletes.single, ('secreto123', 'eliminar'));
  });
}
