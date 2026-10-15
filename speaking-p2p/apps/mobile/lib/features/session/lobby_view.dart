// Lobby (max 5 min), as in the "Lobby" sketch.
import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../domain/exam/models.dart';
import '../exam/widgets/exam_widgets.dart' show formatMs;
import '../home/home_screen.dart' show levelName;
import 'live_session.dart';

class LobbyView extends StatelessWidget {
  const LobbyView({super.key, required this.session, required this.myName, required this.myLanguages, required this.onLeave});
  final LiveSession session;
  final String myName;
  final List<String> myLanguages;
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.roomTitle(levelName(l, row.level).toUpperCase()),
                      style: TextStyle(fontSize: 12, color: p.textSecondary, letterSpacing: 0.4)),
                  Text(l.meetBeforeStart, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
                ]),
              ),
              IconButton.outlined(
                tooltip: l.leaveRoom,
                onPressed: onLeave,
                icon: Icon(Icons.logout, color: p.danger),
              ),
            ]),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Expanded(child: Text(left == null ? l.waitingPartner : l.examStartsIn, style: TextStyle(color: p.textSecondary))),
                  if (left != null)
                    Text(formatMs(left < 0 ? 0 : left),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Candidate(name: '${l.you} · $myName', role: me, languages: myLanguages, ready: iAmReady, highlight: true)),
              const SizedBox(width: 10),
              Expanded(
                child: _Candidate(
                  name: partnerName, role: me.other, languages: session.partner?.languages ?? const [],
                  ready: row.readyOf(me.other), highlight: false,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Card(
              child: Column(children: [
                SwitchListTile(
                  key: const Key('lobby-recording'),
                  value: iRecord,
                  onChanged: (v) => session.setRecording(v),
                  title: Text(l.recordSession, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                  subtitle: Text(l.recordOnlyIfBoth(partnerName, partnerRecords ? l.switchedOn : l.switchedOff),
                      style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ),
                Divider(height: 1, color: p.border),
                ListTile(
                  leading: session.preloaded
                      ? Icon(Icons.check, color: p.success)
                      : const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text(session.preloaded ? l.materialDownloaded : l.materialDownloading,
                      style: TextStyle(color: p.textPrimary)),
                ),
              ]),
            ),
            const Spacer(),
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(border: Border.all(color: p.border), borderRadius: BorderRadius.circular(12)),
                child: Tooltip(
                  message: session.canSpeak ? l.micOnShort : l.micOffShort,
                  child: Icon(session.canSpeak ? Icons.mic : Icons.mic_off, color: session.canSpeak ? p.success : p.textSecondary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  key: const Key('lobby-ready'),
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

class _Candidate extends StatelessWidget {
  const _Candidate({required this.name, required this.role, required this.languages, required this.ready, required this.highlight});
  final String name;
  final Role role;
  final List<String> languages;
  final bool ready;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ready ? p.success : p.border, width: ready ? 2 : 1),
      ),
      child: Column(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: highlight ? p.brand : p.surfaceMuted,
          child: Text(name.characters.first.toUpperCase(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: highlight ? p.onBrand : p.textSecondary)),
        ),
        const SizedBox(height: 8),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
        Text(l.candidateLine(role.code, languages.map((c) => c.toUpperCase()).join(', ')),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: ready ? p.success.withValues(alpha: 0.12) : p.surfaceMuted, borderRadius: BorderRadius.circular(10)),
          child: Text(ready ? l.readyBadge : l.notConfirmed, style: TextStyle(fontSize: 12, color: ready ? p.success : p.textSecondary)),
        ),
      ]),
    );
  }
}
