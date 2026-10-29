// Practice with a simulated VIP partner (debug): the Pro controls on one phone
// (D-039). The exam clock is injected, so pauses and jumps are deterministic.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/data/content/content_repository.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';
import 'package:speaking_p2p/features/exam/control/local_exam_controller.dart';
import 'package:speaking_p2p/features/exam/exam_screen.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

Exam _exam(String level, String id) =>
    Exam.fromJson(jsonDecode(File('assets/content/exams/$level/$id.json').readAsStringSync()) as Map<String, Object?>);

const t0 = 1000000;

class _Harness {
  _Harness(this.exam) : now = t0;
  final Exam exam;
  int now;
  late final LocalExamController c;
  final player = SilentReaderPlayer();

  Future<void> pump(WidgetTester tester, {required int at}) async {
    now = t0 + at;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final repo = ContentRepository(rootBundle);
    c = LocalExamController(
      exam: exam,
      media: const ExamMedia(),
      myRole: Role.a,
      startedAtMs: t0,
      partnerName: 'compañero_sim',
      catalog: const [
        ContentIndexEntry('b2-community-life', Level.b2, 1, 'Community life'),
        ContentIndexEntry('b2-e02-social-media-and-friendship', Level.b2, 1, 'Social media and friendship'),
      ],
      loadExam: repo.exam,
      loadMedia: (_) async => const ExamMedia(),
      now: () => now,
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [readerPlayerFactoryProvider.overrideWithValue((_, {inCall = false}) => player)],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: ListenableBuilder(
          listenable: c,
          builder: (_, _) => ExamScreen(
            key: ValueKey(c.exam.id),
            engine: c.engine,
            myName: 'yo',
            partnerName: 'compañero_sim',
            nowMs: () => now,
            simulatedPartner: true,
            control: c,
            onAbandon: () async {},
            onExit: () {},
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  int remaining() => c.engine.at(now).phase.remainingMs;
  Segment segment() => c.engine.at(now).segment!;
}

Segment _firstSpeak(Exam e, int part) =>
    buildTimeline(e).segments.firstWhere((s) => s.part == part && s.phase == Phase.speak);

/// The exam screen ticks forever: pumpAndSettle would never settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

void main() {
  final b2 = _exam('B2', 'b2-community-life');
  setUp(() => rootBundle.clear());

  testWidgets('el líder ve el dock; pausar congela el tiempo y reanudar lo devuelve', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    expect(find.byKey(const Key('leader-dock')), findsOneWidget);
    expect(find.text('Diriges el examen'), findsOneWidget);
    await _tap(tester, const Key('dock-pause'));
    expect(find.byKey(const Key('exam-paused')), findsOneWidget);
    final before = h.remaining();
    h.now += 60000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.remaining(), before, reason: 'en pausa el reloj no corre');
    await _tap(tester, const Key('dock-pause')); // the same button now resumes
    expect(find.byKey(const Key('exam-paused')), findsNothing);
    expect(h.remaining(), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mientras habla el examinador, el botón principal es "Saltar"', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    await h.pump(tester, at: speak.startMs - 500); // reader of p1-q1
    expect(find.byKey(const Key('dock-pause')), findsNothing, reason: 'no se pausa mientras habla el examinador');
    await _tap(tester, const Key('dock-skip-reader'));
    expect(h.segment().index, speak.index);
  });

  testWidgets('siguiente y anterior: ida y vuelta a la misma pregunta', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    final step = h.segment().stepId;
    await _tap(tester, const Key('dock-next'));
    expect(h.segment().stepId, isNot(step));
    h.now += 1000;
    await _tap(tester, const Key('dock-prev'));
    expect(h.segment().stepId, step, reason: 'vuelve al principio de la pregunta anterior');
    expect(h.segment().phase, Phase.reader, reason: 'el examinador la vuelve a leer');
  });

  testWidgets('"Más": +1:00 alarga el turno; "Sig. parte" pasa a la Parte 2', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    final before = h.remaining();
    await _tap(tester, const Key('dock-more'));
    await _tap(tester, const Key('control-extend-60000'));
    expect(h.remaining(), before + 60000);
    expect(tester.takeException(), isNull, reason: 'el dock desplegado cabe en un móvil');
    await _tap(tester, const Key('dock-next-part'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PARTE 2 DE 4'), findsOneWidget);
  });

  testWidgets('ceder el control al VIP simulado: lo devuelve a los 5 s', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    await _tap(tester, const Key('dock-more'));
    await _tap(tester, const Key('control-transfer'));
    expect(find.byKey(const Key('leader-dock')), findsNothing);
    expect(find.text('Dirige: compañero_sim'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.byKey(const Key('leader-dock')), findsOneWidget);
    expect(h.c.iAmLeader, isTrue);
  });

  testWidgets('feedback: el líder añade tiempo o vuelve a la última pregunta', (tester) async {
    final h = _Harness(b2);
    final total = buildTimeline(b2).totalMs;
    await h.pump(tester, at: total + 1000);
    expect(find.byKey(const Key('feedback-dock')), findsOneWidget);
    final before = h.c.engine.feedbackEndsAtMs;
    await _tap(tester, const Key('control-extend-120000'));
    expect(h.c.engine.feedbackEndsAtMs, before + 120000);
    await _tap(tester, const Key('feedback-back'));
    expect(h.segment().part, 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambiar de examen desde el catálogo empieza el nuevo desde la Parte 1', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 2).startMs + 2000);
    await tester.runAsync(() => h.c.switchExam('b2-e02-social-media-and-friendship'));
    await tester.pump();
    expect(h.c.exam.id, 'b2-e02-social-media-and-friendship');
    expect(h.c.engine.at(h.now).startsInMs, greaterThan(0), reason: 'margen de 3 s antes de la Parte 1');
    h.now += 4000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PARTE 1 DE 4'), findsOneWidget);
  });
}
