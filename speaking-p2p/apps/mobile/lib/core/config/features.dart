// Launch switches (D-067). The app opens FREE for everyone to grow the user
// base: everything about subscriptions and the premium (Pro) simulated partner
// is hidden, not deleted. Each one comes back by building with
// --dart-define=FEATURE_SUBSCRIPTIONS=true / FEATURE_PREMIUM_PRACTICE=true.
// The server side stays as is: `app_config.assume_paid` (D-020) already gives
// every new user an active Standard plan, so nobody meets a paywall.
abstract final class Features {
  /// Subscription card, plans, «Upgrade to Pro», paywall.
  static const subscriptions = bool.fromEnvironment('FEATURE_SUBSCRIPTIONS');

  /// «Practise with a simulated premium (VIP) partner» on Home.
  static const premiumPractice = bool.fromEnvironment('FEATURE_PREMIUM_PRACTICE');
}
