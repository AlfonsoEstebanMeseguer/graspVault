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
                onTap: () => context.go('/practice/${level.code}'),
              ),
            ),
            const SizedBox(height: 24),
            Text(l.examOfLevel(level.code), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            Text(l.examSummary(_approxMinutes[level]!), textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}
