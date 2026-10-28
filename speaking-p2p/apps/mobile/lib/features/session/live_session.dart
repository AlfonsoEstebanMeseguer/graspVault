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
import '../../domain/exam/control.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import '../../domain/exam/timeline.dart';
import '../exam/control/exam_control.dart';
import '../exam/reader_player.dart';

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

class LiveSession extends ChangeNotifier implements ExamControlHandle {
  LiveSession({
    required this.sessionId,
    required this.myUserId,
    required this._repo,
    required this._voice,
    required this._content,
    this._readerAudio,
    this._voices = const [],
    ServerClock? clock,
    this._tickEvery = const Duration(milliseconds: 500),
    this._contentVersion,
  }) : clock = clock ?? ServerClock();

  final String sessionId;
  final String myUserId;
  final SessionRepository _repo;
  final VoiceService _voice;
  final ExamSource _content;
  final ReaderAudio? _readerAudio;
  final List<String> _voices;
  final ServerClock clock;
  final Duration _tickEvery;
  final int? _contentVersion;

  SessionRow? row;
  Role? myRole;
  PublicProfile? partner;
  Exam? exam;
  ExamEngine? engine;
  bool canSpeak = false;
  bool selfMuted = false;
  bool preloaded = false;
  bool _preparing = false;

  /// Examiner audio of this exam on disk (stepId -> file, D-033).
  Map<String, String> readerFiles = const {};

  /// Part 2 photo id -> downloaded image (D-036).
  Map<String, String> photoFiles = const {};
  Object? error;
  Set<String> speakers = const {};

  StreamSubscription<SessionRow>? _rowSub;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _ticker;
  Object? _lastTicked;
  int _lastLobbyTickMs = 0;
  bool _disposed = false;

  ControlNotice? _notice;
  String? _lastControlSeen;
  bool _seededControl = false;
  String? _engineKey;

  @override
  bool get hasLeader => row?.leaderId != null;
  @override
  bool get iAmLeader => row?.leaderId == myUserId;
  @override
  String get partnerName => partner?.username ?? '…';
  @override
  bool get partnerIsPro => myRole != null && (row?.proOf(myRole!.other) ?? false);
  @override
  ControlNotice? get notice => _notice;

  bool get partnerLeft => row?.state == SessionState.aborted && row?.abortedBy != null && row?.abortedBy != myUserId;
  bool get closed => row?.state == SessionState.ended || row?.state == SessionState.aborted;

  Future<void> start() async {
    _rowSub = _repo.watch(sessionId).listen(_onRow, onError: (Object e) => _fail(e));
    _subs.add(_voice.canSpeak.listen((v) => _set(() => canSpeak = v)));
    _subs.add(_voice.activeSpeakers.listen((v) => _set(() => speakers = v)));
    try {
      final sent = clock.nowMs() - clock.offsetMs;
      final join = await _repo.join(sessionId, contentVersion: _contentVersion);
      clock.sync(join.serverNow, sent, clock.nowMs() - clock.offsetMs);
      myRole = join.role;
      await _voice.join(url: join.url, token: join.token);
    } catch (e, st) {
      _fail(e, st);
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
    _noticeFrom(r);
    if (exam == null || exam!.id != r.examId) {
      // First load, or the leader switched exams (D-040): new content and material.
      final e = await _content.exam(r.level, r.examId);
      if (e == null) {
        // This build does not ship the exam the server picked (older app).
        await _repo.abort(sessionId, reason: 'content_missing').catchError((Object _) {});
        return _fail(const AppFailure('content_missing'));
      }
      if (exam != null) {
        _preparing = false;
        engine = null;
      }
      exam = e;
    }
    if (!_preparing) {
      _preparing = true;
      unawaited(_prepareReader(e: exam!, inLobby: r.state == SessionState.lobby || r.pauseReason == 'switching'));
    }
    // A control (or a debug skip) moved the clock, froze it or rewrote the
    // timeline on the server: rebuild the engine from the row.
    final key = '${r.examId}|${r.examStartedAt?.millisecondsSinceEpoch}|${r.pausedAt?.millisecondsSinceEpoch}|${r.controlVersion}';
    if (engine != null && key != _engineKey) engine = null;
    if (engine == null && r.examStartedAt != null && exam != null && myRole != null && exam!.id == r.examId) {
      _engineKey = key;
      engine = ExamEngine(
        exam: exam!,
        myRole: myRole!,
        examStartedAtMs: r.examStartedAt!.millisecondsSinceEpoch,
        timeline: r.schedule == null ? null : Timeline.fromJson(r.schedule!),
        pausedAtMs: r.pausedAt?.millisecondsSinceEpoch,
        pauseReason: r.pauseReason,
        feedbackEndsAtMs: r.feedbackEndsAt?.millisecondsSinceEpoch,
      );
    }
    if (closed) {
      _ticker?.cancel();
      unawaited(_voice.leave());
    }
    notifyListeners();
  }

  /// A toast per new last_control, never for the one already there on entry.
  void _noticeFrom(SessionRow r) {
    final c = r.lastControl;
    final id = c == null ? null : '${c['op']}|${c['at']}|${c['by']}';
    if (!_seededControl) {
      _seededControl = true;
      _lastControlSeen = id;
      return;
    }
    if (c == null || id == _lastControlSeen) return;
    _lastControlSeen = id;
    final byMe = c['by'] == myUserId;
    _notice = ControlNotice(id: (_notice?.id ?? 0) + 1, op: c['op'] as String? ?? '', actorName: byMe ? '' : partnerName, byMe: byMe);
  }

  @override
  Future<void> control(ControlOp op) =>
      _repo.control(sessionId, op: op.name, args: op.args, expectedVersion: row?.controlVersion ?? 0);

  @override
  Future<void> switchExam(String? examId) => _repo.control(sessionId,
      op: 'switch_exam', args: {'examId': ?examId}, expectedVersion: row?.controlVersion ?? 0);

  @override
  Future<void> transfer() => _repo.control(sessionId, op: 'transfer', expectedVersion: row?.controlVersion ?? 0);

  /// Lobby preload (CLAUDE.md §5): the reader audio in this session's voice
  /// and the Part 2 photos.
  /// "preloaded" is reported even when the download fails: a silent reader
  /// with the text on screen beats a stuck lobby.
  Future<void> _prepareReader({required Exam e, required bool inLobby}) async {
    var media = const ExamMedia();
    final audio = _readerAudio;
    if (audio != null && _voices.isNotEmpty) {
      try {
        media = await audio.prepare(e, voiceForSession(sessionId, _voices));
      } catch (err) {
        debugPrint('reader audio unavailable: $err');
      }
    }
    _set(() {
      readerFiles = media.audio;
      photoFiles = media.photos;
      preloaded = true;
    });
    if (inLobby && !_disposed) {
      unawaited(_repo.setFlag(sessionId, 'preloaded', true).catchError((Object _) {}));
    }
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
    // Every control changes the version: tick once so the server pushes the mics.
    final key = '${row!.controlVersion}:${snap.paused}:${snap.segment?.index ?? snap.state}';
    if (key != _lastTicked) {
      _lastTicked = key;
      unawaited(_repo.tick(sessionId).then<void>((_) {}).catchError((Object _) {}));
    }
    notifyListeners();
  }

  Future<void> setReady(bool v) => _repo.setFlag(sessionId, 'ready', v);
  Future<void> setRecording(bool v) => _repo.setFlag(sessionId, 'recording', v);
  Future<void> abort() => _repo.abort(sessionId);
  Future<void> skip() => _repo.skip(sessionId);

  Future<void> toggleMute() async {
    _set(() => selfMuted = !selfMuted);
    await _voice.setSelfMuted(selfMuted);
  }

  void _fail(Object e, [StackTrace? st]) {
    debugPrint('LiveSession failed: $e${st == null ? '' : '\n$st'}');
    _set(() => error = e);
  }

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
