import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/telemetry/telemetry.dart';
import 'core/theming/preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  const env = Env.fromDefines;
  env.assertSafe();
  await Telemetry.instance.init();
  if (env.hasBackend) {
    await Supabase.initialize(url: env.supabaseUrl, publishableKey: env.supabaseAnonKey);
    final auth = Supabase.instance.client.auth;
    Telemetry.instance.identify(auth.currentUser?.id);
    auth.onAuthStateChange.listen((s) => Telemetry.instance.identify(s.session?.user.id), onError: (Object _) {});
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const SpeakingApp(),
  ));
}
