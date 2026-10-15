// Part 3 diagram drawn natively from JSON (CLAUDE.md §5): central question in
// the brand bubble, five prompts around it, connecting lines. Theme-aware.
// A future manual editor writes the same Diagram JSON (DiagramEditor stub).
import 'package:flutter/material.dart';

import '../../../core/theming/palette.dart';
import '../../../domain/exam/models.dart';

class BubbleDiagram extends StatelessWidget {
  const BubbleDiagram({super.key, required this.diagram, this.showDecision = false});

  final Diagram diagram;
  final bool showDecision;

  // Fractional positions (Alignment space) of the 5 prompts.
  static const _slots = [
    Alignment(-0.78, -0.82),
    Alignment(0.78, -0.82),
    Alignment(-0.9, 0.38),
    Alignment(0.9, 0.38),
    Alignment(0, 0.9),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final central = showDecision ? diagram.decisionQuestion : diagram.centralQuestion;
    return Semantics(
      label: '$central. ${diagram.prompts.join(', ')}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.border),
          ),
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(builder: (context, c) {
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _Lines(_slots, p.border))),
              for (var i = 0; i < 5; i++)
                Align(alignment: _slots[i], child: _Bubble(text: diagram.prompts[i], maxWidth: c.maxWidth * 0.42)),
              Align(
                alignment: Alignment.center,
                child: Container(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * 0.46),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: p.brand, borderRadius: BorderRadius.circular(14)),
                  child: Text(central,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.onBrand, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.maxWidth});
  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.textPrimary, fontSize: 13)),
    );
  }
}

class _Lines extends CustomPainter {
  _Lines(this.slots, this.color);
  final List<Alignment> slots;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final center = size.center(Offset.zero);
    for (final a in slots) {
      final end = a.alongSize(size);
      // dashed line
      const dash = 4.0, gap = 4.0;
      final total = (end - center).distance;
      final dir = (end - center) / total;
      for (var d = 0.0; d < total; d += dash + gap) {
        canvas.drawLine(center + dir * d, center + dir * (d + dash).clamp(0, total), paint);
      }
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
