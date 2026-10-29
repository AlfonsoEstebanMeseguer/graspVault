// Chat with the pinned meeting card (D-046). Card and messages are live
// (Realtime); card actions go through meeting-actions, messages are inserted
// directly (RLS checks sender, participation and that the meeting is still
// alive: the chat closes 2 h after its time).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../onboarding/onboarding_screen.dart' show languageName;
import '../profile/avatar/user_avatar.dart';
import '../../data/safety/safety_repository.dart';
import '../safety/safety_sheet.dart';
import 'agenda_common.dart';
import 'invite_sheet.dart' show SlotPicker;

final _chatProvider = FutureProvider.autoDispose.family<ChatSummary?, String>((ref, chatId) async {
  final list = await ref.watch(agendaRepositoryProvider)!.chats(chatId: chatId);
  return list.isEmpty ? null : list.first;
});

final _meetingProvider = StreamProvider.autoDispose.family<Meeting, String>(
  (ref, meetingId) => ref.watch(agendaRepositoryProvider)!.watchMeeting(meetingId),
);

final _messagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>(
  (ref, chatId) => ref.watch(agendaRepositoryProvider)!.watchMessages(chatId),
);

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final chat = ref.watch(_chatProvider(chatId));
    return chat.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(appBar: AppBar(), body: Center(child: Text(l.errorGeneric))),
      data: (c) => c == null
          ? Scaffold(appBar: AppBar(), body: Center(child: Text(l.errorGeneric)))
          : _ChatView(summary: c),
    );
  }
}

class _ChatView extends ConsumerStatefulWidget {
  const _ChatView({required this.summary});
  final ChatSummary summary;
  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send([String? quick]) async {
    final body = (quick ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(agendaRepositoryProvider)!.send(widget.summary.chatId, body, newClientId());
      if (quick == null) _text.clear();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final c = widget.summary;
    final me = ref.watch(agendaRepositoryProvider)!.me;
    final now = ref.watch(agendaClockProvider)();
    final name = c.partnerName ?? l.deletedUser;
    final meeting = ref.watch(_meetingProvider(c.meeting.id)).value ?? c.meeting;
    final messages = ref.watch(_messagesProvider(c.chatId));
    final canWrite = c.partnerId != null && AgendaRules.chatOpen(meeting, now);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        actions: [
          if (c.partnerId != null && ref.watch(safetyRepositoryProvider) != null)
            IconButton(
              key: const Key('chat-report'),
              tooltip: l.reportOrBlock,
              icon: const Icon(AppIcons.report),
              onPressed: () async {
                final blocked = await showSafetySheet(context, userId: c.partnerId!, name: name, where: ReportContext.chat, chatId: c.chatId);
                if (blocked && context.mounted) {
                  refreshAgenda(ref);
                  context.pop();
                }
              },
            ),
        ],
        title: Row(children: [
          UserAvatar(name: name, userId: c.partnerId, avatarKey: c.partnerAvatarKey, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: AppType.headline.copyWith(color: p.textPrimary)),
              if (c.partnerLanguages.isNotEmpty)
                Text(l.speaksLangs(c.partnerLanguages.map((e) => languageName(l, e)).join(', ')),
                    style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
            ]),
          ),
        ]),
      ),
      body: Column(children: [
        MeetingCard(meeting: meeting, me: me, partnerName: name, now: now),
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(l.errorGeneric)),
            data: (list) => ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[list.length - 1 - i];
                if (m.isSystem) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(systemText(context, m, me, name, now),
                        textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textTertiary)),
                  );
                }
                final mine = m.senderId == me;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                    decoration: BoxDecoration(
                      color: mine ? p.brand : p.surfaceMuted,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(mine ? 18 : 6),
                        bottomRight: Radius.circular(mine ? 6 : 18),
                      ),
                    ),
                    child: Text(m.body ?? '', style: AppType.body.copyWith(color: mine ? p.onBrand : p.textPrimary)),
                  ),
                );
              },
            ),
          ),
        ),
        if (!canWrite)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Text(l.chatClosed, textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
            ),
          ),
        if (canWrite)
          // Quick replies keep the chat about organising the meeting.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final q in [l.qrLate, l.qrOtherTime, l.qrSeeYou])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(q), onPressed: _sending ? null : () => _send(q)),
                  ),
              ],
            ),
          ),
        if (canWrite)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: AgendaRules.maxMessage,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l.messageHint,
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: p.brand, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  tooltip: l.sendLabel,
                  onPressed: _sending ? null : _send,
                  icon: AppIcons.send,
                  background: p.brand,
                  color: p.onBrand,
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// The pinned card: date, time, level, ✓/○ per person and the actions.
class MeetingCard extends ConsumerStatefulWidget {
  const MeetingCard({super.key, required this.meeting, required this.me, required this.partnerName, required this.now});
  final Meeting meeting;
  final String me;
  final String partnerName;
  final DateTime now;
  @override
  ConsumerState<MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends ConsumerState<MeetingCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function(AgendaRepository r) action) async {
    setState(() => _busy = true);
    try {
      await action(ref.read(agendaRepositoryProvider)!);
      refreshAgenda(ref);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cancelMeetingTitle),
        content: Text(l.cancelMeetingBody(widget.partnerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.keepMeeting)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.cancelLabel)),
        ],
      ),
    );
    if (ok == true) await _run((r) => r.cancel(widget.meeting.id));
  }

  Future<void> _modify() async {
    final at = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ModifySheet(meeting: widget.meeting, now: widget.now),
    );
    if (at != null) await _run((repo) => repo.modify(widget.meeting.id, at, widget.meeting.level));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final m = widget.meeting;
    final me = widget.me;
    final partner = m.partnerOf(me);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final at = m.scheduledAt.toLocal();
    final pending = m.status == MeetingStatus.pending;
    final confirmed = m.status == MeetingStatus.confirmed;
    final iConfirmed = m.confirmedBy(me);
    final partnerConfirmed = partner != null && m.confirmedBy(partner);
    final canEnter = AgendaRules.canEnter(m, widget.now);
    // Proposed -> partner -> me: a dot per step, filled when done.
    Widget step(bool done, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? p.success : Colors.transparent,
              border: Border.all(color: done ? p.success : p.textTertiary, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(done ? '$label ✓' : label,
                overflow: TextOverflow.ellipsis,
                style: AppType.footnote.copyWith(color: done ? p.success : p.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ]);
    Widget line() => Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 6), color: p.border));
    final Widget primary = switch (m.status) {
      MeetingStatus.pending when !iConfirmed => FilledButton(
          key: const Key('card-confirm'),
          onPressed: _busy ? null : () => _run((r) => r.confirm(m.id)),
          child: Text(l.confirmLabel),
        ),
      MeetingStatus.pending => FilledButton(onPressed: null, child: Text(l.statusAwaitingPartner(widget.partnerName))),
      MeetingStatus.confirmed when canEnter => FilledButton(onPressed: () => enterMeeting(context, ref, m), child: Text(l.enterRoom)),
      _ => const SizedBox.shrink(),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Tile(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 68,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.input)),
              child: Column(children: [
                Text(DateFormat('EEE d', locale).format(at).replaceAll('.', '').toUpperCase(),
                    style: AppType.overline.copyWith(fontSize: 11, color: p.roleB)),
                Text(hm(m.scheduledAt), style: AppType.timer.copyWith(fontSize: 17, height: 1.3, color: p.textPrimary)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${whenText(context, m.scheduledAt, widget.now)} · ${m.level.code}', style: AppType.headline.copyWith(color: p.textPrimary)),
                if (!pending) ...[
                  const SizedBox(height: 8),
                  Text(meetingStatusText(context, m, me, widget.partnerName),
                      style: AppType.footnote.copyWith(color: confirmed ? p.success : p.textSecondary)),
                ],
              ]),
            ),
          ]),
          if (pending) ...[
            const SizedBox(height: 14),
            Row(children: [
              step(true, l.stepProposed),
              line(),
              Flexible(child: step(partnerConfirmed, widget.partnerName)),
              line(),
              step(iConfirmed, l.you),
            ]),
          ],
          if (pending || (confirmed && canEnter)) ...[const SizedBox(height: 12), primary],
          if (confirmed && !canEnter)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.roomOpensBefore, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
            ),
          if ((pending || confirmed) && partner != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              // Secondary actions as plain links: they must not compete with the main one.
              child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                TextButton(key: const Key('card-modify'), onPressed: _busy ? null : _modify, child: Text(l.modifyLabel)),
                Text('·', style: TextStyle(color: p.textTertiary)),
                TextButton(
                  key: const Key('card-cancel'),
                  style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                  onPressed: _busy ? null : _cancel,
                  child: Text(l.cancelLabel),
                ),
              ]),
            ),
          if (kDebugMode && (pending || confirmed))
            // Debug builds only (never in a release): skip the 5-minute wait.
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: p.textTertiary),
              onPressed: () => enterMeeting(context, ref, m, now: true),
              icon: const Icon(Icons.bolt),
              label: Text(l.debugEnterNow),
            ),
        ]),
      ),
    );
  }
}

/// "Proponer otra hora": the same 30-min grid as booking (the server refuses others).
class _ModifySheet extends ConsumerStatefulWidget {
  const _ModifySheet({required this.meeting, required this.now});
  final Meeting meeting;
  final DateTime now;
  @override
  ConsumerState<_ModifySheet> createState() => _ModifySheetState();
}

class _ModifySheetState extends ConsumerState<_ModifySheet> {
  DateTime? _at;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final busy = [
      for (final m in ref.watch(myMeetingsProvider).value ?? const <Meeting>[])
        if (m.id != widget.meeting.id) m.scheduledAt,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.modifyTitle, style: AppType.title2.copyWith(color: p.textPrimary)),
          const SizedBox(height: 12),
          SlotPicker(now: widget.now, busy: busy, value: _at, onChanged: (t) => setState(() => _at = t)),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('modify-save'),
            onPressed: _at == null ? null : () => Navigator.pop(context, _at),
            child: Text(l.saveLabel),
          ),
        ]),
      ),
    );
  }
}
