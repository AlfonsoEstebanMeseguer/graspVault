// "Reservar este hueco" (D-046): the slot was tapped on the board card; this
// confirms it. Booking makes the meeting confirmed for both. Returns the chat id.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../profile/avatar/user_avatar.dart';
import 'agenda_common.dart';

Future<String?> showBookSlotSheet(BuildContext context, Offer offer, DateTime at) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BookSlotSheet(offer: offer, at: at),
    );

class BookSlotSheet extends ConsumerStatefulWidget {
  const BookSlotSheet({super.key, required this.offer, required this.at});
  final Offer offer;
  final DateTime at;
  @override
  ConsumerState<BookSlotSheet> createState() => _BookSlotSheetState();
}

class _BookSlotSheetState extends ConsumerState<BookSlotSheet> {
  bool _busy = false;

  Future<void> _book() async {
    setState(() => _busy = true);
    try {
      final r = await ref.read(agendaRepositoryProvider)!.accept(widget.offer.id, widget.at);
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            UserAvatar(name: name, userId: o.creatorId, avatarKey: o.creatorAvatarKey, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Text(l.bookTitle(o.level.code, name), style: AppType.title2.copyWith(color: p.textPrimary))),
          ]),
          const SizedBox(height: 16),
          Text(whenText(context, widget.at, now), style: AppType.timer.copyWith(fontSize: 26, color: p.textPrimary)),
          Text(l.meetingLength, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400)),
          const SizedBox(height: 12),
          Text(l.bookHint, style: AppType.body.copyWith(color: p.textSecondary)),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('book-slot'),
            onPressed: _busy ? null : _book,
            child: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l.bookThisSlot),
          ),
        ]),
      ),
    );
  }
}
