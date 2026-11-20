// "Invitar a…" (D-046): a mutual companion, a day, a half-hour start and a level.
// The invitation is born with my tick; the other confirms with one tap.
// `SlotPicker` (day + 30-min grid) is shared with "Cambiar hora" in the chat.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show targetLevelProvider;
import '../profile/avatar/user_avatar.dart';
import 'agenda_common.dart';

Future<String?> showInviteSheet(BuildContext context, Companion c) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InviteSheet(companion: c),
    );

class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.companion});
  final Companion companion;
  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  DateTime? _at;
  late Level _level = ref.read(targetLevelProvider);
  bool _busy = false;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(agendaRepositoryProvider)!.invite(widget.companion.partnerId, _at!, _level);
      if (mounted) Navigator.of(context).pop(r.chatId);
    } catch (e) {
      if (mounted) {
        showError(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final c = widget.companion;
    final name = c.name ?? l.deletedUser;
    final now = ref.watch(agendaClockProvider)();
    final busy = ref.watch(myMeetingsProvider).value?.map((m) => m.scheduledAt).toList() ?? const <DateTime>[];
    final label = AppType.headline.copyWith(fontSize: 15, color: p.textPrimary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            UserAvatar(name: name, userId: c.partnerId, avatarKey: c.avatarKey, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Text(l.inviteTitle(name), style: AppType.title2.copyWith(color: p.textPrimary))),
          ]),
          const SizedBox(height: 16),
          SlotPicker(now: now, busy: busy, value: _at, onChanged: (t) => setState(() => _at = t)),
          const SizedBox(height: 16),
          Text(l.examLevelField, style: label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final lv in Level.values) Pill(label: lv.code, selected: _level == lv, onTap: () => setState(() => _level = lv)),
          ]),
          const SizedBox(height: 14),
          Text(l.inviteHint(name), style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('send-invite'),
            onPressed: _at == null || _busy ? null : _send,
            child: Text(l.sendInvite),
          ),
        ]),
      ),
    );
  }
}

/// Day pills (next 7 days) + the half-hour start times of that day still ahead.
/// Times that clash with my confirmed meetings are struck out.
class SlotPicker extends StatefulWidget {
  const SlotPicker({super.key, required this.now, required this.busy, required this.value, required this.onChanged});
  final DateTime now;
  final List<DateTime> busy;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  late DateTime _day = localDay(widget.value ?? widget.now);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final today = localDay(widget.now);
    final times = AgendaRules.dayGrid(_day, widget.now);
    final label = AppType.headline.copyWith(fontSize: 15, color: p.textPrimary);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(l.dayField, style: label),
      const SizedBox(height: 6),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var d = 0; d < 7; d++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Pill(
                label: dayWord(context, today.add(Duration(days: d)), widget.now),
                selected: _day == today.add(Duration(days: d)),
                onTap: () {
                  setState(() => _day = today.add(Duration(days: d)));
                  widget.onChanged(null);
                },
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Text(l.timeField, style: label),
      const SizedBox(height: 6),
      if (times.isEmpty)
        Text(l.noTimesLeft, style: TextStyle(color: p.textSecondary))
      else
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: SingleChildScrollView(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in times)
                _TimeChip(
                  time: hm(t),
                  busy: widget.busy.any((b) => AgendaRules.overlaps(b, t)),
                  selected: widget.value != null && widget.value!.isAtSameMomentAs(t),
                  onTap: () => widget.onChanged(t),
                ),
            ]),
          ),
        ),
    ]);
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.busy, required this.selected, required this.onTap});
  final String time;
  final bool busy, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = selected ? p.brand : (busy ? p.surfaceMuted : p.surface);
    final fg = selected ? p.onBrand : (busy ? p.textTertiary : p.textPrimary);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.chip), side: BorderSide(color: selected ? p.brand : p.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.chip),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(time, style: TextStyle(fontWeight: FontWeight.w700, color: fg, decoration: busy ? TextDecoration.lineThrough : null)),
        ),
      ),
    );
  }
}
