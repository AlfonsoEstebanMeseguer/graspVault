// The big round button with soft expanding rings (matchmaking animation, §7).
// One AnimationController, painted on the raster thread: smooth at 60 fps.
import 'package:flutter/material.dart';

import '../../core/theming/palette.dart';

class SearchPulse extends StatefulWidget {
  const SearchPulse({super.key, required this.label, required this.onTap, this.size = 200});
  final String label;
  final VoidCallback onTap;
  final double size;

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
    return SizedBox.square(
      dimension: widget.size * 1.3,
      child: Stack(alignment: Alignment.center, children: [
        if (!reduceMotion)
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) => CustomPaint(size: Size.square(widget.size * 1.3), painter: _Rings(_c.value, p.brand)),
            ),
          ),
        Semantics(
          button: true,
          label: widget.label,
          excludeSemantics: true,
          onTap: widget.onTap,
          child: Material(
            color: p.brand,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onTap,
              child: SizedBox.square(
                dimension: widget.size * 0.8,
                child: Padding(
                  padding: EdgeInsets.all(widget.size * 0.1),
                  // Scales down instead of overflowing with long labels or large
                  // accessibility font sizes.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: widget.size * 0.6,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.mic_none, color: p.onBrand, size: 36),
                        const SizedBox(height: 8),
                        Text(widget.label, textAlign: TextAlign.center, style: TextStyle(color: p.onBrand, fontSize: 18, fontWeight: FontWeight.w600)),
                      ]),
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
      canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.18 * (1 - v)));
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t || old.color != color;
}
