// The five pieces every exam part is built from (Design 2.0 §7.1): part
// progress, header with the ring clock, the A/B candidate strip, the obsidian
// question card and (in control_panel.dart) the leader's dock. Plus Part 2's
// photos and the "leave" sheet.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theming/palette.dart';
import '../../../core/theming/tokens.dart';
import '../../../core/ui/kit.dart';
import '../../../data/content/content_repository.dart';
import '../../../data/profile/avatar_repository.dart' show AvatarSource;
import '../../../domain/exam/models.dart';
import '../../profile/avatar/user_avatar.dart';

String formatMs(int ms) {
  final s = (ms / 1000).ceil().clamp(0, 99 * 60);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "0:42": the ring's short form (minutes without the leading zero).
String formatShort(int ms) {
  final s = (ms / 1000).ceil().clamp(0, 99 * 60);
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Four 4 px segments: done, current (filling with the clock), to come.
class PartProgress extends StatelessWidget {
  const PartProgress({super.key, required this.partIndex, required this.fraction});
  final int partIndex;

  /// How far into the current part, 0..1.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(children: [
      for (var i = 1; i <= 4; i++) ...[
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: i < partIndex ? p.link : p.overlay),
                if (i == partIndex)
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: ColoredBox(color: p.link),
                  ),
              ]),
            ),
          ),
        ),
        if (i < 4) const SizedBox(width: 6),
      ],
    ]);
  }
}

enum ClockState { normal, warn, over, paused }

/// The ring clock (§4.3): empties as time runs; amber in the last 10 s, red
/// "Tiempo" at 0, dashed with a pause icon while paused. Never blinks.
class RingTimer extends StatelessWidget {
  const RingTimer({super.key, required this.remainingMs, required this.totalMs, this.paused = false, this.size = 56, this.hidden = false});
  final int remainingMs;
  final int totalMs;
  final bool paused;
  final double size;

  /// The user hid the clock: an empty ring with a timer icon (tap shows it again).
  final bool hidden;

  ClockState get state => paused
      ? ClockState.paused
      : remainingMs <= 0
          ? ClockState.over
          : remainingMs <= 10000
              ? ClockState.warn
              : ClockState.normal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final st = state;
    final color = switch (st) {
      ClockState.normal => p.link,
      ClockState.warn => p.warn,
      ClockState.over => p.danger,
      ClockState.paused => p.textSecondary,
    };
    final frac = totalMs <= 0 ? 0.0 : (remainingMs / totalMs).clamp(0.0, 1.0);
    final Widget inside = hidden
        ? Icon(AppIcons.eyeOff, size: size * 0.36, color: p.textSecondary)
        : switch (st) {
            ClockState.paused => Icon(AppIcons.pause, size: size * 0.34, color: p.textPrimary),
            ClockState.over => Text(context.l10n.timeUp, style: AppType.timer.copyWith(fontSize: size * 0.22, color: p.danger)),
            _ => Text(formatShort(remainingMs), style: AppType.timer.copyWith(fontSize: size * 0.3, height: 1, color: st == ClockState.warn ? p.warn : p.textPrimary)),
          };
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _Ring(
          fraction: hidden ? 0 : (st == ClockState.over ? 1 : frac),
          color: color,
          track: p.surfaceMuted,
          dashed: st == ClockState.paused,
        ),
        child: Center(child: FittedBox(child: Padding(padding: const EdgeInsets.all(6), child: inside))),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring({required this.fraction, required this.color, required this.track, required this.dashed});
  final double fraction;
  final Color color, track;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (dashed) {
      paint.color = color;
      const n = 16;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(rect, -math.pi / 2 + i * 2 * math.pi / n, 0.18, false, paint);
      }
      return;
    }
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    if (fraction > 0) canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.fraction != fraction || old.color != color || old.dashed != dashed || old.track != track;
}

/// Progress + "PARTE 2 DE 4" + the part's English name + ring clock (tap hides/shows it).
class ExamHeader extends StatelessWidget {
  const ExamHeader({
    super.key,
    required this.partIndex,
    required this.title,
    required this.remainingMs,
    required this.totalMs,
    required this.partFraction,
    required this.timerVisible,
    required this.onToggleTimer,
    this.paused = false,
  });

  final int partIndex;
  final String title;
  final int remainingMs;
  final int totalMs;
  final double partFraction;
  final bool timerVisible;
  final VoidCallback onToggleTimer;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PartProgress(partIndex: partIndex, fraction: partFraction),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline(l.partOf(partIndex)),
            const SizedBox(height: 2),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.title1.copyWith(fontSize: 26, color: p.textPrimary)),
          ]),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          label: timerVisible ? '${l.hideTimer}, ${formatShort(remainingMs)}' : l.showTimer,
          excludeSemantics: true,
          child: Tooltip(
            message: timerVisible ? l.hideTimer : l.showTimer,
            child: GestureDetector(
              key: const Key('exam-timer'),
              onTap: onToggleTimer,
              child: RingTimer(remainingMs: remainingMs, totalMs: totalMs, paused: paused, size: 64, hidden: !timerVisible),
            ),
          ),
        ),
      ]),
    ]);
  }
}

class ParticipantInfo {
  const ParticipantInfo({required this.name, required this.role, required this.isMe, this.avatar});
  final String name;
  final Role role;
  final bool isMe;
  final AvatarSource? avatar;
}

/// One candidate pill (64 high): avatar, "Tú · A", mic state. The speaker gets
/// a 2 px border in their role colour and a voice ring; the muted one fades to 45 %.
class CandidatePill extends StatelessWidget {
  const CandidatePill({super.key, required this.info, required this.active, required this.micOn, this.status});
  final ParticipantInfo info;
  final bool active;
  final bool micOn;

  /// Overrides the mic wording ("Escucha" while the other one has the turn).
  final String? status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final role = p.role(info.role);
    final name = info.isMe ? l.you : info.name;
    final state = status ?? (micOn ? (active ? l.statusSpeaking : l.statusMicOpen) : l.statusMuted);
    return Semantics(
      label: '${l.roleLabel(name, info.role.code)}, $state',
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: AppMotion.smooth,
        opacity: active || micOn ? 1 : 0.45,
        child: AnimatedContainer(
          duration: AppMotion.smooth,
          curve: AppMotion.curve,
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? p.roleSoft(info.role) : p.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: active ? role : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            _VoiceRing(
              active: active && micOn,
              color: role,
              child: UserAvatar(
                name: info.name,
                userId: info.avatar?.userId,
                avatarKey: info.avatar?.key,
                size: 40,
                background: role,
                foreground: p.onRole,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.roleLabel(name, info.role.code),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.headline.copyWith(color: p.textPrimary)),
                Row(children: [
                  Icon(micOn ? AppIcons.mic : AppIcons.micOff, size: 13, color: micOn ? role : p.textTertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(state,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.footnote.copyWith(color: micOn ? role : p.textTertiary, fontWeight: FontWeight.w500)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A soft ring breathing around the speaker's avatar (a fixed border with
/// reduced motion). Without the audio level it breathes at a calm pace.
class _VoiceRing extends StatefulWidget {
  const _VoiceRing({required this.active, required this.color, required this.child});
  final bool active;
  final Color color;
  final Widget child;
  @override
  State<_VoiceRing> createState() => _VoiceRingState();
}

class _VoiceRingState extends State<_VoiceRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_VoiceRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !MediaQuery.of(context).disableAnimations) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withValues(alpha: 0.5 + 0.5 * _c.value), width: 2),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35 * _c.value), blurRadius: 4 + 8 * _c.value)],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A and B side by side. In single-turn parts the active one takes 2/3 of the width.
class CandidateStrip extends StatelessWidget {
  const CandidateStrip({super.key, required this.a, required this.b, required this.activeA, required this.activeB, required this.micA, required this.micB, this.statusA, this.statusB});
  final ParticipantInfo a, b;
  final bool activeA, activeB, micA, micB;
  final String? statusA, statusB;

  @override
  Widget build(BuildContext context) {
    final single = activeA != activeB;
    final fa = single ? (activeA ? 3 : 2) : 1;
    final fb = single ? (activeB ? 3 : 2) : 1;
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final unit = (c.maxWidth - gap) / (fa + fb);
      return Row(children: [
        AnimatedContainer(
          duration: AppMotion.smooth,
          curve: AppMotion.curve,
          width: unit * fa,
          child: CandidatePill(info: a, active: activeA, micOn: micA, status: statusA),
        ),
        const SizedBox(width: gap),
        AnimatedContainer(
          duration: AppMotion.smooth,
          curve: AppMotion.curve,
          width: unit * fb,
          child: CandidatePill(info: b, active: activeB, micOn: micB, status: statusB),
        ),
      ]);
    });
  }
}

/// "Te toca a ti": appears with a small bounce and a light haptic.
class TurnChip extends StatefulWidget {
  const TurnChip({super.key, required this.text, required this.color});
  final String text;
  final Color color;
  @override
  State<TurnChip> createState() => _TurnChipState();
}

class _TurnChipState extends State<TurnChip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(AppIcons.mic, size: 16, color: widget.color),
          const SizedBox(width: 8),
          Text(widget.text, style: AppType.headline.copyWith(fontSize: 15, color: p.textPrimary)),
        ]),
      ),
    );
  }
}

/// What the examiner says, on the obsidian card. The eye hides the text; a wave
/// that follows the reader stays in its place.
class QuestionCard extends StatelessWidget {
  const QuestionCard({
    super.key,
    required this.text,
    required this.visible,
    required this.onToggle,
    required this.speaking,
    this.addressee,
    this.title,
  });

  final String text;
  final bool visible;
  final VoidCallback onToggle;

  /// The reader is playing this step's audio (the orb moves).
  final bool speaking;
  final String? addressee;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final label = [title ?? l.examiner, ?addressee].join(' · ');
    return PaperCard(
      label: null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          speaking ? VoiceBars(active: true, color: p.paperLabel, height: 14) : Icon(AppIcons.speaker, size: 16, color: p.paperLabel),
          const SizedBox(width: 8),
          Expanded(child: Overline(label, color: p.paperLabel)),
          Semantics(
            button: true,
            label: visible ? l.hideText : l.showText,
            excludeSemantics: true,
            child: Tooltip(
              message: visible ? l.hideText : l.showText,
              child: RoundIconButton(
                key: const Key('exam-text-toggle'),
                icon: visible ? AppIcons.eye : AppIcons.eyeOff,
                onPressed: onToggle,
                size: 44,
                color: p.onPaper,
                background: p.paperEdge,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: AppMotion.smooth,
          curve: AppMotion.curve,
          alignment: Alignment.topLeft,
          child: visible
              ? Text(text, style: AppType.question.copyWith(color: p.onPaper))
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    VoiceBars(active: speaking, color: p.paperLabel, height: 26, bars: 9),
                    const SizedBox(width: 12),
                    Text(l.textHidden, style: AppType.questionSmall.copyWith(color: p.paperLabel)),
                  ]),
                ),
        ),
      ]),
    );
  }
}

/// Part 2 photos: a carousel with "1/2" and a frame; a tap opens them full
/// screen with pinch-to-zoom. A photo with no file shows the caption instead.
class PhotoGrid extends ConsumerStatefulWidget {
  const PhotoGrid({super.key, required this.assets, this.files = const {}});
  final List<String> assets;
  final Map<String, String> files;

  @override
  ConsumerState<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends ConsumerState<PhotoGrid> {
  late final _page = PageController(viewportFraction: 0.86);
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Widget _photo(String id, PhotoCatalog catalog, {BoxFit fit = BoxFit.cover}) {
    final p = context.palette;
    final file = widget.files[id];
    if (file != null) return Image.file(File(file), fit: fit, width: double.infinity, height: double.infinity);
    return ColoredBox(
      color: p.surfaceMuted,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(AppIcons.image, color: p.textSecondary),
            const SizedBox(height: 6),
            Text(context.l10n.photoPlaceholder(catalog.captions[id] ?? id),
                textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textSecondary)),
          ]),
        ),
      ),
    );
  }

  void _zoom(String id, PhotoCatalog catalog) {
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      pageBuilder: (context, _, _) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: SafeArea(
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(child: AspectRatio(aspectRatio: 4 / 3, child: _photo(id, catalog, fit: BoxFit.contain))),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final catalog = ref.watch(photoCatalogProvider).value ?? const PhotoCatalog();
    final n = widget.assets.length;
    Widget framed(int i) => Padding(
          padding: EdgeInsets.only(right: n > 1 ? 10 : 0),
          child: GestureDetector(
            onTap: () => _zoom(widget.assets[i], catalog),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Stack(fit: StackFit.expand, children: [
                _photo(widget.assets[i], catalog),
                if (n > 1)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(AppRadii.chip)),
                      child: Text('${i + 1} / $n', style: AppType.footnote.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ]),
            ),
          ),
        );
    return Column(children: [
      AspectRatio(
        aspectRatio: n == 1 ? 4 / 3 : 1.5,
        child: n == 1
            ? framed(0)
            : PageView.builder(
                controller: _page,
                padEnds: false,
                itemCount: n,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => framed(i),
              ),
      ),
      if (n > 1) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < n; i++)
            AnimatedContainer(
              duration: AppMotion.smooth,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == _index ? p.link : p.overlay, borderRadius: BorderRadius.circular(3)),
            ),
        ]),
      ],
    ]);
  }
}

/// "¿Seguro que quieres salir?" with the confirm button locked for 5 s.
Future<bool> showAbandonSheet(BuildContext context, {required String partnerName}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AbandonSheet(partnerName: partnerName),
  );
  return r ?? false;
}

class _AbandonSheet extends StatefulWidget {
  const _AbandonSheet({required this.partnerName});
  final String partnerName;
  @override
  State<_AbandonSheet> createState() => _AbandonSheetState();
}

class _AbandonSheetState extends State<_AbandonSheet> {
  static const lockSeconds = 5;
  int _left = lockSeconds;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  Future<void> _tick() async {
    while (_left > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _left--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.screen, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(AppIcons.leave, color: p.danger),
          ),
          const SizedBox(height: 14),
          Text(l.abandonTitle, style: AppType.title2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 8),
          Text(l.abandonBody(widget.partnerName), style: AppType.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: 22),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.keepGoing)),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('abandon-confirm'),
            style: FilledButton.styleFrom(backgroundColor: p.danger.withValues(alpha: 0.14), foregroundColor: p.danger),
            onPressed: _left > 0
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    Navigator.pop(context, true);
                  },
            child: Text(_left > 0 ? l.leaveExamIn(_left) : l.leaveExam),
          ),
        ]),
      ),
    );
  }
}
