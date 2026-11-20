// Gesture -> pixels for the avatar crop (ported from Grasp). Pure, so the part
// that could go wrong silently (uploading a different framing than the one the
// user saw) is checked with numbers in test/features/avatar_test.dart.
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

/// Size the image is drawn at before any gesture: BoxFit.cover of a square
/// viewport, so the circle always starts full.
Size coverSize({required Size imageSize, required double viewportSide}) {
  if (imageSize.width <= 0 || imageSize.height <= 0) return Size(viewportSide, viewportSide);
  final scale = viewportSide / (imageSize.width < imageSize.height ? imageSize.width : imageSize.height);
  return Size(imageSize.width * scale, imageSize.height * scale);
}

/// The image region inside the viewport. [matrix] maps child -> viewport
/// (InteractiveViewer: uniform scale + translation only). Clamped to the image;
/// an empty result falls back to the whole image.
Rect computeCropRect({required Matrix4 matrix, required double viewportSide, required Size childSize, required Size imageSize}) {
  final s = Matrix4.inverted(matrix).storage;
  Offset map(double x, double y) => Offset(s[0] * x + s[4] * y + s[12], s[1] * x + s[5] * y + s[13]);
  final tl = map(0, 0);
  final br = map(viewportSide, viewportSide);
  final kx = imageSize.width / childSize.width;
  final ky = imageSize.height / childSize.height;
  final r = Rect.fromLTRB(
    (tl.dx * kx).clamp(0.0, imageSize.width),
    (tl.dy * ky).clamp(0.0, imageSize.height),
    (br.dx * kx).clamp(0.0, imageSize.width),
    (br.dy * ky).clamp(0.0, imageSize.height),
  );
  return r.width <= 0 || r.height <= 0 ? Offset.zero & imageSize : r;
}
