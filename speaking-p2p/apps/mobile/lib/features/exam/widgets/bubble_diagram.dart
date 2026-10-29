// Part 3 diagram drawn natively from JSON (CLAUDE.md §5), "hand-drawn" (Design
// 2.0 §6.2): the central question on the obsidian card, the five prompts as
// small sticky notes in handwriting, joined by slightly wobbly lines.
// Theme-aware. A future manual editor writes the same Diagram JSON.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theming/palette.dart';
import '../../../core/theming/tokens.dart';
import '../../../domain/exam/models.dart';

class BubbleDiagram extends StatelessWidget {
  const BubbleDiagram({super.key, required this.diagram, this.showDecision = false});

  final Diagram diagram;
  final bool showDecision;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final central = showDecision ? diagram.decisionQuestion : diagram.centralQuestion;
    return Semantics(
      label: '$central. ${diagram.prompts.join(', ')}',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(AppRadii.card)),
        padding: const EdgeInsets.all(14),
        child: _DiagramLayout(
          lineColor: p.textTertiary,
          textScale: MediaQuery.textScalerOf(context).scale(16) / 16,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.part,
              child: Container(
                key: ValueKey(central),
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
            for (var i = 0; i < 5; i++) _Note(key: Key('diagram-note-$i'), text: diagram.prompts[i], color: Palette.stickyNotes[i]),
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Text(text, textAlign: TextAlign.center, style: AppType.hand.copyWith(color: Palette.onSticky)),
    );
  }
}

/// Places the central question + 5 tilted notes so that nothing can ever
/// overlap, whatever the screen width, text length (C1) or text scale (200 %):
///
///     [ 1 ]      [ 2 ]
///       [ central  ]
///     [ 3 ]      [ 4 ]
///          [ 5 ]
///
/// Each row starts below the tallest box of the previous one plus a gap, and
/// the two notes of a row live in separate halves. Boxes are measured with
/// their tilt (the rotated bounding box), and tall notes tilt less. The height
/// grows with the text instead of squeezing a fixed aspect ratio (the old
/// layout pinned the boxes to fixed points, so long texts ran into each other).
///
/// When half the width is too narrow for the text size (large accessibility
/// text, small phones), the notes go one per row instead of breaking words:
/// 1 and 2 above the central question, 3 to 5 below.
class _DiagramLayout extends MultiChildRenderObjectWidget {
  const _DiagramLayout({required this.lineColor, required this.textScale, required super.children})
      : assert(children.length == 6);
  final Color lineColor;
  final double textScale;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDiagram(lineColor, textScale);

  @override
  void updateRenderObject(BuildContext context, _RenderDiagram renderObject) => renderObject
    ..lineColor = lineColor
    ..textScale = textScale;
}

class _DiagramParentData extends ContainerBoxParentData<RenderBox> {
  double angle = 0;
}

class _RenderDiagram extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _DiagramParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _DiagramParentData> {
  _RenderDiagram(this._lineColor, this._textScale);

  /// Between the two notes of a row, and between rows (room for the lines).
  static const hGap = 20.0;
  static const vGap = 28.0;

  /// Tilt of the central card and the 5 notes (radians), for a note up to
  /// [_tiltHeight] tall; taller notes tilt proportionally less, so the extra
  /// width of a rotated note is at most [_tiltHeight] x 0.05 = 4.5 px.
  static const _tilts = [0.0, -0.05, 0.04, 0.03, -0.04, 0.02];
  static const _tiltHeight = 90.0;
  static const _tiltRoom = 6.0;

  /// Narrowest half (at 100 % text) that still fits a note's words.
  static const _minNoteWidth = 100.0;

  Color _lineColor;
  set lineColor(Color c) {
    if (c == _lineColor) return;
    _lineColor = c;
    markNeedsPaint();
  }

  double _textScale;
  set textScale(double v) {
    if (v == _textScale) return;
    _textScale = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _DiagramParentData) child.parentData = _DiagramParentData();
  }

  static double _angle(int i, Size s) => s.height <= _tiltHeight ? _tilts[i] : _tilts[i] * _tiltHeight / s.height;

  /// Bounding box of a box of size [s] rotated by [a] about its centre.
  static Size _rotated(Size s, double a) {
    final c = math.cos(a).abs(), n = math.sin(a).abs();
    return Size(s.width * c + s.height * n, s.width * n + s.height * c);
  }

  /// Size, top-left and angle of each child (central, notes 1-5) and the total size.
  ({List<Size> sizes, List<Offset> at, List<double> angles, Size size}) _arrange(
      double width, Size Function(RenderBox child, BoxConstraints c) measure) {
    final kids = getChildrenAsList();
    final half = math.max(0.0, (width - hGap) / 2);
    final oneColumn = half < _minNoteWidth * _textScale;
    BoxConstraints upTo(double w) => BoxConstraints(maxWidth: math.max(0.0, w - _tiltRoom));
    final sizes = [
      measure(kids[0], upTo(width * 0.86)),
      for (var i = 1; i <= 4; i++) measure(kids[i], upTo(oneColumn ? width * 0.86 : half)),
      measure(kids[5], upTo(width * 0.64)),
    ];
    final angles = [for (var i = 0; i < 6; i++) _angle(i, sizes[i])];
    final bounds = [for (var i = 0; i < 6; i++) _rotated(sizes[i], angles[i])];
    final at = List.filled(6, Offset.zero);
    // Puts child [i] so that its rotated bounds start at [left], [top].
    void place(int i, double left, double top) =>
        at[i] = Offset(left + (bounds[i].width - sizes[i].width) / 2, top + (bounds[i].height - sizes[i].height) / 2);
    var y = 0.0;
    // A row of two notes, each centred in its own half; returns its bottom.
    double pair(int l, int r) {
      place(l, (half - bounds[l].width) / 2, y);
      place(r, half + hGap + (half - bounds[r].width) / 2, y);
      return y + math.max(bounds[l].height, bounds[r].height);
    }

    // One box centred on its own row; returns the top of the next row.
    double row(int i) {
      place(i, (width - bounds[i].width) / 2, y);
      return y + bounds[i].height + vGap;
    }

    if (oneColumn) {
      for (final i in [1, 2, 0, 3, 4, 5]) {
        y = row(i);
      }
    } else {
      y = pair(1, 2) + vGap;
      y = row(0);
      y = pair(3, 4) + vGap;
      y = row(5);
    }
    y -= vGap;
    return (sizes: sizes, at: at, angles: angles, size: Size(width, y));
  }

  static double _width(BoxConstraints c) => c.hasBoundedWidth ? c.maxWidth : 360;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_arrange(_width(constraints), (child, c) => child.getDryLayout(c)).size);

  @override
  void performLayout() {
    final r = _arrange(_width(constraints), (child, c) {
      child.layout(c, parentUsesSize: true);
      return child.size;
    });
    var i = 0;
    for (final child in getChildrenAsList()) {
      (child.parentData! as _DiagramParentData)
        ..offset = r.at[i]
        ..angle = r.angles[i];
      i++;
    }
    size = constraints.constrain(r.size);
  }

  @override
  double computeMinIntrinsicHeight(double width) => _arrange(width, (child, c) => child.getDryLayout(c)).size.height;
  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);
  @override
  double computeMinIntrinsicWidth(double height) => 0;
  @override
  double computeMaxIntrinsicWidth(double height) => 360;

  /// The child's offset plus its tilt about its own centre.
  Matrix4 _transformOf(RenderBox child) {
    final pd = child.parentData! as _DiagramParentData;
    final c = child.size.center(Offset.zero);
    return Matrix4.translationValues(pd.offset.dx + c.dx, pd.offset.dy + c.dy, 0)
      ..multiply(Matrix4.rotationZ(pd.angle))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.multiply(_transformOf(child));

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in getChildrenAsList().reversed) {
      final hit = result.addWithPaintTransform(
        transform: _transformOf(child),
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final kids = getChildrenAsList();
    Offset centreOf(RenderBox b) => offset + (b.parentData! as _DiagramParentData).offset + b.size.center(Offset.zero);
    _paintLines(context.canvas, centreOf(kids[0]), [for (final k in kids.skip(1)) centreOf(k)]);
    // The boxes cover the ends of the lines.
    for (final child in kids) {
      context.pushTransform(needsCompositing, offset, _transformOf(child), (context, offset) => context.paintChild(child, offset));
    }
  }

  /// Chalk-like lines: a gentle curve from the centre with a little wobble.
  void _paintLines(Canvas canvas, Offset center, List<Offset> ends) {
    final paint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(3);
    for (final end in ends) {
      final d = end - center;
      if (d.distance == 0) continue;
      final mid = Offset.lerp(center, end, 0.5)!;
      final normal = Offset(-d.dy, d.dx) / d.distance;
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
}

/// Placeholder for the future manual editor (out of the MVP): it will produce
/// exactly `Diagram.toJson()`, validated by the same Zod schema in CI.
abstract class DiagramEditor {
  Diagram build({required String id, required String centralQuestion, required List<String> prompts, required String decisionQuestion});
}
