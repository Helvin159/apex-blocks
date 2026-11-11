import 'package:apexblocks/services/storage_service.dart';
import 'package:apexblocks/theme/themes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<StorageService> open([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return StorageService.open(await SharedPreferences.getInstance());
}

void main() {
  test('defaults on first launch', () async {
    final s = await open();
    expect(s.bestScore, 0);
    expect(s.careerPoints, 0);
    expect(s.gamesPlayed, 0);
    expect(s.isFirstSession, isTrue);
    expect(s.launchCount, 0);
    expect(s.adsRemoved, isFalse);
    expect(s.gameOversSinceInterstitial, 0);
    expect(s.liveryAdsWatched(1), 0);
  });

  test('every field survives a relaunch', () async {
    final s = await open();
    await s.recordRun(120);
    await s.recordRun(80);
    await s.incrementLaunchCount();
    await s.incrementLaunchCount();

    // A new service on the same preferences, like a fresh app start.
    final again = StorageService.open(await SharedPreferences.getInstance());
    final r = await again;
    expect(r.bestScore, 120);
    expect(r.careerPoints, 200);
    expect(r.gamesPlayed, 2);
    expect(r.launchCount, 2);
    expect(r.isFirstSession, isFalse);
  });

  test('best score only increases', () async {
    final s = await open();
    await s.recordRun(300);
    await s.recordRun(50);
    expect(s.bestScore, 300);
    await s.recordRun(301);
    expect(s.bestScore, 301);
  });

  test(
    'recordRun reports the previous best and whether it was beaten',
    () async {
      final s = await open();
      expect(await s.recordRun(100), (previousBest: 0, isNewBest: true));
      expect(await s.recordRun(60), (previousBest: 100, isNewBest: false));
      expect(await s.recordRun(100), (previousBest: 100, isNewBest: false));
      expect(await s.recordRun(101), (previousBest: 100, isNewBest: true));
    },
  );

  test('career points add up every run, games played counts them', () async {
    final s = await open({'careerPoints': 1000, 'gamesPlayed': 4});
    await s.recordRun(25);
    expect(s.careerPoints, 1025);
    expect(s.gamesPlayed, 5);
  });

  test('notifies listeners once per run', () async {
    final s = await open();
    var calls = 0;
    s.addListener(() => calls++);
    await s.recordRun(10);
    expect(calls, 1);
  });

  test(
    'livery and toggles default to Night Race, sound on, haptics on',
    () async {
      final s = await open();
      expect(s.selectedLivery, 0);
      expect(s.theme, nightRace);
      expect(s.soundOn, isTrue);
      expect(s.hapticsOn, isTrue);
    },
  );

  test('livery and toggles survive a relaunch', () async {
    final s = await open({'careerPoints': 20000});
    expect(await s.selectLivery(2), isTrue);
    await s.setSoundOn(false);
    await s.setHapticsOn(false);
    final r = await StorageService.open(await SharedPreferences.getInstance());
    expect(r.selectedLivery, 2);
    expect(r.theme, desertDusk);
    expect(r.soundOn, isFalse);
    expect(r.hapticsOn, isFalse);
  });

  test('a locked livery cannot be equipped or loaded', () async {
    final s = await open({'careerPoints': 100});
    expect(await s.selectLivery(1), isFalse);
    expect(s.selectedLivery, 0);
    final saved = await open({'careerPoints': 100, 'selectedLivery': 2});
    expect(saved.selectedLivery, 0);
  });

  test('the first session is launch #1 only', () async {
    final s = await open();
    await s.incrementLaunchCount();
    expect(s.isFirstSession, isTrue);
    await s.incrementLaunchCount();
    expect(s.isFirstSession, isFalse);
  });

  test('livery ad progress: 1/3, 2/3, unlock on 3/3, per livery', () async {
    final s = await open();
    expect(s.isLiveryUnlockedNow(1), isFalse);
    expect(await s.recordLiveryAdWatched(1), 1);
    expect(await s.recordLiveryAdWatched(1), 2);
    expect(s.isLiveryUnlockedNow(1), isFalse);
    expect(await s.recordLiveryAdWatched(1), 3);
    expect(s.isLiveryUnlockedNow(1), isTrue);
    expect(s.liveryAdsWatched(2), 0);
    expect(s.isLiveryUnlockedNow(2), isFalse); // independent per livery
    expect(await s.selectLivery(1), isTrue);
  });

  test('livery ad progress survives a relaunch', () async {
    final s = await open();
    await s.recordLiveryAdWatched(2);
    await s.recordLiveryAdWatched(2);
    final r = await StorageService.open(await SharedPreferences.getInstance());
    expect(r.liveryAdsWatched(2), 2);
    await r.recordLiveryAdWatched(2);
    expect(r.isLiveryUnlockedNow(2), isTrue);
  });

  test('interstitial counter: first-session runs do not count', () async {
    final s = await open({'launchCount': 1});
    await s.recordRun(10);
    expect(s.gameOversSinceInterstitial, 0);

    final later = await open({'launchCount': 2});
    await later.recordRun(10);
    await later.recordRun(10);
    expect(later.gameOversSinceInterstitial, 2);
    await later.resetInterstitialCounter();
    expect(later.gameOversSinceInterstitial, 0);
  });

  test('Remove Ads unlocks both liveries, and they can be equipped', () async {
    final s = await open();
    expect(s.isLiveryUnlockedNow(1), isFalse);
    expect(s.isLiveryUnlockedNow(2), isFalse);
    await s.setAdsRemoved(true);
    expect(s.isLiveryUnlockedNow(1), isTrue);
    expect(s.isLiveryUnlockedNow(2), isTrue);
    expect(await s.selectLivery(2), isTrue);
    expect(s.selectedLivery, 2);
  });

  test(
    'setAdsRemoved is idempotent: no repeat write or notification',
    () async {
      final s = await open();
      var notifications = 0;
      s.addListener(() => notifications++);
      await s.setAdsRemoved(true);
      await s.setAdsRemoved(true);
      expect(notifications, 1);
      await s.setAdsRemoved(false);
      expect(notifications, 2);
      expect(s.adsRemoved, isFalse);
    },
  );

  test('debug reset purchase clears only the purchase', () async {
    final s = await open({'adsRemoved': true, 'bestScore': 900});
    await s.debugResetPurchase();
    expect(s.adsRemoved, isFalse);
    expect(s.bestScore, 900);
    expect(s.isLiveryUnlockedNow(1), isFalse);
  });

  test('debug reset all progress wipes everything', () async {
    final s = await open({
      'adsRemoved': true,
      'bestScore': 900,
      'careerPoints': 6000,
      'selectedLivery': 1,
      'soundOn': false,
      'launchCount': 5,
      'liveryAds_2': 2,
    });
    s.setPendingRunScore(300);
    await s.debugResetAllProgress();
    expect(s.adsRemoved, isFalse);
    expect(s.bestScore, 0);
    expect(s.careerPoints, 0);
    expect(s.pendingCareerPoints, 0);
    expect(s.selectedLivery, 0);
    expect(s.soundOn, isTrue);
    expect(s.launchCount, 0);
    expect(s.liveryAdsWatched(2), 0);
  });

  test('adsRemoved persists', () async {
    final s = await open();
    await s.setAdsRemoved(true);
    final r = await StorageService.open(await SharedPreferences.getInstance());
    expect(r.adsRemoved, isTrue);
  });

  test(
    'a pending run score unlocks a livery until the run is booked',
    () async {
      final s = await open({'careerPoints': 4900});
      expect(await s.selectLivery(1), isFalse);
      s.setPendingRunScore(150);
      expect(await s.selectLivery(1), isTrue);
      expect(s.selectedLivery, 1);
      expect(s.careerPoints, 4900); // not booked yet
      await s.recordRun(150);
      expect(s.pendingCareerPoints, 0);
      expect(s.careerPoints, 5050);
      expect(s.selectedLivery, 1);
    },
  );

  test('an abandoned pending score no longer unlocks anything', () async {
    final s = await open({'careerPoints': 4900});
    s.setPendingRunScore(150);
    await s.selectLivery(1);
    s.setPendingRunScore(0);
    expect(s.selectedLivery, 0);
  });
}
