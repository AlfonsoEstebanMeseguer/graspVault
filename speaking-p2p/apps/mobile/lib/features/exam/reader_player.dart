// The examiner voice. Each client plays it locally, synchronised to the server
// start of the step (CLAUDE.md §6). Audio comes from the CDN, never the bundle.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/config/env.dart';
import '../../domain/exam/models.dart';

abstract class ReaderPlayer {
  Future<void> play(ExamStep step, Duration offset);
  Future<void> stop();
  Future<void> dispose();
}

/// Until the TTS is generated and uploaded (PROGRESS.md), the reader is silent
/// and the "Ver texto" card carries the content.
class SilentReaderPlayer implements ReaderPlayer {
  final played = <String>[];
  @override
  Future<void> play(ExamStep step, Duration offset) async => played.add(step.id);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class CdnReaderPlayer implements ReaderPlayer {
  CdnReaderPlayer(this.cdnBase);
  final String cdnBase;
  final _player = AudioPlayer();

  @override
  Future<void> play(ExamStep step, Duration offset) async {
    try {
      await _player.setUrl('$cdnBase/${step.audio}', initialPosition: offset);
      await _player.play();
    } catch (_) {
      // A missing or slow file must never block the exam: the text is still there.
    }
  }

  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

final readerPlayerProvider = Provider.autoDispose<ReaderPlayer>((ref) {
  final cdn = Env.fromDefines.contentCdnUrl;
  final player = cdn.isEmpty ? SilentReaderPlayer() : CdnReaderPlayer(cdn);
  ref.onDispose(player.dispose);
  return player;
});
