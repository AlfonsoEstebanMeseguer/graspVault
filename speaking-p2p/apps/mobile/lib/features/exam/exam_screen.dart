// The exam itself: lobby lead, Parts 1-4 and feedback, rendered from
// ExamEngine snapshots. Online and offline sessions use this same screen; only
// the clock and the callbacks change (see practice_screen.dart for offline).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/content/content_repository.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';
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
  });

  final ExamEngine engine;
  final String myName;
  final String partnerName;

  /// Server-aligned clock in a live session, local clock offline.
  final int Function() nowMs;
  final Future<void> Function() onAbandon;
  final VoidCallback onExit;
  final bool partnerLeft;
  final bool simulatedPartner;

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late ExamSnapshot _snap;
  int? _lastSegment;
  bool _timerVisible = true;
  bool _textVisible = true;
  Diagram? _diagram;

  ExamEngine get _engine => widget.engine;

  @override
  void initState() {
    super.initState();
    _snap = _engine.at(widget.nowMs());
    _ticker = createTicker((_) => _onTick())..start();
  }

  void _onTick() {
    final next = _engine.at(widget.nowMs());
    final changedSegment = next.segment?.index != _lastSegment;
    // Rebuild on segment change or when the visible second changes; not every frame.
    if (changedSegment || (next.phase.remainingMs ~/ 1000) != (_snap.phase.remainingMs ~/ 1000) ||
        next.state != _snap.state || (next.startsInMs ~/ 1000) != (_snap.startsInMs ~/ 1000)) {
      setState(() => _snap = next);
    }
    if (changedSegment) {
      _lastSegment = next.segment?.index;
      final cue = _engine.readerCue(next);
      final player = ref.read(readerPlayerProvider);
      if (cue != null) {
        unawaited(player.play(cue.step, Duration(milliseconds: cue.offsetMs)));
      }
      final id = _engine.diagramId(next);
      if (id != null && _diagram?.id != id) {
        unawaited(ref.read(contentRepositoryProvider).diagram(id).then((d) {
          if (mounted) setState(() => _diagram = d);
        }));
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _abandon() async {
    if (await showAbandonSheet(context, partnerName: widget.partnerName)) {
      await widget.onAbandon();
    }
  }

  ParticipantInfo _info(Role r) => r == _engine.myRole
      ? ParticipantInfo(name: widget.myName, role: r, isMe: true)
      : ParticipantInfo(name: widget.partnerName, role: r, isMe: false);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    if (widget.partnerLeft) return _Message(text: l.partnerLeft, action: l.backHome, onAction: widget.onExit);
    if (_snap.state == SessionState.ended) return _Message(text: l.examFinished, action: l.backHome, onAction: widget.onExit);
    if (_snap.state == SessionState.feedback) return _Feedback(remainingMs: _snap.phase.remainingMs, onEnd: widget.onExit);

    final part = _snap.part!;
    final step = _snap.step!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ExamHeader(
              partIndex: part.index,
              title: part.title,
              remainingMs: _snap.startsInMs > 0 ? _snap.startsInMs : _snap.phase.remainingMs,
              timerVisible: _timerVisible,
              onToggleTimer: () => setState(() => _timerVisible = !_timerVisible),
            ),
            const SizedBox(height: 12),
            if (_snap.startsInMs > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l.startingIn((_snap.startsInMs / 1000).ceil()),
                    textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
              ),
            if (widget.simulatedPartner)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(l.simulatedPartnerHint, style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ),
            Expanded(child: SingleChildScrollView(child: _partBody(part, step))),
            _footer(),
          ]),
        ),
      ),
    );
  }

  Widget _partBody(Part part, ExamStep step) {
    final l = context.l10n;
    final me = _engine.myRole;
    final owner = _snap.turnOwner;
    final children = <Widget>[];

    if (part.index <= 2 || part.index == 4) {
      if (part.index == 4 && _snap.readerSpeaking) children.add(_examinerBanner());
      children.add(Row(children: [
        for (final r in [Role.a, Role.b]) ...[
          Expanded(
            child: ParticipantCard(
              info: _info(r),
              active: owner == r || (part.index == 4 && !_snap.readerSpeaking),
              micOn: _snap.phase.mic.forRole(r),
              compact: part.index == 2,
            ),
          ),
          if (r == Role.a) const SizedBox(width: 10),
        ],
      ]));
      if (owner == me) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(child: Chip(label: Text(l.yourTurn))),
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
          const SizedBox(height: 12),
          Text(caption, style: TextStyle(color: context.palette.textSecondary)),
          const SizedBox(height: 8),
          PhotoGrid(assets: assets),
        ]);
      }
    }

    if (part.index == 3) {
      final openSteps = part.steps.where((s) => s.kind == StepKind.open).toList();
      final isDecision = openSteps.length > 1 && step.id == openSteps.last.id;
      if (openSteps.length > 1) {
        children.add(Row(children: [
          Expanded(child: _phaseTab(l.discussionPhase((openSteps.first.durationSec / 60).round()), !isDecision)),
          const SizedBox(width: 8),
          Expanded(child: _phaseTab(l.decisionPhase((openSteps.last.durationSec / 60).round()), isDecision)),
        ]));
        children.add(const SizedBox(height: 10));
      }
      children.add(Row(children: [
        for (final r in [Role.a, Role.b]) ...[
          Expanded(child: ParticipantCard(info: _info(r), active: !_snap.readerSpeaking, micOn: _snap.phase.mic.forRole(r), compact: true)),
          if (r == Role.a) const SizedBox(width: 10),
        ],
      ]));
      children.add(const SizedBox(height: 12));
      if (_diagram != null) children.add(BubbleDiagram(diagram: _diagram!, showDecision: isDecision));
    }

    children.add(const SizedBox(height: 12));
    children.add(ExaminerCard(
      text: step.text,
      visible: _textVisible,
      onToggle: () => setState(() => _textVisible = !_textVisible),
      title: part.index == 2 ? l.examinerQuestion : null,
      addressee: part.index == 4 ? _addressee(step) : null,
    ));
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

  Widget _phaseTab(String text, bool active) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? p.timerFill : p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.border),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? p.onTimerFill : p.textSecondary)),
    );
  }

  Widget _examinerBanner() {
    final p = context.palette;
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.examinerSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.graphic_eq, color: p.onExaminerSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.examinerSpeaking, style: TextStyle(fontWeight: FontWeight.w600, color: p.onExaminerSoft)),
            Text(l.bothMuted, style: TextStyle(fontSize: 12, color: p.onExaminerSoft)),
          ]),
        ),
      ]),
    );
  }

  Widget _footer() {
    final p = context.palette;
    final l = context.l10n;
    final on = _snap.myMicOn;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Icon(Icons.circle, size: 10, color: on ? p.success : p.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(on ? l.micOpen : l.micMuted, style: TextStyle(color: on ? p.success : p.textSecondary))),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger)),
          onPressed: _abandon,
          child: Text(l.abandon),
        ),
      ]),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.remainingMs, required this.onEnd});
  final int remainingMs;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 16),
            Icon(Icons.check_circle_outline, size: 48, color: p.success),
            const SizedBox(height: 12),
            Text(l.examFinished, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.textPrimary)),
            Text(l.feedbackSubtitle, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: p.timerFill, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.feedbackTime, style: TextStyle(fontSize: 12, color: p.onTimerFill)),
                    Text(l.micsOpenBoth, style: TextStyle(color: p.onTimerFill, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Text(formatMs(remainingMs),
                    style: TextStyle(color: p.onTimerFill, fontSize: 26, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
              ]),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.feedbackIdeas, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  for (final (i, idea) in [l.feedbackIdea1, l.feedbackIdea2, l.feedbackIdea3].indexed)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('${i + 1}  $idea', style: TextStyle(color: p.textPrimary)),
                    ),
                ]),
              ),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: p.onDanger),
              onPressed: onEnd,
              child: Text(l.endCall),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action, required this.onAction});
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(action)),
          ]),
        ),
      ),
    );
  }
}
