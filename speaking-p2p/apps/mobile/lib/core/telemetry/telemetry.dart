// App-side observability, prepared but not yet turned on (it will be the last
// thing wired — see docs/OBSERVABILITY.md). Everything here is a no-op until the
// keys arrive through --dart-define, so call sites can be added now without
// pulling in the SDKs or changing behaviour.
//
// Plug the real backends later:
//   - errors:    sentry_flutter, initialised in main() with [sentryDsn]
//   - analytics: posthog_flutter, initialised with [posthogApiKey]/[posthogHost]
// Keep the same two entry points (captureError / track) so call sites do not change.

library;

import 'package:flutter/foundation.dart';

/// Minimum events to emit once analytics is on (CLAUDE.md §11).
enum AppEvent {
  signupCompleted,
  paywallViewed,
  subscriptionStarted,
  subscriptionCancelled,
  matchmakingStarted,
  matchmakingMatched,
  examLobbyEntered,
  examPartStarted,
  examCompleted,
  examAborted,
  textToggleUsed,
  timerToggleUsed,
  appOpenAdShown,
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
  bool get analyticsEnabled => posthogApiKey.isNotEmpty;

  /// Call once from main() when the SDKs are added. No-op for now.
  Future<void> init() async {
    // TODO(observability): initialise sentry_flutter + posthog_flutter here.
  }

  /// Report a caught error. No-op until Sentry is configured.
  void captureError(Object error, StackTrace? stack, {String? hint}) {
    if (!errorsEnabled) {
      if (kDebugMode) debugPrint('[telemetry] error: $error${hint == null ? '' : ' ($hint)'}');
      return;
    }
    // TODO(observability): Sentry.captureException(error, stackTrace: stack).
  }

  /// Track a product event. No-op until PostHog is configured. Never pass PII in
  /// [properties]; the distinct id is the user's uuid, set by identify().
  void track(AppEvent event, {Map<String, Object?> properties = const {}}) {
    if (!analyticsEnabled) return;
    // TODO(observability): Posthog().capture(eventName: event.name, properties: properties).
  }

  /// Bind the current user (uuid) and clear it on sign-out. No-op until on.
  void identify(String? userId) {
    if (!analyticsEnabled) return;
    // TODO(observability): Posthog().identify(userId) / reset() when null.
  }
}
