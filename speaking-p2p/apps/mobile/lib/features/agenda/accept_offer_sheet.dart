// "Elegir hora" (sketch 19): 30-min slots inside the window; the ones that clash
// with my confirmed meetings are blocked ("Ocupado"). Returns the new chat id.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../home/home_screen.dart' show levelName;
import 'agenda_common.dart';

Future<String?> showAcceptOfferSheet(BuildContext context, Offer offer) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AcceptOfferSheet(offer: offer),
    );

class AcceptOfferSheet extends ConsumerStatefulWidget {
  const AcceptOfferSheet({super.key, required this.offer});
  final Offer offer;
  @override
  ConsumerState<AcceptOfferSheet> createState() => _AcceptOfferSheetState();
}

class _AcceptOfferSheetState extends ConsumerState<AcceptOfferSheet> {
  DateTime? _picked;
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(agendaRepositoryProvider)!.accept(widget.offer.id, _picked!);
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
    final o = widget.offer;
    final now = ref.watch(agendaClockProvider)();
    final name = o.creatorName ?? l.deletedUser;
    final busy = ref.watch(myMeetingsProvider).value?.map((m) => m.scheduledAt).toList() ?? const <DateTime>[];
    final slots = AgendaRules.slots(o.windowStart, o.windowEnd, now, busy);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            InitialAvatar(name: name, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.examWithTitle(name), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
                Text('${windowText(context, o.windowStart, o.windowEnd, now)} · ${levelName(l, o.level)}',
                    style: TextStyle(color: p.textSecondary)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          Text(l.chooseStart, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
          const SizedBox(height: 10),
          if (slots.isEmpty)
            Text(l.noSlots, style: TextStyle(color: p.textSecondary))
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.2,
              children: [
                for (final s in slots)
                  _Slot(
                    time: hm(s.at),
                    busy: s.busy,
                    selected: _picked == s.at,
                    onTap: () => setState(() => _picked = s.at),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(l.busyHint, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _picked == null || _busy ? null : _accept,
            child: Text(_picked == null ? l.pickATime : l.proposeAndChat(hm(_picked!))),
          ),
        ]),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.time, required this.busy, required this.selected, required this.onTap});
  final String time;
  final bool busy, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final bg = selected ? p.brand : (busy ? p.surfaceMuted : p.surface);
    final fg = selected ? p.onBrand : (busy ? p.textSecondary : p.textPrimary);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? p.brand : p.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onTap,
        child: Center(
          child: FittedBox(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(time, style: TextStyle(fontWeight: FontWeight.w700, color: fg, decoration: busy ? TextDecoration.lineThrough : null)),
              if (busy) Text(l.busyLabel, style: TextStyle(fontSize: 11, color: fg)),
            ]),
          ),
        ),
      ),
    );
  }
}
