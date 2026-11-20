// Part 3 diagram: no bubble may ever touch another one (D-049), on small and
// large phones, with the longest C1 texts and with the text at 200 %.
// The notes are tilted, so each box is measured by its four rotated corners.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/app_theme.dart';
import 'package:speaking_p2p/domain/exam/models.dart';
import 'package:speaking_p2p/features/exam/widgets/bubble_diagram.dart';

// The longest central question and prompts of the bank (c1-e06, c1-e14, c1-e34, b2-e25).
const _long = Diagram(
  id: 'worst-case',
  centralQuestion: 'How might these things affect someone who is thinking about doing a dangerous activity?',
  prompts: [
    'limiting the number of new collections each year',
    'requiring environmental studies before building',
    'who is responsible when machines make mistakes',
    'limiting the number of new collections each year',
    'requiring environmental studies before building',
  ],
  decisionQuestion: 'Which would be the most effective in making the city a better place to live?',
);

const _short = Diagram(
  id: 'short',
  centralQuestion: 'Why?',
  prompts: ['a', 'b', 'c', 'd', 'e'],
  decisionQuestion: 'Which?',
);

Future<void> _pump(WidgetTester tester, Size screen, double scale, Diagram d, {bool decision = false}) async {
  tester.view.physicalSize = screen * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(size: screen, textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: BubbleDiagram(diagram: d, showDecision: decision),
        ),
      ),
    ),
  ));
  await tester.pump(const Duration(seconds: 1)); // AnimatedSwitcher of the central card
}

/// Screen rect of [finder]'s box after every transform (the tilt of the notes).
Rect _bounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  final s = box.size;
  final corners = [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)].map(box.localToGlobal).toList();
  final xs = corners.map((c) => c.dx), ys = corners.map((c) => c.dy);
  return Rect.fromLTRB(xs.reduce((a, b) => a < b ? a : b), ys.reduce((a, b) => a < b ? a : b), xs.reduce((a, b) => a > b ? a : b),
      ys.reduce((a, b) => a > b ? a : b));
}

void _expectNoOverlap(WidgetTester tester, Diagram d, String central) {
  expect(tester.takeException(), isNull, reason: 'sin desbordes');
  final boxes = <String, Rect>{
    'central': _bounds(tester, find.byKey(ValueKey(central))),
    for (var i = 0; i < 5; i++)
      'prompt ${i + 1}': _bounds(tester, find.descendant(of: find.byKey(Key('diagram-note-$i')), matching: find.byType(Container)).first),
  };
  final names = boxes.keys.toList();
  for (var i = 0; i < names.length; i++) {
    for (var j = i + 1; j < names.length; j++) {
      final a = boxes[names[i]]!, b = boxes[names[j]]!;
      expect(a.overlaps(b), isFalse, reason: '${names[i]} $a toca ${names[j]} $b');
    }
  }
  // Nothing sticks out of the diagram card either (the screen has a 20 px margin).
  final card = tester.getRect(find.byType(BubbleDiagram));
  for (final e in boxes.entries) {
    expect(e.value.left >= card.left && e.value.right <= card.right, isTrue, reason: '${e.key} ${e.value} sale de $card');
  }
}

void main() {
  const screens = {'iPhone SE (320)': Size(320, 568), 'iPhone 15 (393)': Size(393, 852), 'Pixel 5 (393)': Size(393, 851), 'Pro Max (430)': Size(430, 932)};
  for (final screen in screens.entries) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('${screen.key}, texto al ${(scale * 100).round()} %: ningún bocadillo se solapa', (tester) async {
        await _pump(tester, screen.value, scale, _long);
        _expectNoOverlap(tester, _long, _long.centralQuestion);
        await _pump(tester, screen.value, scale, _long, decision: true);
        _expectNoOverlap(tester, _long, _long.decisionQuestion);
        await _pump(tester, screen.value, scale, _short);
        _expectNoOverlap(tester, _short, _short.centralQuestion);
      });
    }
  }

  testWidgets('texto grande: una nota por fila en vez de partir palabras; normal: de dos en dos', (tester) async {
    double left(int i) => tester.getRect(find.byKey(Key('diagram-note-$i'))).left;
    double top(int i) => tester.getRect(find.byKey(Key('diagram-note-$i'))).top;
    await _pump(tester, const Size(393, 852), 1, _long);
    expect((top(0) - top(1)).abs(), lessThan(10), reason: '1 y 2 comparten fila');
    expect(left(1), greaterThan(left(0) + 100));
    await _pump(tester, const Size(393, 852), 2, _long);
    for (var i = 1; i < 5; i++) {
      expect(top(i), greaterThan(top(i - 1)), reason: 'la nota ${i + 1} va debajo de la ${i + 0}');
    }
  });

  testWidgets('los textos largos hacen crecer el diagrama en vez de apretarlo', (tester) async {
    await _pump(tester, const Size(320, 568), 1, _short);
    final short = tester.getSize(find.byType(BubbleDiagram)).height;
    await _pump(tester, const Size(320, 568), 2, _long);
    final long = tester.getSize(find.byType(BubbleDiagram)).height;
    expect(long, greaterThan(short * 1.5));
  });
}
