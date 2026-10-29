// Theme (system by default, persistent override) and UI language (ES/EN).
// Written AND read back on start: a setting nobody reads is a lying button (vault).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    final v = ref.read(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.system);
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class LocaleController extends Notifier<Locale?> {
  static const _key = 'ui_locale';
  static const supported = [Locale('es'), Locale('en')];

  /// Null = follow the device (falls back to Spanish if unsupported).
  @override
  Locale? build() {
    final v = ref.read(sharedPreferencesProvider).getString(_key);
    return v == null ? null : Locale(v);
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
