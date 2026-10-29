// Pro exam controls (DECISIONS D-039): pure, no Flutter, no clock of its own.
// The SQL twin is svc_session_control; both are pinned by
// content/fixtures/control-golden.json (test/domain/control_golden_test.dart).
//
// The rule stays "the exam is a function of the clock": pausing freezes the
// clock, jumping moves startedAt, changing minutes rewrites the session's own
// timeline (never the catalog).
import 'timeline.dart';

const minSpeakMs = 10 * 1000;
const maxSpeakMs = 15 * 60 * 1000;
const maxFeedbackMs = 20 * 60 * 1000;

/// Lead before the new exam starts once both phones have its material.
const switchLeadMs = 3000;
const allowedExtendMs = {-30000, 30000, 60000, 120000};

class ControlError implements Exception {
  const ControlError(this.code);
  final String code;
  @override
  String toString() => 'ControlError($code)';
}

class ControlState {
  const ControlState({
    required this.examId,
    required this.timeline,
    required this.startedAtMs,
    required this.feedbackEndsAtMs,
    this.pausedAtMs,
    this.pauseReason,
    this.version = 0,
  });

  /// A fresh exam starting at [startedAtMs] with the default 5 min feedback.
  factory ControlState.start(String examId, Timeline timeline, int startedAtMs) => ControlState(
        examId: examId,
        timeline: timeline,
        startedAtMs: startedAtMs,
        feedbackEndsAtMs: startedAtMs + timeline.totalMs + feedbackMs,
      );

  final String examId;
  final Timeline timeline;
  final int startedAtMs;
  final int feedbackEndsAtMs;
  final int? pausedAtMs;

  /// 'leader' or 'switching'.
  final String? pauseReason;
  final int version;

  int elapsedAt(int nowMs) => (pausedAtMs ?? nowMs) - startedAtMs;
  int get feedbackLenMs => feedbackEndsAtMs - startedAtMs - timeline.totalMs;

  ControlState _next({
    String? examId,
    Timeline? timeline,
    int? startedAtMs,
    int? feedbackEndsAtMs,
    required int? pausedAtMs,
    required String? pauseReason,
  }) =>
      ControlState(
        examId: examId ?? this.examId,
        timeline: timeline ?? this.timeline,
        startedAtMs: startedAtMs ?? this.startedAtMs,
        feedbackEndsAtMs: feedbackEndsAtMs ?? this.feedbackEndsAtMs,
        pausedAtMs: pausedAtMs,
        pauseReason: pauseReason,
        version: version + 1,
      );
}

sealed class ControlOp {
  const ControlOp();

  /// Wire name, shared with the Edge Function and SQL.
  String get name;
  Map<String, Object?> get args => const {};
}

class Pause extends ControlOp {
  const Pause();
  @override
  String get name => 'pause';
}

class Resume extends ControlOp {
  const Resume();
  @override
  String get name => 'resume';
}

class SkipReader extends ControlOp {
  const SkipReader();
  @override
  String get name => 'skip_reader';
}

class NextStep extends ControlOp {
  const NextStep();
  @override
  String get name => 'next_step';
}

class NextPart extends ControlOp {
  const NextPart();
  @override
  String get name => 'next_part';
}

/// Back to the previous question (from the feedback: the last one).
class PrevStep extends ControlOp {
  const PrevStep();
  @override
  String get name => 'prev_step';
}

class EndExam extends ControlOp {
  const EndExam();
  @override
  String get name => 'end_exam';
}

class RepeatStep extends ControlOp {
  const RepeatStep();
  @override
  String get name => 'repeat_step';
}

class GoToPart extends ControlOp {
  const GoToPart(this.part);
  final int part;
  @override
  String get name => 'go_to_part';
  @override
  Map<String, Object?> get args => {'part': part};
}

class Extend extends ControlOp {
  const Extend(this.deltaMs);
  final int deltaMs;
  @override
  String get name => 'extend';
  @override
  Map<String, Object?> get args => {'deltaMs': deltaMs};
}

/// Duration of the current speaking window and of the later ones of the same
/// part with the same kind and the same duration (e.g. "Part 2 long turns").
class SetPartSpeak extends ControlOp {
  const SetPartSpeak(this.ms);
  final int ms;
  @override
  String get name => 'set_part_speak';
  @override
  Map<String, Object?> get args => {'ms': ms};
}

class SwitchExam extends ControlOp {
  const SwitchExam(this.examId, this.timeline);
  final String examId;
  final Timeline timeline;
  @override
  String get name => 'switch_exam';
  @override
  Map<String, Object?> get args => {'examId': examId};
}

/// Not sent by the leader: the server (or the practice controller) starts the
/// new exam once both phones have its material.
class FinishSwitch extends ControlOp {
  const FinishSwitch();
  @override
  String get name => 'finish_switch';
}

ControlState applyControl(ControlState s, ControlOp op, int nowMs) {
  final switching = s.pauseReason == 'switching';
  if (op is FinishSwitch) {
    if (!switching) throw const ControlError('not_switching');
    final start = nowMs + switchLeadMs;
    return s._next(startedAtMs: start, feedbackEndsAtMs: start + s.timeline.totalMs + feedbackMs, pausedAtMs: null, pauseReason: null);
  }
  if (switching) throw const ControlError('switching');

  final e = s.elapsedAt(nowMs);
  final total = s.timeline.totalMs;
  final fbEndElapsed = s.feedbackEndsAtMs - s.startedAtMs;
  if (e >= fbEndElapsed) throw const ControlError('not_in_exam');
  final inFeedback = e >= total;
  final idx = inFeedback ? -1 : _segmentAt(s.timeline, e);
  final seg = idx < 0 ? null : s.timeline.segments[idx];

  void requirePart() {
    if (seg == null) throw const ControlError('not_in_part');
  }

  ControlState jump(int target) {
    final start = nowMs - target;
    return s._next(startedAtMs: start, feedbackEndsAtMs: start + total + s.feedbackLenMs, pausedAtMs: null, pauseReason: null);
  }

  final segs = s.timeline.segments;
  switch (op) {
    case Pause():
      requirePart();
      if (s.pausedAtMs != null) throw const ControlError('already_paused');
      if (e < 0) throw const ControlError('not_started');
      if (seg!.phase != Phase.speak) throw const ControlError('reader_speaking');
      return s._next(pausedAtMs: nowMs, pauseReason: 'leader');
    case Resume():
      if (s.pauseReason != 'leader') throw const ControlError('not_paused');
      final shift = nowMs - s.pausedAtMs!;
      return s._next(startedAtMs: s.startedAtMs + shift, feedbackEndsAtMs: s.feedbackEndsAtMs + shift, pausedAtMs: null, pauseReason: null);
    case SkipReader():
      requirePart();
      if (seg!.phase != Phase.reader) throw const ControlError('not_reader');
      return jump(seg.endMs);
    case NextStep():
      requirePart();
      final next = segs.skip(idx + 1).where((x) => x.stepId != seg!.stepId).firstOrNull;
      return jump(next?.startMs ?? total);
    case NextPart():
      requirePart();
      final next = segs.skip(idx + 1).where((x) => x.part > seg!.part).firstOrNull;
      return jump(next?.startMs ?? total);
    case PrevStep():
      final String prevId;
      if (seg == null) {
        prevId = segs.last.stepId;
      } else {
        final first = segs.firstWhere((x) => x.stepId == seg.stepId).index;
        if (first == 0) throw const ControlError('out_of_range');
        prevId = segs[first - 1].stepId;
      }
      return jump(segs.firstWhere((x) => x.stepId == prevId).startMs);
    case EndExam():
      requirePart();
      return jump(total);
    case RepeatStep():
      requirePart();
      return jump(segs.firstWhere((x) => x.stepId == seg!.stepId).startMs);
    case GoToPart(:final part):
      final first = segs.where((x) => x.part == part).firstOrNull;
      if (first == null) throw const ControlError('out_of_range');
      return jump(first.startMs);
    case Extend(:final deltaMs):
      if (!allowedExtendMs.contains(deltaMs)) throw const ControlError('bad_delta');
      if (inFeedback) {
        final len = s.feedbackLenMs + deltaMs;
        // Never above 20 min, never ending within the next 5 s.
        if (len > maxFeedbackMs || s.feedbackEndsAtMs + deltaMs - (s.pausedAtMs ?? nowMs) < 5000) {
          throw const ControlError('out_of_range');
        }
        return s._next(feedbackEndsAtMs: s.feedbackEndsAtMs + deltaMs, pausedAtMs: s.pausedAtMs, pauseReason: s.pauseReason);
      }
      final k = _speakTarget(s.timeline, idx);
      return _resize(s, {k: segs[k].durationMs + deltaMs}, e, idx);
    case SetPartSpeak(:final ms):
      requirePart();
      final k = _speakTarget(s.timeline, idx);
      final ref = segs[k];
      final sizes = <int, int>{
        for (final x in segs.skip(k))
          if (x.part == ref.part && x.phase == Phase.speak && x.kind == ref.kind && x.durationMs == ref.durationMs) x.index: ms,
      };
      return _resize(s, sizes, e, idx);
    case SwitchExam(:final examId, :final timeline):
      if (e < 0) throw const ControlError('not_started');
      return s._next(
        examId: examId,
        timeline: timeline,
        startedAtMs: nowMs,
        feedbackEndsAtMs: nowMs + timeline.totalMs + feedbackMs,
        pausedAtMs: nowMs,
        pauseReason: 'switching',
      );
    case FinishSwitch():
      throw StateError('handled above');
  }
}

/// The last segment whose start is <= elapsed (lead time counts as segment 0).
int _segmentAt(Timeline t, int elapsed) {
  var i = 0;
  for (final s in t.segments) {
    if (s.startMs <= (elapsed < 0 ? 0 : elapsed)) i = s.index;
  }
  return i;
}

/// The speaking window the time controls act on: the current one, or the one
/// that follows the reader of the same step. A narration has none.
int _speakTarget(Timeline t, int idx) {
  if (idx < 0) throw const ControlError('not_in_part');
  final seg = t.segments[idx];
  if (seg.phase == Phase.speak) return idx;
  if (idx + 1 < t.segments.length && t.segments[idx + 1].stepId == seg.stepId) return idx + 1;
  throw const ControlError('out_of_range');
}

ControlState _resize(ControlState s, Map<int, int> sizes, int elapsed, int idx) {
  final durations = [for (final x in s.timeline.segments) sizes[x.index] ?? x.durationMs];
  for (final MapEntry(key: k, value: d) in sizes.entries) {
    if (d < minSpeakMs || d > maxSpeakMs) throw const ControlError('out_of_range');
    // The running window may shrink, but must not end in the past.
    if (k == idx && s.timeline.segments[k].startMs + d <= elapsed + 1000) throw const ControlError('out_of_range');
  }
  final timeline = s.timeline.withDurations(durations);
  final delta = timeline.totalMs - s.timeline.totalMs;
  return s._next(timeline: timeline, feedbackEndsAtMs: s.feedbackEndsAtMs + delta, pausedAtMs: s.pausedAtMs, pauseReason: s.pauseReason);
}
