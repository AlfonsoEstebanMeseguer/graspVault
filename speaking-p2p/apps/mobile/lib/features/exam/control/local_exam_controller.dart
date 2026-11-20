// Offline practice with a simulated VIP partner (debug builds): the Pro
// controls run on the device with the same reducer the server mirrors
// (domain/exam/control.dart), so the UI can be tried with one phone.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../data/content/content_repository.dart';
import '../../../domain/exam/control.dart';
import '../../../domain/exam/engine.dart';
import '../../../domain/exam/models.dart';
import '../../../domain/exam/timeline.dart';
import '../reader_player.dart';
import 'exam_control.dart';

class LocalExamController extends ChangeNotifier implements ExamControlHandle {
  LocalExamController({
    required Exam exam,
    required this._media,
    required this.myRole,
    required int startedAtMs,
    required this.partnerName,
    required this.catalog,
    required this.loadExam,
    required this.loadMedia,
    int Function()? now,
    this.returnControlAfter = const Duration(seconds: 5),
  })  : _exam = exam,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _state = ControlState.start(exam.id, buildTimeline(exam), startedAtMs);

  final Role myRole;
  @override
  final String partnerName;
  final List<ContentIndexEntry> catalog;
  final Future<Exam?> Function(Level level, String id) loadExam;
  final Future<ExamMedia> Function(Exam exam) loadMedia;
  final Duration returnControlAfter;
  final int Function() _now;

  Exam _exam;
  ExamMedia _media;
  ControlState _state;
  ExamEngine? _engine;
  bool _iAmLeader = true;
  ControlNotice? _notice;
  Timer? _giveBack;
  bool _disposed = false;

  Exam get exam => _exam;
  ExamMedia get media => _media;

  ExamEngine get engine => _engine ??= ExamEngine(
        exam: _exam,
        myRole: myRole,
        examStartedAtMs: _state.startedAtMs,
        timeline: _state.timeline,
        pausedAtMs: _state.pausedAtMs,
        pauseReason: _state.pauseReason,
        feedbackEndsAtMs: _state.feedbackEndsAtMs,
      );

  @override
  bool get hasLeader => true;
  @override
  bool get iAmLeader => _iAmLeader;
  @override
  bool get partnerIsPro => true;
  @override
  ControlNotice? get notice => _notice;

  void _apply(ControlOp op) {
    _state = applyControl(_state, op, _now());
    _engine = null;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _notify(String op, {required String actor, required bool byMe}) {
    _notice = ControlNotice(id: (_notice?.id ?? 0) + 1, op: op, actorName: actor, byMe: byMe);
  }

  @override
  Future<void> control(ControlOp op) async {
    if (!_iAmLeader) throw const ControlError('not_leader');
    _apply(op);
  }

  @override
  Future<void> switchExam(String? examId) async {
    if (!_iAmLeader) throw const ControlError('not_leader');
    final id = examId ?? _randomOther();
    final entry = catalog.firstWhere((e) => e.id == id);
    final next = await loadExam(entry.level, id);
    if (next == null) throw const ControlError('content_missing_partner');
    _exam = next;
    _media = const ExamMedia();
    _apply(SwitchExam(id, buildTimeline(next)));
    try {
      _media = await loadMedia(next);
    } catch (_) {
      // Silent reader: the text is still on screen.
    }
    if (!_disposed) _apply(const FinishSwitch());
  }

  String _randomOther() {
    final same = catalog.where((e) => e.level == _exam.level && e.id != _exam.id).toList();
    return same[math.Random().nextInt(same.length)].id;
  }

  /// The simulated partner takes the lead and hands it back a few seconds
  /// later, so both directions of the handover can be tried on one phone.
  @override
  Future<void> transfer() async {
    if (!_iAmLeader) throw const ControlError('not_leader');
    _iAmLeader = false;
    _notify('transfer', actor: partnerName, byMe: false);
    _changed();
    _giveBack = Timer(returnControlAfter, () {
      _iAmLeader = true;
      _notify('transfer', actor: partnerName, byMe: true);
      _changed();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _giveBack?.cancel();
    super.dispose();
  }
}
