import 'dart:async';
import 'package:speaking_p2p/domain/feedback/peer_rating.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/voice/voice_service.dart';
import 'package:speaking_p2p/data/session/session_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/control.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';
import 'package:speaking_p2p/features/session/live_session.dart';

class FakeRepo implements SessionRepository {
  final rows = StreamController<SessionRow>.broadcast();
  final ratings = <PeerRating>[];
  @override
  Future<void> rate(String sessionId, PeerRating rating) async => ratings.add(rating);
  final flags = <String>[];
  int ticks = 0;
  String? abortedWith;
  DateTime serverNow = DateTime.utc(2026, 10, 15, 18);

  @override
  Stream<SessionRow> watch(String sessionId) => rows.stream;
  final controls = <String>[];

  @override
  Future<JoinResult> join(String sessionId, {int? contentVersion}) async =>
      JoinResult(token: 'tok', url: 'wss://x', role: Role.b, serverNow: serverNow);
  @override
  Future<DateTime> tick(String sessionId) async {
    ticks++;
    return serverNow;
  }

  @override
  Future<void> setFlag(String sessionId, String flag, bool value) async => flags.add('$flag=$value');
  @override
  Future<void> abort(String sessionId, {String reason = 'left'}) async => abortedWith = reason;
  @override
  Future<void> skip(String sessionId) async {}
  @override
  Future<void> control(String sessionId, {required String op, Map<String, Object?> args = const {}, required int expectedVersion}) async =>
      controls.add('$op@$expectedVersion$args');
  @override
  Future<PublicProfile?> publicProfile(String userId) async =>
      PublicProfile(id: userId, username: 'dani_r', languages: const ['es', 'en']);
}

class FixedExams implements ExamSource {
  FixedExams(this.value);
  final Exam? value;
  @override
  Future<Exam?> exam(Level level, String id) async => value;
}

/// Any id resolves to the B2 content under that id (to follow an exam switch).
class AnyExam implements ExamSource {
  @override
  Future<Exam?> exam(Level level, String id) async {
    final e = _b2();
    return Exam(id: id, level: e.level, version: e.version, topic: id, parts: e.parts);
  }
}

Exam _b2() => Exam.fromJson(jsonDecode(File('assets/content/exams/B2/b2-community-life.json').readAsStringSync()) as Map<String, Object?>);

SessionRow row(SessionState s, {DateTime? started, String? abortedBy}) => SessionRow(
      id: 's1', level: Level.b2, examId: 'b2-community-life', userA: 'partner', userB: 'me',
      state: s, examStartedAt: started, abortedBy: abortedBy);

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeRepo repo;
  late SilentVoiceService voice;
  late int localNow;
  late LiveSession s;

  setUp(() {
    repo = FakeRepo();
    voice = SilentVoiceService();
    localNow = DateTime.utc(2026, 10, 15, 18).millisecondsSinceEpoch - 2000; // device 2 s behind
    s = LiveSession(
      sessionId: 's1', myUserId: 'me', repo: repo, voice: voice, content: FixedExams(_b2()),
      clock: ServerClock(() => localNow), tickEvery: const Duration(hours: 1),
    );
  });
  tearDown(() => s.dispose());

  test('el reloj se alinea con el servidor y se entra a la voz con el token del servidor', () async {
    await s.start();
    expect(s.clock.offsetMs, 2000);
    expect(s.myRole, Role.b);
    expect(voice.joinedWith, 'tok');
  });

  test('precarga una sola vez en el lobby y crea el motor cuando el servidor arranca', () async {
    await s.start();
    repo.rows.add(row(SessionState.lobby));
    await settle();
    repo.rows.add(row(SessionState.lobby));
    await settle();
    expect(repo.flags, ['preloaded=true']);
    expect(s.partner?.username, 'dani_r');
    expect(s.engine, isNull);
    final started = DateTime.utc(2026, 10, 15, 18, 0, 3);
    repo.rows.add(row(SessionState.part1, started: started));
    await settle();
    expect(s.engine, isNotNull);
    expect(s.engine!.myRole, Role.b);
  });

  test('un salto de debug mueve exam_started_at y el motor se rehace con la nueva hora', () async {
    await s.start();
    final started = DateTime.utc(2026, 10, 15, 18);
    repo.rows.add(row(SessionState.part1, started: started));
    await settle();
    final first = s.engine;
    final skipped = started.subtract(const Duration(seconds: 7));
    repo.rows.add(row(SessionState.part1, started: skipped));
    await settle();
    expect(identical(s.engine, first), isFalse);
    expect(s.engine!.examStartedAtMs, skipped.millisecondsSinceEpoch);
  });

  test('silenciarse solo toca mi micro y se puede deshacer', () async {
    await s.start();
    await s.toggleMute();
    expect(s.selfMuted, isTrue);
    expect(voice.selfMuted, isTrue);
    await s.toggleMute();
    expect(voice.selfMuted, isFalse);
  });

  test('latido: un tick por frontera de segmento, no por cada vuelta del temporizador', () async {
    await s.start();
    final started = DateTime.utc(2026, 10, 15, 18);
    repo.rows.add(row(SessionState.part1, started: started));
    await settle();
    final segs = s.engine!.timeline.segments;
    localNow = started.millisecondsSinceEpoch - s.clock.offsetMs + 100;
    s.tickNow();
    s.tickNow();
    expect(repo.ticks, 1);
    localNow = started.millisecondsSinceEpoch - s.clock.offsetMs + segs[1].startMs + 10;
    s.tickNow();
    s.tickNow();
    expect(repo.ticks, 2);
  });

  test('el compañero abandona: partnerLeft y se cuelga la voz', () async {
    await s.start();
    repo.rows.add(row(SessionState.aborted, abortedBy: 'partner'));
    await settle();
    expect(s.partnerLeft, isTrue);
    expect(s.closed, isTrue);
  });

  test('si esta build no trae el examen elegido, se aborta con content_missing', () async {
    s.dispose();
    s = LiveSession(sessionId: 's1', myUserId: 'me', repo: repo, voice: voice, content: FixedExams(null),
        clock: ServerClock(() => localNow), tickEvery: const Duration(hours: 1));
    await s.start();
    repo.rows.add(row(SessionState.lobby));
    await settle();
    await settle();
    expect(repo.abortedWith, 'content_missing');
    expect((s.error as AppFailure).code, 'content_missing');
  });

  group('control Pro (D-038/D-039)', () {
    final started = DateTime.utc(2026, 10, 15, 18);
    SessionRow pro({String exam = 'b2-community-life', DateTime? paused, int version = 0, Map<String, Object?>? last, String? reason}) =>
        SessionRow(
          id: 's1', level: Level.b2, examId: exam, userA: 'partner', userB: 'me', state: SessionState.part1,
          examStartedAt: started, leaderId: 'me', proA: true, proB: true, pausedAt: paused,
          pauseReason: paused == null ? null : (reason ?? 'leader'), controlVersion: version, lastControl: last,
        );

    test('líder, compañero Pro y el control viaja con la versión que vio el móvil', () async {
      await s.start();
      repo.rows.add(pro(version: 4));
      await settle();
      expect(s.iAmLeader, isTrue);
      expect(s.partnerIsPro, isTrue);
      await s.control(const Extend(60000));
      await s.switchExam(null);
      expect(repo.controls, ['extend@4{deltaMs: 60000}', 'switch_exam@4{}']);
    });

    test('la pausa del servidor congela el motor', () async {
      await s.start();
      repo.rows.add(pro());
      await settle();
      final first = s.engine;
      final pausedAt = started.add(const Duration(seconds: 30));
      repo.rows.add(pro(paused: pausedAt, version: 1));
      await settle();
      expect(identical(s.engine, first), isFalse, reason: 'nueva versión de control: motor nuevo');
      final a = s.engine!.at(pausedAt.millisecondsSinceEpoch + 1000);
      final b = s.engine!.at(pausedAt.millisecondsSinceEpoch + 90000);
      expect(a.paused, isTrue);
      expect(b.phase.remainingMs, a.phase.remainingMs);
    });

    test('cambio de examen: carga el nuevo, descarga su material y avisa de la precarga', () async {
      s.dispose();
      s = LiveSession(sessionId: 's1', myUserId: 'me', repo: repo, voice: voice, content: AnyExam(),
          clock: ServerClock(() => localNow), tickEvery: const Duration(hours: 1));
      await s.start();
      repo.rows.add(pro());
      await settle();
      repo.flags.clear();
      repo.rows.add(pro(exam: 'b2-e02-social-media-and-friendship', paused: started, version: 1, reason: 'switching'));
      await settle();
      await settle();
      expect(s.exam!.id, 'b2-e02-social-media-and-friendship');
      expect(s.engine!.exam.id, 'b2-e02-social-media-and-friendship');
      expect(s.engine!.at(started.millisecondsSinceEpoch).pauseReason, 'switching');
      expect(repo.flags, ['preloaded=true'], reason: 'el servidor espera a los dos');
    });

    test('aviso por cada acción nueva del líder, nunca por la que ya estaba al entrar', () async {
      await s.start();
      repo.rows.add(pro(last: {'op': 'next_part', 'by': 'partner', 'at': '1'}));
      await settle();
      expect(s.notice, isNull);
      repo.rows.add(pro(version: 1, last: {'op': 'pause', 'by': 'partner', 'at': '2'}));
      await settle();
      expect(s.notice?.op, 'pause');
      expect(s.notice?.byMe, isFalse);
      expect(s.notice?.actorName, 'dani_r');
    });
  });
}
