import 'package:flutter/foundation.dart';

/// Build with `--dart-define=REAL_ADS=true` to use the real ad unit IDs.
/// Every other build (debug, profile, release, TestFlight) uses Google's
/// official test IDs, so a stray build can never serve or click real ads.
const bool realAdsRequested = bool.fromEnvironment('REAL_ADS');

/// Marks a real ID that has not been filled in yet.
const String _placeholder = 'XXXX';

/// Ad unit IDs, one per placement so AdMob reports each separately.
class AdUnitIds {
  /// Rewarded "Pit Stop" continue at the Chequered flag.
  final String pitStop;

  /// Rewarded ad that counts toward a livery unlock.
  final String liveryUnlock;

  /// Interstitial between races.
  final String betweenRaces;

  const AdUnitIds({
    required this.pitStop,
    required this.liveryUnlock,
    required this.betweenRaces,
  });

  bool get hasPlaceholder => [
    pitStop,
    liveryUnlock,
    betweenRaces,
  ].any((id) => id.contains(_placeholder));
}

// Google's official demo IDs: https://developers.google.com/admob/flutter/test-ads
const String testAppIdIos = 'ca-app-pub-3940256099942544~1458002511';
const String testAppIdAndroid = 'ca-app-pub-3940256099942544~3347511713';

const AdUnitIds _testIos = AdUnitIds(
  pitStop: 'ca-app-pub-3940256099942544/1712485313',
  liveryUnlock: 'ca-app-pub-3940256099942544/1712485313',
  betweenRaces: 'ca-app-pub-3940256099942544/4411468910',
);

const AdUnitIds _testAndroid = AdUnitIds(
  pitStop: 'ca-app-pub-3940256099942544/5224354917',
  liveryUnlock: 'ca-app-pub-3940256099942544/5224354917',
  betweenRaces: 'ca-app-pub-3940256099942544/1033173712',
);

// TODO(release): replace with the real ad unit IDs from the AdMob console
// (see RELEASE.md). The app IDs live in Info.plist and AndroidManifest.xml.
const AdUnitIds _realIos = AdUnitIds(
  pitStop: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  liveryUnlock: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  betweenRaces: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
);

const AdUnitIds _realAndroid = AdUnitIds(
  pitStop: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  liveryUnlock: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  betweenRaces: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
);

/// Which ad IDs this build uses.
class AdConfig {
  /// True when the real IDs were requested with REAL_ADS.
  final bool realAds;
  final AdUnitIds ids;

  const AdConfig._(this.realAds, this.ids);

  /// Real IDs that are still placeholders are never requested: ads stay off.
  bool get usable => !ids.hasPlaceholder;

  String get modeLabel => realAds ? 'REAL ads' : 'TEST ads';

  static AdConfig forMode({required bool realAds, required bool isIOS}) {
    if (!realAds) return AdConfig._(false, isIOS ? _testIos : _testAndroid);
    return AdConfig._(true, isIOS ? _realIos : _realAndroid);
  }

  static AdConfig get current => forMode(
    realAds: realAdsRequested,
    isIOS: defaultTargetPlatform == TargetPlatform.iOS,
  );
}
