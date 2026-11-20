// The big round button with soft expanding rings (matchmaking animation, §7).
// One AnimationController, painted on the raster thread: smooth at 60 fps.
// Design 2.0: cobalt with a soft gradient and the "two people" icon instead of
// the microphone (the mic suggested "talk now", not "find someone").
// On tap (D-069): the circle squashes and springs back, a shockwave ring and a
// few sparks leave it, and [sound] plays; [tapDelay] lets that be seen before
// [onTap] navigates away.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../core/ui/ui_sounds.dart';

class SearchPulse extends StatefulWidget {
  const SearchPulse({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 200,
    this.icon = AppIcons.search,
    this.child,
    this.circle,
    this.onCircle,
    this.rings,
    this.sound,
    this.tapDelay = Duration.zero,
  });
  final String label;
  final VoidCallback onTap;
  final double size;
  final IconData icon;

  /// Palette roles; null keeps Home's look: cobalt circle with mandarin rings
  /// (D-043). [onCircle] is the icon and label colour on [circle].
  final Color? circle;
  final Color? onCircle;
  final Color? rings;

  /// Replaces icon + label inside the circle (the search screen shows the avatar).
  final Widget? child;

  /// Played (with its haptic) the moment the finger lands.
  final UiSound? sound;

  /// How long the burst plays before [onTap]; zero calls it at once.
  final Duration tapDelay;

  @override
  State<SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<SearchPulse> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  late final AnimationController _burst = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    _burst.dispose();
    super.dispose();
  }

  /// 1 → 0.9 (press) → 1.06 (spring) → 1.
  static double _scale(double t) {
    if (t < 0.2) return 1 - 0.1 * Curves.easeOut.transform(t / 0.2);
    if (t < 0.55) return 0.9 + 0.16 * Curves.easeOutBack.transform((t - 0.2) / 0.35);
    return 1.06 - 0.06 * Curves.easeInOut.transform((t - 0.55) / 0.45);
  }

  Future<void> _tap() async {
    if (_busy) return;
    final sound = widget.sound;
    if (sound != null) ProviderScope.containerOf(context, listen: false).read(uiSoundsProvider).play(sound);
    if (!MediaQuery.of(context).disableAnimations) _burst.forward(from: 0);
    if (widget.tapDelay == Duration.zero) return widget.onTap();
    _busy = true;
    await Future<void>.delayed(widget.tapDelay);
    _busy = false;
    if (mounted) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final d = widget.size * 0.8;
    final fill = widget.circle ?? p.brand;
    final onFill = widget.onCircle ?? p.onBrand;
    final ringColor = widget.rings ?? p.roleB;
    return SizedBox.square(
      dimension: widget.size * 1.3,
      child: Stack(alignment: Alignment.center, children: [
        if (!reduceMotion)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(size: Size.square(widget.size * 1.3), painter: _Rings(_c.value, ringColor)),
            ),
          ),
        if (!reduceMotion)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _burst,
                builder: (_, _) => _burst.isAnimating
                    ? CustomPaint(size: Size.square(widget.size * 1.3), painter: _Burst(_burst.value, d / 2, ringColor, fill))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        AnimatedBuilder(
          animation: _burst,
          builder: (_, child) => Transform.scale(scale: _burst.isAnimating ? _scale(_burst.value) : 1, child: child),
          child: Semantics(
            button: true,
            label: widget.label,
            excludeSemantics: true,
            onTap: _tap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: fill.withValues(alpha: 0.35), blurRadius: 36, offset: const Offset(0, 14))],
              ),
              child: Material(
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Ink(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(fill, Colors.white, 0.18)!, fill, Color.lerp(fill, Colors.black, 0.18)!],
                    ),
                  ),
                  child: InkWell(
                    onTap: _tap,
                    child: SizedBox.square(
                      dimension: d,
                      child: Padding(
                        padding: EdgeInsets.all(widget.size * 0.1),
                        // Scales down instead of overflowing with long labels or large
                        // accessibility font sizes.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: widget.child ??
                              SizedBox(
                                width: widget.size * 0.6,
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(widget.icon, color: onFill, size: 40),
                                  const SizedBox(height: 10),
                                  Text(widget.label, textAlign: TextAlign.center, style: AppType.title2.copyWith(color: onFill, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                        ),
                      ),
                    ),
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

class _Rings extends CustomPainter {
  _Rings(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final v = (t + i / 3) % 1.0;
      final r = size.width * (0.3 + 0.2 * v);
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.2 * (1 - v)));
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = color.withValues(alpha: 0.35 * (1 - v)));
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t || old.color != color;
}

/// The tap burst: a shockwave ring leaving the circle and eight sparks.
class _Burst extends CustomPainter {
  _Burst(this.t, this.r0, this.ring, this.spark);
  final double t, r0;
  final Color ring, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t);
    final fade = 1 - Curves.easeIn.transform(t);
    final rMax = size.width / 2;
    final r = r0 + (rMax - r0) * e;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 6 * fade
          ..color = ring.withValues(alpha: 0.7 * fade));
    final sparkPaint = Paint()..color = Color.lerp(spark, ring, 0.5)!.withValues(alpha: fade);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + math.pi / 8;
      final d = r0 + (rMax - r0) * 0.9 * e;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * d, 2 + 3 * fade, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(_Burst old) => old.t != t;
}
