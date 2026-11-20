// D-057: the examiner audio of an exam may arrive after its screen exists
// (switching exam: the screen is built at once, the files are downloaded
// after). The reader must be rebuilt with them, or that exam stays silent.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/domain/exam/engine.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/exam/exam_screen.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

const t0 = 1000000;

void main() {
  final exam = Exam.fromJson(
      jsonDecode(File('assets/content/exams/B2/b2-e02-social-media-and-friendship.json').readAsStringSync()) as Map<String, Object?>);

  testWidgets('el audio llega después de crear la pantalla: el lector se rehace y suena el paso en curso', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final built = <Map<String, String>>[];
    final players = <SilentReaderPlayer>[];
    final engine = ExamEngine(exam: exam, myRole: Role.a, examStartedAtMs: t0);
    final files = ValueNotifier<Map<String, String>>(const {});
    addTearDown(files.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        readerPlayerFactoryProvider.overrideWithValue((f, {inCall = false}) {
          built.add(f);
          return (players..add(SilentReaderPlayer())).last;
        }),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: ValueListenableBuilder(
          valueListenable: files,
          builder: (_, f, _) => ExamScreen(
            key: const ValueKey('same-exam'),
            engine: engine,
            readerFiles: f,
            myName: 'yo',
            partnerName: 'compañero',
            nowMs: () => t0 + 300, // inside the greeting, after the lead
            onAbandon: () async {},
            onExit: () {},
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    expect(built, [isEmpty], reason: 'la pantalla nace sin audio (aún se está descargando)');

    files.value = {'p1-intro': '/tmp/p1-intro.mp3'};
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(built.length, 2, reason: 'con el audio ya descargado, el lector se vuelve a crear');
    expect(built.last.keys, ['p1-intro']);
    expect(players.last.played, ['p1-intro'], reason: 'y suena el paso en el que está el examen');
  });
}
