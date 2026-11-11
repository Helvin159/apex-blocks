// Ad rules. Pure Dart (no Flutter or plugin imports), so they are unit-tested
// without ads.

import '../game/unlocks.dart';

/// An interstitial is due every this many game overs.
const int interstitialEvery = 3;

/// Minimum time between two interstitials.
const int interstitialMinGapMs = 90000;

/// Rewarded ads that unlock a livery.
const int liveryAdsRequired = 3;

/// Whether to show an interstitial now, on leaving the Chequered flag.
///
/// [gameOversSinceLast] counts game overs since the last interstitial was
/// shown. It is compared with `>=`, so a slot skipped for any reason (no ad
/// loaded, too soon) is due again at the next opportunity. [msSinceLast] is
/// null when none was shown yet in this process.
bool shouldShowInterstitial({
  required int gameOversSinceLast,
  required int? msSinceLast,
  required bool isFirstSession,
  required bool adsRemoved,
}) {
  if (adsRemoved || isFirstSession) return false;
  if (gameOversSinceLast < interstitialEvery) return false;
  return msSinceLast == null || msSinceLast >= interstitialMinGapMs;
}

/// Whether the Chequered flag offers the Pit Stop (rewarded continue).
bool isPitStopEligible({
  required bool usedThisRun,
  required bool adLoaded,
  required bool adsAllowed,
  required bool runRecorded,
}) => !usedThisRun && !runRecorded && adLoaded && adsAllowed;

/// A livery is unlocked by career points, by [liveryAdsRequired] rewarded
/// ads, or instantly for every livery with Remove Ads ([adsRemoved]).
bool isLiveryUnlockedWith({
  required int livery,
  required int careerPoints,
  required int adsWatched,
  bool adsRemoved = false,
}) =>
    (adsRemoved && livery >= 0 && livery < liveryUnlockPoints.length) ||
    isLiveryUnlocked(livery, careerPoints) ||
    (livery > defaultLivery &&
        livery < liveryUnlockPoints.length &&
        adsWatched >= liveryAdsRequired);
