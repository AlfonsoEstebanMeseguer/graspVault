// The examiner voice. Each client plays it locally, synchronised to the server
// start of the step (CLAUDE.md §6). Audio and Part 2 photos come from R2,
// never the bundle.
//
// D-033: every step exists in several voices (content/index.json "voices").
// Both clients of a session derive the same voice from the session id. The
// files are downloaded during the lobby (the "material downloaded" check) and
// played from disk, so a slow network never shifts the examiner mid-exam.
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/config/env.dart';
import '../../domain/exam/models.dart';

abstract class ReaderPlayer {
  Future<void> play(ExamStep step, Duration offset);
  Future<void> stop();
  Future<void> dispose();
}

/// No audio (offline build, tests, or the download failed): the "Ver texto"
/// card carries the content.
class SilentReaderPlayer implements ReaderPlayer {
  final played = <String>[];
  @override
  Future<void> play(ExamStep step, Duration offset) async => played.add(step.id);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

/// Plays the downloaded files (stepId -> local path).
///
/// D-048: one owner of the audio session. In a call ([inCall]) the voice
/// engine owns it (speaker by default, headset/Bluetooth when connected, echo
/// cancellation), so the reader never activates, reconfigures or takes audio
/// focus: just_audio's default would switch iOS to a "music" playback session
/// under the call and request Android focus against it. On Android it plays on
/// the call stream, so it follows the same route and volume keys as the partner.
/// Offline the reader owns a spoken-audio session (audible in silent mode).
class FileReaderPlayer implements ReaderPlayer {
  FileReaderPlayer(this.files, {this.inCall = false})
      : _player = AudioPlayer(
          handleAudioSessionActivation: !inCall,
          handleInterruptions: !inCall,
          androidApplyAudioAttributes: !inCall,
        ) {
    _ready = (inCall ? _player.setAndroidAudioAttributes(callAttributes) : _configureOffline())
        .catchError((Object _) {}); // never block the exam on the audio setup
  }

  final Map<String, String> files;
  final bool inCall;
  final AudioPlayer _player;
  late final Future<void> _ready;

  /// The partner's voice stream (LiveKit plays it as voice communication).
  static const callAttributes = AndroidAudioAttributes(
    contentType: AndroidAudioContentType.speech,
    usage: AndroidAudioUsage.voiceCommunication,
  );

  static Future<void> _configureOffline() async =>
      (await AudioSession.instance).configure(const AudioSessionConfiguration.speech());

  @override
  Future<void> play(ExamStep step, Duration offset) async {
    final path = files[step.id];
    if (path == null) return;
    try {
      await _ready;
      await _player.setFilePath(path, initialPosition: offset);
      await _player.play();
    } catch (_) {
      // A broken file must never block the exam: the text is still there.
    }
  }

  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

typedef ReaderPlayerFactory = ReaderPlayer Function(Map<String, String> files, {bool inCall});

/// Builds the player for an exam from its downloaded files. Overridden in tests.
final readerPlayerFactoryProvider = Provider<ReaderPlayerFactory>(
  (ref) => (files, {inCall = false}) => files.isEmpty ? SilentReaderPlayer() : FileReaderPlayer(files, inCall: inCall),
);

/// Same voice on both phones: a stable hash of the session id (not
/// String.hashCode, which is not guaranteed across runs/platforms).
String voiceForSession(String sessionId, List<String> voices) {
  var h = 0;
  for (final c in sessionId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return voices[h % voices.length];
}

String randomVoice(List<String> voices) => voices[math.Random().nextInt(voices.length)];

/// R2 key of one step in one voice: the step keeps its voice-less path.
String voiceKey(String voice, String audio) => audio.replaceFirst('audio/', 'audio/$voice/');

/// R2 key of a Part 2 photo (D-036): compressed WebP, never in the bundle.
String photoKey(Exam exam, String assetId) => 'img/${exam.level.code}/${exam.id}/$assetId.webp';

/// What the lobby downloaded: stepId -> audio file, photo id -> image file.
/// Anything missing degrades gracefully (silent step, captioned placeholder).
class ExamMedia {
  const ExamMedia({this.audio = const {}, this.photos = const {}});
  final Map<String, String> audio;
  final Map<String, String> photos;
}

abstract class ReaderAudio {
  /// Downloads (or reuses) every step of [exam] in [voice] and its photos.
  Future<ExamMedia> prepare(Exam exam, String voice);
}

class R2ReaderAudio implements ReaderAudio {
  R2ReaderAudio(this._c);
  final sb.SupabaseClient _c;

  @override
  Future<ExamMedia> prepare(Exam exam, String voice) async {
    final steps = [for (final p in exam.parts) ...p.steps];
    final audioKeys = {for (final s in steps) voiceKey(voice, s.audio): s.id};
    final photoKeys = {
      for (final s in steps)
        for (final id in s.assets) photoKey(exam, id): id,
    };
    final files = await _download([...audioKeys.keys, ...photoKeys.keys]);
    return ExamMedia(
      audio: {for (final e in audioKeys.entries) if (files[e.key] != null) e.value: files[e.key]!},
      photos: {for (final e in photoKeys.entries) if (files[e.key] != null) e.value: files[e.key]!},
    );
  }

  /// R2 key -> local file. A file already on disk from an earlier session is
  /// reused (see [reusable]): every reuse saves an R2 read and a signed URL.
  Future<Map<String, String>> _download(List<String> keys) async {
    final dir = Directory('${Directory.systemTemp.path}/reader');
    final out = <String, String>{};
    final missing = <String>[];
    final now = DateTime.now();
    for (final key in keys) {
      final file = File('${dir.path}/$key');
      if (reusable(key, file.existsSync() ? file.statSync() : null, now)) {
        out[key] = file.path;
      } else {
        missing.add(key);
      }
    }
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      for (var i = 0; i < missing.length; i += 100) {
        final batch = missing.sublist(i, math.min(i + 100, missing.length));
        final r = await _c.functions.invoke('media-view-url', body: {'kind': 'content', 'keys': batch});
        final urls = ((r.data as Map)['urls'] as Map).cast<String, String>();
        await Future.wait(batch.map((key) async {
          final url = urls[key];
          if (url == null) return;
          try {
            final res = await (await http.getUrl(Uri.parse(url))).close();
            if (res.statusCode != 200) {
              // 404 = a photo not uploaded yet: the placeholder shows its caption.
              await res.drain<void>();
              return;
            }
            final file = File('${dir.path}/$key');
            await file.parent.create(recursive: true);
            // Unique temp name: two sessions may fetch the same photo at once.
            final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.part');
            await res.pipe(tmp.openWrite());
            await tmp.rename(file.path);
            out[key] = file.path;
          } catch (_) {
            // One missing file is not a reason to hold the exam.
          }
        }));
      }
    } finally {
      http.close(force: true);
    }
    return out;
  }
}

/// Audio is immutable per path, so it is reused forever. A photo can be replaced
/// under the same key, so a copy is reused for [photoCacheTtl] (D-047).
const photoCacheTtl = Duration(days: 14);

bool reusable(String key, FileStat? stat, DateTime now) =>
    stat != null &&
    stat.type == FileSystemEntityType.file &&
    stat.size > 0 &&
    (key.startsWith('audio/') || now.difference(stat.modified) < photoCacheTtl);

/// Null without backend: the reader stays silent.
final readerAudioProvider = Provider<ReaderAudio?>((ref) {
  return Env.fromDefines.hasBackend ? R2ReaderAudio(sb.Supabase.instance.client) : null;
});
