// Renders every main screen of the app (no dialogs or sheets) with sample data
// and saves them as contact sheets, several screens per image, in
// docs/screenshots/. Not part of the normal suite: it only runs with a
// (fake) backend configured, so the screens show their online version:
//
//   flutter test test/screenshots --dart-define=SUPABASE_URL=https://example.supabase.co --dart-define=SUPABASE_ANON_KEY=screenshot
//
// (optionally with SCREENSHOT_FONT_DIR set, see _loadFonts; SCREENSHOT_THEME=dark
// renders the dark theme into *-oscuro.png).
//
// Nothing talks to a server: every repository is a fake from the feature tests.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speaking_p2p/app.dart';
import 'package:speaking_p2p/core/config/env.dart';
import 'package:speaking_p2p/core/router/router.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/core/theming/preferences.dart';
import 'package:speaking_p2p/core/voice/voice_service.dart';
import 'package:speaking_p2p/data/account/account_repository.dart';
import 'package:speaking_p2p/data/agenda/agenda_repository.dart';
import 'package:speaking_p2p/data/auth/auth_repository.dart';
import 'package:speaking_p2p/data/matchmaking/matchmaking_repository.dart';
import 'package:speaking_p2p/data/profile/avatar_repository.dart';
import 'package:speaking_p2p/data/profile/profile_repository.dart';
import 'package:speaking_p2p/data/safety/safety_repository.dart';
import 'package:speaking_p2p/data/session/session_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/agenda/agenda.dart' show MeetingStatus;
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';
import 'package:speaking_p2p/features/agenda/agenda_common.dart';
import 'package:speaking_p2p/features/exam/control/local_exam_controller.dart';
import 'package:speaking_p2p/features/exam/exam_screen.dart';
import 'package:speaking_p2p/features/exam/reader_player.dart';
import 'package:speaking_p2p/features/exam/widgets/bubble_diagram.dart';
import 'package:speaking_p2p/features/matchmaking/matchmaking_controller.dart';
import 'package:speaking_p2p/features/session/live_session.dart';
import 'package:speaking_p2p/features/session/lobby_view.dart';
import 'package:speaking_p2p/l10n/app_localizations.dart';

import '../features/agenda_flow_test.dart' as agenda;
import '../features/avatar_test.dart' as avatars;
import '../features/live_session_test.dart' as live;
import '../features/matchmaking_test.dart' as mm;
import '../features/onboarding_flow_test.dart' as onboarding;
import '../features/profile_settings_test.dart' as account;

const _root = Key('screenshot-root');
const _pixelRatio = 2.0;
final _dark = Platform.environment['SCREENSHOT_THEME'] == 'dark';
final _shots = <(String, ui.Image)>[];

/// Real fonts instead of the test font (which draws boxes): the app's bundled
/// fonts and icon fonts. SCREENSHOT_FONT_DIR may point to local copies of Roboto
/// (used for the sheet captions and any fallback); those are never committed.
Future<void> _loadFonts() async {
  final flutterFonts = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final textFonts = Platform.environment['SCREENSHOT_FONT_DIR'] ?? flutterFonts;
  Future<ByteData> font(String dir, String f) async => ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  await (FontLoader('Roboto')
        ..addFont(font(textFonts, 'roboto-regular.ttf'))
        ..addFont(font(textFonts, 'roboto-medium.ttf'))
        ..addFont(font(textFonts, 'roboto-bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')..addFont(font(flutterFonts, 'materialicons-regular.otf'))).load();
  const bundled = {
    'InstrumentSans': ['InstrumentSans-400', 'InstrumentSans-500', 'InstrumentSans-600', 'InstrumentSans-700'],
    'Newsreader': ['Newsreader-500', 'Newsreader-500Italic'],
    'PlexMono': ['IBMPlexMono-500', 'IBMPlexMono-600'],
    'Caveat': ['Caveat-500', 'Caveat-600'],
  };
  for (final MapEntry(key: family, value: files) in bundled.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(font('assets/fonts', '$f.ttf'));
    }
    await loader.load();
  }
  for (final style in ['Regular', 'Fill', 'Bold']) {
    await (FontLoader('Phosphor$style')..addFont(font('assets/fonts', 'Phosphor-$style.ttf'))).load();
  }
}


/// Pumps frames, letting real I/O (assets) complete in between.
Future<void> _settle(WidgetTester tester, {int rounds = 12}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String title) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_root));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: _pixelRatio));
  _shots.add((title, image!));
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340); // Pixel 5
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

/// The whole app (router, tabs, theme) with fakes behind every repository.
Future<ProviderContainer> _app(WidgetTester tester, {AuthUser? user, MyProfile? profile, agenda.FakeAgenda? agendaFake}) async {
  SharedPreferences.setMockInitialValues({'ui_locale': 'es', 'target_level': 'C1', if (_dark) 'theme_mode': 'dark'});
  final prefs = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    authRepositoryProvider.overrideWithValue(OfflineAuthRepository()),
    authUserProvider.overrideWith((ref) => Stream.value(user)),
    myProfileProvider.overrideWith((ref) async => profile),
    accountRepositoryProvider.overrideWithValue(account.FakeAccount()),
    agendaRepositoryProvider.overrideWithValue(agendaFake ?? agenda.FakeAgenda()),
    agendaClockProvider.overrideWithValue(() => agenda.now),
    matchmakingRepositoryProvider.overrideWithValue(mm.FakeQueue()),
    profileRepositoryProvider.overrideWithValue(onboarding.FakeProfiles()),
    avatarRepositoryProvider.overrideWithValue(avatars.FakeAvatars()),
    sessionRepositoryProvider.overrideWithValue(live.FakeRepo()),
    readerAudioProvider.overrideWithValue(null),
    readerPlayerFactoryProvider.overrideWithValue((_, {inCall = false}) => SilentReaderPlayer()),
    safetyRepositoryProvider.overrideWithValue(_FakeSafety()),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    key: UniqueKey(),
    container: c,
    child: const RepaintBoundary(key: _root, child: SpeakingApp()),
  ));
  await _settle(tester);
  return c;
}

/// A single screen outside the router (lobby, exam), same theme and locale.
Future<void> _alone(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [readerPlayerFactoryProvider.overrideWithValue((_, {inCall = false}) => SilentReaderPlayer())],
    child: RepaintBoundary(
      key: _root,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(_dark ? Brightness.dark : Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: screen,
      ),
    ),
  ));
  await _settle(tester);
}

const _me = AuthUser(id: 'me', email: 'laura@example.com');
const _profile = MyProfile(id: 'me', username: 'laura_m', languages: ['es', 'en'], targetLevel: Level.c1);

/// Draws the screens side by side, each with its title, on one PNG.
Future<void> _sheet(String file, String heading, List<(String, ui.Image)> shots) async {
  const pad = 48.0, gap = 40.0, captionH = 64.0, headH = 110.0;
  final w = shots.first.$2.width.toDouble(), h = shots.first.$2.height.toDouble();
  final size = Size(pad * 2 + shots.length * w + (shots.length - 1) * gap, headH + captionH + h + pad);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & size, Paint()..color = _dark ? const Color(0xFF0E1015) : const Color(0xFFEDEFF3));

  void text(String s, double x, double y, double maxW, double fontSize, FontWeight weight, Color color) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: fontSize, fontWeight: weight))
      ..pushStyle(ui.TextStyle(color: color))
      ..addText(s);
    final p = b.build()..layout(ui.ParagraphConstraints(width: maxW));
    canvas.drawParagraph(p, Offset(x, y));
  }

  text(heading, pad, 36, size.width - pad * 2, 44, FontWeight.w700, _dark ? const Color(0xFFF1F3F7) : const Color(0xFF1B1F27));
  for (final (i, (title, img)) in shots.indexed) {
    final x = pad + i * (w + gap);
    text(title, x, headH + 8, w, 30, FontWeight.w500, _dark ? const Color(0xFFB8BFCC) : const Color(0xFF3A4150));
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, headH + captionH, w, h), const Radius.circular(36));
    canvas.drawRRect(r.shift(const Offset(0, 6)), Paint()..color = const Color(0x22000000));
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawImage(img, Offset(x, headH + captionH), Paint());
    canvas.restore();
  }
  final image = await rec.endRecording().toImage(size.width.ceil(), size.height.ceil());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final name = _dark ? file.replaceFirst('.png', '-oscuro.png') : file;
  final out = File('../../docs/screenshots/$name')..createSync(recursive: true);
  out.writeAsBytesSync(png!.buffer.asUint8List());
}

Exam _exam(String level, String id) =>
    Exam.fromJson(jsonDecode(File('assets/content/exams/$level/$id.json').readAsStringSync()) as Map<String, Object?>);

void main() {
  setUpAll(() async {
    WidgetsApp.debugAllowBannerOverride = false; // no DEBUG ribbon on the pictures
    await _loadFonts();
  });
  setUp(() => rootBundle.clear());

  testWidgets('pantallas principales -> docs/screenshots', (tester) async {
    await _phone(tester);
    debugDisableShadows = false; // tests draw shadows as solid slabs by default

    // Access
    await _app(tester);
    await _shot(tester, 'Inicio de sesión');
    await _app(tester, user: _me);
    await _shot(tester, 'Registro (onboarding)');

    // Main tabs
    final c = await _app(tester, user: _me, profile: _profile);
    await _shot(tester, 'Inicio');
    unawaited(c.read(matchmakingProvider.notifier).start(Level.c1));
    c.read(routerProvider).go('/search');
    await _settle(tester);
    await _shot(tester, 'Buscando pareja');
    await c.read(matchmakingProvider.notifier).cancel();
    for (final (path, title) in [('/agenda', 'Agenda'), ('/chat/c1', 'Chat de una reunión'), ('/profile', 'Perfil'), ('/settings', 'Ajustes')]) {
      c.read(routerProvider).go(path);
      await _settle(tester);
      await _shot(tester, title);
    }

    // Agenda with nothing of mine: the mandarin button (D-050)
    final empty = await _app(tester, user: _me, profile: _profile,
        agendaFake: agenda.FakeAgenda()
          ..mine = []
          ..extraChats = []
          ..card = agenda.meeting(status: MeetingStatus.closed));
    empty.read(routerProvider).go('/agenda');
    await _settle(tester);
    await tester.tap(find.byKey(const Key('agenda-tab-mine')));
    await _settle(tester);
    await _shot(tester, 'Agenda · sin exámenes');

    // Session lobby
    final repo = live.FakeRepo();
    final session = LiveSession(sessionId: 's1', myUserId: 'me', repo: repo, voice: SilentVoiceService(), content: live.FixedExams(_exam('C1', 'c1-work-and-technology')));
    addTearDown(session.dispose);
    await tester.runAsync(session.start);
    repo.rows.add(SessionRow(
      id: 's1', level: Level.c1, examId: 'c1-work-and-technology', userA: 'partner', userB: 'me', state: SessionState.lobby,
      lobbyDeadline: repo.serverNow.add(const Duration(minutes: 4, seconds: 12)), readyA: true, leaderId: 'me', proA: true, proB: true,
    ));
    // The session listens in the real zone: let it load the partner and the material.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await _alone(tester, LobbyView(session: session, myName: 'laura_m', myLanguages: const ['es', 'en'], onLeave: () {}));
    await _shot(tester, 'Sala de espera (lobby)');

    // The exam (leader with Pro, so the control dock shows)
    final exam = _exam('B2', 'b2-community-life');
    final timeline = buildTimeline(exam);
    const t0 = 1000000;
    var now = t0;
    final ctl = LocalExamController(
      exam: exam,
      media: const ExamMedia(),
      myRole: Role.a,
      startedAtMs: t0,
      partnerName: 'marta.eng',
      catalog: const [],
      loadExam: (_, _) async => null,
      loadMedia: (_) async => const ExamMedia(),
      now: () => now,
    );
    addTearDown(ctl.dispose);
    int speakOf(int part) => timeline.segments.firstWhere((s) => s.part == part && s.phase == Phase.speak).startMs + 4000;
    for (final (at, title) in [
      (speakOf(1), 'Examen · Parte 1'),
      (speakOf(2), 'Examen · Parte 2'),
      (speakOf(3), 'Examen · Parte 3'),
      (speakOf(4), 'Examen · Parte 4'),
      (timeline.totalMs + 20000, 'Feedback'),
    ]) {
      now = t0 + at;
      await _alone(
        tester,
        ExamScreen(
          engine: ctl.engine,
          myName: 'laura_m',
          partnerName: 'marta.eng',
          nowMs: () => now,
          control: ctl,
          onAbandon: () async {},
          onExit: () {},
        ),
      );
      await _shot(tester, title);
    }

    // Part 3 diagram alone (D-049): the longest C1 texts, and the text at 200 % (top and bottom).
    final diagram = Diagram.fromJson(
        jsonDecode(File('assets/content/diagrams/c1-e06-the-cost-of-fashion.json').readAsStringSync()) as Map<String, Object?>);
    for (final (scale, decision, bottom, title) in [
      (1.0, false, false, 'Parte 3 · C1, discusión'),
      (1.0, true, false, 'Parte 3 · C1, decisión'),
      (2.0, false, false, 'Texto al 200 % · arriba'),
      (2.0, false, true, 'Texto al 200 % · abajo'),
    ]) {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await _alone(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: BubbleDiagram(diagram: diagram, showDecision: decision),
                ),
              ),
            ),
          ),
        ),
      );
      if (bottom) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await _settle(tester, rounds: 2);
      }
      await _shot(tester, title);
    }

    // Contact sheets, several screens per image
    final byTitle = {for (final s in _shots) s.$1: s};
    List<(String, ui.Image)> pick(List<String> titles) => [for (final t in titles) byTitle[t]!];
    await tester.runAsync(() async {
      final suffix = _dark ? ' · modo oscuro' : '';
      await _sheet('01-acceso-e-inicio.png', 'Acceso e inicio$suffix',
          pick(['Inicio de sesión', 'Registro (onboarding)', 'Inicio', 'Buscando pareja']));
      await _sheet('02-agenda-y-cuenta.png', 'Agenda y cuenta$suffix', pick(['Agenda', 'Agenda · sin exámenes', 'Chat de una reunión', 'Perfil', 'Ajustes']));
      await _sheet('03-sesion-y-examen.png', 'Sala de espera y examen$suffix',
          pick(['Sala de espera (lobby)', 'Examen · Parte 1', 'Examen · Parte 2', 'Examen · Parte 3']));
      await _sheet('04-examen-final.png', 'Final del examen$suffix', pick(['Examen · Parte 4', 'Feedback']));
      await _sheet('05-diagrama-parte-3.png', 'Diagrama de la Parte 3$suffix',
          pick(['Parte 3 · C1, discusión', 'Parte 3 · C1, decisión', 'Texto al 200 % · arriba', 'Texto al 200 % · abajo']));
    });
    debugDisableShadows = true; // the binding checks it is restored
  }, skip: !Env.fromDefines.hasBackend);
}

/// Report/block does nothing here; it only has to exist so the menus are drawn.
class _FakeSafety implements SafetyRepository {
  @override
  Future<void> report(String userId, ReportReason reason, {String? details, required ReportContext context, String? sessionId, String? chatId}) async {}
  @override
  Future<void> block(String userId) async {}
  @override
  Future<void> unblock(String userId) async {}
  @override
  Future<List<String>> blocked() async => const [];
}
