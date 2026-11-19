// App-side observability (D-061, D-063, docs/OBSERVABILITY.md): Sentry for
// errors, PostHog for the few events only the phone sees. Each half is off
// until its key arrives through --dart-define (env/dev.json), so a build without
// keys behaves exactly as before.
//
// What the server already emits (signup, subscription, matches, exam states,
// meetings) is NOT in [AppEvent]: sending it from here too would count it twice
// and let a modified client fake it.

library;

import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';

/// Client-only events (CLAUDE.md §11). The wire name is snake_case, the same
/// convention as the server's events, so PostHog sees one name per event.
enum AppEvent {
  paywallViewed,
  matchmakingStarted,
  matchmakingPromptShown,
  matchmakingPromptAccepted,
  textToggleUsed,
  timerToggleUsed,
  appOpenAdShown;

  String get wireName => name.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');
}

class Telemetry {
  Telemetry._();
  static final Telemetry instance = Telemetry._();

  // Injected at build time; empty when not configured.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN_APP');
  static const posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const posthogHost =
      String.fromEnvironment('POSTHOG_HOST', defaultValue: 'https://eu.i.posthog.com');

  bool get errorsEnabled => sentryDsn.isNotEmpty;

  /// Configured AND allowed by the user (Settings > Share usage statistics, D-064).
  bool get analyticsEnabled => posthogApiKey.isNotEmpty && _analyticsAllowed;

  /// SharedPreferences key of the device copy of the choice. The server keeps
  /// the real one (profiles_private.analytics_opt_out), synced at sign-in.
  static const optOutPrefKey = 'analytics_opt_out';

  String? _userId;
  bool _analyticsAllowed = true;
  bool _posthogReady = false;

  /// Once, from main(), before runApp. Never throws: telemetry must not stop
  /// the app from starting. [analyticsAllowed]: the device copy of the opt-out.
  Future<void> init({bool analyticsAllowed = true}) async {
    _analyticsAllowed = analyticsAllowed;
    if (errorsEnabled) {
      try {
        // Installs the Flutter / platform / isolate error handlers itself.
        await SentryFlutter.init((o) {
          o.dsn = sentryDsn;
          o.environment = kReleaseMode ? 'production' : 'debug';
          if (BuildInfo.number.isNotEmpty) o.dist = BuildInfo.number;
          o.sendDefaultPii = false; // no IP, no device name
          o.attachScreenshot = false; // the screen may show names and chat
          o.attachViewHierarchy = false;
        });
      } catch (e) {
        debugPrint('[telemetry] sentry init failed: $e');
      }
    }
    if (posthogApiKey.isNotEmpty) {
      try {
        final c = PostHogConfig(posthogApiKey)
          ..optOut = !_analyticsAllowed // opted out: nothing is captured, not even app opens
          ..host = posthogHost
          ..debug = kDebugMode
          ..captureApplicationLifecycleEvents = true // app opened/backgrounded: retention D1/D7/D30
          ..personProfiles = PostHogPersonProfiles.identifiedOnly
          ..disableGeoIp = true // no city/country from the IP: the Privacy Policy promises no location
          ..sessionReplay = false
          ..surveys = false
          ..preloadFeatureFlags = false;
        await Posthog().setup(c);
        _posthogReady = true;
      } catch (e) {
        debugPrint('[telemetry] posthog init failed: $e');
      }
    }
  }

  /// Report a caught error. Uncaught ones reach Sentry on their own.
  void captureError(Object error, StackTrace? stack, {String? hint}) {
    if (!errorsEnabled) {
      if (kDebugMode) debugPrint('[telemetry] error: $error${hint == null ? '' : ' ($hint)'}');
      return;
    }
    Sentry.captureException(error, stackTrace: stack, hint: hint == null ? null : Hint.withMap({'hint': hint}))
        .ignore();
  }

  /// Track a client event. Never pass PII in [properties]; the distinct id is
  /// the user's uuid, set by identify().
  void track(AppEvent event, {Map<String, Object> properties = const {}}) {
    if (!analyticsEnabled) return;
    Posthog().capture(eventName: event.wireName, properties: properties).ignore();
  }

  /// The Settings switch. Opting out stops PostHog on the phone at once and
  /// forgets the identity it holds; Sentry (errors, no profiling) is unaffected.
  Future<void> setAnalyticsAllowed(bool allowed) async {
    if (allowed == _analyticsAllowed) return;
    _analyticsAllowed = allowed;
    if (!_posthogReady) return;
    try {
      if (allowed) {
        await Posthog().optIn();
        final id = _userId;
        if (id != null) await Posthog().identify(userId: id);
      } else {
        await Posthog().reset();
        await Posthog().optOut();
      }
    } catch (e) {
      debugPrint('[telemetry] posthog opt-in/out failed: $e');
    }
  }

  /// Bind the current user (uuid only) and clear it on sign-out. Called on
  /// every auth change, including token refreshes: only a real change acts.
  void identify(String? userId) {
    if (userId == _userId) return;
    final had = _userId != null;
    _userId = userId;
    if (errorsEnabled) {
      Sentry.configureScope((s) => s.setUser(userId == null ? null : SentryUser(id: userId)));
    }
    if (!analyticsEnabled) return;
    if (userId != null) {
      Posthog().identify(userId: userId).ignore();
    } else if (had) {
      Posthog().reset().ignore();
    }
  }
}
