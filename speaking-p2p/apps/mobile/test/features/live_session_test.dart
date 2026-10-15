import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/voice/voice_service.dart';
import 'package:speaking_p2p/data/session/session_repository.dart';
import 'package:speaking_p2p/domain/account/account.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';
import 'package:speaking_p2p/features/session/live_session.dart';

class FakeRepo implements SessionRepository {
  final rows = StreamController<SessionRow>.broadcast();
  final flags = <String>[];
  int ticks = 0;
  String? abortedWith;
  DateTime serverNow = DateTime.utc(2026, 10, 15, 18);

  @override
  Stream<SessionRow> watch(String sessionId) => rows.stream;
  @override
  Future<JoinResult> join(String sessionId) async =>
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
  Future<PublicProfile?> publicProfile(String userId) async =>
      PublicProfile(id: userId, username: 'dani_r', languages: const ['es', 'en']);
}

class FixedExams implements ExamSource {
  FixedExams(this.value);
  final Exam? value;
  @override
  Future<Exam?> exam(Level level, String id) async => value;
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
}
