// Move and zoom the photo inside a circle before uploading (Grasp's crop
// sheet). Plain Flutter instead of image_cropper: same look on every phone and
// no native setup. Returns PNG bytes of a 512 px square, or null if cancelled.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/theming/palette.dart';
import 'avatar_image.dart' show avatarSide;
import 'crop_geometry.dart';

class AvatarCropSheet extends StatefulWidget {
  const AvatarCropSheet({super.key, required this.imageBytes});
  final Uint8List imageBytes;

  static Future<Uint8List?> show(BuildContext context, Uint8List imageBytes) => showModalBottomSheet<Uint8List?>(
        context: context,
        isScrollControlled: true,
        // Dragging the photo down would otherwise close the sheet mid-framing.
        enableDrag: false,
        isDismissible: false,
        builder: (_) => AvatarCropSheet(imageBytes: imageBytes),
      );

  @override
  State<AvatarCropSheet> createState() => _AvatarCropSheetState();
}

class _AvatarCropSheetState extends State<AvatarCropSheet> {
  final _controller = TransformationController();
  ui.Image? _image;
  bool _working = false;
  bool _failed = false;
  double _side = 300;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (mounted) setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _confirm() async {
    final image = _image;
    if (image == null) return;
    setState(() => _working = true);
    try {
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final src = computeCropRect(
        matrix: _controller.value,
        viewportSide: _side,
        childSize: coverSize(imageSize: imageSize, viewportSide: _side),
        imageSize: imageSize,
      );
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(image, src, Rect.fromLTWH(0, 0, avatarSide.toDouble(), avatarSide.toDouble()),
          Paint()..filterQuality = FilterQuality.high);
      final cropped = await recorder.endRecording().toImage(avatarSide, avatarSide);
      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();
      if (data == null) throw StateError('empty crop');
      if (mounted) Navigator.of(context).pop(data.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(() {
          _working = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final image = _image;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.avatarCropTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
          const SizedBox(height: 4),
          Text(l.avatarCropHelp, textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
          const SizedBox(height: 16),
          if (_failed)
            Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Text(l.errorPhotoUpload, textAlign: TextAlign.center))
          else if (image == null)
            const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator())
          else
            LayoutBuilder(builder: (context, c) {
              final side = c.maxWidth.clamp(0.0, 300.0);
              _side = side;
              final child = coverSize(imageSize: Size(image.width.toDouble(), image.height.toDouble()), viewportSide: side);
              return ClipOval(
                child: SizedBox.square(
                  dimension: side,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 1,
                    maxScale: 5,
                    constrained: false,
                    child: RawImage(image: image, width: child.width, height: child.height, fit: BoxFit.fill),
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: _working ? null : () => Navigator.of(context).pop(), child: Text(l.cancelLabel)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('avatar-crop-use'),
                onPressed: image == null || _working || _failed ? null : _confirm,
                child: Text(l.avatarCropUse),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
