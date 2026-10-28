// Part 3 diagram drawn natively from JSON (CLAUDE.md §5), "hand-drawn" (Design
// 2.0 §6.2): the central question on the obsidian card, the five prompts as
// small sticky notes in handwriting, joined by slightly wobbly lines.
// Theme-aware. A future manual editor writes the same Diagram JSON.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theming/palette.dart';
import '../../../core/theming/tokens.dart';
import '../../../domain/exam/models.dart';

class BubbleDiagram extends StatelessWidget {
  const BubbleDiagram({super.key, required this.diagram, this.showDecision = false});

  final Diagram diagram;
  final bool showDecision;

  // Fractional positions (Alignment space) and tilt of the 5 notes.
  static const _slots = [
    (Alignment(-0.72, -0.86), -0.05),
    (Alignment(0.72, -0.8), 0.04),
    (Alignment(-0.78, 0.5), 0.03),
    (Alignment(0.78, 0.5), -0.04),
    (Alignment(0, 0.92), 0.02),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final central = showDecision ? diagram.decisionQuestion : diagram.centralQuestion;
    return Semantics(
      label: '$central. ${diagram.prompts.join(', ')}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 0.92,
        child: Container(
          decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _Lines([for (final s in _slots) s.$1], p.textTertiary))),
              for (var i = 0; i < 5; i++)
                Align(
                  alignment: _slots[i].$1,
                  child: _Note(text: diagram.prompts[i], color: Palette.stickyNotes[i], tilt: _slots[i].$2, maxWidth: c.maxWidth * 0.46),
                ),
              Align(
                alignment: const Alignment(0, -0.08),
                child: AnimatedSwitcher(
                  duration: AppMotion.part,
                  child: Container(
                    key: ValueKey(central),
                    constraints: BoxConstraints(maxWidth: c.maxWidth * 0.56),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: p.paper,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: p.paperEdge),
                      boxShadow: [BoxShadow(color: p.shadow, blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: Text(central,
                        textAlign: TextAlign.center,
                        style: AppType.question.copyWith(fontSize: 18, height: 1.3, color: p.onPaper)),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color, required this.tilt, required this.maxWidth});
  final String text;
  final Color color;
  final double tilt;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Text(text, textAlign: TextAlign.center, style: AppType.hand.copyWith(color: Palette.onSticky)),
      ),
    );
  }
}

/// Chalk-like lines: a gentle curve from the centre with a little wobble.
class _Lines extends CustomPainter {
  _Lines(this.slots, this.color);
  final List<Alignment> slots;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final center = const Alignment(0, -0.08).alongSize(size);
    final rnd = math.Random(3);
    for (final a in slots) {
      final end = a.alongSize(size);
      final mid = Offset.lerp(center, end, 0.5)!;
      final normal = Offset(-(end - center).dy, (end - center).dx) / (end - center).distance;
      final bend = (rnd.nextDouble() - 0.5) * 24;
      final path = Path()..moveTo(center.dx, center.dy);
      // Few short segments with a tiny jitter: drawn by hand, not by a ruler.
      const steps = 12;
      for (var i = 1; i <= steps; i++) {
        final t = i / steps;
        final q = Offset(
          (1 - t) * (1 - t) * center.dx + 2 * (1 - t) * t * (mid.dx + normal.dx * bend) + t * t * end.dx,
          (1 - t) * (1 - t) * center.dy + 2 * (1 - t) * t * (mid.dy + normal.dy * bend) + t * t * end.dy,
        );
        final j = (rnd.nextDouble() - 0.5) * 1.2;
        path.lineTo(q.dx + normal.dx * j, q.dy + normal.dy * j);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Lines old) => old.color != color;
}

/// Placeholder for the future manual editor (out of the MVP): it will produce
/// exactly `Diagram.toJson()`, validated by the same Zod schema in CI.
abstract class DiagramEditor {
  Diagram build({required String id, required String centralQuestion, required List<String> prompts, required String decisionQuestion});
}
