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

  /// Test hook: simulate a permission change coming from the server.
  void emitCanSpeak(bool v) => _can.add(v);
}
