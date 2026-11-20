import 'package:flutter_test/flutter_test.dart';
import 'package:speaking_p2p/core/telemetry/telemetry.dart';

void main() {
  test('los eventos de la app salen en snake_case, como los del servidor', () {
    expect(AppEvent.textToggleUsed.wireName, 'text_toggle_used');
    expect(AppEvent.matchmakingPromptAccepted.wireName, 'matchmaking_prompt_accepted');
    expect(AppEvent.paywallViewed.wireName, 'paywall_viewed');
    expect(AppEvent.appOpenAdShown.wireName, 'app_open_ad_shown');
  });

  test('sin claves todo es no-op y nunca lanza', () async {
    final t = Telemetry.instance;
    expect(t.errorsEnabled, isFalse);
    expect(t.analyticsEnabled, isFalse);
    await t.init();
    t.track(AppEvent.timerToggleUsed, properties: {'visible': false});
    t.identify('00000000-0000-0000-0000-000000000001');
    t.identify(null);
    t.captureError(StateError('x'), StackTrace.current, hint: 'test');
  });
}
