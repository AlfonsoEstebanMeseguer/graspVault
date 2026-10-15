// Drives one live exam session on the device.
//  * Reads the row (Realtime) and acts through SessionRepository.
//  * Keeps a server-aligned clock: every client derives the exam from
//    (serverNow - exam_started_at), never from its own stopwatch (CLAUDE.md §6).
//  * Ticks the server at every segment boundary so the mic policy is applied
//    on time (the cron is only a backstop, D-003).
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/voice/voice_service.dart';
import '../../data/content/content_repository.dart';
import '../../data/session/session_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';

class ServerClock {
  ServerClock([int Function()? localNow]) : _local = localNow ?? (() => DateTime.now().millisecondsSinceEpoch);
  final int Function() _local;
  int _offsetMs = 0;
  int get offsetMs => _offsetMs;

  /// NTP-style: the server instant corresponds to the middle of the round trip.
  void sync(DateTime serverNow, int sentAtLocalMs, int receivedAtLocalMs) {
    final mid = (sentAtLocalMs + receivedAtLocalMs) ~/ 2;
    _offsetMs = serverNow.millisecondsSinceEpoch - mid;
  }

  int nowMs() => _local() + _offsetMs;
}

abstract class ExamSource {
  Future<Exam?> exam(Level level, String id);
}

class BundleExamSource implements ExamSource {
  BundleExamSource(this._repo);
  final ContentRepository _repo;
  @override
  Future<Exam?> exam(Level level, String id) => _repo.exam(level, id);
}

class LiveSession extends ChangeNotifier {
  LiveSession({
    required this.sessionId,
    required this.myUserId,
    required this._repo,
    required this._voice,
    required this._content,
    ServerClock? clock,
    this._tickEvery = const Duration(milliseconds: 500),
  }) : clock = clock ?? ServerClock();

  final String sessionId;
  final String myUserId;
  final SessionRepository _repo;
  final VoiceService _voice;
  final ExamSource _content;
  final ServerClock clock;
  final Duration _tickEvery;

  SessionRow? row;
  Role? myRole;
  PublicProfile? partner;
  Exam? exam;
  ExamEngine? engine;
  bool canSpeak = false;
  bool preloaded = false;
  Object? error;
  Set<String> speakers = const {};

  StreamSubscription<SessionRow>? _rowSub;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _ticker;
  Object? _lastTicked;
  int _lastLobbyTickMs = 0;
  bool _disposed = false;

  bool get partnerLeft => row?.state == SessionState.aborted && row?.abortedBy != null && row?.abortedBy != myUserId;
  bool get closed => row?.state == SessionState.ended || row?.state == SessionState.aborted;

  Future<void> start() async {
    _rowSub = _repo.watch(sessionId).listen(_onRow, onError: (Object e) => _fail(e));
    _subs.add(_voice.canSpeak.listen((v) => _set(() => canSpeak = v)));
    _subs.add(_voice.activeSpeakers.listen((v) => _set(() => speakers = v)));
    try {
      final sent = clock.nowMs() - clock.offsetMs;
      final join = await _repo.join(sessionId);
      clock.sync(join.serverNow, sent, clock.nowMs() - clock.offsetMs);
      myRole = join.role;
      await _voice.join(url: join.url, token: join.token);
    } catch (e) {
      _fail(e);
      return;
    }
    _ticker = Timer.periodic(_tickEvery, (_) => tickNow());
    notifyListeners();
  }

  Future<void> _onRow(SessionRow r) async {
    row = r;
    myRole ??= r.roleOf(myUserId);
    final partnerId = myRole == null ? null : r.userOf(myRole!.other);
    if (partner == null && partnerId != null) {
      unawaited(_repo.publicProfile(partnerId).then((p) => _set(() => partner = p)).catchError((Object _) {}));
    }
    if (exam == null) {
      final e = await _content.exam(r.level, r.examId);
      if (e == null) {
        // This build does not ship the exam the server picked (older app).
        await _repo.abort(sessionId, reason: 'content_missing').catchError((Object _) {});
        return _fail(const AppFailure('content_missing'));
      }
      exam = e;
      // Reader audio/photos are not on R2 yet (no TTS): the JSON is the material.
      if (!preloaded && r.state == SessionState.lobby) {
        preloaded = true;
        unawaited(_repo.setFlag(sessionId, 'preloaded', true).catchError((Object _) {}));
      }
    }
    if (engine == null && r.examStartedAt != null && exam != null && myRole != null) {
      engine = ExamEngine(exam: exam!, myRole: myRole!, examStartedAtMs: r.examStartedAt!.millisecondsSinceEpoch);
    }
    if (closed) {
      _ticker?.cancel();
      unawaited(_voice.leave());
    }
    notifyListeners();
  }

  @visibleForTesting
  void tickNow() {
    if (closed || row == null) return;
    final now = clock.nowMs();
    final e = engine;
    if (e == null) {
      // Lobby: let the server start the exam at the deadline even if nobody ticks.
      if (now - _lastLobbyTickMs > 5000) {
        _lastLobbyTickMs = now;
        unawaited(_repo.tick(sessionId).then<void>((_) {}).catchError((Object _) {}));
      }
      return;
    }
    final snap = e.at(now);
    final key = snap.segment?.index ?? snap.state;
    if (key != _lastTicked) {
      _lastTicked = key;
      unawaited(_repo.tick(sessionId).then<void>((_) {}).catchError((Object _) {}));
    }
    notifyListeners();
  }

  Future<void> setReady(bool v) => _repo.setFlag(sessionId, 'ready', v);
  Future<void> setRecording(bool v) => _repo.setFlag(sessionId, 'recording', v);
  Future<void> abort() => _repo.abort(sessionId);

  void _fail(Object e) => _set(() => error = e);

  void _set(VoidCallback f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    unawaited(_rowSub?.cancel());
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    unawaited(_voice.leave());
    super.dispose();
  }
}
