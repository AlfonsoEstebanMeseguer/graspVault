// «Compartir estadísticas de uso» (D-064): legitimate interest with an opt-out,
// on by default. Two copies of the choice:
//   * the server one (profiles_private.analytics_opt_out) is the truth: it also
//     silences the server-side events and follows the user to another device;
//   * the device one (SharedPreferences) applies before sign-in and offline.
// Sentry is not affected: error reports carry no profile and stay on.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/account/account_repository.dart';
import '../theming/preferences.dart';
import 'telemetry.dart';

bool analyticsAllowedOnDevice(SharedPreferences prefs) => !(prefs.getBool(Telemetry.optOutPrefKey) ?? false);

/// At sign-in, before identify(): the server choice wins over the device copy.
/// [readOptOut] null = unknown (network error): keep the device copy.
Future<void> applyServerAnalyticsChoice(SharedPreferences prefs, Future<bool?> Function() readOptOut) async {
  bool? optOut;
  try {
    optOut = await readOptOut();
  } catch (e) {
    debugPrint('[telemetry] could not read the analytics choice: $e');
  }
  if (optOut == null) return;
  await prefs.setBool(Telemetry.optOutPrefKey, optOut);
  await Telemetry.instance.setAnalyticsAllowed(!optOut);
}

class AnalyticsConsentController extends Notifier<bool> {
  @override
  bool build() => analyticsAllowedOnDevice(ref.read(sharedPreferencesProvider));

  Future<void> set(bool allowed) async {
    final previous = state;
    state = allowed;
    await Telemetry.instance.setAnalyticsAllowed(allowed);
    await ref.read(sharedPreferencesProvider).setBool(Telemetry.optOutPrefKey, !allowed);
    final repo = ref.read(accountRepositoryProvider);
    if (repo == null) return; // not signed in: the device copy is all there is
    try {
      await repo.setAnalyticsOptOut(!allowed);
    } catch (e) {
      // The server did not take it: undo everything, so the switch never lies.
      state = previous;
      await Telemetry.instance.setAnalyticsAllowed(previous);
      await ref.read(sharedPreferencesProvider).setBool(Telemetry.optOutPrefKey, !previous);
      rethrow;
    }
  }
}

final analyticsConsentProvider = NotifierProvider<AnalyticsConsentController, bool>(AnalyticsConsentController.new);
