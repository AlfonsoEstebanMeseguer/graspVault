// "Examen" tab: pick the level and look for a partner. Without backend the big
// button starts the offline practice with a simulated partner.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/preferences.dart';
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: profile == null
                    ? Text(l.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.homeHello, style: TextStyle(color: p.textSecondary)),
                        Text(profile.username, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ]),
              ),
              DropdownButton<Level>(
                value: level,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: [for (final lv in Level.values) DropdownMenuItem(value: lv, child: Text(levelName(l, lv)))],
                onChanged: (v) => v == null ? null : ref.read(targetLevelProvider.notifier).set(v),
              ),
            ]),
            if (offline)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: p.brandSoft, borderRadius: BorderRadius.circular(12)),
                child: Text(l.offlineBanner, style: TextStyle(color: p.onBrandSoft)),
              ),
            const Spacer(),
            Center(
              child: SearchPulse(
                label: offline ? l.practiceSimulated : l.searchPartner,
                onTap: () {
                  if (offline) return context.go('/practice/${level.code}');
                  ref.read(matchmakingProvider.notifier).start(level);
                  context.go('/search');
                },
              ),
            ),
            if (!offline)
              TextButton(
                onPressed: () => context.go('/practice/${level.code}'),
                child: Text(l.practiceSimulated),
              ),
            const SizedBox(height: 24),
            if (!offline) const NextMeetingCard(),
            Text(l.examOfLevel(level.code), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            Text(l.examSummary(_approxMinutes[level]!), textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

/// "HOY 19:00 · Reunión con dani_r · C1 · La sala se abre 5 min antes · Ver".
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dayWord(context, next.scheduledAt, now).toUpperCase(), style: TextStyle(fontSize: 11, color: p.textSecondary)),
              Text(hm(next.scheduledAt), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: p.textPrimary)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FutureBuilder(
                  future: partner == null ? null : repo.profile(partner),
                  builder: (context, snap) => Text(
                    l.meetingWith(snap.data?.username ?? (partner == null ? l.deletedUser : '…'), next.level.code),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(l.roomOpensBefore, style: TextStyle(fontSize: 12, color: p.textSecondary)),
              ]),
            ),
            canEnter
                ? FilledButton(style: inlineButton, onPressed: () => enterMeeting(context, ref, next), child: Text(l.enterRoom))
                : TextButton(onPressed: () => context.go('/agenda'), child: Text(l.viewLabel)),
          ]),
        ),
      ),
    );
  }
}
