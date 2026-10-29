// Logo (spec §6.1): two speech bubbles, A indigo and B tangerine, overlapping
// into a wave. Plus the welcome hero: the A and B circles with Pico between.
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theming/palette.dart';
import '../theming/tokens.dart';
import 'pico.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 32});
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: CustomPaint(size: Size(size * 1.25, size), painter: _LogoPainter(p.roleA, p.roleB, p.onRole)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.a, this.b, this.ink);
  final Color a, b, ink;

  Path _bubble(Rect r, {required bool tailLeft}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.3));
    final tail = Path();
    if (tailLeft) {
      tail
        ..moveTo(r.left + r.width * 0.18, r.bottom - 1)
        ..lineTo(r.left + r.width * 0.12, r.bottom + r.height * 0.32)
        ..lineTo(r.left + r.width * 0.42, r.bottom - 1)
        ..close();
    } else {
      tail
        ..moveTo(r.right - r.width * 0.18, r.bottom - 1)
        ..lineTo(r.right - r.width * 0.12, r.bottom + r.height * 0.32)
        ..lineTo(r.right - r.width * 0.42, r.bottom - 1)
        ..close();
    }
    return Path.combine(PathOperation.union, Path()..addRRect(rr), tail);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ra = Rect.fromLTWH(0, 0, w * 0.62, h * 0.62);
    final rb = Rect.fromLTWH(w * 0.36, h * 0.22, w * 0.64, h * 0.6);
    canvas.drawPath(_bubble(ra, tailLeft: true), Paint()..color = a);
    canvas.drawPath(_bubble(rb, tailLeft: false), Paint()..color = b);
    // The wave in B, where the two meet.
    final bars = [0.35, 0.7, 1.0, 0.6];
    final paint = Paint()
      ..color = ink
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final cy = rb.center.dy;
    for (var i = 0; i < bars.length; i++) {
      final x = rb.left + rb.width * (0.3 + i * 0.14);
      final half = rb.height * 0.32 * bars[i];
      canvas.drawLine(Offset(x, cy - half), Offset(x, cy + half), paint);
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.a != a || old.b != b;
}

/// Logo + "Speaking P2P".
class BrandRow extends StatelessWidget {
  const BrandRow({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(children: [
      const AppLogo(size: 30),
      const SizedBox(width: 12),
      Text(context.l10n.appName, style: AppType.title2.copyWith(fontWeight: FontWeight.w700, color: p.textPrimary)),
    ]);
  }
}

/// A and B circles with Pico in the middle (welcome, login).
class AbHero extends StatelessWidget {
  const AbHero({super.key, this.height = 170, this.mood = PicoMood.wave});
  final double height;
  final PicoMood mood;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = height * 0.72;
    Widget circle(String t, Color c) => Container(
          width: d,
          height: d,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          child: Text(t, style: AppType.largeTitle.copyWith(fontSize: d * 0.36, color: p.onRole, height: 1)),
        );
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
          Transform.translate(offset: Offset(-d * 0.62, 0), child: circle('A', p.roleA)),
          Transform.translate(offset: Offset(d * 0.62, 0), child: circle('B', p.roleB)),
          Pico(size: height * 0.92, mood: mood),
        ]),
      ),
    );
  }
}
