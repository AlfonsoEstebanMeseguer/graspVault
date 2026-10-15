// Chat with the pinned meeting card (sketch 20). Card and messages are live
// (Realtime); card actions go through meeting-actions, messages are inserted
// directly (RLS checks sender and participation).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../onboarding/onboarding_screen.dart' show languageName;
import 'agenda_common.dart';

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

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(agendaRepositoryProvider)!.send(widget.summary.chatId, body, newClientId());
      _text.clear();
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
    final canWrite = c.partnerId != null;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          InitialAvatar(name: name, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (c.partnerLanguages.isNotEmpty)
                Text(l.speaksLangs(c.partnerLanguages.map((e) => languageName(l, e)).join(', ')),
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
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
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                  );
                }
                final mine = m.senderId == me;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                    decoration: BoxDecoration(
                      color: mine ? p.brand : p.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(m.body ?? '', style: TextStyle(color: mine ? p.onBrand : p.textPrimary)),
                  ),
                );
              },
            ),
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
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(hintText: l.messageHint, counterText: '', border: const OutlineInputBorder()),
                  ),
                ),
                IconButton(tooltip: l.sendLabel, onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
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
    final r = await showModalBottomSheet<({DateTime at, Level level})>(
      context: context,
      showDragHandle: true,
      builder: (_) => _ModifySheet(meeting: widget.meeting, now: widget.now),
    );
    if (r != null) await _run((repo) => repo.modify(widget.meeting.id, r.at, r.level));
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
    Widget tick(bool ok, String who) => Text('${ok ? '✓' : '○'} $who',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ok ? p.success : p.textSecondary));
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(DateFormat('EEE d', locale).format(at).replaceAll('.', '').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.onBrandSoft)),
                Text(hm(m.scheduledAt), style: TextStyle(fontWeight: FontWeight.w800, color: p.onBrandSoft)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${whenText(context, m.scheduledAt, widget.now)} · ${m.level.code}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (meetingIsLive(m))
                  Wrap(spacing: 12, children: [
                    tick(partner != null && m.confirmedBy(partner), widget.partnerName),
                    tick(iConfirmed, l.you),
                  ])
                else
                  Text(meetingStatusText(context, m, me, widget.partnerName), style: TextStyle(color: p.textSecondary)),
              ]),
            ),
          ]),
          if (pending || confirmed) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (pending) ...[
                Expanded(child: OutlinedButton(onPressed: _busy ? null : _modify, child: FittedBox(child: Text(l.modifyLabel)))),
                const SizedBox(width: 8),
              ],
              Expanded(child: OutlinedButton(onPressed: _busy ? null : _cancel, child: FittedBox(child: Text(l.cancelLabel)))),
              const SizedBox(width: 8),
              if (pending)
                Expanded(
                  child: FilledButton(
                    onPressed: _busy || iConfirmed ? null : () => _run((r) => r.confirm(m.id)),
                    child: FittedBox(child: Text(l.confirmLabel)),
                  ),
                ),
              if (confirmed && AgendaRules.canEnter(m, widget.now))
                Expanded(child: FilledButton(onPressed: () => enterMeeting(context, ref, m), child: FittedBox(child: Text(l.enterRoom)))),
            ]),
          ],
          if (confirmed && !AgendaRules.canEnter(m, widget.now))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.roomOpensBefore, style: TextStyle(fontSize: 12, color: p.textSecondary)),
            ),
        ]),
      ),
    );
  }
}

class _ModifySheet extends StatefulWidget {
  const _ModifySheet({required this.meeting, required this.now});
  final Meeting meeting;
  final DateTime now;
  @override
  State<_ModifySheet> createState() => _ModifySheetState();
}

class _ModifySheetState extends State<_ModifySheet> {
  late DateTime _day = localDay(widget.meeting.scheduledAt);
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.meeting.scheduledAt.toLocal());
  late Level _level = widget.meeting.level;

  DateTime get _at => DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final today = localDay(widget.now);
    final valid = _at.isAfter(widget.now) && !_at.isAfter(widget.now.add(AgendaRules.horizon));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.modifyTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (var d = 0; d < 7; d++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill(
                    label: dayWord(context, today.add(Duration(days: d)), widget.now),
                    selected: _day == today.add(Duration(days: d)),
                    onTap: () => setState(() => _day = today.add(Duration(days: d))),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text(MaterialLocalizations.of(context).formatTimeOfDay(_time, alwaysUse24HourFormat: true)),
            onPressed: () async {
              final t = await showTimePicker(context: context, initialTime: _time);
              if (t != null) setState(() => _time = TimeOfDay(hour: t.hour, minute: t.minute - t.minute % 5));
            },
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            for (final lv in Level.values) Pill(label: lv.code, selected: _level == lv, onTap: () => setState(() => _level = lv)),
          ]),
          if (!valid) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.errorBadTime, style: TextStyle(color: p.danger))),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: valid ? () => Navigator.pop(context, (at: _at, level: _level)) : null,
            child: Text(l.saveLabel),
          ),
        ]),
      ),
    );
  }
}
