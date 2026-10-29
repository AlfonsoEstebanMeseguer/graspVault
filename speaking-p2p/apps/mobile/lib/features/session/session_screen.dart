// One live session: lobby -> Parts 1-4 -> feedback, driven by the server.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/voice/livekit_engine.dart';
import '../../core/voice/voice_service.dart';
import '../../data/auth/auth_repository.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../data/content/content_repository.dart';
import '../../data/profile/profile_repository.dart';
import '../../data/session/session_repository.dart';
import '../../domain/account/account.dart';
import '../../domain/agenda/agenda.dart' show CompanionLink;
import '../../domain/exam/timeline.dart';
import '../exam/exam_screen.dart';
import '../exam/reader_player.dart';
import 'live_session.dart';
import '../../data/safety/safety_repository.dart';
import '../safety/safety_sheet.dart';
import 'lobby_view.dart';

/// Overridable in tests (no WebRTC in the test VM).
final voiceServiceFactoryProvider = Provider<VoiceService Function()>((ref) => LiveKitEngine.new);

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.sessionId});
  final String sessionId;
  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  LiveSession? _session;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(sessionRepositoryProvider);
    final user = ref.read(authUserProvider).value;
    if (repo == null || user == null) return;
    _session = LiveSession(
      sessionId: widget.sessionId,
      myUserId: user.id,
      repo: repo,
      voice: ref.read(voiceServiceFactoryProvider)(),
      content: BundleExamSource(ref.read(contentRepositoryProvider)),
      readerAudio: ref.read(readerAudioProvider),
      voices: ref.read(contentIndexProvider).value?.voices ?? const [],
      contentVersion: ref.read(contentIndexProvider).value?.version,
    )..start();
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _home() => context.go('/');

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final l = context.l10n;
    if (s == null) return _Message(text: l.sessionError, action: l.backHome, onAction: _home);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final profile = ref.watch(myProfileProvider).value;
        final row = s.row;
        if (s.error != null) {
          final missing = s.error is AppFailure && (s.error! as AppFailure).code == 'content_missing';
          final text = missing ? l.contentMissing : l.sessionError;
          return _Message(text: kDebugMode ? '$text\n\n${s.error}' : text, action: l.backHome, onAction: _home);
        }
        if (row == null || s.myRole == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (row.state == SessionState.aborted) {
          final text = s.partnerLeft
              ? (row.abortReason == 'no_show' ? l.partnerNoShow : l.partnerLeft)
              : l.sessionClosed;
          return _Message(text: text, action: l.backHome, onAction: _home);
        }
        if (row.state == SessionState.lobby || s.engine == null) {
          return LobbyView(
            session: s,
            myName: profile?.username ?? '',
            myLanguages: profile?.languages ?? const [],
            myAvatarKey: profile?.avatarKey,
            onLeave: () async {
              await s.abort();
              _home();
            },
          );
        }
        return ExamScreen(
          // A new exam (the leader switched, D-040) = a new screen: its own reader files and diagram.
          key: ValueKey(row.examId),
          engine: s.engine!,
          control: s.hasLeader ? s : null,
          myName: profile?.username ?? l.you,
          partnerName: s.partner?.username ?? '…',
          myAvatar: (userId: s.myUserId, key: profile?.avatarKey),
          partnerAvatar: s.partner == null ? null : (userId: s.partner!.id, key: s.partner!.avatarKey),
          nowMs: s.clock.nowMs,
          partnerLeft: s.partnerLeft,
          selfMuted: s.selfMuted,
          onToggleMute: s.toggleMute,
          onDebugSkip: kDebugMode ? () => s.skip().catchError((Object _) {}) : null,
          readerFiles: s.readerFiles,
          inCall: true,
          photoFiles: s.photoFiles,
          onRate: (r) => ref.read(sessionRepositoryProvider)!.rate(s.sessionId, r),
          onReport: s.partner == null || ref.read(safetyRepositoryProvider) == null
              ? null
              : (where) async {
                  final blocked = await showSafetySheet(context,
                      userId: s.partner!.id, name: s.partner!.username, where: where, sessionId: s.sessionId);
                  // Blocking during the exam also ends it: nobody stays in a call with someone they blocked.
                  if (blocked) {
                    await s.abort();
                    _home();
                  }
                },
          companion: _companion(s),
          onAbandon: () async {
            await s.abort();
            _home();
          },
          onExit: _home,
        );
      },
    );
  }

  /// "Añadir a compañeros" / "Repetir con…" (D-046); null without a partner or agenda backend.
  CompanionHandle? _companion(LiveSession s) {
    final agenda = ref.read(agendaRepositoryProvider);
    final partner = s.partner;
    if (agenda == null || partner == null) return null;
    Future<CompanionLink> status() async {
      final c = (await agenda.companions()).where((c) => c.partnerId == partner.id).firstOrNull;
      if (c == null || !c.iAdded) return CompanionLink.none;
      return c.mutual ? CompanionLink.mutual : CompanionLink.waiting;
    }

    return CompanionHandle(
      status: status,
      add: () async {
        await agenda.addCompanion(s.sessionId);
        return status();
      },
      repeat: () => context.go('/agenda?invite=${partner.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.action, required this.onAction});
  final String text;
  final String action;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
            const SizedBox(height: 24),
            FilledButton(onPressed: onAction, child: Text(action)),
          ]),
        ),
      ),
    );
  }
}
