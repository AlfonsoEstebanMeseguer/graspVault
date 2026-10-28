// The exam itself: lobby lead, Parts 1-4 and feedback, rendered from
// ExamEngine snapshots. Online and offline sessions use this same screen; only
// the clock and the callbacks change (see practice_screen.dart for offline).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../core/ui/pico.dart';
import '../../data/content/content_repository.dart';
import '../../data/profile/avatar_repository.dart' show AvatarSource;
import '../../domain/exam/control.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';
import '../../domain/feedback/peer_rating.dart';
import '../../data/safety/safety_repository.dart' show ReportContext;
import '../../domain/agenda/agenda.dart' show CompanionLink;
import 'control/control_panel.dart';
import 'control/exam_control.dart';
import 'reader_player.dart';
import 'widgets/bubble_diagram.dart';
import 'widgets/exam_widgets.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({
    super.key,
    required this.engine,
    required this.myName,
    required this.partnerName,
    required this.nowMs,
    required this.onAbandon,
    required this.onExit,
    this.partnerLeft = false,
    this.simulatedPartner = false,
    this.selfMuted = false,
    this.onToggleMute,
    this.onDebugSkip,
    this.readerFiles = const {},
    this.photoFiles = const {},
    this.myAvatar,
    this.partnerAvatar,
    this.control,
    this.onRate,
    this.onReport,
    this.companion,
  });

  final ExamEngine engine;
  final String myName;
  final String partnerName;

  /// Profile photos for the candidate cards; null (offline practice) = initials.
  final AvatarSource? myAvatar;
  final AvatarSource? partnerAvatar;

  /// Server-aligned clock in a live session, local clock offline.
  final int Function() nowMs;
  final Future<void> Function() onAbandon;
  final VoidCallback onExit;
  final bool partnerLeft;
  final bool simulatedPartner;

  /// The user's own mute (live sessions only; offline there is no mic).
  final bool selfMuted;
  final VoidCallback? onToggleMute;

  /// Debug builds only: jump to the next segment (D-031).
  final VoidCallback? onDebugSkip;

  /// Examiner audio downloaded for this exam (stepId -> file, D-033).
  final Map<String, String> readerFiles;

  /// Part 2 photo id -> downloaded image; missing ones show their caption.
  final Map<String, String> photoFiles;

  /// Pro exam controls (D-039); null = nobody leads this exam.
  final ExamControlHandle? control;

  /// Saves the private feedback rubric for the partner (live sessions only).
  final Future<void> Function(PeerRating rating)? onRate;

  /// Report or block the partner (live sessions only, D-044).
  final void Function(ReportContext where)? onReport;

  /// "Añadir a compañeros" / "Repetir con…" at the end (live sessions only, D-046).
  final CompanionHandle? companion;

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

/// What the end of a live exam can do with the partner (D-046).
class CompanionHandle {
  const CompanionHandle({required this.status, required this.add, required this.repeat});
  final Future<CompanionLink> Function() status;
  final Future<CompanionLink> Function() add;

  /// Leaves the session and opens the invitation to this partner.
  final VoidCallback repeat;
}

class _ExamScreenState extends ConsumerState<ExamScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late ExamSnapshot _snap;
  int? _lastSegment;
  bool _timerVisible = true;
  bool _textVisible = true;
  Diagram? _diagram;

  ExamEngine get _engine => widget.engine;
  // Created up front: a lazy field first touched in dispose() would use ref
  // after unmount (screen opened and closed in the feedback, never playing).
  late final ReaderPlayer _player;

  int _lastNotice = 0;

  /// The live snapshot for the "More" sheet, which outlives a single build.
  late final ValueNotifier<ExamSnapshot> _snapNotifier = ValueNotifier(_snap);

  @override
  void initState() {
    super.initState();
    _player = ref.read(readerPlayerFactoryProvider)(widget.readerFiles);
    _snap = _engine.at(widget.nowMs());
    _ticker = createTicker((_) => _onTick())..start();
    _lastNotice = widget.control?.notice?.id ?? 0;
    widget.control?.addListener(_onControl);
  }

  @override
  void didUpdateWidget(ExamScreen old) {
    super.didUpdateWidget(old);
    if (old.control != widget.control) {
      old.control?.removeListener(_onControl);
      widget.control?.addListener(_onControl);
    }
    // A control moved the clock or the timeline (or a debug skip): re-cue the
    // reader even if the segment index is the same (repeat question).
    if (old.engine != widget.engine) {
      _lastSegment = null;
      _snap = _engine.at(widget.nowMs());
    }
  }

  /// Toast for what the leader did, once per notice.
  void _onControl() {
    final n = widget.control?.notice;
    if (!mounted) return;
    setState(() {});
    if (n == null || n.id == _lastNotice) return;
    _lastNotice = n.id;
    if (n.byMe && n.op != 'transfer') return;
    final l = context.l10n;
    final text = switch (n.op) {
      'transfer' => widget.control!.iAmLeader ? l.noticeLeaderYou : l.noticeLeader(n.actorName),
      'pause' => l.noticePause(n.actorName),
      'resume' => l.noticeResume(n.actorName),
      'skip_reader' => l.noticeSkipReader(n.actorName),
      'next_step' => l.noticeNextStep(n.actorName),
      'prev_step' => l.noticePrevStep(n.actorName),
      'next_part' => l.noticeNextPart(n.actorName),
      'end_exam' => l.noticeEndExam(n.actorName),
      'repeat_step' => l.noticeRepeat(n.actorName),
      'go_to_part' => l.noticeGoToPart(n.actorName),
      'switch_exam' => l.noticeSwitchExam(n.actorName),
      _ => l.noticeTime(n.actorName),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _onTick() {
    final next = _engine.at(widget.nowMs());
    final changedSegment = next.segment?.index != _lastSegment;
    // Rebuild on segment change or when the visible second changes; not every frame.
    if (changedSegment ||
        (next.phase.remainingMs ~/ 1000) != (_snap.phase.remainingMs ~/ 1000) ||
        next.state != _snap.state ||
        (next.startsInMs ~/ 1000) != (_snap.startsInMs ~/ 1000) ||
        next.paused != _snap.paused) {
      if (next.paused && !_snap.paused) unawaited(_player.stop());
      if (next.phase.remainingMs <= 10000 && _snap.phase.remainingMs > 10000 && next.phase.remainingMs > 0) {
        HapticFeedback.lightImpact(); // 10 s left: one soft tap, never a blinking alarm
      }
      setState(() => _snap = next);
      _snapNotifier.value = next;
    }
    if (changedSegment) {
      _lastSegment = next.segment?.index;
      final cue = _engine.readerCue(next);
      final player = _player;
      // A jump may land outside the reader while the previous file still plays.
      unawaited(player.stop());
      if (cue != null) {
        unawaited(player.play(cue.step, Duration(milliseconds: cue.offsetMs)));
      }
      final id = _engine.diagramId(next);
      if (id != null && _diagram?.id != id) {
        unawaited(
          ref.read(contentRepositoryProvider).diagram(id).then((d) {
            if (mounted) setState(() => _diagram = d);
          }),
        );
      }
    }
  }

  @override
  void dispose() {
    widget.control?.removeListener(_onControl);
    _ticker.dispose();
    _snapNotifier.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _abandon() async {
    if (await showAbandonSheet(context, partnerName: widget.partnerName)) {
      await widget.onAbandon();
    }
  }

  ParticipantInfo _info(Role r) => r == _engine.myRole
      ? ParticipantInfo(name: widget.myName, role: r, isMe: true, avatar: widget.myAvatar)
      : ParticipantInfo(name: widget.partnerName, role: r, isMe: false, avatar: widget.partnerAvatar);

  bool get _leader => widget.control?.iAmLeader ?? false;

  /// How far into the current part (for the progress segment), 0..1.
  double _partFraction() {
    final seg = _snap.segment;
    if (seg == null) return 0;
    final segs = _engine.timeline.segments.where((s) => s.part == seg.part);
    final start = segs.first.startMs, end = segs.last.endMs;
    return end <= start ? 0 : (_snap.elapsedMs - start) / (end - start);
  }

  void _openMore() => showExamMoreSheet(
        context,
        control: widget.control!,
        snap: _snapNotifier,
        exam: _engine.exam,
        onAbandon: _abandon,
        onReport: widget.onReport == null ? null : () => widget.onReport!(ReportContext.exam),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    if (widget.partnerLeft) return _Message(text: l.partnerLeft, action: l.backHome, onAction: widget.onExit, mood: PicoMood.listen);
    if (_snap.state == SessionState.ended) {
      return _Message(
        text: l.examFinished,
        action: l.backHome,
        onAction: widget.onExit,
        mood: PicoMood.celebrate,
        extra: widget.companion == null ? null : _CompanionCard(handle: widget.companion!, partnerName: widget.partnerName),
      );
    }
    if (_snap.state == SessionState.feedback) {
      return _Feedback(
        remainingMs: _snap.phase.remainingMs,
        totalMs: _engine.feedbackEndsAtMs - (_engine.examStartedAtMs + _engine.timeline.totalMs),
        summary: l.examSummaryLine(_engine.exam.level.code, _engine.exam.topic, (_engine.timeline.totalMs / 60000).round()),
        partnerName: widget.partnerName,
        partnerRole: _engine.myRole.other,
        onEnd: widget.onExit,
        onRate: widget.onRate,
        onReport: widget.onReport == null ? null : () => widget.onReport!(ReportContext.feedback),
        companion: widget.companion,
        dock: _leader ? FeedbackDock(control: widget.control!) : null,
      );
    }
    if (_snap.pauseReason == 'switching') return _Switching(text: l.switchingExam);

    final part = _snap.part!;
    final step = _snap.step!;
    final seg = _snap.segment!;
    final lead = _snap.startsInMs > 0;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 12, AppSpace.screen, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExamHeader(
                partIndex: part.index,
                title: part.title,
                remainingMs: lead ? _snap.startsInMs : _snap.phase.remainingMs,
                totalMs: lead ? 3000 : seg.durationMs,
                partFraction: _partFraction(),
                paused: _snap.paused,
                timerVisible: _timerVisible,
                onToggleTimer: () => setState(() => _timerVisible = !_timerVisible),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_snap.paused) _pausedBanner(),
                    if (lead)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(l.startingIn((_snap.startsInMs / 1000).ceil()),
                            textAlign: TextAlign.center, style: AppType.body.copyWith(color: p.textSecondary)),
                      ),
                    if (widget.simulatedPartner)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(widget.control == null ? l.simulatedPartnerHint : l.simulatedVipHint,
                            style: AppType.footnote.copyWith(color: p.textTertiary, fontWeight: FontWeight.w400)),
                      ),
                    // "Page turn" between parts: the body slides in from the right.
                    AnimatedSwitcher(
                      duration: AppMotion.part,
                      switchInCurve: AppMotion.curve,
                      transitionBuilder: (child, a) => MediaQuery.of(context).disableAnimations
                          ? FadeTransition(opacity: a, child: child)
                          : SlideTransition(
                              position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(a),
                              child: FadeTransition(opacity: a, child: child),
                            ),
                      child: KeyedSubtree(key: ValueKey(part.index), child: _partBody(part, step)),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              _bottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _partBody(Part part, ExamStep step) {
    final l = context.l10n;
    final p = context.palette;
    final me = _engine.myRole;
    final owner = _snap.turnOwner;
    final reader = _snap.readerSpeaking;
    final children = <Widget>[];
    final micA = _snap.paused || _snap.phase.mic.forRole(Role.a);
    final micB = _snap.paused || _snap.phase.mic.forRole(Role.b);

    String? listening(Role r) => owner != null && owner != r ? l.statusListening : null;

    if (part.index <= 2) {
      children.add(CandidateStrip(
        a: _info(Role.a),
        b: _info(Role.b),
        activeA: owner == Role.a,
        activeB: owner == Role.b,
        micA: micA,
        micB: micB,
        statusA: listening(Role.a),
        statusB: listening(Role.b),
      ));
      if (owner == me) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: TurnChip(key: ValueKey('turn-${_snap.segment?.index}'), text: l.yourTurnNow, color: p.role(me))),
        ));
      } else if (owner != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: Text(l.listeningTo(widget.partnerName),
                style: AppType.footnote.copyWith(color: p.textSecondary, fontSize: 14)),
          ),
        ));
      }
    }

    if (part.index == 2) {
      final assets = _engine.visibleAssets(_snap);
      if (assets.isNotEmpty) {
        final ownerName = _photoOwner(part, step) == me ? l.you : widget.partnerName;
        final caption = switch (assets.length) {
          1 => l.describesPhoto(ownerName),
          2 => l.comparesPhotos(ownerName),
          _ => l.choosesTwoPhotos(ownerName),
        };
        children.addAll([
          const SizedBox(height: 14),
          PhotoGrid(assets: assets, files: widget.photoFiles),
          const SizedBox(height: 6),
          Text(caption, textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textSecondary)),
        ]);
      }
    }

    if (part.index == 3) {
      final openSteps = part.steps.where((s) => s.kind == StepKind.open).toList();
      final isDecision = openSteps.length > 1 && step.id == openSteps.last.id;
      if (openSteps.length > 1) {
        children.add(AppSegmented<bool>(
          height: 46,
          items: [
            SegmentItem(false, l.discussionPhase((openSteps.first.durationSec / 60).round()), dot: !isDecision ? p.link : null),
            SegmentItem(true, l.decisionPhase((openSteps.last.durationSec / 60).round()), dot: isDecision ? p.link : null),
          ],
          selected: isDecision,
          onChanged: null,
        ));
        children.add(const SizedBox(height: 12));
      }
      children.add(CandidateStrip(a: _info(Role.a), b: _info(Role.b), activeA: !reader, activeB: !reader, micA: micA, micB: micB));
      children.add(const SizedBox(height: 14));
      if (_diagram != null) children.add(BubbleDiagram(diagram: _diagram!, showDecision: isDecision));
    }

    if (part.index == 4) {
      children.add(CandidateStrip(a: _info(Role.a), b: _info(Role.b), activeA: !reader, activeB: !reader, micA: micA, micB: micB));
    }

    children.add(const SizedBox(height: 14));
    children.add(QuestionCard(
      text: step.text,
      visible: _textVisible,
      speaking: reader && !_snap.paused,
      onToggle: () => setState(() => _textVisible = !_textVisible),
      title: part.index == 2 ? l.examinerQuestion : null,
      addressee: part.index == 4 ? _addressee(step) : null,
    ));
    if (part.index == 4) {
      final idx = part.steps.indexWhere((s) => s.id == step.id);
      final left = part.steps.skip(idx + 1).where((s) => s.kind == StepKind.open).length;
      children.add(Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(l.questionsLeft(left), textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textTertiary)),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  Role _photoOwner(Part part, ExamStep step) {
    final idx = part.steps.indexWhere((s) => s.id == step.id);
    for (var i = idx; i >= 0; i--) {
      final s = part.steps[i];
      if (s.assets.isNotEmpty) return s.target == Target.a ? Role.a : Role.b;
    }
    return Role.a;
  }

  String? _addressee(ExamStep step) {
    final l = context.l10n;
    return switch (step.target) {
      Target.both => l.addressedToBoth,
      Target.a => _engine.myRole == Role.a ? l.addressedToYou : l.addressedTo(widget.partnerName),
      Target.b => _engine.myRole == Role.b ? l.addressedToYou : l.addressedTo(widget.partnerName),
      null => null,
    };
  }

  Widget _pausedBanner() {
    final p = context.palette;
    final l = context.l10n;
    final by = _leader ? l.you : (widget.control?.partnerName ?? '');
    return Padding(
      key: const Key('exam-paused'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Tile(
        color: p.surfaceMuted,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.overlay, shape: BoxShape.circle),
            child: Icon(AppIcons.pause, color: p.textPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.pausedTitle, style: AppType.headline.copyWith(color: p.textPrimary)),
              Text(l.pausedBy(by), style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
            ]),
          ),
          if (_leader)
            FilledButton(
              key: const Key('exam-resume'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => runControl(context, () => widget.control!.control(const Resume())),
              child: Text(l.controlResume),
            ),
        ]),
      ),
    );
  }

  /// Mic line + the dock: the leader's controls, or (everyone else) mute and leave.
  Widget _bottom() {
    final p = context.palette;
    final l = context.l10n;
    final on = _snap.myMicOn && !widget.selfMuted;
    final mic = StatusDot(
      text: widget.selfMuted ? l.micOffShort : (on ? l.micOnShort : l.micListening),
      color: on ? p.success : p.textTertiary,
      style: AppType.headline.copyWith(fontSize: 15),
    );
    final c = widget.control;
    final leaderInfo = c != null && c.hasLeader
        ? Row(key: const Key('exam-leader'), mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.crown, size: 15, color: p.pro),
            const SizedBox(width: 6),
            Flexible(
              child: Text(c.iAmLeader ? l.leaderYou : l.leaderOther(c.partnerName),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.footnote.copyWith(color: p.textSecondary)),
            ),
          ])
        : null;
    final mute = widget.onToggleMute == null
        ? null
        : RoundIconButton(
            key: const Key('exam-mute'),
            tooltip: widget.selfMuted ? l.unmuteMe : l.muteMe,
            icon: widget.selfMuted ? AppIcons.micOff : AppIcons.mic,
            color: widget.selfMuted ? p.danger : p.textPrimary,
            onPressed: widget.onToggleMute,
          );
    final debug = widget.onDebugSkip == null
        ? null
        : RoundIconButton(key: const Key('exam-debug-skip'), tooltip: l.debugSkip, icon: AppIcons.next, onPressed: widget.onDebugSkip);

    if (_leader) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Row(children: [
            Expanded(child: mic),
            Icon(AppIcons.crown, size: 15, color: p.pro),
            const SizedBox(width: 6),
            Flexible(child: Text(l.dockTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.footnote.copyWith(color: p.textSecondary))),
            if (mute != null) ...[const SizedBox(width: 8), mute],
            if (debug != null) ...[const SizedBox(width: 8), debug],
          ]),
        ),
        LeaderDock(control: c!, snap: _snap, exam: _engine.exam, onMore: _openMore),
      ]);
    }
    return Glass(
      radius: 40,
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            mic,
            if (leaderInfo != null) Padding(padding: const EdgeInsets.only(top: 2), child: leaderInfo),
          ]),
        ),
        if (mute != null) ...[const SizedBox(width: 8), mute],
        if (debug != null) ...[const SizedBox(width: 8), debug],
        if (widget.onReport != null) ...[
          const SizedBox(width: 8),
          RoundIconButton(
            key: const Key('exam-report'),
            tooltip: l.reportOrBlock,
            icon: AppIcons.report,
            onPressed: () => widget.onReport!(ReportContext.exam),
          ),
        ],
        const SizedBox(width: 8),
        RoundIconButton(key: const Key('exam-abandon'), tooltip: l.abandon, icon: AppIcons.leave, color: p.danger, onPressed: _abandon),
      ]),
    );
  }
}

class _Feedback extends StatefulWidget {
  const _Feedback({
    required this.remainingMs,
    required this.totalMs,
    required this.summary,
    required this.partnerName,
    required this.partnerRole,
    required this.onEnd,
    this.onRate,
    this.onReport,
    this.companion,
    this.dock,
  });
  final int remainingMs;
  final int totalMs;
  final String summary;
  final String partnerName;
  final Role partnerRole;
  final VoidCallback onEnd;
  final Future<void> Function(PeerRating rating)? onRate;
  final VoidCallback? onReport;
  final CompanionHandle? companion;

  /// The leader's controls (more feedback time, back to the exam); null for the others.
  final Widget? dock;

  @override
  State<_Feedback> createState() => _FeedbackState();
}

class _FeedbackState extends State<_Feedback> {
  var _rating = const PeerRating();

  void _rate(Criterion c, int v) {
    setState(() => _rating = _rating.withScore(c, v));
    HapticFeedback.selectionClick();
    final save = widget.onRate;
    if (save != null) {
      save(_rating).catchError((Object e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context.l10n, e))));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final ideas = [l.feedbackIdea1, l.feedbackIdea2, l.feedbackIdea3];
    final frac = widget.totalMs <= 0 ? 0.0 : (widget.remainingMs / widget.totalMs).clamp(0.0, 1.0);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    const _DoneMedal(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.examFinished, style: AppType.title1.copyWith(fontSize: 28, color: p.textPrimary)),
                        Text(widget.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(color: p.textSecondary)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  Tile(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Overline(l.feedbackTime),
                          const SizedBox(height: 4),
                          StatusDot(text: l.micsOpenBoth, color: p.success, style: AppType.body),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(value: frac, minHeight: 6, color: p.link, backgroundColor: p.overlay),
                          ),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Text(formatShort(widget.remainingMs), style: AppType.timer.copyWith(fontSize: 40, height: 1, color: p.textPrimary)),
                    ]),
                  ),
                  const SizedBox(height: 22),
                  Text(l.feedbackIdeasTitle, style: AppType.title2.copyWith(color: p.textPrimary)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: ideas.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => SizedBox(
                        width: MediaQuery.sizeOf(context).width * 0.68,
                        child: i == 0
                            ? PaperCard(
                                label: '${i + 1} / ${ideas.length}',
                                child: Text(ideas[i], maxLines: 4, overflow: TextOverflow.ellipsis, style: AppType.question.copyWith(fontSize: 18, height: 1.3, color: p.onPaper)),
                              )
                            : Tile(
                                color: p.surfaceMuted,
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Overline('${i + 1} / ${ideas.length}'),
                                  const SizedBox(height: 10),
                                  Text(ideas[i], maxLines: 4, overflow: TextOverflow.ellipsis, style: AppType.question.copyWith(fontSize: 18, height: 1.3, color: p.textPrimary)),
                                ]),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Rubric(
                    partnerName: widget.partnerName,
                    color: p.role(widget.partnerRole),
                    rating: _rating,
                    onRate: _rate,
                  ),
                  if (widget.companion != null) ...[
                    const SizedBox(height: 14),
                    _CompanionCard(handle: widget.companion!, partnerName: widget.partnerName),
                  ],
                  if (widget.onReport != null)
                    Center(
                      child: TextButton.icon(
                        key: const Key('feedback-report'),
                        style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                        onPressed: widget.onReport,
                        icon: const Icon(AppIcons.report, size: 16),
                        label: Text(l.reportPartner(widget.partnerName)),
                      ),
                    ),
                ]),
              ),
            ),
            if (widget.dock != null) ...[const SizedBox(height: 10), widget.dock!],
            const SizedBox(height: 10),
            FilledButton(key: const Key('feedback-end'), onPressed: widget.onEnd, child: Text(l.endFeedback)),
          ]),
        ),
      ),
    );
  }
}

/// The clay "done" medal.
class _DoneMedal extends StatelessWidget {
  const _DoneMedal();
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [Color.lerp(p.success, Colors.white, 0.35)!, p.success, Color.lerp(p.success, Colors.black, 0.25)!],
          stops: const [0, 0.6, 1],
        ),
        boxShadow: [BoxShadow(color: p.success.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Icon(AppIcons.check, color: p.onRole, size: 30),
    );
  }
}

/// "Valora a marta": the four Cambridge criteria, five dots each. Private.
class _Rubric extends StatelessWidget {
  const _Rubric({required this.partnerName, required this.color, required this.rating, required this.onRate});
  final String partnerName;
  final Color color;
  final PeerRating rating;
  final void Function(Criterion c, int v) onRate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final names = {
      Criterion.grammar: l.criterionGrammar,
      Criterion.discourse: l.criterionDiscourse,
      Criterion.pronunciation: l.criterionPronunciation,
      Criterion.interaction: l.criterionInteraction,
    };
    return Tile(
      key: const Key('feedback-rubric'),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.ratePartner(partnerName), style: AppType.headline.copyWith(fontSize: 19, color: p.textPrimary)),
        const SizedBox(height: 2),
        Row(children: [
          Icon(AppIcons.lock, size: 13, color: p.textTertiary),
          const SizedBox(width: 4),
          Flexible(child: Text(l.onlyTheySee(partnerName), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.footnote.copyWith(color: p.textTertiary))),
        ]),
        const SizedBox(height: 6),
        for (final c in Criterion.values)
          Row(children: [
            Expanded(child: Text(names[c]!, style: AppType.body.copyWith(color: p.textPrimary))),
            for (var v = PeerRating.min; v <= PeerRating.max; v++)
              Semantics(
                button: true,
                selected: (rating.of(c) ?? 0) >= v,
                label: '${names[c]}: $v / ${PeerRating.max}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: Key('rate-${c.name}-$v'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onRate(c, v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: (rating.of(c) ?? 0) >= v ? color : p.overlay),
                    ),
                  ),
                ),
              ),
          ]),
      ]),
    );
  }
}

class _Switching extends StatelessWidget {
  const _Switching({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text, key: const Key('exam-switching'), textAlign: TextAlign.center, style: AppType.body.copyWith(color: context.palette.textPrimary)),
          ]),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action, required this.onAction, this.mood = PicoMood.idle, this.extra});
  final String text;
  final String action;
  final VoidCallback onAction;
  final PicoMood mood;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Pico(size: 150, mood: mood)),
            const SizedBox(height: 20),
            Text(text, textAlign: TextAlign.center, style: AppType.title1.copyWith(color: p.textPrimary)),
            if (extra != null) ...[const SizedBox(height: 20), extra!],
            const SizedBox(height: 28),
            FilledButton(onPressed: onAction, child: Text(action)),
          ]),
        ),
      ),
    );
  }
}

/// "¿Repetiríais?": add the partner to my companions; once both have, repeat with them.
class _CompanionCard extends StatefulWidget {
  const _CompanionCard({required this.handle, required this.partnerName});
  final CompanionHandle handle;
  final String partnerName;
  @override
  State<_CompanionCard> createState() => _CompanionCardState();
}

class _CompanionCardState extends State<_CompanionCard> {
  CompanionLink? _link;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.handle.status().then((v) {
      if (mounted) setState(() => _link = v);
    }, onError: (Object _) {
      if (mounted) setState(() => _link = CompanionLink.none);
    });
  }

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      final v = await widget.handle.add();
      if (mounted) setState(() => _link = v);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context.l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final link = _link;
    if (link == null) return const SizedBox(height: 48);
    final name = widget.partnerName;
    return Tile(
      key: const Key('companion-card'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          switch (link) {
            CompanionLink.none => l.companionPrompt(name),
            CompanionLink.waiting => l.companionAdded(name),
            CompanionLink.mutual => l.companionMutual(name),
          },
          style: AppType.body.copyWith(color: p.textPrimary),
        ),
        if (link == CompanionLink.none) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('companion-add'),
            onPressed: _busy ? null : _add,
            icon: const Icon(AppIcons.plus, size: 18),
            label: Text(l.addCompanion),
          ),
        ],
        if (link == CompanionLink.mutual) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('companion-repeat'),
            onPressed: widget.handle.repeat,
            icon: const Icon(AppIcons.repeat, size: 18),
            label: Text(l.repeatWith(name)),
          ),
        ],
      ]),
    );
  }
}
