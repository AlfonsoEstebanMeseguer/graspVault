// "Practicar" tab: pick the level and look for a partner. Without backend the big
// button starts the offline practice with a simulated partner.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/preferences.dart';
import '../../core/theming/tokens.dart';
import '../../core/ui/kit.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/exam/models.dart';
import '../matchmaking/matchmaking_controller.dart';
import '../../data/agenda/agenda_repository.dart';
import '../../domain/agenda/agenda.dart';
import '../agenda/agenda_common.dart';
import 'search_pulse.dart';

class TargetLevelController extends Notifier<Level> {
  static const _key = 'target_level';
  @override
  Level build() {
    final v = ref.read(sharedPreferencesProvider).getString(_key);
    return Level.values.firstWhere((l) => l.code == v, orElse: () => Level.b2);
  }

  Future<void> set(Level level) async {
    state = level;
    await ref.read(sharedPreferencesProvider).setString(_key, level.code);
  }
}

final targetLevelProvider = NotifierProvider<TargetLevelController, Level>(TargetLevelController.new);

String levelName(AppLocalizations l, Level level) => switch (level) {
      Level.b1 => l.levelB1,
      Level.b2 => l.levelB2,
      Level.c1 => l.levelC1,
    };

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _approxMinutes = {Level.b1: 12, Level.b2: 14, Level.c1: 15};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l = context.l10n;
    final profile = ref.watch(myProfileProvider).value;
    final level = ref.watch(targetLevelProvider);
    final offline = !Env.fromDefines.hasBackend;
    void practise({bool vip = false}) => context.go('/practice/${level.code}${vip ? '?vip=1' : ''}');
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.screen, 16, AppSpace.screen, 24), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: ScreenTitle(l.tabPractice, above: profile == null ? null : '${l.homeHello} ${profile.username}')),
            _LevelPicker(level: level, onChanged: (v) => ref.read(targetLevelProvider.notifier).set(v)),
          ]),
          if (offline)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Tile(
                color: p.brandSoft,
                padding: const EdgeInsets.all(14),
                child: Text(l.offlineBanner, style: AppType.footnote.copyWith(color: p.onBrandSoft, fontSize: 14)),
              ),
            ),
          const SizedBox(height: 8),
          // The live search: the round pulsing button, free on the page (user's choice).
          Center(
            child: SearchPulse(
              key: const Key('home-search'),
              label: offline ? l.practiceSimulated : l.searchPartner,
              onTap: () {
                if (offline) return practise();
                ref.read(matchmakingProvider.notifier).start(level);
                context.go('/search');
              },
            ),
          ),
          Text(l.examOfLevel(level.code), textAlign: TextAlign.center, style: AppType.headline.copyWith(color: p.textPrimary)),
          const SizedBox(height: 2),
          Text(l.examSummary(_approxMinutes[level]!),
              textAlign: TextAlign.center, style: AppType.footnote.copyWith(color: p.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          if (!offline) const NextMeetingCard(),
          if (!offline)
            _SoloTile(
              key: const Key('home-practice-solo'),
              icon: AppIcons.chat,
              title: l.practiceSoloTitle,
              body: l.practiceSoloBody,
              onTap: practise,
            ),
          // Debug only: in release this would hand out the Pro controls for free.
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            _SoloTile(
              key: const Key('practice-vip'),
              icon: AppIcons.crown,
              iconColor: p.pro,
              title: l.practiceVip,
              body: l.practiceVipBody,
              onTap: () => practise(vip: true),
            ),
          ],
          const SizedBox(height: 96), // room for the floating tab bar
        ]),
      ),
    );
  }
}

/// "C1 Advanced ▾" pill.
class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.level, required this.onChanged});
  final Level level;
  final ValueChanged<Level> onChanged;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    String short(Level lv) => levelName(l, lv).split(' ').last;
    return PopupMenuButton<Level>(
      key: const Key('home-level'),
      initialValue: level,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final lv in Level.values)
          PopupMenuItem(value: lv, child: Row(children: [LevelBadge(lv, size: 13), const SizedBox(width: 10), Text(short(lv))])),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          LevelBadge(level, size: 14),
          const SizedBox(width: 10),
          Text(short(level), style: AppType.headline.copyWith(color: p.textPrimary)),
          const SizedBox(width: 6),
          Icon(AppIcons.caretDown, size: 14, color: p.textSecondary),
        ]),
      ),
    );
  }
}

/// "Practicar solo": the secondary way in, explained (spec §1: it looked like debug).
class _SoloTile extends StatelessWidget {
  const _SoloTile({super.key, required this.icon, required this.title, required this.body, required this.onTap, this.iconColor});
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tile(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.input)),
          child: Icon(icon, color: iconColor ?? p.link, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppType.headline.copyWith(color: p.textPrimary)),
            const SizedBox(height: 2),
            Text(body, style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400, fontSize: 14)),
          ]),
        ),
        Icon(AppIcons.caretRight, color: p.textTertiary, size: 18),
      ]),
    );
  }
}

/// "HOY 19:00 · Reunión con marta_x · C1 · la sala abre 5 min antes · Ver".
class NextMeetingCard extends ConsumerWidget {
  const NextMeetingCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final repo = ref.watch(agendaRepositoryProvider);
    if (repo == null) return const SizedBox.shrink();
    final now = ref.watch(agendaClockProvider)();
    final list = ref.watch(myMeetingsProvider).value ?? const <Meeting>[];
    final next = list.where((m) => m.scheduledAt.add(AgendaRules.courtesy).isAfter(now)).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final partner = next.partnerOf(repo.me);
    final canEnter = AgendaRules.canEnter(next, now);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tile(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: p.surfaceMuted, borderRadius: BorderRadius.circular(AppRadii.input)),
            child: Column(children: [
              Text(dayWord(context, next.scheduledAt, now).toUpperCase(), style: AppType.overline.copyWith(color: p.roleB)),
              Text(hm(next.scheduledAt), style: AppType.timer.copyWith(fontSize: 19, height: 1.3, color: p.textPrimary)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FutureBuilder(
                future: partner == null ? null : repo.profile(partner),
                builder: (context, snap) => Text(
                  l.meetingWithName(snap.data?.username ?? (partner == null ? l.aPartner : '…')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.headline.copyWith(color: p.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text('${next.level.code} · ${l.roomOpensBefore.toLowerCase()}',
                  style: AppType.footnote.copyWith(color: p.textSecondary, fontWeight: FontWeight.w400, fontSize: 14)),
            ]),
          ),
          const SizedBox(width: 8),
          canEnter
              ? FilledButton(style: inlineButton, onPressed: () => enterMeeting(context, ref, next), child: Text(l.enterRoom))
              : FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: p.brandSoft, foregroundColor: p.onBrandSoft),
                  onPressed: () => context.go('/agenda'),
                  child: Text(l.viewLabel),
                ),
        ]),
      ),
    );
  }
}
