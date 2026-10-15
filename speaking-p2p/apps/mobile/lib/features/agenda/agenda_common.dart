// Shared bits of the Agenda tab: providers, date/time wording, status lines,
// system-message text and the "Entrar a la sala" action.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../data/content/content_repository.dart';
import '../../domain/agenda/agenda.dart';

final myOffersProvider = FutureProvider.autoDispose<List<Offer>>((ref) async {
  return await ref.watch(agendaRepositoryProvider)?.myOffers() ?? const [];
});

final chatsProvider = FutureProvider.autoDispose<List<ChatSummary>>((ref) async {
  return await ref.watch(agendaRepositoryProvider)?.chats() ?? const [];
});

final myMeetingsProvider = FutureProvider.autoDispose<List<Meeting>>((ref) async {
  return await ref.watch(agendaRepositoryProvider)?.myMeetings() ?? const [];
});

/// Every agenda list after a write: cheap, and the lists are small.
void refreshAgenda(WidgetRef ref) {
  ref.invalidate(myOffersProvider);
  ref.invalidate(chatsProvider);
  ref.invalidate(myMeetingsProvider);
}

/// Test seam for "now" (minute-level wording, the enter window).
final agendaClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

String hm(DateTime t) => DateFormat.Hm().format(t.toLocal());

DateTime localDay(DateTime t) {
  final l = t.toLocal();
  return DateTime(l.year, l.month, l.day);
}

/// "Hoy" / "Mañana" / "Jue 16".
String dayWord(BuildContext context, DateTime t, DateTime now) {
  final l = context.l10n;
  final diff = localDay(t).difference(localDay(now)).inDays;
  if (diff == 0) return l.todayLabel;
  if (diff == 1) return l.tomorrowLabel;
  final s = DateFormat('EEE d', Localizations.localeOf(context).toLanguageTag()).format(t.toLocal());
  return s[0].toUpperCase() + s.substring(1).replaceAll('.', '');
}

/// "Hoy · 18:00–21:00"
String windowText(BuildContext context, DateTime start, DateTime end, DateTime now) =>
    '${dayWord(context, start, now)} · ${hm(start)}–${hm(end)}';

/// "Mañana · 18:30"
String whenText(BuildContext context, DateTime t, DateTime now) => '${dayWord(context, t, now)} · ${hm(t)}';

/// The status line under a chat ("Hoy 19:00 · C1 · Confirmada ✓✓").
String meetingStatusText(BuildContext context, Meeting m, String me, String partnerName) {
  final l = context.l10n;
  return switch (m.status) {
    MeetingStatus.confirmed => l.statusConfirmed,
    MeetingStatus.pending => m.confirmedBy(me) ? l.statusAwaitingPartner(partnerName) : l.statusAwaitingYou,
    MeetingStatus.closed => l.statusClosed,
    MeetingStatus.cancelled => l.statusCancelled,
    MeetingStatus.done => l.statusDone,
    MeetingStatus.noShow => l.statusNoShow,
  };
}

bool meetingIsLive(Meeting m) => m.status == MeetingStatus.pending || m.status == MeetingStatus.confirmed;

/// System messages are stored as codes + args and worded here (ES/EN).
String systemText(BuildContext context, ChatMessage msg, String me, String partnerName, DateTime now) {
  final l = context.l10n;
  final by = msg.systemArgs['by'] as String? ?? msg.systemArgs['user'] as String?;
  final mine = by == me;
  final at = msg.systemArgs['scheduled_at'] is String ? DateTime.tryParse(msg.systemArgs['scheduled_at'] as String) : null;
  final when = at == null ? '' : whenText(context, at, now);
  return switch (msg.systemCode) {
    'meeting_proposed' => mine ? l.sysProposedByMe(when) : l.sysProposed(partnerName, when),
    'meeting_modified' => mine ? l.sysModifiedByMe(when) : l.sysModified(partnerName, when),
    'meeting_confirmed_by' => mine ? l.sysConfirmedByMe : l.sysConfirmedBy(partnerName),
    'meeting_confirmed' => l.sysConfirmed,
    'meeting_partner_overlap' => l.sysPartnerOverlap(partnerName),
    'meeting_unavailable' => l.sysUnavailable,
    'meeting_cancelled' => mine ? l.sysCancelledByMe : l.sysCancelled(partnerName),
    'meeting_expired' => l.sysExpired,
    'partner_deleted_account' => l.sysPartnerDeleted,
    _ => l.sysUpdate,
  };
}

/// Text preview of any message for the chat list.
String previewText(BuildContext context, ChatMessage? msg, String me, String partnerName, DateTime now) {
  if (msg == null) return '';
  return msg.isSystem ? systemText(context, msg, me, partnerName, now) : (msg.body ?? '');
}

/// RFC 4122 v4, for chat `client_id` (idempotent resend).
String newClientId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// The theme makes buttons full width; inside a Row they need a finite size.
final inlineButton = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(0, 40)));

void showError(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(context.l10n, e))));
}

/// "Entrar a la sala": the server creates (or returns) the meeting's session.
Future<void> enterMeeting(BuildContext context, WidgetRef ref, Meeting m) async {
  final repo = ref.read(agendaRepositoryProvider);
  if (repo == null) return;
  try {
    final version = (await ref.read(contentIndexProvider.future)).version;
    final id = await repo.enter(m.id, version);
    if (context.mounted) context.go('/session/$id');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar({super.key, required this.name, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: p.brandSoft,
      child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
          style: TextStyle(color: p.onBrandSoft, fontWeight: FontWeight.w700, fontSize: size * 0.4)),
    );
  }
}

/// Selectable pill used by the filters and the create sheet.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.selected, required this.onTap, this.enabled = true});
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      selectedColor: p.brand,
      labelStyle: TextStyle(color: selected ? p.onBrand : p.textPrimary, fontWeight: FontWeight.w600),
      showCheckmark: false,
    );
  }
}
