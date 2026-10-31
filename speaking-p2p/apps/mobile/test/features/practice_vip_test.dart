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
import 'package:speaking_p2p/features/exam/cue_player.dart';
import 'package:speaking_p2p/features/exam/exam_screen.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';
import 'package:speaking_p2p/features/exam/widgets/exam_widgets.dart' show formatShort;
import 'package:speaking_p2p/l10n/app_localizations.dart';

Exam _exam(String level, String id) =>
    Exam.fromJson(jsonDecode(File('assets/content/exams/$level/$id.json').readAsStringSync()) as Map<String, Object?>);

const t0 = 1000000;

/// Records what the examiner was asked to play, and from where.
class _Reader implements ReaderPlayer {
  final plays = <(String, Duration)>[];
  int stops = 0;
  @override
  Future<void> play(ExamStep step, Duration offset) async => plays.add((step.id, offset));
  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async {}
}

class _Harness {
  _Harness(this.exam) : now = t0;
  final Exam exam;
  int now;
  late final LocalExamController c;
  final player = _Reader();
  final cues = SilentCuePlayer();

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
      overrides: [
        readerPlayerFactoryProvider.overrideWithValue((_, {inCall = false}) => player),
        cuePlayerFactoryProvider.overrideWithValue(({inCall = false}) => cues),
      ],
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

  testWidgets('pausar mientras lee el examinador lo calla; reanudar sigue donde se quedó', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    final reader = buildTimeline(b2).segments[speak.index - 1];
    await h.pump(tester, at: reader.startMs + 1500);
    await _settle(tester);
    expect(h.player.plays.last.$1, reader.stepId);
    final stops = h.player.stops;
    await _tap(tester, const Key('dock-pause'));
    expect(find.byKey(const Key('exam-paused')), findsOneWidget);
    expect(h.player.stops, greaterThan(stops), reason: 'el examinador se calla');
    final at = h.c.engine.at(h.now).elapsedMs - reader.startMs;
    h.now += 30000;
    await tester.pump(const Duration(milliseconds: 100));
    await _tap(tester, const Key('dock-pause')); // resume
    expect(h.player.plays.last, (reader.stepId, Duration(milliseconds: at)), reason: 'sigue por donde iba');
  });

  testWidgets('el dock es el mismo con el examinador y en la tarea; "Saltar" salta lo que suena', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    await h.pump(tester, at: speak.startMs - 500); // reader of p1-q1
    const keys = ['dock-prev', 'dock-pause', 'dock-skip', 'dock-repeat', 'dock-more'];
    for (final k in keys) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    await _tap(tester, const Key('dock-skip'));
    expect(h.segment().index, speak.index, reason: 'del examinador a la tarea');
    for (final k in keys) {
      expect(find.byKey(Key(k)), findsOneWidget, reason: k);
    }
    await _tap(tester, const Key('dock-skip'));
    expect(h.segment().stepId, isNot(speak.stepId), reason: 'de la tarea a la siguiente pregunta');
  });

  testWidgets('repetir vuelve a leer la pregunta actual', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    await h.pump(tester, at: speak.startMs + 5000);
    await _tap(tester, const Key('dock-repeat'));
    expect(h.segment().stepId, speak.stepId);
    expect(h.segment().phase, Phase.reader);
  });

  testWidgets('el cronómetro no corre mientras lee el examinador; pitidos al empezar y al acabar', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    await h.pump(tester, at: speak.startMs - 1500);
    final window = formatShort(speak.durationMs);
    expect(find.text(window), findsOneWidget, reason: 'el turno entero, quieto');
    h.now += 1000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(window), findsOneWidget);
    expect(h.cues.played, isEmpty);
    h.now += 1000; // the window opens
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.cues.played, [Cue.start]);
    h.now += 3000;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(formatShort(speak.durationMs - 3500)), findsOneWidget, reason: 'ahora sí corre');
    h.now = t0 + speak.endMs + 200; // time is up
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.cues.played, [Cue.start, Cue.end]);
  });

  testWidgets('la campana silencia los pitidos; saltar no pita "fin"', (tester) async {
    final h = _Harness(b2);
    final speak = _firstSpeak(b2, 1);
    await h.pump(tester, at: speak.startMs + 2000);
    await _settle(tester);
    expect(h.cues.played, [Cue.start]);
    await _tap(tester, const Key('dock-skip'));
    expect(h.cues.played, [Cue.start], reason: 'saltar no es "se acabó el tiempo"');
    await _tap(tester, const Key('exam-cues'));
    await _tap(tester, const Key('dock-skip')); // reader -> task: would beep
    expect(h.cues.played, [Cue.start]);
  });

  testWidgets('siguiente y anterior: ida y vuelta a la misma pregunta', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    final step = h.segment().stepId;
    await _tap(tester, const Key('dock-skip'));
    expect(h.segment().stepId, isNot(step));
    h.now += 1000;
    await _tap(tester, const Key('dock-prev'));
    expect(h.segment().stepId, step, reason: 'vuelve al principio de la pregunta anterior');
    expect(h.segment().phase, Phase.reader, reason: 'el examinador la vuelve a leer');
  });

  testWidgets('"Más": +1:00 alarga el turno; sin "Sig. parte" ni "Repetir"; "Parte 2" salta', (tester) async {
    final h = _Harness(b2);
    await h.pump(tester, at: _firstSpeak(b2, 1).startMs + 2000);
    final before = h.remaining();
    await _tap(tester, const Key('dock-more'));
    await _tap(tester, const Key('control-extend-60000'));
    expect(h.remaining(), before + 60000);
    expect(tester.takeException(), isNull, reason: 'el dock desplegado cabe en un móvil');
    expect(find.byKey(const Key('dock-next-part')), findsNothing);
    expect(find.byKey(const Key('control-repeat')), findsNothing);
    await _tap(tester, const Key('control-part-2'));
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
