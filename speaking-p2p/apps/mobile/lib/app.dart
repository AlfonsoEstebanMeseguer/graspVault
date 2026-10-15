import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/l10n.dart';
import 'core/router/router.dart';
import 'core/theming/app_theme.dart';
import 'core/theming/preferences.dart';
import 'features/matchmaking/matchmaking_controller.dart';

class SpeakingApp extends ConsumerWidget {
  const SpeakingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A match can arrive on any screen (the search keeps running in the tabs).
    ref.listen(matchmakingProvider, (prev, next) {
      final id = next.matchedSessionId;
      if (id != null && id != prev?.matchedSessionId) {
        ref.read(routerProvider).go('/session/$id');
        ref.read(matchmakingProvider.notifier).consumeMatch();
      }
    });
    return MaterialApp.router(
      onGenerateTitle: (c) => c.l10n.appName,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) =>
          supported.firstWhere((s) => s.languageCode == device?.languageCode, orElse: () => const Locale('es')),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
