import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/legal/bundled_licenses.dart';
import 'core/telemetry/analytics_consent.dart';
import 'core/telemetry/telemetry.dart';
import 'core/theming/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  const env = Env.fromDefines;
  env.assertSafe();
  registerBundledLicenses();
  final prefs = await SharedPreferences.getInstance();
  await Telemetry.instance.init(analyticsAllowed: analyticsAllowedOnDevice(prefs));
  if (env.hasBackend) {
    await Supabase.initialize(url: env.supabaseUrl, publishableKey: env.supabaseAnonKey);
    final client = Supabase.instance.client;
    // The server copy of the opt-out wins (D-064), and is applied BEFORE identify.
    Future<void> onUser(String? id) async {
      if (id != null) {
        await applyServerAnalyticsChoice(prefs, () async {
          final r = await client.from('profiles_private').select('analytics_opt_out').eq('id', id).maybeSingle();
          return r?['analytics_opt_out'] as bool?;
        });
      }
      Telemetry.instance.identify(id);
    }
    onUser(client.auth.currentUser?.id).ignore();
    client.auth.onAuthStateChange.listen((s) => onUser(s.session?.user.id).ignore(), onError: (Object _) {});
  }
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SpeakingApp(),
  ));
}
