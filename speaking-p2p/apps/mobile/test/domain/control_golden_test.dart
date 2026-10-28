// The Pro controls contract (D-039): the Dart reducer must produce exactly what
// content/fixtures/control-golden.json says. The SQL suite reads the same file
// (07_session_control.sql), so both sides of the session agree.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/exam/control.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';

Map<String, Object?> _read(String rel) =>
    jsonDecode(File('../../content/fixtures/$rel').readAsStringSync()) as Map<String, Object?>;

ControlOp _op(String name, Map<String, Object?> args, Timeline timeline) => switch (name) {
      'pause' => const Pause(),
      'resume' => const Resume(),
      'skip_reader' => const SkipReader(),
      'next_step' => const NextStep(),
      'prev_step' => const PrevStep(),
      'next_part' => const NextPart(),
      'end_exam' => const EndExam(),
      'repeat_step' => const RepeatStep(),
      'go_to_part' => GoToPart(args['part']! as int),
      'extend' => Extend(args['deltaMs']! as int),
      'set_part_speak' => SetPartSpeak(args['ms']! as int),
      'switch_exam' => SwitchExam(args['examId']! as String, timeline),
      'finish_switch' => const FinishSwitch(),
      _ => throw ArgumentError(name),
    };

void main() {
  final timeline = Timeline.fromJson(_read('timeline-golden.json')['timeline']! as Map<String, Object?>);
  final golden = _read('control-golden.json');

  test('la línea temporal sobrevive a JSON', () {
    final again = Timeline.fromJson(jsonDecode(jsonEncode(timeline.toJson())) as Map<String, Object?>);
    expect(jsonEncode(again.toJson()), jsonEncode(timeline.toJson()));
  });

  test('cada control da lo mismo que el fixture', () {
    var s = ControlState.start(golden['examId']! as String, timeline, golden['startedAtMs']! as int);
    for (final (i, c) in (golden['cases']! as List<Object?>).cast<Map<String, Object?>>().indexed) {
      final now = c['nowMs']! as int;
      final op = _op(c['op']! as String, (c['args']! as Map).cast<String, Object?>(), timeline);
      final e = (c['expect']! as Map).cast<String, Object?>();
      final why = 'caso $i (${c['op']})';
      if (e['error'] != null) {
        expect(() => applyControl(s, op, now), throwsA(isA<ControlError>().having((x) => x.code, 'code', e['error'])), reason: why);
        continue;
      }
      s = applyControl(s, op, now);
      expect(s.startedAtMs, e['startedAtMs'], reason: why);
      expect(s.pausedAtMs, e['pausedAtMs'], reason: why);
      expect(s.pauseReason, e['pauseReason'], reason: why);
      expect(s.timeline.totalMs, e['totalMs'], reason: why);
      expect(s.feedbackEndsAtMs, e['feedbackEndsAtMs'], reason: why);
      expect(s.version, e['version'], reason: why);
      if (e['examId'] != null) expect(s.examId, e['examId'], reason: why);
      if (e['durationsMs'] != null) {
        expect([for (final x in s.timeline.segments) x.durationMs], e['durationsMs'], reason: why);
      }
      final phase = phaseAt(s.timeline, s.elapsedAt(now), feedbackEndMs: s.feedbackEndsAtMs - s.startedAtMs);
      expect(phase.state.name, e['state'], reason: why);
      expect(phase.segment?.index, e['segment'], reason: why);
    }
  });
}
