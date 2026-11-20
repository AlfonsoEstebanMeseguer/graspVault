import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theming/palette.dart';
import '../../../data/profile/avatar_repository.dart';

/// Someone's avatar: their R2 photo if they have one, else the initial. While
/// the photo loads, or if it fails, the initial shows: an avatar is decoration
/// and never breaks the screen it is on.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({
    super.key,
    required this.name,
    required this.userId,
    required this.avatarKey,
    this.size = 40,
    this.background,
    this.foreground,
  });

  final String name;

  /// Null for a deleted user.
  final String? userId;
  final String? avatarKey;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final id = userId;
    final bytes = id == null || avatarKey == null ? null : ref.watch(avatarBytesProvider((userId: id, key: avatarKey))).value;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: background ?? p.brandSoft,
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      onForegroundImageError: bytes == null ? null : (_, _) {},
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: foreground ?? p.onBrandSoft, fontWeight: FontWeight.w700, fontSize: size * 0.4)),
    );
  }
}
