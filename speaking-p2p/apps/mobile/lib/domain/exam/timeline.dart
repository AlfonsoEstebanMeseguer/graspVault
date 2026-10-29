// Dart mirror of _shared/exam/timeline.ts. Both implementations are pinned by
// content/fixtures/timeline-golden.json (test/domain/timeline_golden_test.dart):
// change one without the other and CI goes red.
import 'models.dart';

const readerGapMs = 600;
const feedbackMs = 5 * 60 * 1000;
const lobbyMs = 5 * 60 * 1000;

enum Phase { reader, speak }

class Mic {
  const Mic(this.a, this.b);
  final bool a;
  final bool b;
  static const muted = Mic(false, false);
  static const open = Mic(true, true);

  bool forRole(Role r) => r == Role.a ? a : b;

  @override
  bool operator ==(Object other) => other is Mic && other.a == a && other.b == b;
  @override
  int get hashCode => Object.hash(a, b);
  @override
  String toString() => 'Mic(A: $a, B: $b)';
}

class Segment {
  const Segment({
    required this.index,
    required this.part,
    required this.stepId,
    required this.kind,
    required this.phase,
    required this.target,
    required this.startMs,
    required this.endMs,
    required this.mic,
  });

  final int index;
  final int part;
  final String stepId;
  final StepKind kind;
  final Phase phase;
  final Target? target;
  final int startMs;
  final int endMs;
  final Mic mic;

  int get durationMs => endMs - startMs;

  Segment withRange(int start, int end) => Segment(
        index: index, part: part, stepId: stepId, kind: kind, phase: phase,
        target: target, startMs: start, endMs: end, mic: mic,
      );

  Map<String, Object?> toJson() => {
        'index': index,
        'part': part,
        'stepId': stepId,
        'kind': kind.name,
        'phase': phase.name,
        'target': switch (target) { Target.a => 'A', Target.b => 'B', Target.both => 'both', null => null },
        'startMs': startMs,
        'endMs': endMs,
        'mic': {'A': mic.a, 'B': mic.b},
      };

  factory Segment.fromJson(Map<String, Object?> j) {
    final mic = j['mic']! as Map<String, Object?>;
    return Segment(
      index: j['index']! as int,
      part: j['part']! as int,
      stepId: j['stepId']! as String,
      kind: StepKind.values.byName(j['kind']! as String),
      phase: Phase.values.byName(j['phase']! as String),
      target: switch (j['target']) { 'A' => Target.a, 'B' => Target.b, 'both' => Target.both, _ => null },
      startMs: j['startMs']! as int,
      endMs: j['endMs']! as int,
      mic: Mic(mic['A']! as bool, mic['B']! as bool),
    );
  }
}

class Timeline {
  const Timeline(this.segments, this.totalMs);
  final List<Segment> segments;
  final int totalMs;

  /// The shape of exam_catalog.timeline / exam_sessions.schedule. A live
  /// session reads the server copy: the leader may have changed durations (D-039).
  Map<String, Object?> toJson() => {'segments': [for (final s in segments) s.toJson()], 'totalMs': totalMs};

  factory Timeline.fromJson(Map<String, Object?> j) => Timeline(
        List.unmodifiable([for (final s in (j['segments']! as List<Object?>)) Segment.fromJson(s! as Map<String, Object?>)]),
        j['totalMs']! as int,
      );

  /// Same segments with new durations, laid out back to back from 0.
  Timeline withDurations(List<int> durations) {
    var t = 0;
    final out = <Segment>[];
    for (var i = 0; i < segments.length; i++) {
      out.add(segments[i].withRange(t, t + durations[i]));
      t += durations[i];
    }
    return Timeline(List.unmodifiable(out), t);
  }
}

Mic micFor(ExamStep step, Phase phase) {
  if (phase == Phase.reader || step.kind == StepKind.narration) return Mic.muted;
  if (step.kind == StepKind.turn) return Mic(step.target == Target.a, step.target == Target.b);
  return Mic.open;
}

Timeline buildTimeline(Exam exam) {
  final segments = <Segment>[];
  var t = 0;
  void push(int part, ExamStep step, Phase phase, int durationMs) {
    if (durationMs <= 0) return;
    segments.add(Segment(
      index: segments.length,
      part: part,
      stepId: step.id,
      kind: step.kind,
      phase: phase,
      target: step.target,
      startMs: t,
      endMs: t + durationMs,
      mic: micFor(step, phase),
    ));
    t += durationMs;
  }

  for (final part in exam.parts) {
    for (final step in part.steps) {
      push(part.index, step, Phase.reader, step.audioMs + readerGapMs);
      if (step.kind != StepKind.narration) push(part.index, step, Phase.speak, step.durationSec * 1000);
    }
  }
  return Timeline(List.unmodifiable(segments), t);
}

enum SessionState { lobby, part1, part2, part3, part4, feedback, ended, aborted }

class PhaseAt {
  const PhaseAt._(this.state, this.segment, this.remainingMs);
  final SessionState state;

  /// Null in feedback / ended.
  final Segment? segment;

  /// Remaining of the whole STEP (reader + speaking window) in parts, of the
  /// feedback in feedback, 0 when ended.
  final int remainingMs;

  Mic get mic => switch (state) {
        SessionState.feedback || SessionState.lobby => Mic.open,
        SessionState.ended || SessionState.aborted => Mic.muted,
        _ => segment!.mic,
      };
}

/// [feedbackEndMs] is the elapsed instant at which the feedback ends; by
/// default 5 min after the parts, but the leader can stretch it (D-039).
PhaseAt phaseAt(Timeline timeline, int elapsedMs, {int? feedbackEndMs}) {
  final e = elapsedMs < 0 ? 0 : elapsedMs;
  final fbEnd = feedbackEndMs ?? timeline.totalMs + feedbackMs;
  if (e >= fbEnd) return const PhaseAt._(SessionState.ended, null, 0);
  if (e >= timeline.totalMs) {
    return PhaseAt._(SessionState.feedback, null, fbEnd - e);
  }
  var lo = 0, hi = timeline.segments.length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (timeline.segments[mid].startMs <= e) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final seg = timeline.segments[lo];
  var stepEnd = seg.endMs;
  if (lo + 1 < timeline.segments.length && timeline.segments[lo + 1].stepId == seg.stepId) {
    stepEnd = timeline.segments[lo + 1].endMs;
  }
  return PhaseAt._(SessionState.values[seg.part], seg, stepEnd - e);
}
