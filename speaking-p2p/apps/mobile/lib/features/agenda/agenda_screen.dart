// Agenda tab (sketches 16–18): Chats · Reuniones (board) · Mi agenda, with
// "Crear reunión" on top. `/agenda?create=1` opens the create sheet (from the
// 15 s prompt of the live search).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/ui/placeholder_screen.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show levelName, targetLevelProvider;
import 'accept_offer_sheet.dart';
import 'agenda_common.dart';
import 'create_offer_sheet.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.openCreate = false});
  final bool openCreate;
  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openCreate) WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  @override
  void didUpdateWidget(AgendaScreen old) {
    super.didUpdateWidget(old);
    if (widget.openCreate && !old.openCreate) WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    if (!mounted) return;
    final created = await showCreateOfferSheet(context);
    if (created == true && mounted) refreshAgenda(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    if (ref.watch(agendaRepositoryProvider) == null) {
      return PlaceholderScreen(title: l.agendaTitle);
    }
    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(children: [
                Expanded(child: Text(l.agendaTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: p.textPrimary))),
                FilledButton.icon(style: inlineButton, onPressed: _create, icon: const Icon(Icons.add, size: 18), label: Text(l.createMeeting)),
              ]),
            ),
            TabBar(tabs: [Tab(text: l.agendaChats), Tab(text: l.agendaBoard), Tab(text: l.agendaMine)]),
            const Expanded(child: TabBarView(children: [_ChatsTab(), _BoardTab(), _MineTab()])),
          ]),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Chats
class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final me = ref.watch(agendaRepositoryProvider)!.me;
    final now = ref.watch(agendaClockProvider)();
    final chats = ref.watch(chatsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(chatsProvider.future),
      child: chats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: l.errorGeneric),
        data: (list) => list.isEmpty
            ? _Message(text: l.noChats)
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: p.border),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final name = c.partnerName ?? l.deletedUser;
                  final m = c.meeting;
                  final live = meetingIsLive(m);
                  final status = '${whenText(context, m.scheduledAt, now)} · ${m.level.code} · ${meetingStatusText(context, m, me, name)}';
                  final last = c.lastMessage;
                  return ListTile(
                    leading: InitialAvatar(name: name),
                    title: Row(children: [
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                      if (last != null)
                        Text(
                          localDay(last.createdAt) == localDay(now) ? hm(last.createdAt) : dayWord(context, last.createdAt, now),
                          style: TextStyle(fontSize: 12, color: p.textSecondary),
                        ),
                    ]),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(previewText(context, last, me, name, now), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        live ? status : meetingStatusText(context, m, me, name),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: m.status == MeetingStatus.confirmed
                              ? p.success
                              : (m.status == MeetingStatus.pending && !m.confirmedBy(me) ? p.brand : p.textSecondary),
                        ),
                      ),
                    ]),
                    onTap: () async {
                      await context.push('/chat/${c.chatId}');
                      refreshAgenda(ref);
                    },
                  );
                },
              ),
      ),
    );
  }
}

// ----------------------------------------------------------------- Board
class _BoardTab extends ConsumerStatefulWidget {
  const _BoardTab();
  @override
  ConsumerState<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends ConsumerState<_BoardTab> {
  Level? _level;
  bool _adjacent = false;
  DateTime? _day; // local midnight, null = any day
  Future<List<Offer>>? _board;

  Level get level => _level ?? ref.read(targetLevelProvider);

  Future<List<Offer>> _query() =>
      ref.read(agendaRepositoryProvider)!.board([level, if (_adjacent) ...AgendaRules.adjacent(level)]);

  void _load() {
    final f = _query();
    setState(() {
      _board = f;
    });
  }

  @override
  void initState() {
    super.initState();
    _board = _query();
  }

  Future<void> _refresh() async {
    _load();
    ref.invalidate(myOffersProvider);
    await _board;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final now = ref.watch(agendaClockProvider)();
    final mine = ref.watch(myOffersProvider);
    final today = localDay(now);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        ...mine.maybeWhen(
          data: (offers) => [
            Text(l.myOffersCount(offers.length), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.textSecondary)),
            const SizedBox(height: 8),
            for (final o in offers)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${windowText(context, o.windowStart, o.windowEnd, now)} · ${o.level.code}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(l.interestedCount(o.interested), style: TextStyle(color: p.brand)),
                  trailing: IconButton(
                    tooltip: l.withdrawOffer,
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      try {
                        await ref.read(agendaRepositoryProvider)!.cancelOffer(o.id);
                        refreshAgenda(ref);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          orElse: () => const <Widget>[],
        ),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PopupMenuButton<Level>(
            initialValue: level,
            onSelected: (v) {
              _level = v;
              _load();
            },
            itemBuilder: (_) => [for (final lv in Level.values) PopupMenuItem(value: lv, child: Text(levelName(l, lv)))],
            child: Chip(label: Text('${levelName(l, level)} ▾')),
          ),
          Pill(
            label: l.includeLevel(AgendaRules.adjacent(level).map((e) => e.code).join(', ')),
            selected: _adjacent,
            onTap: () {
              _adjacent = !_adjacent;
              _load();
            },
          ),
          PopupMenuButton<int>(
            onSelected: (d) => setState(() => _day = d < 0 ? null : today.add(Duration(days: d))),
            itemBuilder: (_) => [
              PopupMenuItem(value: -1, child: Text(l.anyDay)),
              for (var d = 0; d < 7; d++)
                PopupMenuItem(value: d, child: Text(dayWord(context, today.add(Duration(days: d)), now))),
            ],
            child: Chip(label: Text('${_day == null ? l.anyDay : dayWord(context, _day!, now)} ▾')),
          ),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<List<Offer>>(
          future: _board,
          builder: (context, snap) {
            if (snap.hasError) return _Message(text: l.errorGeneric);
            if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            final offers = snap.data!.where((o) {
              if (_day == null) return true;
              final next = _day!.add(const Duration(days: 1));
              return o.windowStart.toLocal().isBefore(next) && o.windowEnd.toLocal().isAfter(_day!);
            }).toList();
            if (offers.isEmpty) return _Message(text: l.noOffers);
            return Column(children: [for (final o in offers) _OfferCard(offer: o, now: now, onAccepted: _refresh)]);
          },
        ),
      ]),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.now, required this.onAccepted});
  final Offer offer;
  final DateTime now;
  final Future<void> Function() onAccepted;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final name = offer.creatorName ?? l.deletedUser;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            InitialAvatar(name: name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(l.speaksLangs(offer.creatorLanguages.map((e) => e.toUpperCase()).join(', ')),
                    style: TextStyle(color: p.textSecondary, fontSize: 13)),
              ]),
            ),
            Chip(label: Text(offer.level.code), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.availableLabel, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                Text(windowText(context, offer.windowStart, offer.windowEnd, now), style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            FilledButton.tonal(
              style: inlineButton,
              onPressed: () async {
                final chatId = await showAcceptOfferSheet(context, offer);
                if (chatId == null || !context.mounted) return;
                refreshAgenda(ref);
                await onAccepted();
                if (context.mounted) unawaited(context.push('/chat/$chatId'));
              },
              child: Text(l.chooseTime),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ----------------------------------------------------------------- Mi agenda
class _MineTab extends ConsumerStatefulWidget {
  const _MineTab();
  @override
  ConsumerState<_MineTab> createState() => _MineTabState();
}

class _MineTabState extends ConsumerState<_MineTab> {
  DateTime? _day;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // "Empieza en 4 min" and the enter button move with the clock.
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(agendaClockProvider)();
    final today = localDay(now);
    final me = ref.watch(agendaRepositoryProvider)!.me;
    final meetings = ref.watch(myMeetingsProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myMeetingsProvider.future),
      child: meetings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: l.errorGeneric),
        data: (all) {
          final days = {for (final m in all) localDay(m.scheduledAt)};
          final shown = _day == null ? all : all.where((m) => localDay(m.scheduledAt) == _day).toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              for (var d = 0; d < 7; d++)
                Expanded(child: _DayCell(
                  day: today.add(Duration(days: d)),
                  locale: locale,
                  selected: _day == today.add(Duration(days: d)),
                  hasMeeting: days.contains(today.add(Duration(days: d))),
                  onTap: () => setState(() => _day = _day == today.add(Duration(days: d)) ? null : today.add(Duration(days: d))),
                )),
            ]),
            const SizedBox(height: 16),
            if (shown.isEmpty) _Message(text: l.noMeetings),
            for (final m in shown) _MeetingRow(meeting: m, me: me, now: now),
          ]);
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.locale, required this.selected, required this.hasMeeting, required this.onTap});
  final DateTime day;
  final String locale;
  final bool selected, hasMeeting;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.onBrand : p.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: selected ? p.brand : p.surface, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          FittedBox(child: Text(intlDay(day, locale), style: TextStyle(fontSize: 11, color: selected ? p.onBrand : p.textSecondary))),
          Text('${day.day}', style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: hasMeeting ? (selected ? p.onBrand : p.brand) : Colors.transparent)),
        ]),
      ),
    );
  }
}

class _MeetingRow extends ConsumerWidget {
  const _MeetingRow({required this.meeting, required this.me, required this.now});
  final Meeting meeting;
  final String me;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final partner = meeting.partnerOf(me);
    final canEnter = AgendaRules.canEnter(meeting, now);
    final mins = meeting.scheduledAt.difference(now).inSeconds;
    return FutureBuilder(
      future: partner == null ? null : ref.read(agendaRepositoryProvider)!.profile(partner),
      builder: (context, snap) {
        final name = snap.data?.username ?? (partner == null ? l.deletedUser : '…');
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SizedBox(
                width: 64,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dayWord(context, meeting.scheduledAt, now).toUpperCase(), style: TextStyle(fontSize: 11, color: p.textSecondary)),
                  Text(hm(meeting.scheduledAt), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(l.meetingLength, style: TextStyle(fontSize: 11, color: p.textSecondary)),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.examWith(meeting.level.code, name), style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    canEnter
                        ? (mins >= 0 ? l.startsInMinutes((mins / 60).ceil()) : l.startedMinutesAgo(-mins ~/ 60))
                        : l.remindBefore,
                    style: TextStyle(fontSize: 12, color: canEnter ? p.brand : p.textSecondary),
                  ),
                ]),
              ),
              if (canEnter) FilledButton(style: inlineButton, onPressed: () => enterMeeting(context, ref, meeting), child: Text(l.enterRoom)),
            ]),
          ),
        );
      },
    );
  }
}

String intlDay(DateTime d, String locale) => DateFormat('EEE', locale).format(d).replaceAll('.', '').toUpperCase();

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => ListView(shrinkWrap: true, physics: const AlwaysScrollableScrollPhysics(), children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.palette.textSecondary)),
        ),
      ]);
}
