// Design 2.0 building blocks shared by every screen (spec §6.2, §7): glass for
// floating controls only, the obsidian question card, level badges, the
// segmented control and the small status line. Screens compose these; they do
// not restyle them.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/exam/models.dart' show Level, LevelCode;
import '../theming/palette.dart';
import '../theming/tokens.dart';

/// Frosted surface for the dock, the tab bar and toasts. Content stays opaque.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = AppRadii.sheet, this.padding = EdgeInsets.zero});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: r, boxShadow: [BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(color: p.glass, borderRadius: r, border: Border.all(color: p.glassEdge)),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// A filled card (bg.elevated, radius 20, no border).
class Tile extends StatelessWidget {
  const Tile({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = BorderRadius.circular(AppRadii.card);
    return Material(
      color: color ?? p.surface,
      shape: RoundedRectangleBorder(borderRadius: r, side: border == null ? BorderSide.none : BorderSide(color: border!, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// "PARTE 2 DE 4", "TU OFERTA": uppercase, tracked.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: AppType.overline.copyWith(color: color ?? context.palette.textSecondary));
}

/// Screen title (Large Title), optionally with a greeting above.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.above});
  final String title;
  final String? above;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (above != null) Text(above!, style: AppType.body.copyWith(color: p.textSecondary)),
      Text(title, style: AppType.largeTitle.copyWith(color: p.textPrimary)),
    ]);
  }
}

/// "C1" on its soft level colour; the code is always written (never colour only).
class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key, this.size = 14});
  final Level level;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.55, vertical: size * 0.3),
      decoration: BoxDecoration(color: p.levelSoft(level), borderRadius: BorderRadius.circular(AppRadii.chip)),
      child: Text(level.code, style: AppType.headline.copyWith(fontSize: size, height: 1.1, fontWeight: FontWeight.w700, color: p.level(level))),
    );
  }
}

/// Coloured dot + text ("Tu micro está abierto", "Listo").
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.text, required this.color, this.style});
  final String text;
  final Color color;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: (style ?? AppType.headline).copyWith(color: color))),
      ]);
}

class SegmentItem<T> {
  const SegmentItem(this.value, this.label, {this.dot, this.key});
  final T value;
  final String label;

  /// A small colour dot before the label (level colours).
  final Color? dot;
  final Key? key;
}

/// Segmented control: a filled track, the selected segment raised. Equal widths.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({super.key, required this.items, required this.selected, required this.onChanged, this.height = 48});
  final List<SegmentItem<T>> items;
  final T selected;
  final ValueChanged<T>? onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadii.input + 2)),
      child: Row(children: [
        for (final it in items)
          Expanded(
            child: Semantics(
              selected: it.value == selected,
              button: true,
              child: GestureDetector(
                key: it.key,
                behavior: HitTestBehavior.opaque,
                onTap: onChanged == null ? null : () => onChanged!(it.value),
                child: AnimatedContainer(
                  duration: AppMotion.smooth,
                  curve: AppMotion.curve,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: it.value == selected ? p.overlay : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.input - 2),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (it.dot != null) ...[
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: it.dot, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                        ],
                        Text(it.label,
                            style: AppType.headline.copyWith(
                                fontSize: 15, color: it.value == selected ? p.textPrimary : p.textSecondary)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The question card: obsidian "paper", the examiner's words in serif (§6.2,
/// user's change: obsidian instead of cream). The one element that is not the
/// app around it, so the eye goes there.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.label,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });
  final Widget child;
  final String? label;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.paper,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: p.paperEdge),
        boxShadow: [BoxShadow(color: p.shadow, blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (label != null || trailing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 16, color: p.paperLabel), const SizedBox(width: 8)],
              if (label != null) Expanded(child: Overline(label!, color: p.paperLabel)) else const Spacer(),
              ?trailing,
            ]),
          ),
        DefaultTextStyle.merge(style: AppType.question.copyWith(color: p.onPaper), child: child),
      ]),
    );
  }
}

/// Round icon button on a raised fill (close, eye, mic).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.size = 48, this.color, this.background});
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;
  final Color? background;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final b = Material(
      color: background ?? p.surfaceMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(dimension: size, child: Icon(icon, size: size * 0.46, color: color ?? p.textPrimary)),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

/// Five bars that move while the examiner speaks (orb / hidden text).
class VoiceBars extends StatefulWidget {
  const VoiceBars({super.key, required this.active, required this.color, this.height = 18, this.bars = 5});
  final bool active;
  final Color color;
  final double height;
  final int bars;
  @override
  State<VoiceBars> createState() => _VoiceBarsState();
}

class _VoiceBarsState extends State<VoiceBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(VoiceBars old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (widget.active && !reduce) {
      if (!_c.isAnimating) _c.repeat();
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
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            size: Size(widget.bars * 6.0, widget.height),
            painter: _Bars(widget.active ? _c.value : -1, widget.color, widget.bars),
          ),
        ),
      );
}

class _Bars extends CustomPainter {
  _Bars(this.t, this.color, this.n);
  final double t;
  final Color color;
  final int n;
  static const _shape = [0.45, 0.8, 1.0, 0.7, 0.4, 0.85, 0.55];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final gap = size.width / n;
    for (var i = 0; i < n; i++) {
      var h = _shape[i % _shape.length];
      if (t >= 0) h *= 0.55 + 0.45 * (0.5 + 0.5 * _wave(t * 2 + i * 0.27));
      final x = gap * (i + 0.5);
      final half = size.height * h / 2;
      canvas.drawLine(Offset(x, size.height / 2 - half), Offset(x, size.height / 2 + half), paint);
    }
  }

  static double _wave(double v) {
    final f = v % 1.0;
    return f < 0.5 ? (f * 4 - 1) : (3 - f * 4);
  }

  @override
  bool shouldRepaint(_Bars old) => old.t != t || old.color != color;
}

/// The Phosphor icons used across the app, in one place (fonts bundled in
/// assets/fonts, MIT; codepoints from phosphor-icons/core).
abstract final class AppIcons {
  static const practice = IconData(0xe802, fontFamily: 'PhosphorRegular') /* waveform */;
  static const practiceOn = IconData(0xe802, fontFamily: 'PhosphorFill') /* waveform */;
  static const agenda = IconData(0xe7b4, fontFamily: 'PhosphorRegular') /* calendarDots */;
  static const agendaOn = IconData(0xe7b4, fontFamily: 'PhosphorFill') /* calendarDots */;
  static const profile = IconData(0xe4c4, fontFamily: 'PhosphorRegular') /* userCircle */;
  static const profileOn = IconData(0xe4c4, fontFamily: 'PhosphorFill') /* userCircle */;
  static const settings = IconData(0xe272, fontFamily: 'PhosphorRegular') /* gearSix */;
  static const settingsOn = IconData(0xe272, fontFamily: 'PhosphorFill') /* gearSix */;
  static const search = IconData(0xe68e, fontFamily: 'PhosphorFill') /* usersThree */;
  static const mic = IconData(0xe326, fontFamily: 'PhosphorFill') /* microphone */;
  static const micOff = IconData(0xe328, fontFamily: 'PhosphorFill') /* microphoneSlash */;
  static const micLine = IconData(0xe326, fontFamily: 'PhosphorRegular') /* microphone */;
  static const speaker = IconData(0xe44a, fontFamily: 'PhosphorRegular') /* speakerHigh */;
  static const pause = IconData(0xe39e, fontFamily: 'PhosphorFill') /* pause */;
  static const play = IconData(0xe3d0, fontFamily: 'PhosphorFill') /* play */;
  static const prev = IconData(0xe5a4, fontFamily: 'PhosphorFill') /* skipBack */;
  static const next = IconData(0xe5a6, fontFamily: 'PhosphorFill') /* skipForward */;
  static const fastForward = IconData(0xe6a6, fontFamily: 'PhosphorFill') /* fastForward */;
  static const timer = IconData(0xe492, fontFamily: 'PhosphorRegular') /* timer */;
  static const crown = IconData(0xe614, fontFamily: 'PhosphorFill') /* crown */;
  static const crownLine = IconData(0xe614, fontFamily: 'PhosphorRegular') /* crown */;
  static const record = IconData(0xe3ee, fontFamily: 'PhosphorRegular') /* record */;
  static const leave = IconData(0xe42a, fontFamily: 'PhosphorRegular') /* signOut */;
  static const eye = IconData(0xe220, fontFamily: 'PhosphorRegular') /* eye */;
  static const eyeOff = IconData(0xe224, fontFamily: 'PhosphorRegular') /* eyeSlash */;
  static const close = IconData(0xe4f6, fontFamily: 'PhosphorRegular') /* x */;
  static const check = IconData(0xe182, fontFamily: 'PhosphorBold') /* check */;
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorFill') /* checkCircle */;
  static const plus = IconData(0xe3d4, fontFamily: 'PhosphorBold') /* plus */;
  static const apple = IconData(0xe516, fontFamily: 'PhosphorFill') /* appleLogo */;
  static const google = IconData(0xe292, fontFamily: 'PhosphorBold') /* googleLogo */;
  static const mail = IconData(0xe218, fontFamily: 'PhosphorRegular') /* envelopeSimple */;
  static const lock = IconData(0xe2fa, fontFamily: 'PhosphorFill') /* lock */;
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorBold') /* caretDown */;
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular') /* caretRight */;
  static const back = IconData(0xe058, fontFamily: 'PhosphorRegular') /* arrowLeft */;
  static const chat = IconData(0xe178, fontFamily: 'PhosphorRegular') /* chatTeardropText */;
  static const repeat = IconData(0xe038, fontFamily: 'PhosphorRegular') /* arrowCounterClockwise */;
  static const flag = IconData(0xea38, fontFamily: 'PhosphorRegular') /* flagCheckered */;
  static const shuffle = IconData(0xe422, fontFamily: 'PhosphorRegular') /* shuffle */;
  static const find = IconData(0xe30c, fontFamily: 'PhosphorRegular') /* magnifyingGlass */;
  static const swap = IconData(0xe83c, fontFamily: 'PhosphorRegular') /* swap */;
  static const books = IconData(0xe758, fontFamily: 'PhosphorRegular') /* books */;
  static const signal = IconData(0xe144, fontFamily: 'PhosphorRegular') /* cellSignalHigh */;
  static const send = IconData(0xe396, fontFamily: 'PhosphorFill') /* paperPlaneRight */;
  static const camera = IconData(0xe10e, fontFamily: 'PhosphorRegular') /* camera */;
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular') /* trash */;
  static const image = IconData(0xe2ca, fontFamily: 'PhosphorRegular') /* image */;
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorRegular') /* clock */;
  static const sparkle = IconData(0xe6a2, fontFamily: 'PhosphorFill') /* sparkle */;
  static const warning = IconData(0xe4e0, fontFamily: 'PhosphorRegular') /* warning */;
  static const skipPart = IconData(0xe6a6, fontFamily: 'PhosphorRegular') /* fastForward */;
  static const report = IconData(0xe244, fontFamily: 'PhosphorRegular') /* flag */;
  static const block = IconData(0xe3de, fontFamily: 'PhosphorRegular') /* prohibit */;
  static const menu = IconData(0xe208, fontFamily: 'PhosphorRegular') /* dotsThreeVertical */;
  static const more = IconData(0xe1fe, fontFamily: 'PhosphorBold') /* dotsThree */;
  static const bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular') /* bell */;
  static const bellOff = IconData(0xe0d4, fontFamily: 'PhosphorRegular') /* bellSlash */;
}
