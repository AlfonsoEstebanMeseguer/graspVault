// The ONLY file that imports livekit_client (vault rule 1 of Voz.md).
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

  @override
  Future<void> join({required String url, required String token}) async {
    await leave();
    _conn.add(VoiceConnection.connecting);
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
    }
  }
}
