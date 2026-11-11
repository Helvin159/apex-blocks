import 'package:apexblocks/config/ad_config.dart';
import 'package:flutter_test/flutter_test.dart';

const _googleTestPrefix = 'ca-app-pub-3940256099942544';

void main() {
  test('this test build asks for test ads unless REAL_ADS is set', () {
    expect(realAdsRequested, isFalse);
    final config = AdConfig.current;
    expect(config.realAds, isFalse);
    expect(config.modeLabel, 'TEST ads');
    expect(config.usable, isTrue);
    for (final id in [
      config.ids.pitStop,
      config.ids.liveryUnlock,
      config.ids.betweenRaces,
    ]) {
      expect(id, startsWith(_googleTestPrefix));
    }
  });

  for (final isIOS in [true, false]) {
    test('without REAL_ADS only Google test IDs, isIOS=$isIOS', () {
      final config = AdConfig.forMode(realAds: false, isIOS: isIOS);
      expect(config.realAds, isFalse);
      expect(config.usable, isTrue);
      expect(config.ids.pitStop, startsWith(_googleTestPrefix));
      expect(config.ids.liveryUnlock, startsWith(_googleTestPrefix));
      expect(config.ids.betweenRaces, startsWith(_googleTestPrefix));
      // A rewarded unit is never used as the interstitial.
      expect(config.ids.betweenRaces, isNot(config.ids.pitStop));
    });

    test('with REAL_ADS unfilled placeholders keep ads off, isIOS=$isIOS', () {
      final config = AdConfig.forMode(realAds: true, isIOS: isIOS);
      expect(config.realAds, isTrue);
      expect(config.modeLabel, 'REAL ads');
      expect(config.ids.pitStop, isNot(startsWith(_googleTestPrefix)));
      expect(config.usable, isFalse);
    });
  }

  test('test app IDs are Google demo IDs', () {
    expect(testAppIdIos, startsWith(_googleTestPrefix));
    expect(testAppIdAndroid, startsWith(_googleTestPrefix));
  });
}
