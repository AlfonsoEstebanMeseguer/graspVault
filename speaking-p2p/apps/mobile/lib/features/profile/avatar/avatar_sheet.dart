// Change the profile photo: a bottom sheet over Perfil, not a screen of its own
// (vault ADR 0014). Pick -> crop -> compress -> upload; it applies at once.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/errors.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theming/palette.dart';
import '../../../data/profile/avatar_repository.dart';
import '../../../data/profile/profile_repository.dart';
import 'avatar_crop_sheet.dart';
import 'avatar_image.dart';

enum AvatarPickSource { gallery, camera }

/// The system picker; overridden in tests (there is none in the test VM).
final avatarPickerProvider = Provider<Future<Uint8List?> Function(AvatarPickSource)>((ref) => (source) async {
      final file = await ImagePicker().pickImage(
        source: source == AvatarPickSource.camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.front,
        // Only avoids holding a 12 MP photo in memory; the real resize is prepareAvatar.
        maxWidth: 2048,
        maxHeight: 2048,
      );
      return file?.readAsBytes();
    });

/// Overridable so widget tests can skip decoding a real image.
final avatarCropProvider = Provider<Future<Uint8List?> Function(BuildContext, Uint8List)>((ref) => AvatarCropSheet.show);
final avatarEncoderProvider = Provider<AvatarEncoder>((ref) => platformAvatarEncoder);

class AvatarSheet extends ConsumerStatefulWidget {
  const AvatarSheet({super.key, required this.hasPhoto});
  final bool hasPhoto;

  static Future<void> show(BuildContext context, {required bool hasPhoto}) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => AvatarSheet(hasPhoto: hasPhoto),
      );

  @override
  ConsumerState<AvatarSheet> createState() => _AvatarSheetState();
}

class _AvatarSheetState extends ConsumerState<AvatarSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<bool> Function() action, String done) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await action()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      ref.invalidate(myProfileProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      // Shown inside the sheet: closing it would make the user start over to retry.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(context.l10n, e);
        });
      }
    }
  }

  Future<bool> _upload(AvatarPickSource source) async {
    final picked = await ref.read(avatarPickerProvider)(source);
    if (picked == null || !mounted) return false; // cancelled: not an error
    // Crop BEFORE compressing, so zooming never magnifies compression artefacts.
    final cropped = await ref.read(avatarCropProvider)(context, picked);
    if (cropped == null) return false;
    final ready = await prepareAvatar(cropped, encode: ref.read(avatarEncoderProvider));
    await ref.read(avatarRepositoryProvider)!.upload(ready.bytes, ready.mimeType);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    Widget action(Key key, IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
          key: key,
          enabled: !_busy,
          leading: Icon(icon, color: color ?? p.brand),
          title: Text(label, style: TextStyle(color: color ?? p.textPrimary, fontWeight: FontWeight.w600)),
          onTap: onTap,
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.avatarTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
          ),
          action(const Key('avatar-gallery'), Icons.photo_library_outlined, l.avatarFromGallery,
              () => _run(() => _upload(AvatarPickSource.gallery), l.avatarUpdated)),
          action(const Key('avatar-camera'), Icons.photo_camera_outlined, l.avatarFromCamera,
              () => _run(() => _upload(AvatarPickSource.camera), l.avatarUpdated)),
          if (widget.hasPhoto)
            action(const Key('avatar-remove'), Icons.delete_outline, l.avatarRemove, () => _run(() async {
                  await ref.read(avatarRepositoryProvider)!.remove();
                  return true;
                }, l.avatarRemoved), color: p.danger),
          if (_busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.danger)),
            ),
        ]),
      ),
    );
  }
}
