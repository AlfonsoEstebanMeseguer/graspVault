// Little rewards outside the exam (D-069): a sound and a tap of haptics when
// the user searches, gets a partner, sends a message or proposes a time.
// Bundled WAVs (scripts/content/ui_sounds.py), one preloaded player each so the
// sound lands with the finger. Ambient session: it mixes with the user's music
// and respects the silent switch; never used during a call or the exam.
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

enum UiSound { search, match, sent, propose }

abstract class UiSounds {
  void play(UiSound sound);
}

class SilentUiSounds implements UiSounds {
  final played = <UiSound>[];
  @override
  void play(UiSound sound) => played.add(sound);
}

class AssetUiSounds implements UiSounds {
  final _players = <UiSound, AudioPlayer>{};
  Future<void>? _ready;

  static const _assets = {
    UiSound.search: 'assets/sounds/ui_search.wav',
    UiSound.match: 'assets/sounds/ui_match.wav',
    UiSound.sent: 'assets/sounds/ui_sent.wav',
    UiSound.propose: 'assets/sounds/ui_propose.wav',
  };

  static const _ambient = AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.ambient,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
    androidAudioAttributes: _attributes,
    androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
  );

  static const _attributes = AndroidAudioAttributes(
    contentType: AndroidAudioContentType.sonification,
    usage: AndroidAudioUsage.media,
  );

  Future<void> _load() async {
    for (final s in UiSound.values) {
      // No session activation nor focus: the user's music keeps playing.
      final p = AudioPlayer(handleAudioSessionActivation: false, handleInterruptions: false, androidApplyAudioAttributes: false);
      _players[s] = p;
      await p.setAndroidAudioAttributes(_attributes);
      await p.setAsset(_assets[s]!);
    }
  }

  /// Starts loading the players (call it where a sound is about to be needed).
  void warmUp() => _ready ??= _load().catchError((Object _) {});

  @override
  void play(UiSound sound) {
    _haptic(sound);
    _play(sound);
  }

  Future<void> _play(UiSound sound) async {
    try {
      // The reader sets a spoken session for the exam: back to ambient here.
      await (await AudioSession.instance).configure(_ambient);
      warmUp();
      await _ready;
      final p = _players[sound];
      if (p == null) return;
      await p.seek(Duration.zero);
      await p.play();
    } catch (_) {
      // A nicety: never let it break the flow.
    }
  }

  static void _haptic(UiSound sound) {
    switch (sound) {
      case UiSound.match:
        HapticFeedback.mediumImpact();
      case UiSound.sent:
        HapticFeedback.selectionClick();
      case UiSound.search || UiSound.propose:
        HapticFeedback.lightImpact();
    }
  }
}

bool get _underTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// Overridden in tests; silent under `flutter test` (no audio plugin there).
final uiSoundsProvider = Provider<UiSounds>((ref) => _underTest ? SilentUiSounds() : (AssetUiSounds()..warmUp()));
