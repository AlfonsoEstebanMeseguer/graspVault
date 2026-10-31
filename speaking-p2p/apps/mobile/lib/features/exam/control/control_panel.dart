// The leader's controls (Pro, D-039), Design 2.0: a floating glass dock like
// a podcast player — VIP · ⏮ previous · ⏯ pause · ⏭ skip · ↺ repeat · More,
// the same while the examiner reads and while the candidates speak (D-058).
// "More" is a sheet with go to part, time, turn length, switch exam, hand
// over and end. Plus the exam catalog.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/errors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theming/palette.dart';
import '../../../core/theming/tokens.dart';
import '../../../core/ui/kit.dart';
import '../../../data/content/content_repository.dart';
import '../../../domain/exam/control.dart';
import '../../../domain/exam/engine.dart';
import '../../../domain/exam/models.dart';
import '../../../domain/exam/timeline.dart';
import 'exam_control.dart';

const _turnLengths = [30000, 45000, 60000, 90000, 120000, 180000];
const _deltas = [(-30000, '−0:30'), (30000, '+0:30'), (60000, '+1:00'), (120000, '+2:00')];

/// Runs [action] and reports a refusal (reader speaking, out of range…) as a toast.
Future<void> runControl(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  try {
    await action();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
  }
}

String _mmss(int ms) => '${ms ~/ 60000}:${((ms % 60000) ~/ 1000).toString().padLeft(2, '0')}';

/// The leader's dock under the exam (parts 1-4): a 72 px glass capsule.
class LeaderDock extends StatelessWidget {
  const LeaderDock({
    super.key,
    required this.control,
    required this.snap,
    required this.exam,
    required this.onMore,
  });

  final ExamControlHandle control;
  final ExamSnapshot snap;
  final Exam exam;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final reader = snap.readerSpeaking;
    void send(ControlOp op) => runControl(context, () => control.control(op));

    // Pause also silences the examiner; resume carries on where it stopped.
    final (IconData mainIcon, String mainLabel, ControlOp mainOp) =
        snap.paused ? (AppIcons.play, l.controlResume, const Resume()) : (AppIcons.pause, l.controlPause, const Pause());
    // Skip what is running: the examiner's reading (straight to the task), or the task (next question).
    final ControlOp skipOp = reader ? const SkipReader() : const NextStep();

    return Glass(
      key: const Key('leader-dock'),
      radius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Semantics(
          label: l.dockTitle,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.pro.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(AppIcons.crown, size: 20, color: p.pro),
          ),
        ),
        Expanded(child: _DockIcon(key: const Key('dock-prev'), icon: AppIcons.prev, label: l.dockPrev, onPressed: () => send(const PrevStep()))),
        _MainButton(
          key: const Key('dock-pause'),
          icon: mainIcon,
          label: mainLabel,
          onPressed: () {
            HapticFeedback.mediumImpact();
            send(mainOp);
          },
        ),
        Expanded(child: _DockIcon(key: const Key('dock-skip'), icon: AppIcons.next, label: l.dockSkip, onPressed: () => send(skipOp))),
        Expanded(
          child: _DockIcon(key: const Key('dock-repeat'), icon: AppIcons.repeat, label: l.controlRepeat, onPressed: () => send(const RepeatStep())),
        ),
        Semantics(
          button: true,
          label: l.dockMore,
          excludeSemantics: true,
          child: Material(
            color: p.overlay,
            shape: const StadiumBorder(),
            child: InkWell(
              key: const Key('dock-more'),
              customBorder: const StadiumBorder(),
              onTap: onMore,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text(l.dockMore, style: AppType.headline.copyWith(color: p.textPrimary)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DockIcon extends StatelessWidget {
  const _DockIcon({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkResponse(
            onTap: onPressed,
            radius: 28,
            child: SizedBox(height: 56, child: Icon(icon, size: 26, color: context.palette.textPrimary)),
          ),
        ),
      );
}

class _MainButton extends StatelessWidget {
  const _MainButton({super.key, required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: p.inverse,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(dimension: 64, child: Icon(icon, size: 28, color: p.onInverse)),
          ),
        ),
      ),
    );
  }
}

/// The "More" sheet: everything the dock does not show. It follows the live
/// exam through [snap]; navigation closes it, time changes keep it open.
Future<void> showExamMoreSheet(
  BuildContext context, {
  required ExamControlHandle control,
  required ValueListenable<ExamSnapshot> snap,
  required Exam exam,
  required VoidCallback onAbandon,
  VoidCallback? onReport,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.72,
      child: ListenableBuilder(
        listenable: Listenable.merge([snap, control]),
        builder: (context, _) => _More(control: control, snap: snap.value, exam: exam, onAbandon: onAbandon, onReport: onReport),
      ),
    ),
  );
}

class _More extends StatelessWidget {
  const _More({required this.control, required this.snap, required this.exam, required this.onAbandon, this.onReport});
  final ExamControlHandle control;
  final ExamSnapshot snap;
  final Exam exam;
  final VoidCallback onAbandon;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final seg = snap.segment;
    final speak = seg != null && seg.phase == Phase.speak ? seg : null;
    final nav = Navigator.of(context);
    void send(ControlOp op, {bool close = false}) => runControl(context, () async {
          await control.control(op);
          if (close && nav.mounted) nav.pop();
        });

    Widget label(String text) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Overline(text));
    Widget action(Key key, IconData icon, String text, VoidCallback? onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tile(
            key: key,
            color: p.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: onTap,
            child: Row(children: [
              Icon(icon, size: 22, color: onTap == null ? p.textTertiary : (color ?? p.link)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(text,
                    style: AppType.headline.copyWith(fontWeight: FontWeight.w500, color: onTap == null ? p.textTertiary : (color ?? p.textPrimary))),
              ),
            ]),
          ),
        );

    // A Column, not a lazy list: every action exists (and can be found) at once.
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Icon(AppIcons.crown, color: p.pro, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(l.dockTitle, style: AppType.title2.copyWith(color: p.textPrimary))),
      ]),
      label(l.controlNavigation),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(l.controlGoToPart, style: AppType.body.copyWith(color: p.textSecondary)),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var part = 1; part <= 4; part++)
          ChoiceChip(
            key: Key('control-part-$part'),
            label: Text(l.partN(part)),
            selected: seg?.part == part,
            onSelected: (_) => send(GoToPart(part), close: true),
          ),
      ]),
      label(l.controlTurnTime),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (d, text) in _deltas)
          ActionChip(key: Key('control-extend-$d'), avatar: Icon(AppIcons.timer, size: 16, color: p.link), label: Text(text), onPressed: () => send(Extend(d))),
      ]),
      if (speak != null) ...[
        label(l.controlTurnLength),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ms in _turnLengths)
            ChoiceChip(
              key: Key('control-turn-$ms'),
              label: Text(_mmss(ms)),
              selected: speak.durationMs == ms,
              onSelected: (_) => send(SetPartSpeak(ms)),
            ),
        ]),
      ],
      label(l.controlExam),
      action(const Key('control-switch-exam'), AppIcons.books, l.controlSwitchExam, () async {
        final pick = await showExamCatalog(context, level: exam.level, currentId: exam.id);
        if (pick == null || !context.mounted) return;
        await runControl(context, () => control.switchExam(pick.id));
        if (nav.mounted) nav.pop();
      }),
      action(
        const Key('control-transfer'),
        AppIcons.swap,
        control.partnerIsPro ? l.controlTransfer(control.partnerName) : l.controlTransferNoPro(control.partnerName),
        control.partnerIsPro
            ? () => runControl(context, () async {
                  await control.transfer();
                  if (nav.mounted) nav.pop();
                })
            : null,
      ),
      action(const Key('control-end-exam'), AppIcons.flag, l.controlEndExam, () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            content: Text(l.controlEndExamConfirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
              FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: Text(l.controlEndExam)),
            ],
          ),
        );
        if (ok == true) send(const EndExam(), close: true);
      }),
      const SizedBox(height: 12),
      if (onReport != null)
        action(const Key('more-report'), AppIcons.report, l.reportPartner(control.partnerName), () {
          nav.pop();
          onReport!();
        }, color: p.textSecondary),
      action(const Key('exam-abandon'), AppIcons.leave, l.abandon, () {
        nav.pop();
        onAbandon();
      }, color: p.danger),
    ]));
  }
}

/// The leader's controls during the feedback: more (or less) time, or back to the exam.
class FeedbackDock extends StatelessWidget {
  const FeedbackDock({super.key, required this.control});
  final ExamControlHandle control;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    void send(ControlOp op) => runControl(context, () => control.control(op));
    return Tile(
      key: const Key('feedback-dock'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(AppIcons.crown, size: 16, color: p.pro),
          const SizedBox(width: 8),
          Expanded(child: Overline(l.controlFeedbackTime)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (d, text) in _deltas) ActionChip(key: Key('control-extend-$d'), label: Text(text), onPressed: () => send(Extend(d))),
          ActionChip(
            key: const Key('feedback-back'),
            avatar: Icon(AppIcons.prev, size: 14, color: p.link),
            label: Text(l.controlBackToExam),
            onPressed: () => send(const PrevStep()),
          ),
        ]),
      ]),
    );
  }
}

/// `id == null` means random.
typedef ExamPick = ({String? id});

Future<ExamPick?> showExamCatalog(BuildContext context, {required Level level, required String currentId}) {
  return showModalBottomSheet<ExamPick>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: _Catalog(level: level, currentId: currentId)),
  );
}

class _Catalog extends ConsumerStatefulWidget {
  const _Catalog({required this.level, required this.currentId});
  final Level level;
  final String currentId;
  @override
  ConsumerState<_Catalog> createState() => _CatalogState();
}

class _CatalogState extends ConsumerState<_Catalog> {
  late Level _level = widget.level;
  String _query = '';

  Future<void> _pick(ExamPick pick) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.controlSwitchConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(MaterialLocalizations.of(c).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.controlSwitchExam)),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop(pick);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final exams = (ref.watch(contentIndexProvider).value?.exams ?? const <ContentIndexEntry>[])
        .where((e) => e.level == _level && (_query.isEmpty || e.topic.toLowerCase().contains(_query.toLowerCase())))
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.controlSwitchExam, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        SegmentedButton<Level>(
          segments: [for (final lv in Level.values) ButtonSegment(value: lv, label: Text(lv.code))],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: l.controlSearch, isDense: true),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        if (_level == widget.level)
          ListTile(
            key: const Key('catalog-random'),
            leading: const Icon(Icons.shuffle),
            title: Text(l.controlRandom),
            onTap: () => _pick((id: null)),
          ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: exams.length,
            itemBuilder: (_, i) {
              final e = exams[i];
              final current = e.id == widget.currentId;
              return ListTile(
                key: Key('catalog-${e.id}'),
                title: Text(e.topic),
                subtitle: Text(e.id, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                trailing: current ? Chip(label: Text(l.controlCurrent)) : null,
                onTap: current ? null : () => _pick((id: e.id)),
              );
            },
          ),
        ),
      ]),
    );
  }
}
