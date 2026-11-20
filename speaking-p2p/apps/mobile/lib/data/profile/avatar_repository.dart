// Profile photo in R2 (vault ADR 0010/0012/0013): the server picks the key and
// signs a PUT, the client uploads the bytes straight to R2, and the server
// checks the magic bytes before writing profiles.avatar_key.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/account/account.dart';

abstract class AvatarRepository {
  /// [mimeType] must describe the bytes for real: it is signed into the PUT.
  Future<void> upload(Uint8List bytes, String mimeType);
  Future<void> remove();

  /// The photo bytes of [userId], or null if they have none.
  Future<Uint8List?> download(String userId);
}

class SupabaseAvatarRepository implements AvatarRepository {
  SupabaseAvatarRepository(this._c);
  final sb.SupabaseClient _c;
  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  Future<Map<String, dynamic>> _invoke(String fn, Map<String, Object?> body) async {
    try {
      return ((await _c.functions.invoke(fn, body: body)).data as Map).cast<String, dynamic>();
    } on sb.FunctionException catch (e) {
      final d = e.details;
      throw AppFailure(d is Map && d['error'] is String ? d['error'] as String : 'server_error');
    }
  }

  @override
  Future<void> upload(Uint8List bytes, String mimeType) async {
    final signed = await _invoke('avatar-upload-url', {'mimeType': mimeType});
    final req = await _http.putUrl(Uri.parse(signed['url'] as String));
    req.headers.set(HttpHeaders.contentTypeHeader, mimeType);
    req.contentLength = bytes.length;
    req.add(bytes);
    final res = await req.close();
    await res.drain<void>();
    if (res.statusCode != 200) throw const AppFailure('upload_failed');
    await _invoke('avatar-confirm', {'key': signed['key']});
  }

  @override
  Future<void> remove() => _invoke('avatar-confirm', {'remove': true});

  @override
  Future<Uint8List?> download(String userId) async {
    final String url;
    try {
      url = (await _invoke('media-view-url', {'kind': 'avatar', 'userId': userId}))['url'] as String;
    } on AppFailure catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
    final res = await (await _http.getUrl(Uri.parse(url))).close();
    if (res.statusCode != 200) {
      await res.drain<void>();
      return null;
    }
    final out = BytesBuilder(copy: false);
    await for (final chunk in res) {
      out.add(chunk);
    }
    return out.takeBytes();
  }
}

final avatarRepositoryProvider = Provider<AvatarRepository?>((ref) {
  return Env.fromDefines.hasBackend ? SupabaseAvatarRepository(sb.Supabase.instance.client) : null;
});

/// Who to draw: the key is part of the cache key, so a new photo refetches on
/// its own while an unchanged one is downloaded once per app run.
typedef AvatarSource = ({String userId, String? key});

/// Photo bytes, cached for as long as the key stays the same. Keys are
/// immutable (a new photo = a new uuid), so caching bytes instead of the
/// signed URL (which expires in 300 s) never shows a stale or broken image.
final avatarBytesProvider = FutureProvider.autoDispose.family<Uint8List?, AvatarSource>((ref, src) async {
  final repo = ref.watch(avatarRepositoryProvider);
  if (src.key == null || repo == null) return null;
  final link = ref.keepAlive();
  try {
    return await repo.download(src.userId);
  } catch (_) {
    // Not cached: the next time the avatar is shown it tries again.
    link.close();
    return null;
  }
});
