// The ONLY file that imports livekit_client (vault rule 1 of Voz.md).
//
// The audio session API is marked experimental in livekit_client 2.13; it is
// the only way to keep the iOS session fixed during a call (D-048). Re-check
// _iosCallSession when upgrading livekit_client.
// ignore_for_file: experimental_member_use
import 'dart:async';

import 'package:livekit_client/livekit_client.dart' as lk;

import 'voice_service.dart';

class LiveKitEngine implements VoiceService {
  final _conn = StreamController<VoiceConnection>.broadcast();
  final _can = StreamController<bool>.broadcast();
  final _speakers = StreamController<Set<String>>.broadcast();
  lk.Room? _room;
  lk.EventsListener<lk.RoomEvent>? _listener;
  bool _serverAllows = false;
  bool _selfMuted = false;

  @override
  Stream<VoiceConnection> get connection => _conn.stream;
  @override
  Stream<bool> get canSpeak => _can.stream;
  @override
  Stream<Set<String>> get activeSpeakers => _speakers.stream;

  /// iOS session for the whole room (D-048). In its automatic mode LiveKit
  /// follows the WebRTC engine: playback-only when nobody may speak and
  /// deactivated when the engine idles. That is exactly when the examiner
  /// reads (the server closes both mics), so his audio was cut until a volume
  /// key woke the session up. This fixed call session never changes under the
  /// reader: speaker by default, a headset or Bluetooth device when one is
  /// connected (no forced override), and the same voice processing as before
  /// (echo cancellation). Android keeps LiveKit's automatic communication mode.
  static const _iosCallSession = lk.AudioSessionOptions.communication(
    apple: lk.AppleAudioSessionConfiguration(
      category: lk.AppleAudioCategory.playAndRecord,
      categoryOptions: {
        lk.AppleAudioCategoryOption.defaultToSpeaker,
        lk.AppleAudioCategoryOption.allowBluetooth,
        lk.AppleAudioCategoryOption.allowBluetoothA2DP,
        lk.AppleAudioCategoryOption.allowAirPlay,
      },
      mode: lk.AppleAudioMode.videoChat,
    ),
  );

  static bool get _ios => lk.lkPlatformIs(lk.PlatformType.iOS);

  @override
  Future<void> join({required String url, required String token}) async {
    await leave();
    _conn.add(VoiceConnection.connecting);
    if (_ios) {
      try {
        await lk.AudioManager.instance.setAudioSessionOptions(_iosCallSession);
      } catch (_) {
        // The call still connects with LiveKit's own session.
      }
    }
    final room = lk.Room(roomOptions: const lk.RoomOptions(adaptiveStream: false, dynacast: false));
    _room = room;
    _listener = room.createListener()
      ..on<lk.RoomReconnectingEvent>((_) => _conn.add(VoiceConnection.reconnecting))
      ..on<lk.RoomReconnectedEvent>((_) => _conn.add(VoiceConnection.connected))
      ..on<lk.RoomDisconnectedEvent>((_) => _conn.add(VoiceConnection.disconnected))
      ..on<lk.ActiveSpeakersChangedEvent>((e) => _speakers.add(e.speakers.map((p) => p.identity).toSet()))
      ..on<lk.ParticipantPermissionsUpdatedEvent>((e) async {
        if (e.participant is! lk.LocalParticipant) return;
        await _applyPermission(e.permissions.canPublish);
      });
    await room.connect(url, token);
    _conn.add(VoiceConnection.connected);
    await _applyPermission(room.localParticipant?.permissions.canPublish ?? false);
  }

  Future<void> _applyPermission(bool canPublish) async {
    _serverAllows = canPublish;
    _can.add(canPublish);
    await _syncMic();
  }

  // Opening the mic only when the server allows it AND the user has not muted
  // themselves; when the server revokes, LiveKit unpublishes the track and this
  // just keeps the local state in sync.
  Future<void> _syncMic() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(_serverAllows && !_selfMuted);
    } catch (_) {
      // Missing OS permission: the UI shows the mic as closed; the exam goes on.
    }
  }

  @override
  Future<void> setSelfMuted(bool muted) async {
    _selfMuted = muted;
    await _syncMic();
  }

  @override
  Future<void> leave() async {
    await _listener?.dispose();
    _listener = null;
    final room = _room;
    _room = null;
    if (room != null) {
      await room.disconnect();
      await room.dispose();
      // Give the session back (other apps' audio resumes); offline practice
      // configures its own playback session.
      if (_ios) {
        try {
          await lk.AudioManager.instance.deactivateAudioSession();
        } catch (_) {}
      }
    }
  }
}
