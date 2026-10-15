// Offline practice / development mode with a simulated partner (Milestone 2):
// test the whole exam on one device, without backend or LiveKit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../data/content/content_repository.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import 'exam_screen.dart';

final _practiceExamProvider = FutureProvider.autoDispose.family<Exam?, Level>((ref, level) async {
  final repo = ref.watch(contentRepositoryProvider);
  final index = await repo.index();
  final entry = index.exams.firstWhere((e) => e.level == level);
  return repo.exam(level, entry.id);
});

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.level, this.role = Role.a, this.skipToMs = 0});
  final Level level;
  final Role role;

  /// Development aid: start as if this much of the exam had already elapsed
  /// (/practice/B2?at=600000 jumps to Part 3 territory). Offline practice only.
  final int skipToMs;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  // 3 s lead, like a live session.
  late final int _startedAt = DateTime.now().millisecondsSinceEpoch + (widget.skipToMs > 0 ? -widget.skipToMs : 3000);

  @override
  Widget build(BuildContext context) {
    final exam = ref.watch(_practiceExamProvider(widget.level));
    return exam.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (exam) => exam == null
          ? const Scaffold(body: SizedBox.shrink())
          : ExamScreen(
              engine: ExamEngine(exam: exam, myRole: widget.role, examStartedAtMs: _startedAt),
              myName: 'yo',
              partnerName: context.l10n.simulatedPartner,
              nowMs: () => DateTime.now().millisecondsSinceEpoch,
              simulatedPartner: true,
              onAbandon: () async => context.go('/'),
              onExit: () => context.go('/'),
            ),
    );
  }
}
