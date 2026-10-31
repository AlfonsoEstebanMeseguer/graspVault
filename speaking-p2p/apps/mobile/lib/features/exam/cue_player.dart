// The exam's two cue sounds (D-058): a beep when a speaking window opens (the
// clock starts with it, never while the examiner reads) and a softer one when
// its time is up. Bundled WAVs (scripts/content/cues.py), muted from the exam
// with the bell button; the choice persists.
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theming/preferences.dart';
import 'reader_player.dart';

enum Cue { start, end }

abstract class CuePlayer {
  Future<void> play(Cue cue);
  Future<void> dispose();
}

class SilentCuePlayer implements CuePlayer {
  final played = <Cue>[];
  @override
  Future<void> play(Cue cue) async => played.add(cue);
  @override
  Future<void> dispose() async {}
}

/// One preloaded player per cue, so a beep never waits for a load. Same
/// audio-session rule as the reader (D-048): in a call the voice engine owns
/// the session and the cues play on its stream; offline the reader's spoken
/// session is reused, never a new one.
class AssetCuePlayer implements CuePlayer {
  AssetCuePlayer({this.inCall = false});
  final bool inCall;
  final _players = <Cue, AudioPlayer>{};
  Future<void>? _ready;

  static const _assets = {Cue.start: 'assets/sounds/cue_start.wav', Cue.end: 'assets/sounds/cue_end.wav'};

  Future<void> _load() async {
    if (!inCall) await (await AudioSession.instance).configure(const AudioSessionConfiguration.speech());
    for (final cue in Cue.values) {
      final p = AudioPlayer(
        handleAudioSessionActivation: !inCall,
        handleInterruptions: !inCall,
        androidApplyAudioAttributes: !inCall,
      );
      _players[cue] = p;
      if (inCall) await p.setAndroidAudioAttributes(FileReaderPlayer.callAttributes);
      await p.setAsset(_assets[cue]!);
    }
  }

  @override
  Future<void> play(Cue cue) async {
    try {
      await (_ready ??= _load());
      final p = _players[cue]!;
      await p.seek(Duration.zero);
      await p.play();
    } catch (_) {
      // A cue is a nicety: never let it break the exam.
    }
  }

  @override
  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
  }
}

typedef CuePlayerFactory = CuePlayer Function({bool inCall});

/// Overridden in tests.
final cuePlayerFactoryProvider = Provider<CuePlayerFactory>((ref) => ({inCall = false}) => AssetCuePlayer(inCall: inCall));

/// The bell button: cues muted. Persisted; without preferences (some widget
/// tests) it simply starts unmuted.
class ExamCuesMuted extends Notifier<bool> {
  static const _key = 'exam_cues_muted';

  @override
  bool build() => _prefs()?.getBool(_key) ?? false;

  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  void toggle() {
    state = !state;
    _prefs()?.setBool(_key, state);
  }
}

final examCuesMutedProvider = NotifierProvider<ExamCuesMuted, bool>(ExamCuesMuted.new);
