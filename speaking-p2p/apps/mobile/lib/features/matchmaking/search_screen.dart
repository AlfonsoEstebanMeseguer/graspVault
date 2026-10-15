// "Buscando pareja" + "Aviso a los 15 s" sketches.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/errors.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../data/profile/profile_repository.dart';
import '../../domain/account/account.dart';
import '../exam/widgets/exam_widgets.dart' show formatMs;
import '../home/home_screen.dart' show levelName;
import '../home/search_pulse.dart';
import 'matchmaking_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = context.l10n;
    final m = ref.watch(matchmakingProvider);
    final ctrl = ref.read(matchmakingProvider.notifier);
    final name = ref.watch(myProfileProvider).value?.username ?? '?';
    final elapsed = m.startedAt == null ? 0 : DateTime.now().difference(m.startedAt!).inMilliseconds;
    final tips = [l.tip1, l.tip2, l.tip3, l.tip4];
    final tip = tips[(elapsed ~/ 12000) % tips.length];

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (m.level != null) Center(child: Chip(label: Text(levelName(l, m.level!)))),
              const Spacer(),
              Center(
                child: SearchPulse(label: name.characters.first.toUpperCase(), onTap: () {}, size: 180),
              ),
              const SizedBox(height: 12),
              Text(l.searchingPartner, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
              Text(formatMs(elapsed), textAlign: TextAlign.center,
                  style: TextStyle(color: p.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
              if (m.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(errorText(l, AppFailure(m.error!)), textAlign: TextAlign.center, style: TextStyle(color: p.danger)),
                ),
              const Spacer(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.whileYouWait, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.onExaminerSoft)),
                    const SizedBox(height: 4),
                    Text(tip, style: TextStyle(color: p.textPrimary)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('search-cancel'),
                onPressed: () async {
                  await ctrl.cancel();
                  if (context.mounted) context.go('/');
                },
                child: Text(l.cancelSearch),
              ),
            ]),
          ),
          if (m.showPrompt)
            Positioned(
              left: 12,
              right: 12,
              top: 8,
              child: Material(
                elevation: 6,
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.calendar_today_outlined, color: p.onExaminerSoft),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.nobodySearchingTitle, style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
                          Text(l.nobodySearchingBody, style: TextStyle(color: p.textSecondary)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: OutlinedButton(key: const Key('prompt-no'), onPressed: ctrl.dismissPrompt, child: Text(l.noLabel))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const Key('prompt-yes'),
                          onPressed: () {
                            ctrl.dismissPrompt();
                            context.go('/agenda?create=1');
                          },
                          child: Text(l.yesSchedule),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
