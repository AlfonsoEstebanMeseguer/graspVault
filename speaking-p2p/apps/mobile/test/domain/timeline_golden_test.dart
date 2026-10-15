// The cross-language contract: the Dart timeline must produce exactly what the
// TypeScript one wrote into content/fixtures/timeline-golden.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/domain/exam/timeline.dart';

Map<String, Object?> _read(String rel) =>
    jsonDecode(File('../../content/fixtures/$rel').readAsStringSync()) as Map<String, Object?>;

void main() {
  final input = Exam.fromJson(_read('timeline-input.json'));
  final golden = _read('timeline-golden.json');
  final goldenTimeline = golden['timeline']! as Map<String, Object?>;
  final timeline = buildTimeline(input);

  test('mismos segmentos que el servidor', () {
    final expected = (goldenTimeline['segments']! as List<Object?>).cast<Map<String, Object?>>();
    expect(timeline.totalMs, goldenTimeline['totalMs']);
    expect(timeline.segments.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      final s = timeline.segments[i];
      final g = expected[i];
      final mic = g['mic']! as Map<String, Object?>;
      expect(
        [s.index, s.part, s.stepId, s.kind.name, s.phase.name, s.startMs, s.endMs, s.mic.a, s.mic.b],
        [g['index'], g['part'], g['stepId'], g['kind'], g['phase'], g['startMs'], g['endMs'], mic['A'], mic['B']],
        reason: 'segmento $i',
      );
      final target = g['target'];
      expect(s.target == null ? null : (s.target == Target.both ? 'both' : s.target!.name.toUpperCase()), target);
    }
  });

  test('mismo estado en cada sonda', () {
    for (final p in (golden['probes']! as List<Object?>).cast<Map<String, Object?>>()) {
      final r = phaseAt(timeline, p['elapsedMs']! as int);
      expect(r.state.name, p['state'], reason: 'elapsed ${p['elapsedMs']}');
      expect(r.segment?.index, p['segmentIndex'], reason: 'elapsed ${p['elapsedMs']}');
      if (p['remainingMs'] != null) expect(r.remainingMs, p['remainingMs'], reason: 'elapsed ${p['elapsedMs']}');
    }
  });

  test('el contenido empaquetado se parsea entero', () {
    for (final level in ['B1', 'B2', 'C1']) {
      for (final f in Directory('assets/content/exams/$level').listSync().whereType<File>()) {
        final exam = Exam.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, Object?>);
        expect(exam.level.code, level);
        expect(buildTimeline(exam).totalMs, greaterThan(10 * 60 * 1000));
      }
    }
  });
}
