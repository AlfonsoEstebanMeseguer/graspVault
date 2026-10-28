// Lobby (max 5 min), Design 2.0 "Sala de espera": the XL countdown, the two
// candidates with their role colour (A indigo, B tangerine) and "ready" state,
// a checklist (material, recording, who leads) and "Estoy listo".
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../domain/exam/models.dart';
import '../exam/control/control_panel.dart' show runControl, showExamCatalog;
import '../exam/widgets/exam_widgets.dart' show formatMs;
import '../home/home_screen.dart' show levelName;
import '../profile/avatar/user_avatar.dart';
import '../../data/safety/safety_repository.dart';
import '../safety/safety_sheet.dart';
import 'live_session.dart';

class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.session, required this.myName, required this.myLanguages, required this.onLeave, this.myAvatarKey});
  final LiveSession session;
  final String myName;
  final List<String> myLanguages;
  final String? myAvatarKey;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final row = session.row!;
    final me = session.myRole ?? Role.a;
    final deadline = row.lobbyDeadline;
    final left = deadline == null ? null : deadline.millisecondsSinceEpoch - session.clock.nowMs();
    final partnerName = session.partner?.username ?? '…';
    final iAmReady = row.readyOf(me);
    final iRecord = row.recordingOf(me);
    final partnerRecords = row.recordingOf(me.other);
    Widget divider() => Divider(height: 1, indent: 56, color: p.border);

    final cards = [
      _Candidate(
        name: '${l.you} · $myName',
        avatarName: myName,
        userId: session.myUserId,
        avatarKey: myAvatarKey,
        role: me,
        languages: myLanguages,
        ready: iAmReady,
      ),
      _Candidate(
        name: partnerName,
        avatarName: partnerName,
        userId: session.partner?.id,
        avatarKey: session.partner?.avatarKey,
        role: me.other,
        languages: session.partner?.languages ?? const [],
        ready: row.readyOf(me.other),
      ),
    ];
    // A always on the left, whoever I am: both phones show the same picture.
    if (me == Role.b) cards.setAll(0, cards.reversed.toList());

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Overline(l.roomTitle(levelName(l, row.level))),
                        const SizedBox(height: 4),
                        Text(l.meetBeforeStart, style: AppType.title1.copyWith(fontSize: 28, color: p.textPrimary)),
                      ]),
                    ),
                    if (session.partner != null) ...[
                      RoundIconButton(
                        key: const Key('lobby-report'),
                        icon: AppIcons.report,
                        tooltip: l.reportOrBlock,
                        onPressed: () async {
                          final blocked = await showSafetySheet(context,
                              userId: session.partner!.id, name: partnerName, where: ReportContext.lobby, sessionId: session.sessionId);
                          if (blocked) onLeave();
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    RoundIconButton(icon: AppIcons.close, tooltip: l.leaveRoom, onPressed: onLeave),
                  ]),
                  const SizedBox(height: 18),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Text(left == null ? l.waitingPartner : l.examStartsIn,
                          style: AppType.body.copyWith(fontSize: 17, color: p.textSecondary)),
                    ),
                    if (left != null) Text(formatMs(left < 0 ? 0 : left), style: AppType.timerXl.copyWith(color: p.textPrimary)),
                  ]),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Tile(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _Check(
                        icon: session.preloaded
                            ? Icon(AppIcons.check, color: p.success)
                            : const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        title: session.preloaded ? l.materialDownloaded : l.materialDownloading,
                      ),
                      divider(),
                      _Check(
                        key: const Key('lobby-recording'),
                        icon: Icon(AppIcons.record, color: p.link),
                        title: l.recordSession,
                        subtitle: l.recordOnlyIfBoth(partnerName, partnerRecords ? l.switchedOn : l.switchedOff),
                        trailing: Switch(value: iRecord, onChanged: (v) => session.setRecording(v)),
                        onTap: () => session.setRecording(!iRecord),
                      ),
                      // Pro (D-038): who leads, and the leader picks the exam before starting.
                      if (session.hasLeader) ...[
                        divider(),
                        _Check(
                          key: const Key('lobby-leader'),
                          icon: Icon(AppIcons.crownLine, color: p.pro),
                          title: session.iAmLeader ? l.leaderYouLong : l.leaderOther(partnerName),
                          trailing: session.iAmLeader
                              ? TextButton(
                                  key: const Key('lobby-switch-exam'),
                                  onPressed: () async {
                                    final pick = await showExamCatalog(context, level: row.level, currentId: row.examId);
                                    if (pick == null || !context.mounted) return;
                                    await runControl(context, () => session.switchExam(pick.id));
                                  },
                                  child: Text(l.changeLabel),
                                )
                              : null,
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              RoundIconButton(
                key: const Key('lobby-mute'),
                size: 56,
                tooltip: session.selfMuted ? l.unmuteMe : l.muteMe,
                onPressed: session.toggleMute,
                icon: session.canSpeak && !session.selfMuted ? AppIcons.micLine : AppIcons.micOff,
                color: session.selfMuted ? p.danger : (session.canSpeak ? p.textPrimary : p.textTertiary),
              ),
              if (kDebugMode) ...[
                const SizedBox(width: 10),
                RoundIconButton(
                  key: const Key('lobby-debug-skip'),
                  size: 56,
                  tooltip: l.debugSkip,
                  onPressed: () => session.skip().catchError((Object _) {}),
                  icon: AppIcons.next,
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('lobby-ready'),
                  style: iAmReady ? FilledButton.styleFrom(backgroundColor: p.surfaceMuted, foregroundColor: p.textPrimary) : null,
                  onPressed: () => session.setReady(!iAmReady),
                  child: Text(iAmReady ? l.notReadyYet : l.imReady),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  final Widget icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          SizedBox(width: 24, child: Center(child: IconTheme.merge(data: const IconThemeData(size: 22), child: icon))),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppType.body.copyWith(fontSize: 17, color: p.textPrimary)),
              if (subtitle != null)
                Text(subtitle!, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
            ]),
          ),
          ?trailing,
        ]),
      ),
    );
  }
}

class _Candidate extends StatelessWidget {
  const _Candidate({
    required this.name,
    required this.avatarName,
    required this.userId,
    required this.avatarKey,
    required this.role,
    required this.languages,
    required this.ready,
  });
  final String name;
  final String avatarName;
  final String? userId;
  final String? avatarKey;
  final Role role;
  final List<String> languages;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final color = p.role(role);
    return AnimatedContainer(
      duration: AppMotion.smooth,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadii.card + 4),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          UserAvatar(name: avatarName, userId: userId, avatarKey: avatarKey, size: 72, background: color, foreground: p.onRole),
          if (ready)
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(color: p.success, shape: BoxShape.circle, border: Border.all(color: p.surface, width: 3)),
                child: Icon(AppIcons.check, size: 14, color: p.onRole),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppType.headline.copyWith(color: p.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: p.roleSoft(role), borderRadius: BorderRadius.circular(AppRadii.chip)),
          child: Text(l.candidateRole(role.code), style: AppType.footnote.copyWith(fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(height: 8),
        Text(
          ready ? l.readyLabel : languages.map((c) => c.toUpperCase()).join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.footnote.copyWith(
              fontSize: 14, color: ready ? p.success : p.textSecondary, fontWeight: ready ? FontWeight.w700 : FontWeight.w500),
        ),
      ]),
    );
  }
}
