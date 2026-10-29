// What the exam screen shows at a given instant. Pure: no Flutter, no timers.
// `nowMs` must be SERVER time (local clock + measured offset) in a live session;
// in offline practice it is the local clock. No independent local stopwatch.
import 'models.dart';
import 'timeline.dart';

class ExamSnapshot {
  const ExamSnapshot({
    required this.phase,
    required this.myRole,
    required this.startsInMs,
    required this.elapsedMs,
    this.part,
    this.step,
    this.pauseReason,
  });

  final PhaseAt phase;
  final Role myRole;

  /// > 0 during the short lead before Part 1.
  final int startsInMs;
  final int elapsedMs;
  final Part? part;
  final ExamStep? step;

  /// 'leader' (paused by the leader) or 'switching' (loading another exam); null = running.
  final String? pauseReason;
  bool get paused => pauseReason != null;

  SessionState get state => phase.state;
  Segment? get segment => phase.segment;
  bool get readerSpeaking => segment?.phase == Phase.reader;
  /// While paused both mics are open: a pause is free conversation (D-039).
  bool get myMicOn => paused || phase.mic.forRole(myRole);
  bool get partnerMicOn => paused || phase.mic.forRole(myRole.other);

  /// Turn steps (Parts 1-2) in their speaking window: whose turn it is.
  Role? get turnOwner {
    final s = segment;
    if (s == null || s.kind != StepKind.turn || s.phase != Phase.speak) return null;
    return s.target == Target.a ? Role.a : Role.b;
  }
}

class ExamEngine {
  /// [timeline] is the session's copy when the leader may have changed it
  /// (live: exam_sessions.schedule); by default the exam's own. While
  /// [pausedAtMs] is set the clock stands still at that instant (D-039).
  ExamEngine({
    required this.exam,
    required this.myRole,
    required this.examStartedAtMs,
    Timeline? timeline,
    this.pausedAtMs,
    this.pauseReason,
    this._feedbackEndsAtMs,
  }) : timeline = timeline ?? buildTimeline(exam);

  final Exam exam;
  final Role myRole;
  final int examStartedAtMs;
  final Timeline timeline;
  final int? pausedAtMs;
  final String? pauseReason;
  final int? _feedbackEndsAtMs;

  int get feedbackEndsAtMs => _feedbackEndsAtMs ?? examStartedAtMs + timeline.totalMs + feedbackMs;

  ExamSnapshot at(int nowMs) {
    final paused = pausedAtMs != null;
    final elapsed = (pausedAtMs ?? nowMs) - examStartedAtMs;
    final phase = phaseAt(timeline, elapsed, feedbackEndMs: feedbackEndsAtMs - examStartedAtMs);
    final seg = phase.segment;
    return ExamSnapshot(
      phase: phase,
      myRole: myRole,
      startsInMs: elapsed < 0 && !paused ? -elapsed : 0,
      elapsedMs: elapsed,
      part: seg == null ? null : exam.parts[seg.part - 1],
      step: seg == null ? null : exam.step(seg.stepId),
      pauseReason: paused ? (pauseReason ?? 'leader') : null,
    );
  }

  /// Reader audio to start when entering a reader segment, with the offset a
  /// late client must skip so both devices hear the same word at the same time.
  /// Null if there is nothing (left) to play.
  ({ExamStep step, int offsetMs})? readerCue(ExamSnapshot snap) {
    final seg = snap.segment;
    if (seg == null || seg.phase != Phase.reader || snap.startsInMs > 0 || snap.paused) return null;
    final offset = snap.elapsedMs - seg.startMs;
    final step = snap.step!;
    if (offset >= step.audioMs) return null;
    return (step: step, offsetMs: offset < 0 ? 0 : offset);
  }

  /// Photos visible in Part 2: those of the current turn, or of the last turn
  /// that had them (the partner's follow-up question keeps showing them).
  List<String> visibleAssets(ExamSnapshot snap) {
    final part = snap.part;
    if (part == null || part.index != 2) return const [];
    final idx = part.steps.indexWhere((s) => s.id == snap.step!.id);
    for (var i = idx; i >= 0; i--) {
      if (part.steps[i].assets.isNotEmpty) return part.steps[i].assets;
    }
    return const [];
  }

  /// Part 3 diagram: the first open step of the part that declares one.
  String? diagramId(ExamSnapshot snap) {
    final part = snap.part;
    if (part == null || part.index != 3) return null;
    return part.steps.map((s) => s.diagram).whereType<String>().firstOrNull;
  }
}
