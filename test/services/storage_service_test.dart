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
    expect(s.firstSession, isTrue);
  });

  test('every field survives a relaunch', () async {
    final s = await open();
    await s.recordRun(120);
    await s.recordRun(80);
    await s.endFirstSession();

    // A new service on the same preferences, like a fresh app start.
    final again = StorageService.open(await SharedPreferences.getInstance());
    final r = await again;
    expect(r.bestScore, 120);
    expect(r.careerPoints, 200);
    expect(r.gamesPlayed, 2);
    expect(r.firstSession, isFalse);
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
}
