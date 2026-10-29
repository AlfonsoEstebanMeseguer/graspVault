// Widget tests at a REAL phone size (vault: the default 800x600 surface hides
// overflows; and an overflow is only caught with tester.takeException()).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/app.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';

/// The `inCall` of every reader the app built (D-048: practice owns its audio session).
final _readerInCall = <bool>[];

Future<SilentReaderPlayer> _pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1080, 2340); // Pixel 5
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final player = SilentReaderPlayer();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      readerPlayerFactoryProvider.overrideWithValue((_, {inCall = false}) {
        _readerInCall.add(inCall);
        return player;
      }),
    ],
    child: const SpeakingApp(),
  ));
  // The search button pulses forever: pumpAndSettle would never settle.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return player;
}

/// Asset loading is real I/O: fake-time pumps alone do not wait for it.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsWidgets);
}

void main() {
  // rootBundle caches loadString futures; one created inside a previous test's
  // fake-async zone never completes in the next test.
  setUp(() {
    rootBundle.clear();
    _readerInCall.clear();
  });

  testWidgets('inicio -> practica: cabecera, texto del examinador y conmutadores', (tester) async {
    await _pumpApp(tester, prefs: {'ui_locale': 'es', 'target_level': 'B2'});
    expect(find.text('Practicar con compañero simulado'), findsOneWidget);
    expect(find.text('Practicar con compañero VIP simulado'), findsOneWidget, reason: 'modo debug');
    await tester.tap(find.text('Practicar con compañero simulado'));
    await pumpUntilFound(tester, find.text('PARTE 1 DE 4'));
    expect(find.text('Interview'), findsOneWidget);
    expect(find.textContaining('First of all'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('leader-dock')), findsNothing, reason: 'sin VIP no hay controles de líder');
    expect(_readerInCall, [false], reason: 'sin llamada el lector configura su propia sesión de audio');

    await tester.tap(find.byTooltip('Ocultar texto'));
    await tester.pump();
    expect(find.textContaining('First of all'), findsNothing);
    expect(find.byTooltip('Ver texto'), findsOneWidget);

    await tester.tap(find.byTooltip('Ocultar cronómetro'));
    await tester.pump();
    expect(find.byTooltip('Mostrar cronómetro'), findsOneWidget);
  });

  testWidgets('cuenta atrás de 3 s y después suena el saludo del examinador (p1-intro)', (tester) async {
    final player = await _pumpApp(tester, prefs: {'ui_locale': 'es', 'target_level': 'B2'});
    await tester.tap(find.text('Practicar con compañero simulado'));
    await pumpUntilFound(tester, find.byKey(const Key('exam-countdown')));
    expect(find.text('EL EXAMEN EMPIEZA EN'), findsOneWidget);
    // Frames during the lead, as on a phone (the screen ticks every frame).
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(player.played, isEmpty, reason: 'durante la cuenta atrás el examinador calla');
    // The practice clock is the real one: let the 3 s lead pass for real.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3300)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('exam-countdown')), findsNothing);
    expect(player.played.first, 'p1-intro', reason: 'antes se saltaba el saludo y sonaba ya el siguiente paso');
  });

  testWidgets('abandonar: el boton de confirmar esta bloqueado 5 s', (tester) async {
    await _pumpApp(tester, prefs: {'ui_locale': 'es'});
    await tester.tap(find.text('Practicar con compañero simulado'));
    await pumpUntilFound(tester, find.byTooltip('Abandonar'));
    await tester.tap(find.byTooltip('Abandonar'));
    await tester.pump(const Duration(milliseconds: 400));
    FilledButton confirm() => tester.widget<FilledButton>(find.byKey(const Key('abandon-confirm')));
    expect(confirm().onPressed, isNull);
    expect(find.text('Salir del examen (5)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(confirm().onPressed, isNull, reason: 'a los 4 s sigue bloqueado');
    await tester.pump(const Duration(seconds: 1));
    expect(confirm().onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('abandon-confirm')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Practicar con compañero simulado'), findsOneWidget, reason: 'vuelve al inicio');
  });

  testWidgets('ajustes: tema e idioma se guardan y se releen', (tester) async {
    await _pumpApp(tester, prefs: {'ui_locale': 'es'});
    await tester.tap(find.text('Ajustes'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Oscuro'));
    await tester.tap(find.text('English'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings'), findsWidgets);
    final sp = await SharedPreferences.getInstance();
    expect(sp.getString('theme_mode'), 'dark');
    expect(sp.getString('ui_locale'), 'en');
    expect(Theme.of(tester.element(find.text('APPEARANCE'))).brightness, Brightness.dark);
  });
}
