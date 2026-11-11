import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/unlocks.dart';
import '../theme/themes.dart';
import 'ad_rules.dart';

const String _bestScoreKey = 'bestScore';
const String _careerPointsKey = 'careerPoints';
const String _gamesPlayedKey = 'gamesPlayed';
const String _launchCountKey = 'launchCount';
const String _selectedLiveryKey = 'selectedLivery';
const String _soundOnKey = 'soundOn';
const String _hapticsOnKey = 'hapticsOn';
const String _adsRemovedKey = 'adsRemoved';
const String _interstitialCounterKey = 'gameOversSinceInterstitial';
const String _liveryAdsKeyPrefix = 'liveryAds_';

/// What [StorageService.recordRun] changed.
typedef RunRecord = ({int previousBest, bool isNewBest});

/// Persistent player data. Reads are synchronous (values are cached from
/// [SharedPreferences]); listeners are notified after every write.
class StorageService extends ChangeNotifier {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  /// Opens the service on [prefs], or on the app's shared preferences.
  static Future<StorageService> open([SharedPreferences? prefs]) async =>
      StorageService(prefs ?? await SharedPreferences.getInstance());

  int get bestScore => _prefs.getInt(_bestScoreKey) ?? 0;

  /// Sum of the final scores of every finished run.
  int get careerPoints => _prefs.getInt(_careerPointsKey) ?? 0;

  int get gamesPlayed => _prefs.getInt(_gamesPlayedKey) ?? 0;

  /// How many times the app has been launched (see [incrementLaunchCount]).
  int get launchCount => _prefs.getInt(_launchCountKey) ?? 0;

  /// The first session is launch #1 only.
  bool get isFirstSession => launchCount <= 1;

  /// Remove Ads was bought: no interstitials, every livery unlocked.
  bool get adsRemoved => _prefs.getBool(_adsRemovedKey) ?? false;

  /// Game overs since the last interstitial was shown; first-session game
  /// overs are not counted.
  int get gameOversSinceInterstitial =>
      _prefs.getInt(_interstitialCounterKey) ?? 0;

  /// Score of a run that ended but is not booked yet (the Chequered flag is
  /// up and a Pit Stop could still continue it). In memory only. Unlock
  /// checks count it, so a livery the run earned can be equipped at once.
  int _pendingCareerPoints = 0;
  int get pendingCareerPoints => _pendingCareerPoints;

  /// Rewarded ads watched toward [livery]'s unlock.
  int liveryAdsWatched(int livery) =>
      _prefs.getInt('$_liveryAdsKeyPrefix$livery') ?? 0;

  /// Whether [livery] is unlocked, by career points or by rewarded ads.
  bool isLiveryUnlockedNow(int livery) => isLiveryUnlockedWith(
    livery: livery,
    careerPoints: careerPoints + _pendingCareerPoints,
    adsWatched: liveryAdsWatched(livery),
    adsRemoved: adsRemoved,
  );

  /// Index of the equipped livery; Night Race if the saved one is locked.
  int get selectedLivery {
    final saved = _prefs.getInt(_selectedLiveryKey) ?? defaultLivery;
    return isLiveryUnlockedNow(saved) ? saved : defaultLivery;
  }

  /// The equipped livery's colors.
  ApexTheme get theme => allLiveries[selectedLivery];

  bool get soundOn => _prefs.getBool(_soundOnKey) ?? true;

  bool get hapticsOn => _prefs.getBool(_hapticsOnKey) ?? true;

  /// Equips [livery] if it is unlocked; returns whether it was.
  Future<bool> selectLivery(int livery) async {
    if (!isLiveryUnlockedNow(livery)) return false;
    await _prefs.setInt(_selectedLiveryKey, livery);
    notifyListeners();
    return true;
  }

  Future<void> setSoundOn(bool value) async {
    await _prefs.setBool(_soundOnKey, value);
    notifyListeners();
  }

  Future<void> setHapticsOn(bool value) async {
    await _prefs.setBool(_hapticsOnKey, value);
    notifyListeners();
  }

  /// Idempotent: setting the current value again writes and notifies nothing.
  Future<void> setAdsRemoved(bool value) async {
    if (value == adsRemoved) return;
    await _prefs.setBool(_adsRemovedKey, value);
    notifyListeners();
  }

  /// Counts an app launch. Call once at startup.
  Future<void> incrementLaunchCount() async {
    await _prefs.setInt(_launchCountKey, launchCount + 1);
    notifyListeners();
  }

  /// Records one rewarded ad watched toward [livery]; returns the new count.
  Future<int> recordLiveryAdWatched(int livery) async {
    final watched = liveryAdsWatched(livery) + 1;
    await _prefs.setInt('$_liveryAdsKeyPrefix$livery', watched);
    notifyListeners();
    return watched;
  }

  /// Call after an interstitial was shown.
  Future<void> resetInterstitialCounter() async {
    await _prefs.setInt(_interstitialCounterKey, 0);
    notifyListeners();
  }

  /// Sets the score of a finished but unbooked run (see
  /// [pendingCareerPoints]).
  void setPendingRunScore(int score) {
    _pendingCareerPoints = score;
    notifyListeners();
  }

  /// Debug-build testing aid: adds [points] career points.
  Future<void> debugAddCareerPoints(int points) async {
    assert(kDebugMode);
    if (!kDebugMode) return;
    await _prefs.setInt(_careerPointsKey, careerPoints + points);
    notifyListeners();
  }

  /// Debug-build testing aid: forgets the Remove Ads purchase locally. The
  /// store still owns it, so Restore Purchases brings it back.
  Future<void> debugResetPurchase() async {
    assert(kDebugMode);
    if (!kDebugMode) return;
    await _prefs.setBool(_adsRemovedKey, false);
    notifyListeners();
  }

  /// Debug-build testing aid: wipes every saved value (scores, liveries,
  /// settings, purchase flag, counters) for a clean first run.
  Future<void> debugResetAllProgress() async {
    assert(kDebugMode);
    if (!kDebugMode) return;
    _pendingCareerPoints = 0;
    await _prefs.clear();
    notifyListeners();
  }

  /// Books a finished run: raises the best score if beaten, adds [score] to
  /// career points and counts the game. Call once per run, when the run truly
  /// ends (not while a Pit Stop could still continue it).
  Future<RunRecord> recordRun(int score) async {
    final previousBest = bestScore;
    final isNewBest = score > previousBest;
    _pendingCareerPoints = 0;
    await Future.wait([
      _prefs.setInt(_bestScoreKey, math.max(previousBest, score)),
      _prefs.setInt(_careerPointsKey, careerPoints + score),
      _prefs.setInt(_gamesPlayedKey, gamesPlayed + 1),
      if (!isFirstSession)
        _prefs.setInt(_interstitialCounterKey, gameOversSinceInterstitial + 1),
    ]);
    notifyListeners();
    return (previousBest: previousBest, isNewBest: isNewBest);
  }
}
