import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/exam/engine.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';

Exam _exam(String level, String id) =>
    Exam.fromJson(jsonDecode(File('assets/content/exams/$level/$id.json').readAsStringSync()) as Map<String, Object?>);

void main() {
  final b2 = _exam('B2', 'b2-community-life');
  const t0 = 1000000;

  Segment firstSpeak(ExamEngine e, {int? part, StepKind? kind}) => e.timeline.segments
      .firstWhere((s) => s.phase == Phase.speak && (part == null || s.part == part) && (kind == null || s.kind == kind));

  test('antes de empezar: cuenta atras y sin audio', () {
    final e = ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0);
    final s = e.at(t0 - 2500);
    expect(s.startsInMs, 2500);
    expect(s.state, SessionState.part1);
    expect(e.readerCue(s), isNull);
    expect(s.myMicOn, isFalse);
  });

  test('el lector arranca con desfase si el cliente llega tarde', () {
    final e = ExamEngine(exam: b2, myRole: Role.b, examStartedAtMs: t0);
    final cue = e.readerCue(e.at(t0 + 1200))!;
    expect(cue.step.id, 'p1-intro');
    expect(cue.offsetMs, 1200);
    // pasado el final del audio (en el hueco) no se reproduce nada
    final seg0 = e.timeline.segments.first;
    expect(e.readerCue(e.at(t0 + seg0.endMs - 1)), isNull);
  });

  test('turno de A: solo A con micro, B lo ve igual', () {
    final seg = firstSpeak(ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0), part: 1);
    for (final role in Role.values) {
      final s = ExamEngine(exam: b2, myRole: role, examStartedAtMs: t0).at(t0 + seg.startMs + 10);
      expect(s.turnOwner, Role.a, reason: 'ambos ven el mismo turno');
      expect(s.myMicOn, role == Role.a);
      expect(s.partnerMicOn, role == Role.b);
    }
  });

  test('parte 2: la pregunta de seguimiento sigue mostrando las fotos del compañero', () {
    final e = ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0);
    final follow = e.timeline.segments.firstWhere((s) => s.stepId == 'p2-a-follow' && s.phase == Phase.speak);
    final s = e.at(t0 + follow.startMs + 5);
    expect(e.visibleAssets(s), ['volunteers-park', 'food-bank']);
    expect(s.turnOwner, Role.b);
  });

  test('parte 3: diagrama y micros abiertos tras el enunciado', () {
    final e = ExamEngine(exam: b2, myRole: Role.b, examStartedAtMs: t0);
    final seg = firstSpeak(e, part: 3);
    final s = e.at(t0 + seg.startMs + 1);
    expect(e.diagramId(s), 'b2-community');
    expect(s.myMicOn && s.partnerMicOn, isTrue);
    final reader = e.at(t0 + seg.startMs - 1);
    expect(reader.readerSpeaking, isTrue);
    expect(reader.myMicOn || reader.partnerMicOn, isFalse, reason: 'mientras lee el lector, los dos mudos');
  });

  test('feedback de 5 min y fin', () {
    final e = ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0);
    expect(e.at(t0 + e.timeline.totalMs).state, SessionState.feedback);
    expect(e.at(t0 + e.timeline.totalMs).myMicOn, isTrue);
    expect(e.at(e.feedbackEndsAtMs).state, SessionState.ended);
  });

  test('pausa del líder: el reloj se para, micros abiertos y sin lector (D-039)', () {
    final seg = firstSpeak(ExamEngine(exam: b2, myRole: Role.b, examStartedAtMs: t0), part: 1);
    final pausedAt = t0 + seg.startMs + 5000;
    final e = ExamEngine(exam: b2, myRole: Role.b, examStartedAtMs: t0, pausedAtMs: pausedAt, pauseReason: 'leader');
    final a = e.at(pausedAt + 1000), b = e.at(pausedAt + 60000);
    expect(a.paused, isTrue);
    expect(b.phase.remainingMs, a.phase.remainingMs, reason: 'el tiempo no corre');
    expect(b.segment!.index, seg.index);
    expect(b.myMicOn && b.partnerMicOn, isTrue, reason: 'la pausa es conversación libre');
    expect(e.readerCue(b), isNull);
  });

  test('feedback alargado por el líder', () {
    final base = ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0);
    final e = ExamEngine(exam: b2, myRole: Role.a, examStartedAtMs: t0, feedbackEndsAtMs: base.feedbackEndsAtMs + 120000);
    expect(e.at(base.feedbackEndsAtMs).state, SessionState.feedback);
    expect(e.at(base.feedbackEndsAtMs + 120000).state, SessionState.ended);
  });
}
