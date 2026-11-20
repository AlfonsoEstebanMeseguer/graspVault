// Turning the cropped square into the bytes that go to R2 (vault ADR 0012):
// the declared mime comes from sniffing the OUTPUT, never from what was asked.
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../domain/account/account.dart';

/// Side of the uploaded photo. Avatars are drawn at <= 88 px; 512 covers dense screens.
const avatarSide = 512;

/// Sanity cap: a 512 px WebP/JPEG is ~30-80 KB, so this only catches a broken codec.
const maxAvatarBytes = 300 * 1024;

const _qualityLadder = [85, 70, 55];

enum AvatarFormat {
  webp('image/webp'),
  jpeg('image/jpeg');

  const AvatarFormat(this.mimeType);
  final String mimeType;
}

/// Magic bytes only, same rule as `sniffImage` in the backend.
AvatarFormat? sniffAvatarFormat(Uint8List b) {
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return AvatarFormat.webp;
  }
  if (b.length >= 3 && b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) return AvatarFormat.jpeg;
  return null;
}

/// The platform codec; returns null when it cannot produce [format].
typedef AvatarEncoder = Future<Uint8List?> Function(Uint8List source, AvatarFormat format, int quality);

Future<Uint8List?> platformAvatarEncoder(Uint8List source, AvatarFormat format, int quality) async {
  try {
    return await FlutterImageCompress.compressWithList(
      source,
      minWidth: avatarSide,
      minHeight: avatarSide,
      quality: quality,
      format: format == AvatarFormat.webp ? CompressFormat.webp : CompressFormat.jpeg,
    );
  } on UnsupportedError {
    // Some devices have no WebP encoder: the caller falls back to JPEG.
    return null;
  }
}

/// WebP first, JPEG as the fallback, lowering quality until it fits.
Future<({Uint8List bytes, String mimeType})> prepareAvatar(Uint8List source, {AvatarEncoder encode = platformAvatarEncoder}) async {
  for (final format in AvatarFormat.values) {
    for (final q in _qualityLadder) {
      final out = await encode(source, format, q);
      if (out == null || sniffAvatarFormat(out) != format) break; // this format is not available here
      if (out.length <= maxAvatarBytes) return (bytes: out, mimeType: format.mimeType);
    }
  }
  throw const AppFailure('image_unreadable');
}
