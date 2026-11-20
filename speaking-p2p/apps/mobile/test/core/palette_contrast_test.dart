// Contrast is COMPUTED, never estimated (vault ADR 0031: `success` sat at 4.48:1
// for a year without anyone noticing). WCAG AA for normal text: 4.5:1.
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/theming/palette.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  for (final (name, palette) in [('claro', Palette.light), ('oscuro', Palette.dark)]) {
    test('tema $name: todos los pares de texto cumplen AA (4.5:1)', () {
      for (final (pair, fg, bg) in palette.textPairs) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name $pair = ${contrast(fg, bg).toStringAsFixed(2)}');
      }
    });
  }

  test('la formula reproduce un valor conocido (negro sobre blanco = 21)', () {
    expect(contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
  });
}
