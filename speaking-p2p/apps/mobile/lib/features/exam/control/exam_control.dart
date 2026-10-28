// What the exam screen needs to offer the Pro controls (D-038/D-039). Two
// implementations: LocalExamController (offline practice with a simulated VIP
// partner) and LiveSession (the server decides). The UI is the same.
import 'package:flutter/foundation.dart';

import '../../../domain/exam/control.dart';

/// One thing the leader did, for the toast both phones show.
class ControlNotice {
  const ControlNotice({required this.id, required this.op, required this.actorName, required this.byMe});

  /// Changes with every new notice (the screen shows each one once).
  final int id;

  /// Wire name of the op ('pause', 'next_part', 'transfer'…).
  final String op;
  final String actorName;
  final bool byMe;
}

abstract class ExamControlHandle implements Listenable {
  /// Somebody leads this exam (at least one participant has Pro).
  bool get hasLeader;
  bool get iAmLeader;

  /// Shown as "Led by …" when the partner leads.
  String get partnerName;
  bool get partnerIsPro;
  ControlNotice? get notice;

  /// Throws ControlError (offline) or AppFailure (live) with the same codes.
  Future<void> control(ControlOp op);

  /// Null = random exam of the same level.
  Future<void> switchExam(String? examId);
  Future<void> transfer();
}
