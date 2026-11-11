import 'package:apexblocks/services/ads_service.dart';
import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/theme/themes.dart';
import 'package:apexblocks/ui/home_screen.dart';
import 'package:apexblocks/ui/setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  for (final size in phoneSizes) {
    testWidgets('fits $size', (tester) async {
      useScreen(tester, size);
      final storage = await makeStorage({'bestScore': 1234567});
      await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
      expect(tester.takeException(), isNull);
      final button = find.ancestor(
        of: find.text('LIGHTS OUT →'),
        matching: find.byType(FilledButton),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
    });
  }

  testWidgets('shows round, pole and livery progress', (tester) async {
    final storage = await makeStorage({
      'gamesPlayed': 6,
      'bestScore': 4821,
      'careerPoints': 3240,
    });
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    expect(find.text('ROUND 7 · NIGHT RACE'), findsOneWidget);
    expect(find.text('4,821'), findsOneWidget);
    expect(find.text('3,240 / 5,000 pts'), findsOneWidget);
    expect(find.text('3,240 / 15,000 pts'), findsOneWidget);
    expect(find.text('EQUIPPED'), findsOneWidget);
    expect(find.text('APEX'), findsOneWidget);
    expect(find.text('BLOCKS'), findsOneWidget);
    expect(find.text('ENDLESS BLOCK RACING'), findsOneWidget);
  });

  testWidgets('shows SETUP; CLEAN AIR waits for the purchase milestone', (
    tester,
  ) async {
    final storage = await makeStorage();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    expect(find.text('SETUP'), findsOneWidget);
    expect(find.textContaining('CLEAN AIR'), findsNothing);
  });

  testWidgets('tapping a locked livery explains; unlocked one equips', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage({'careerPoints': 5000});
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));

    await tester.tap(find.text('DESERT DUSK'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.text('Locked. Earn 15,000 career points (5,000 so far).'),
      findsOneWidget,
    );
    expect(find.textContaining('Watch ad'), findsNothing); // no ads here
    expect(storage.selectedLivery, 0);
    await tester.tapAt(const Offset(10, 10)); // dismiss the sheet
    await tester.pumpAndSettle();

    await tester.tap(find.text('RAIN RACE'));
    await tester.pump();
    expect(storage.selectedLivery, 1);
    expect(find.text('ROUND 1 · RAIN RACE'), findsOneWidget);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, rainRace.background);
  });

  testWidgets('Setup toggles persist and flip the service flags', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final audio = RecordingAudio();
    final haptics = RecordingHaptics();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, audio: audio, haptics: haptics),
      ),
    );
    await tester.tap(find.text('SETUP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sound'));
    await tester.tap(find.text('Haptics'));
    await tester.pumpAndSettle();
    expect(storage.soundOn, isFalse);
    expect(storage.hapticsOn, isFalse);
    expect(audio.enabled.value, isFalse);
    expect(haptics.enabled.value, isFalse);
    expect(find.text('Licenses'), findsOneWidget);
    expect(find.text(appVersion), findsOneWidget);
  });

  testWidgets('LIGHTS OUT starts a run; the Home screen refreshes after', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump(const Duration(seconds: 3)); // the start lights
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);

    await storage.recordRun(500);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text('ROUND 2 · NIGHT RACE'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
  });

  group('livery unlock by ads', () {
    const size = Size(375, 667);

    testWidgets('cards mention ads only while a livery ad is on offer', (
      tester,
    ) async {
      useScreen(tester, size);
      final storage = await makeStorage({'liveryAds_1': 1});
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage, ads: FakeAds()),
        ),
      );
      expect(find.text('1/3 ads watched'), findsOneWidget);
      expect(find.text('or watch 3 ads'), findsOneWidget);

      final off = await makeStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: UniqueKey(), // a new State, so it takes the new ads
            storage: off,
            ads: FakeAds(liveryReady: false),
          ),
        ),
      );
      expect(find.textContaining('watch'), findsNothing);
    });

    testWidgets('three rewarded ads unlock the livery, with the banner', (
      tester,
    ) async {
      useScreen(tester, size);
      final storage = await makeStorage();
      final ads = FakeAds();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage, ads: ads),
        ),
      );
      await tester.tap(find.text('DESERT DUSK'));
      await tester.pumpAndSettle();

      for (var n = 1; n <= 2; n++) {
        await tester.tap(find.text('Watch ad ($n/3)'));
        await tester.pumpAndSettle();
        expect(storage.liveryAdsWatched(2), n);
        expect(storage.isLiveryUnlockedNow(2), isFalse);
      }
      expect(storage.liveryAdsWatched(1), 0); // independent per livery

      await tester.tap(find.text('Watch ad (3/3)'));
      await tester.pumpAndSettle();
      expect(ads.rewardedShown, everyElement(RewardedPlacement.liveryUnlock));
      expect(storage.isLiveryUnlockedNow(2), isTrue);
      expect(find.text('LIVERY UNLOCKED · DESERT DUSK'), findsOneWidget);

      await tester.tap(find.text('Equip'));
      await tester.pumpAndSettle();
      expect(storage.selectedLivery, 2);
    });

    testWidgets('an ad closed without the reward counts for nothing', (
      tester,
    ) async {
      useScreen(tester, size);
      final storage = await makeStorage();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage, ads: FakeAds(rewardEarned: false)),
        ),
      );
      await tester.tap(find.text('RAIN RACE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Watch ad (1/3)'));
      await tester.pumpAndSettle();
      expect(storage.liveryAdsWatched(1), 0);
    });
  });
}
