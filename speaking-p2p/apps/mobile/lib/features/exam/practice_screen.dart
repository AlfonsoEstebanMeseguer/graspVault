// Offline practice / development mode with a simulated partner (Milestone 2):
// test the whole exam on one device, without backend or LiveKit.
// `vip`: the simulated partner has Pro and you lead the exam (D-039), so the
// Pro controls can be tried with one phone (debug builds only).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../data/content/content_repository.dart';
import '../../domain/exam/engine.dart';
import '../../domain/exam/models.dart';
import 'control/local_exam_controller.dart';
import 'exam_screen.dart';
import 'reader_player.dart';

/// Reader audio in a random voice (D-033) and the photos. Without backend, or
/// if the download fails, the reader is silent and the text carries it.
Future<ExamMedia> _media(WidgetRef ref, Exam exam, List<String> voices) async {
  final audio = ref.read(readerAudioProvider);
  if (audio == null || voices.isEmpty) return const ExamMedia();
  try {
    return await audio.prepare(exam, randomVoice(voices));
  } catch (_) {
    return const ExamMedia();
  }
}

final _practiceExamProvider =
    FutureProvider.autoDispose.family<({Exam exam, ExamMedia media, ContentIndex index})?, Level>((ref, level) async {
  final repo = ref.watch(contentRepositoryProvider);
  final index = await repo.index();
  final entry = index.exams.firstWhere((e) => e.level == level);
  final exam = await repo.exam(level, entry.id);
  if (exam == null) return null;
  var media = const ExamMedia();
  final audio = ref.read(readerAudioProvider);
  if (audio != null && index.voices.isNotEmpty) {
    try {
      media = await audio.prepare(exam, randomVoice(index.voices));
    } catch (_) {}
  }
  return (exam: exam, media: media, index: index);
});

class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.level, this.role = Role.a, this.skipToMs = 0, this.vip = false});
  final Level level;
  final Role role;

  /// Development aid: start as if this much of the exam had already elapsed
  /// (/practice/B2?at=600000 jumps to Part 3 territory). Offline practice only.
  final int skipToMs;

  /// The simulated partner is VIP: Pro controls on (/practice/B2?vip=1).
  final bool vip;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  // 3 s lead, like a live session.
  late final int _startedAt = DateTime.now().millisecondsSinceEpoch + (widget.skipToMs > 0 ? -widget.skipToMs : 3000);
  LocalExamController? _vip;

  @override
  void dispose() {
    _vip?.dispose();
    super.dispose();
  }

  LocalExamController _controller(({Exam exam, ExamMedia media, ContentIndex index}) ready) => _vip ??= LocalExamController(
        exam: ready.exam,
        media: ready.media,
        myRole: widget.role,
        startedAtMs: _startedAt,
        partnerName: context.l10n.simulatedPartner,
        catalog: ready.index.exams,
        loadExam: ref.read(contentRepositoryProvider).exam,
        loadMedia: (e) => _media(ref, e, ready.index.voices),
      );

  ExamScreen _screen({
    Key? key,
    required ExamEngine engine,
    required ExamMedia media,
    LocalExamController? control,
  }) =>
      ExamScreen(
        key: key,
        engine: engine,
        readerFiles: media.audio,
        photoFiles: media.photos,
        myName: 'yo',
        partnerName: context.l10n.simulatedPartner,
        nowMs: () => DateTime.now().millisecondsSinceEpoch,
        simulatedPartner: true,
        control: control,
        onAbandon: () async => context.go('/'),
        onExit: () => context.go('/'),
      );

  @override
  Widget build(BuildContext context) {
    final exam = ref.watch(_practiceExamProvider(widget.level));
    return exam.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (ready) {
        if (ready == null) return const Scaffold(body: SizedBox.shrink());
        if (!widget.vip) {
          return _screen(
            engine: ExamEngine(exam: ready.exam, myRole: widget.role, examStartedAtMs: _startedAt),
            media: ready.media,
          );
        }
        final c = _controller(ready);
        return ListenableBuilder(
          listenable: c,
          // A new exam = a new screen (its own reader files and diagram).
          builder: (context, _) => _screen(key: ValueKey(c.exam.id), engine: c.engine, media: c.media, control: c),
        );
      },
    );
  }
}
