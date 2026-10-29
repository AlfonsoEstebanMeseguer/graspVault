// The voice contract (vault, Voz.md / ADR 0033). Screens never import the
// provider SDK: only this interface. There is no mute(otherUser) or
// promote(otherUser): the client can never change what someone else may do.
// What the user may say (canSpeak) is decided by the SERVER (canPublish).
import 'dart:async';

enum VoiceConnection { idle, connecting, connected, reconnecting, disconnected }

abstract class VoiceService {
  Stream<VoiceConnection> get connection;

  /// Server permission to publish. When it turns true the engine opens the
  /// microphone by itself ("al asignar el turno se enciende el micro").
  Stream<bool> get canSpeak;

  /// Identities currently talking (for the "Hablando" badges).
  Stream<Set<String>> get activeSpeakers;

  Future<void> join({required String url, required String token});
  Future<void> leave();

  /// The user's own mute. It can only close the mic: while muted the mic stays
  /// off even if the server allows it; unmuting reopens it only if the server
  /// still allows it. Nobody can mute or unmute someone else.
  Future<void> setSelfMuted(bool muted);
}

/// No audio at all: offline practice, tests and devices without permission.
class SilentVoiceService implements VoiceService {
  final _conn = StreamController<VoiceConnection>.broadcast();
  final _can = StreamController<bool>.broadcast();
  final _speakers = StreamController<Set<String>>.broadcast();
  String? joinedWith;

  @override
  Stream<VoiceConnection> get connection => _conn.stream;
  @override
  Stream<bool> get canSpeak => _can.stream;
  @override
  Stream<Set<String>> get activeSpeakers => _speakers.stream;

  @override
  Future<void> join({required String url, required String token}) async {
    joinedWith = token;
    _conn.add(VoiceConnection.connected);
  }

  @override
  Future<void> leave() async => _conn.add(VoiceConnection.disconnected);

  bool selfMuted = false;
  @override
  Future<void> setSelfMuted(bool muted) async => selfMuted = muted;

  /// Test hook: simulate a permission change coming from the server.
  void emitCanSpeak(bool v) => _can.add(v);

  /// Test hook: who LiveKit says is talking.
  void emitSpeakers(Set<String> ids) => _speakers.add(ids);
}
