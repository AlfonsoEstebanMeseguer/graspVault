// Renders Pico (the code-drawn mascot) into the launcher icon sources:
//   flutter test tool/app_icon/render_icon_test.dart
//   dart run flutter_launcher_icons
// Not under test/, so the normal suite does not rewrite the PNGs.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/ui/pico.dart';

const _size = 1024.0;

/// Brand gradient behind Pico on iOS and legacy Android icons.
const _bgTop = Color(0xFF232D52);
const _bgBottom = Color(0xFF0B0E14);

Future<void> _write(String path, {required bool background, required double scale}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const full = Rect.fromLTWH(0, 0, _size, _size);
  if (background) {
    c.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])
            .createShader(full),
    );
  }
  // Pico's art spans roughly y 14..96 of its 100-unit box: nudge it up a bit so it looks centred.
  final side = _size * scale;
  c.translate((_size - side) / 2, (_size - side) / 2 - side * 0.04);
  PicoPainter(t: 0, mood: PicoMood.wave).paint(c, Size.square(side));
  final img = await rec.endRecording().toImage(_size.toInt(), _size.toInt());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render the launcher icon sources', () async {
    await _write('assets/branding/icon.png', background: true, scale: 0.86);
    // Android adaptive foreground: flutter_launcher_icons adds a 16 % inset, so Pico can fill it.
    await _write('assets/branding/icon_foreground.png', background: false, scale: 0.9);
  });
}
