// "Proponer horario": day, window From–To, level, proposals left. Others book
// 30-min slots inside it (D-046). Same validation as svc_offer_create so the
// button never lies.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show targetLevelProvider;
import 'agenda_common.dart';

Future<bool?> showCreateOfferSheet(BuildContext context) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CreateOfferSheet(),
    );

class CreateOfferSheet extends ConsumerStatefulWidget {
  const CreateOfferSheet({super.key});
  @override
  ConsumerState<CreateOfferSheet> createState() => _CreateOfferSheetState();
}

class _CreateOfferSheetState extends ConsumerState<CreateOfferSheet> {
  late DateTime _day; // local midnight
  late TimeOfDay _from;
  late TimeOfDay _to;
  late Level _level;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final now = ref.read(agendaClockProvider)();
    _day = localDay(now);
    // Next full hour, a 3-hour window by default (sketch: 17:00–20:00).
    final startHour = now.hour + 1;
    if (startHour >= 23) {
      _day = _day.add(const Duration(days: 1));
      _from = const TimeOfDay(hour: 17, minute: 0);
    } else {
      _from = TimeOfDay(hour: startHour, minute: 0);
    }
    _to = TimeOfDay(hour: (_from.hour + 3).clamp(0, 23), minute: _from.hour + 3 > 23 ? 59 : 0);
    _level = ref.read(targetLevelProvider);
  }

  DateTime _at(TimeOfDay t) => DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);

  Future<void> _pickTime(bool from) async {
    final t = await showTimePicker(context: context, initialTime: from ? _from : _to);
    if (t == null) return;
    // Half-hour grid, like the slots people can book.
    final snapped = TimeOfDay(hour: t.hour, minute: t.minute - t.minute % 30);
    setState(() => from ? _from = snapped : _to = snapped);
  }

  Future<void> _pickOtherDay(DateTime today) async {
    final d = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 6)),
      initialDate: _day,
    );
    if (d != null) setState(() => _day = DateTime(d.year, d.month, d.day));
  }

  Future<void> _publish() async {
    setState(() => _busy = true);
    try {
      await ref.read(agendaRepositoryProvider)!.createOffer(_level, _at(_from), _at(_to));
      if (mounted) Navigator.of(context).pop(true);
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
    final now = ref.watch(agendaClockProvider)();
    final today = localDay(now);
    final open = ref.watch(myOffersProvider).value?.length ?? 0;
    final left = AgendaRules.offersLeft(open);
    final error = AgendaRules.offerWindowError(_at(_from), _at(_to), now);
    final quick = [for (var d = 0; d < 3; d++) today.add(Duration(days: d))];
    final isOther = !quick.contains(_day);
    final label = TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(l.createMeeting, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
          const SizedBox(height: 16),
          Text(l.dayField, style: label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final d in quick) Pill(label: dayWord(context, d, now), selected: _day == d, onTap: () => setState(() => _day = d)),
            Pill(label: isOther ? dayWord(context, _day, now) : '${l.otherDay} ▾', selected: isOther, onTap: () => _pickOtherDay(today)),
          ]),
          const SizedBox(height: 16),
          Text(l.windowField, style: label),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _TimeBox(label: l.fromField, value: _from, onTap: () => _pickTime(true))),
            const SizedBox(width: 12),
            Expanded(child: _TimeBox(label: l.toField, value: _to, onTap: () => _pickTime(false))),
          ]),
          const SizedBox(height: 6),
          Text(l.windowHint, style: TextStyle(fontSize: 12, color: p.textSecondary)),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(l.errorWindow, style: TextStyle(fontSize: 12, color: p.danger)),
          ],
          const SizedBox(height: 16),
          Text(l.examLevelField, style: label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final lv in Level.values) Pill(label: lv.code, selected: _level == lv, onTap: () => setState(() => _level = lv)),
          ]),
          const SizedBox(height: 16),
          Text(l.offersLeft(left), textAlign: TextAlign.center, style: TextStyle(color: left == 0 ? p.danger : p.textSecondary)),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _busy || error != null || left == 0 ? null : _publish,
            child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.publishOffer),
          ),
        ]),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, required this.onTap});
  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(MaterialLocalizations.of(context).formatTimeOfDay(value, alwaysUse24HourFormat: true),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary)),
      ),
    );
  }
}
