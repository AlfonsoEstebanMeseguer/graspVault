import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theming/palette.dart';
import '../../core/theming/preferences.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l = context.l10n;
    final mode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider) ?? Localizations.localeOf(context);
    Widget section(String t) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 12, color: p.textSecondary, letterSpacing: 0.4)),
        );
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(l.settingsTitle, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.textPrimary)),
          section(l.appearance),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
              ButtonSegment(value: ThemeMode.system, label: Text(l.themeSystem)),
            ],
            selected: {mode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
          section(l.appLanguage),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 'es', label: Text(l.languageSpanish)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
          ),
          section(l.subscription),
          // Honest placeholder: text only, no buttons that pretend to do something.
          Text(l.needsBackend, style: TextStyle(color: p.textSecondary)),
          section(l.account),
          Text(l.needsBackend, style: TextStyle(color: p.textSecondary)),
        ]),
      ),
    );
  }
}
