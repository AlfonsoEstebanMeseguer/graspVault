// Agenda tab (D-046): "Mis exámenes" (what waits for me, what is coming, my
// proposals, companions, the past) and "Buscar horario" (the board, with the free
// slots right on each card). Every meeting is one card that opens its chat.
// `/agenda?create=1` opens "Proponer horario" (from the 15 s prompt of the live
// search); `/agenda?invite=<user>` opens the invitation to that companion.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../core/ui/placeholder_screen.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../data/safety/safety_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../../domain/exam/models.dart';
import '../home/home_screen.dart' show levelName, targetLevelProvider;
import '../home/search_pulse.dart';
import '../profile/avatar/user_avatar.dart';
import '../safety/safety_sheet.dart';
import 'accept_offer_sheet.dart';
import 'agenda_common.dart';
import 'create_offer_sheet.dart';
import 'invite_sheet.dart';

class AgendaScreen extends ConsumerStatefulWidget {
  const AgendaScreen({super.key, this.openCreate = false, this.invite});
  final bool openCreate;

  /// A companion to invite as soon as the list is loaded ("Repetir con…").
  final String? invite;
  @override
  ConsumerState<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends ConsumerState<AgendaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(() => setState(() {}));
  bool _tabChosen = false;

  @override
  void initState() {
    super.initState();
    if (widget.openCreate) WidgetsBinding.instance.addPostFrameCallback((_) => _create());
    if (widget.invite != null) WidgetsBinding.instance.addPostFrameCallback((_) => _invite(widget.invite!));
  }

  @override
  void didUpdateWidget(AgendaScreen old) {
    super.didUpdateWidget(old);
    if (widget.openCreate && !old.openCreate) WidgetsBinding.instance.addPostFrameCallback((_) => _create());
    if (widget.invite != null && widget.invite != old.invite) WidgetsBinding.instance.addPostFrameCallback((_) => _invite(widget.invite!));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!mounted) return;
    final created = await showCreateOfferSheet(context);
    if (created == true && mounted) {
      refreshAgenda(ref);
      _tabs.animateTo(0);
    }
  }

  Future<void> _invite(String partnerId) async {
    final list = await ref.read(companionsProvider.future);
    final c = list.where((c) => c.partnerId == partnerId && c.mutual).firstOrNull;
    if (c == null || !mounted) return;
    await inviteAndOpenChat(context, ref, c);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    if (ref.watch(agendaRepositoryProvider) == null) {
      return PlaceholderScreen(title: l.agendaTitle);
    }
    final me = ref.watch(agendaRepositoryProvider)!.me;
    final chats = ref.watch(chatsProvider).value;
    final offers = ref.watch(myOffersProvider).value;
    final live = chats == null ? 0 : AgendaBuckets.of(chats, me).needsMe.length + AgendaBuckets.of(chats, me).upcoming.length;
    // Start on the board when there is nothing of mine yet (first visit).
    if (!_tabChosen && chats != null && offers != null) {
      _tabChosen = true;
      if (live == 0 && offers.isEmpty && !widget.openCreate) _tabs.index = 1;
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 14),
              child: Row(
                children: [
                  Expanded(child: ScreenTitle(l.agendaTitle)),
                  FilledButton.icon(
                    key: const Key('agenda-create'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shadowColor: p.brand.withValues(alpha: 0.5),
                    ),
                    onPressed: _create,
                    icon: const Icon(AppIcons.plus, size: 18),
                    label: Text(l.offerSlot),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: AppSegmented<int>(
                items: [
                  SegmentItem(0, live > 0 ? l.agendaMineCount(live) : l.agendaMine, key: const Key('agenda-tab-mine')),
                  SegmentItem(1, l.agendaBoard, key: const Key('agenda-tab-board')),
                ],
                selected: _tabs.index,
                onChanged: _tabs.animateTo,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _MineTab(onFind: () => _tabs.animateTo(1), onCreate: _create),
                  _BoardTab(onCreate: _create),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Invite sheet -> the new chat. Shared by the companion strip and "Repetir con…".
Future<void> inviteAndOpenChat(BuildContext context, WidgetRef ref, Companion c) async {
  final chatId = await showInviteSheet(context, c);
  if (chatId == null || !context.mounted) return;
  refreshAgenda(ref);
  unawaited(context.push('/chat/$chatId'));
}

Future<void> _openChat(BuildContext context, WidgetRef ref, String chatId) async {
  await context.push('/chat/$chatId');
  refreshAgenda(ref);
}

// ----------------------------------------------------------------- Mis exámenes
class _MineTab extends ConsumerStatefulWidget {
  const _MineTab({required this.onFind, required this.onCreate});
  final VoidCallback onFind;
  final VoidCallback onCreate;
  @override
  ConsumerState<_MineTab> createState() => _MineTabState();
}

class _MineTabState extends ConsumerState<_MineTab> {
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

  Future<void> _refresh() async {
    refreshAgenda(ref);
    await ref.read(chatsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final me = ref.watch(agendaRepositoryProvider)!.me;
    final now = ref.watch(agendaClockProvider)();
    final chats = ref.watch(chatsProvider);
    final offers = ref.watch(myOffersProvider).value ?? const <Offer>[];
    final companions = ref.watch(companionsProvider).value ?? const <Companion>[];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: chats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(text: l.errorGeneric),
        data: (list) {
          final b = AgendaBuckets.of(list, me);
          final bookings = {
            for (final o in offers)
              o.id: [
                for (final c in list)
                  if (c.meeting.offerId == o.id && meetingIsLive(c.meeting)) c,
              ]..sort((x, y) => x.meeting.scheduledAt.compareTo(y.meeting.scheduledAt)),
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.screen, 8, AppSpace.screen, 180),
            children: [
              if (companions.isNotEmpty) ...[
                Overline(l.companionsTitle),
                const SizedBox(height: 10),
                _CompanionStrip(companions: companions),
                const SizedBox(height: 18),
              ],
              if (b.needsMe.isNotEmpty) ...[
                Overline(l.sectionNeedsYou),
                const SizedBox(height: 10),
                for (final c in b.needsMe) _MeetingTile(chat: c, me: me, now: now),
                const SizedBox(height: 8),
              ],
              if (b.upcoming.isNotEmpty) ...[
                Overline(l.sectionUpcoming),
                const SizedBox(height: 10),
                for (final c in b.upcoming) _MeetingTile(chat: c, me: me, now: now),
                const SizedBox(height: 8),
              ],
              if (offers.isNotEmpty) ...[
                Overline(l.myOffersCount(offers.length)),
                const SizedBox(height: 10),
                for (final o in offers) _MyOfferTile(offer: o, bookings: bookings[o.id]!, now: now),
                const SizedBox(height: 8),
              ],
              if (b.isEmpty && offers.isEmpty)
                _EmptyMine(onFind: widget.onFind, onCreate: widget.onCreate, hint: companions.isEmpty ? l.companionsEmpty : null),
              if (b.past.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: const Key('agenda-past'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.pastCount(b.past.length), style: AppType.headline.copyWith(color: p.textSecondary)),
                    children: [for (final c in b.past) _MeetingTile(chat: c, me: me, now: now)],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyMine extends StatelessWidget {
  const _EmptyMine({required this.onFind, required this.onCreate, this.hint});
  final VoidCallback onFind;
  final VoidCallback onCreate;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // The Home button with its colours swapped (D-050): mandarin circle, cobalt rings.
          SearchPulse(
            key: const Key('agenda-pulse'),
            label: l.createMeeting,
            icon: AppIcons.agendaOn,
            size: 170,
            circle: p.roleB,
            onCircle: p.onRole,
            rings: p.brand,
            onTap: onCreate,
          ),
          const SizedBox(height: 4),
          Text(
            l.emptyMine,
            textAlign: TextAlign.center,
            style: AppType.title2.copyWith(color: p.textPrimary),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: p.textSecondary),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(onPressed: onFind, child: Text(l.agendaBoard)),
        ],
      ),
    );
  }
}

/// One meeting = one card: when, with whom, where it stands, the one action that
/// makes sense now. Tapping it opens the chat.
class _MeetingTile extends ConsumerWidget {
  const _MeetingTile({required this.chat, required this.me, required this.now});
  final ChatSummary chat;
  final String me;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final m = chat.meeting;
    final name = chat.partnerName ?? l.deletedUser;
    final live = meetingIsLive(m);
    final needsMe = m.status == MeetingStatus.pending && !m.confirmedBy(me) && chat.partnerId != null;
    final canEnter = AgendaRules.canEnter(m, now);
    final secs = m.scheduledAt.difference(now).inSeconds;
    final (String status, Color color) = switch (m.status) {
      _ when canEnter => (secs >= 0 ? l.startsInMinutes((secs / 60).ceil()) : l.startedMinutesAgo(-secs ~/ 60), p.link),
      MeetingStatus.confirmed => (l.statusConfirmed, p.success),
      MeetingStatus.pending => needsMe ? (l.statusAwaitingYou, p.link) : (l.statusAwaitingPartner(name), p.textSecondary),
      MeetingStatus.done || MeetingStatus.noShow => (meetingStatusText(context, m, me, name), p.textSecondary),
      _ => ('${l.statusGone} · ${meetingStatusText(context, m, me, name)}', p.textTertiary),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: live ? 1 : 0.7,
        child: Tile(
          key: Key('meeting-${m.id}'),
          padding: const EdgeInsets.all(14),
          onTap: () => _openChat(context, ref, chat.chatId),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.input)),
                    child: Column(
                      children: [
                        FittedBox(
                          child: Text(dayWord(context, m.scheduledAt, now).toUpperCase(), style: AppType.overline.copyWith(fontSize: 11, color: p.roleB)),
                        ),
                        Text(hm(m.scheduledAt), style: AppType.timer.copyWith(fontSize: 18, height: 1.3, color: p.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(name: name, userId: chat.partnerId, avatarKey: chat.partnerAvatarKey, size: 22),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l.examWith(m.level.code, name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.headline.copyWith(color: p.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(status, maxLines: 2, style: AppType.footnote.copyWith(color: color)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canEnter)
                    FilledButton(style: inlineButton, onPressed: () => enterMeeting(context, ref, m), child: Text(l.enterRoom))
                  else if (!needsMe)
                    Icon(AppIcons.chat, color: p.textTertiary, size: 20),
                ],
              ),
              if (needsMe && !canEnter) ...[
                const SizedBox(height: 12),
                FilledButton(
                  key: Key('confirm-${m.id}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    try {
                      await ref.read(agendaRepositoryProvider)!.confirm(m.id);
                      refreshAgenda(ref);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  child: Text(l.confirmLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// My open proposal: who booked which slot (each opens its chat) and "Retirar".
class _MyOfferTile extends ConsumerWidget {
  const _MyOfferTile({required this.offer, required this.bookings, required this.now});
  final Offer offer;
  final List<ChatSummary> bookings;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tile(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${windowText(context, offer.windowStart, offer.windowEnd, now)} · ${offer.level.code}',
                    style: AppType.headline.copyWith(color: p.textPrimary),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.textSecondary),
                  onPressed: () async {
                    try {
                      await ref.read(agendaRepositoryProvider)!.cancelOffer(offer.id);
                      refreshAgenda(ref);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  },
                  child: Text(l.withdrawOffer),
                ),
              ],
            ),
            if (bookings.isEmpty)
              Text(
                l.noBookingsYet,
                style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in bookings)
                    ActionChip(
                      avatar: UserAvatar(name: c.partnerName ?? l.deletedUser, userId: c.partnerId, avatarKey: c.partnerAvatarKey, size: 22),
                      label: Text('${c.partnerName ?? l.deletedUser} · ${hm(c.meeting.scheduledAt)}'),
                      onPressed: () => _openChat(context, ref, c.chatId),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Companions in a row: mutual ones can be invited; the rest show where they stand.
class _CompanionStrip extends ConsumerWidget {
  const _CompanionStrip({required this.companions});
  final List<Companion> companions;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final sorted = [...companions]..sort((a, b) => (b.mutual ? 1 : 0).compareTo(a.mutual ? 1 : 0));
    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: sorted.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = sorted[i];
          final name = c.name ?? l.deletedUser;
          final (String action, Color color) = c.mutual
              ? (l.inviteLabel, p.link)
              : (c.theyAdded ? (l.addBack, p.link) : (l.companionPendingShort, p.textTertiary));
          return SizedBox(
            width: 104,
            child: Tile(
              key: Key('companion-${c.partnerId}'),
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              onTap: () => _companionSheet(context, ref, c),
              child: Column(
                children: [
                  UserAvatar(name: name, userId: c.partnerId, avatarKey: c.avatarKey, size: 44),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.footnote.copyWith(color: p.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.footnote.copyWith(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _companionSheet(BuildContext context, WidgetRef ref, Companion c) async {
    final l = context.l10n;
    final p = context.palette;
    final name = c.name ?? l.deletedUser;
    final repo = ref.read(agendaRepositoryProvider)!;
    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
        refreshAgenda(ref);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  UserAvatar(name: name, userId: c.partnerId, avatarKey: c.avatarKey, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppType.title2.copyWith(color: p.textPrimary)),
                        Text(
                          l.examsTogether(c.sessionsTogether),
                          style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400),
                        ),
                        if (!c.mutual) Text(c.theyAdded ? l.companionAddedYou : l.companionPendingShort, style: AppType.footnote.copyWith(color: p.link)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (c.mutual) FilledButton(onPressed: () => Navigator.pop(ctx, 'invite'), child: Text(l.inviteLabel)),
              if (c.theyAdded && !c.iAdded && c.lastSessionId != null) FilledButton(onPressed: () => Navigator.pop(ctx, 'add'), child: Text(l.addBack)),
              if (c.iAdded) ...[
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: p.danger),
                  onPressed: () => Navigator.pop(ctx, 'remove'),
                  child: Text(l.removeCompanion),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'invite':
        await inviteAndOpenChat(context, ref, c);
      case 'add':
        await run(() => repo.addCompanion(c.lastSessionId!));
      case 'remove':
        await run(() => repo.removeCompanion(c.partnerId));
    }
  }
}

// ----------------------------------------------------------------- Buscar horario
class _BoardTab extends ConsumerStatefulWidget {
  const _BoardTab({required this.onCreate});
  final VoidCallback onCreate;
  @override
  ConsumerState<_BoardTab> createState() => _BoardTabState();
}

class _BoardTabState extends ConsumerState<_BoardTab> {
  Level? _level;
  bool _adjacent = false;
  DateTime? _day; // local midnight, null = every day
  Future<List<Offer>>? _board;

  Level get level => _level ?? ref.read(targetLevelProvider);

  Future<List<Offer>> _query() => ref.read(agendaRepositoryProvider)!.board([level, if (_adjacent) ...AgendaRules.adjacent(level)]);

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
    refreshAgenda(ref);
    await _board;
  }

  Future<void> _book(Offer o, DateTime at) async {
    final chatId = await showBookSlotSheet(context, o, at);
    if (chatId == null || !mounted) return;
    refreshAgenda(ref);
    _load();
    unawaited(context.push('/chat/$chatId'));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final now = ref.watch(agendaClockProvider)();
    final today = localDay(now);
    final busy = ref.watch(myMeetingsProvider).value?.map((m) => m.scheduledAt).toList() ?? const <DateTime>[];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.screen, 8, AppSpace.screen, 180),
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Pill(label: l.allDays, selected: _day == null, onTap: () => setState(() => _day = null)),
                ),
                for (var d = 0; d < 7; d++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pill(
                      label: dayWord(context, today.add(Duration(days: d)), now),
                      selected: _day == today.add(Duration(days: d)),
                      onTap: () => setState(() => _day = today.add(Duration(days: d))),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PopupMenuButton<Level>(
                initialValue: level,
                position: PopupMenuPosition.under,
                onSelected: (v) {
                  _level = v;
                  _load();
                },
                itemBuilder: (_) => [for (final lv in Level.values) PopupMenuItem(value: lv, child: Text(levelName(l, lv)))],
                child: _FilterChip(dot: p.level(level), label: levelName(l, level), caret: true),
              ),
              FilterChip(
                key: const Key('board-adjacent'),
                label: Text(l.seeAlsoLevel(AgendaRules.adjacent(level).map((e) => e.code).join(', '))),
                selected: _adjacent,
                onSelected: (v) {
                  _adjacent = v;
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Offer>>(
            future: _board,
            builder: (context, snap) {
              if (snap.hasError) return _Message(text: l.errorGeneric);
              if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
              final offers = [
                for (final o in snap.data!)
                  if (_day == null || (o.windowStart.toLocal().isBefore(_day!.add(const Duration(days: 1))) && o.windowEnd.toLocal().isAfter(_day!)))
                    // Nothing left to book (all taken or past) = not on the board.
                    if (AgendaRules.slots(o.windowStart, o.windowEnd, now, busy, o.taken).any((s) => s.state != SlotState.taken)) o,
              ];
              if (offers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        l.noOffers,
                        textAlign: TextAlign.center,
                        style: AppType.body.copyWith(color: p.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(onPressed: widget.onCreate, icon: const Icon(AppIcons.plus, size: 18), label: Text(l.proposeMine)),
                    ],
                  ),
                );
              }
              final byDay = <DateTime, List<Offer>>{};
              for (final o in offers) {
                byDay.putIfAbsent(localDay(o.windowStart), () => []).add(o);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final MapEntry(key: day, value: list) in byDay.entries) ...[
                    Overline(dayWord(context, day, now).toUpperCase()),
                    const SizedBox(height: 10),
                    for (final o in list) _OfferCard(offer: o, now: now, busy: busy, onBook: (at) => _book(o, at), onBlocked: _refresh),
                    const SizedBox(height: 6),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends ConsumerWidget {
  const _OfferCard({required this.offer, required this.now, required this.busy, required this.onBook, required this.onBlocked});
  final Offer offer;
  final DateTime now;
  final List<DateTime> busy;
  final void Function(DateTime at) onBook;
  final Future<void> Function() onBlocked;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final name = offer.creatorName ?? l.deletedUser;
    final slots = AgendaRules.slots(offer.windowStart, offer.windowEnd, now, busy, offer.taken).where((s) => s.state != SlotState.taken);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tile(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  name: name,
                  userId: offer.creatorId,
                  avatarKey: offer.creatorAvatarKey,
                  size: 44,
                  background: p.surfaceMuted,
                  foreground: p.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppType.headline.copyWith(fontSize: 17, color: p.textPrimary)),
                      Text(
                        l.speaksLangs(offer.creatorLanguages.map((e) => e.toUpperCase()).join(' · ')),
                        style: AppType.body.copyWith(fontSize: 14, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                LevelBadge(offer.level),
                if (ref.watch(safetyRepositoryProvider) != null)
                  SizedBox(
                    width: 36,
                    height: 32,
                    child: IconButton(
                      key: Key('offer-report-${offer.id}'),
                      padding: EdgeInsets.zero,
                      tooltip: l.reportOrBlock,
                      icon: Icon(AppIcons.menu, size: 20, color: p.textTertiary),
                      onPressed: () async {
                        final blocked = await showSafetySheet(context, userId: offer.creatorId, name: name, where: ReportContext.offer);
                        if (blocked) await onBlocked();
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.freeFromTo(hm(offer.windowStart), hm(offer.windowEnd)), style: AppType.footnote.copyWith(color: p.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in slots)
                  _SlotChip(key: Key('slot-${offer.id}-${hm(s.at)}'), time: hm(s.at), busy: s.state == SlotState.busy, onTap: () => onBook(s.at)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A free slot to tap, or one that clashes with my meetings (struck out).
class _SlotChip extends StatelessWidget {
  const _SlotChip({super.key, required this.time, required this.busy, required this.onTap});
  final String time;
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    return Semantics(
      button: !busy,
      label: busy ? '$time · ${l.busyLabel}' : time,
      excludeSemantics: true,
      child: Material(
        color: busy ? p.surfaceMuted : p.brandSoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              time,
              style: AppType.headline.copyWith(
                fontSize: 15,
                color: busy ? p.textTertiary : p.onBrandSoft,
                decoration: busy ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter dropdown: "● C1 Advanced ⌄".
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.dot, this.caret = false});
  final String label;
  final Color? dot;
  final bool caret;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.input)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(label, style: AppType.headline.copyWith(fontSize: 15, color: p.textPrimary)),
          if (caret) ...[const SizedBox(width: 6), Icon(AppIcons.caretDown, size: 12, color: p.textSecondary)],
        ],
      ),
    );
  }
}

String intlDay(DateTime d, String locale) => DateFormat('EEE', locale).format(d).replaceAll('.', '').toUpperCase();

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary),
        ),
      ),
    ],
  );
}
