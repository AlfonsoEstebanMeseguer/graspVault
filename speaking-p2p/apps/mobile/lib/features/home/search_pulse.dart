// The big round button with soft expanding rings (matchmaking animation, §7).
// One AnimationController, painted on the raster thread: smooth at 60 fps.
// Design 2.0: cobalt with a soft gradient and the "two people" icon instead of
// the microphone (the mic suggested "talk now", not "find someone").
import 'package:flutter/material.dart';

import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';

class SearchPulse extends StatefulWidget {
  const SearchPulse({super.key, required this.label, required this.onTap, this.size = 200, this.icon = AppIcons.search, this.child});
  final String label;
  final VoidCallback onTap;
  final double size;
  final IconData icon;

  /// Replaces icon + label inside the circle (the search screen shows the avatar).
  final Widget? child;

  @override
  State<SearchPulse> createState() => _SearchPulseState();
}

class _SearchPulseState extends State<SearchPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final d = widget.size * 0.8;
    return SizedBox.square(
      dimension: widget.size * 1.3,
      child: Stack(alignment: Alignment.center, children: [
        if (!reduceMotion)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              // Rings in candidate B's mandarin (D-043): the button stays cobalt.
              builder: (_, _) => CustomPaint(size: Size.square(widget.size * 1.3), painter: _Rings(_c.value, p.roleB)),
            ),
          ),
        Semantics(
          button: true,
          label: widget.label,
          excludeSemantics: true,
          onTap: widget.onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: p.brand.withValues(alpha: 0.35), blurRadius: 36, offset: const Offset(0, 14))],
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
                    colors: [Color.lerp(p.brand, Colors.white, 0.18)!, p.brand, Color.lerp(p.brand, Colors.black, 0.18)!],
                  ),
                ),
                child: InkWell(
                  onTap: widget.onTap,
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
                                Icon(widget.icon, color: p.onBrand, size: 40),
                                const SizedBox(height: 10),
                                Text(widget.label, textAlign: TextAlign.center, style: AppType.title2.copyWith(color: p.onBrand, fontWeight: FontWeight.w700)),
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
