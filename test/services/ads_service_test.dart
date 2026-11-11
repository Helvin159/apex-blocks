import 'package:apexblocks/config/ad_config.dart';
import 'package:apexblocks/services/ad_rules.dart';
import 'package:apexblocks/services/ads_service.dart';
import 'package:apexblocks/services/audio_service.dart';
import 'package:apexblocks/services/consent_service.dart';
import 'package:apexblocks/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consent_service_test.dart' show FakeGateway;

class FakeAd implements LoadedAd {
  final AudioService audio;
  bool earned;
  bool? mutedWhileShowing;
  int shown = 0;
  bool disposed = false;

  FakeAd(this.audio, {this.earned = true});

  @override
  Future<bool> show() async {
    shown++;
    mutedWhileShowing = audio.muted;
    return earned;
  }

  @override
  void dispose() => disposed = true;
}

class Rig {
  final StorageService storage;
  final AudioService audio = AudioService.silent();
  final FakeGateway gateway = FakeGateway();
  final List<FakeAd> rewardedAds = [];
  final List<FakeAd> interstitialAds = [];
  int rewardedLoads = 0;
  int interstitialLoads = 0;
  int inits = 0;
  bool loadsFail = false;
  bool adEarns = true;
  DateTime clock = DateTime(2026, 1, 1, 12);
  late final AdsService ads;

  Rig(this.storage, {AdConfig? config}) {
    ads = AdsService(
      config: config ?? AdConfig.forMode(realAds: false, isIOS: true),
      storage: storage,
      audio: audio,
      consent: ConsentService(gateway),
      rewardedLoader: (_) async {
        rewardedLoads++;
        if (loadsFail) return null;
        final ad = FakeAd(audio, earned: adEarns);
        rewardedAds.add(ad);
        return ad;
      },
      interstitialLoader: (_) async {
        interstitialLoads++;
        if (loadsFail) return null;
        final ad = FakeAd(audio);
        interstitialAds.add(ad);
        return ad;
      },
      initializer: () async => inits++,
      now: () => clock,
    );
    addTearDown(ads.dispose);
  }
}

Future<Rig> rig([
  Map<String, Object> prefs = const {},
  AdConfig? config,
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open(
    await SharedPreferences.getInstance(),
  );
  return Rig(storage, config: config);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('startup', () {
    test('no consent: nothing is initialized, loaded or offered', () async {
      final r = await rig();
      r.gateway.canRequest = false;
      await r.ads.start();
      await settle();
      expect(r.inits, 0);
      expect(r.rewardedLoads + r.interstitialLoads, 0);
      expect(r.ads.adsAllowed, isFalse);
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isFalse);
      expect(
        r.ads.isRewardedAvailable(RewardedPlacement.liveryUnlock),
        isFalse,
      );
      expect(await r.ads.showRewarded(RewardedPlacement.pitStop), isFalse);
    });

    test('with consent: initializes, then preloads all three units', () async {
      final r = await rig();
      await r.ads.start();
      await settle();
      expect(r.inits, 1);
      expect(r.rewardedLoads, 2); // Pit Stop and livery unlock
      expect(r.interstitialLoads, 1);
      expect(r.ads.adsAllowed, isTrue);
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isTrue);
      expect(r.ads.isRewardedReady(RewardedPlacement.liveryUnlock), isTrue);
    });

    test('Remove Ads: no interstitial is loaded, rewarded stay', () async {
      final r = await rig({'adsRemoved': true});
      await r.ads.start();
      await settle();
      expect(r.interstitialLoads, 0);
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isTrue);
    });

    test('real IDs still placeholders: ads stay off', () async {
      final r = await rig(
        const {},
        AdConfig.forMode(realAds: true, isIOS: true),
      );
      await r.ads.start();
      await settle();
      expect(r.inits, 0);
      expect(r.gateway.calls, isEmpty); // not even the consent flow
      expect(r.ads.adsAllowed, isFalse);
    });

    test('a failed load is not offered; refresh tries again', () async {
      final r = await rig();
      r.loadsFail = true;
      await r.ads.start();
      await settle();
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isFalse);
      expect(r.ads.isRewardedAvailable(RewardedPlacement.pitStop), isFalse);
      r.loadsFail = false;
      r.ads.refresh();
      await settle();
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isTrue);
    });

    test('the disabled service offers and shows nothing', () async {
      final ads = AdsService.disabled();
      await ads.start();
      expect(ads.adsAllowed, isFalse);
      expect(await ads.showRewarded(RewardedPlacement.pitStop), isFalse);
      await ads.showInterstitialIfDue(afterPitStop: false);
    });
  });

  group('rewarded', () {
    test('the reward is reported only when it was earned', () async {
      final r = await rig();
      await r.ads.start();
      await settle();
      r.rewardedAds.first.earned = false; // closed early, no reward
      expect(await r.ads.showRewarded(RewardedPlacement.pitStop), isFalse);

      expect(await r.ads.showRewarded(RewardedPlacement.liveryUnlock), isTrue);
    });

    test('audio is muted while it shows and restored after', () async {
      final r = await rig();
      await r.ads.start();
      await settle();
      final ad = r.rewardedAds.first;
      expect(r.audio.muted, isFalse);
      await r.ads.showRewarded(RewardedPlacement.pitStop);
      expect(ad.mutedWhileShowing, isTrue);
      expect(r.audio.muted, isFalse);
    });

    test('it is disposed and a new one is loaded after use', () async {
      final r = await rig();
      await r.ads.start();
      await settle();
      final loadsBefore = r.rewardedLoads;
      final ad = r.rewardedAds.first;
      await r.ads.showRewarded(RewardedPlacement.pitStop);
      await settle();
      expect(ad.disposed, isTrue);
      expect(r.rewardedLoads, loadsBefore + 1);
      expect(r.ads.isRewardedReady(RewardedPlacement.pitStop), isTrue);
    });

    test('with no ad loaded nothing shows', () async {
      final r = await rig();
      r.loadsFail = true;
      await r.ads.start();
      await settle();
      expect(await r.ads.showRewarded(RewardedPlacement.pitStop), isFalse);
    });
  });

  group('interstitial', () {
    Future<Rig> due({int games = 3, bool first = false}) async {
      final r = await rig({
        'launchCount': first ? 1 : 2,
        'gameOversSinceInterstitial': games,
      });
      await r.ads.start();
      await settle();
      return r;
    }

    test('shows when due, mutes audio, resets the counter', () async {
      final r = await due();
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      final ad = r.interstitialAds.first;
      expect(ad.shown, 1);
      expect(ad.mutedWhileShowing, isTrue);
      expect(r.audio.muted, isFalse);
      expect(r.storage.gameOversSinceInterstitial, 0);
    });

    test('not before the 3rd game over', () async {
      final r = await due(games: 2);
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.interstitialAds.first.shown, 0);
      expect(r.storage.gameOversSinceInterstitial, 2);
    });

    test('never right after a Pit Stop, and it stays due', () async {
      final r = await due();
      await r.ads.showInterstitialIfDue(afterPitStop: true);
      expect(r.interstitialAds.first.shown, 0);
      expect(r.storage.gameOversSinceInterstitial, 3);
    });

    test('never in the first session', () async {
      final r = await due(first: true);
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.interstitialAds.first.shown, 0);
    });

    test('never when ads are removed', () async {
      final r = await rig({
        'launchCount': 2,
        'gameOversSinceInterstitial': 3,
        'adsRemoved': true,
      });
      await r.ads.start();
      await settle();
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.interstitialAds, isEmpty);
    });

    test('at least 90 s apart', () async {
      final r = await due();
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      await settle();
      await r.storage.recordRun(1);
      await r.storage.recordRun(1);
      await r.storage.recordRun(1); // 3 game overs again

      r.clock = r.clock.add(const Duration(milliseconds: 89999));
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.interstitialAds[1].shown, 0); // too soon

      r.clock = r.clock.add(const Duration(milliseconds: 1));
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.interstitialAds[1].shown, 1);
    });

    test('no ad loaded: skipped without error, counter kept', () async {
      final r = await rig({'launchCount': 2, 'gameOversSinceInterstitial': 3});
      r.loadsFail = true;
      await r.ads.start();
      await settle();
      await r.ads.showInterstitialIfDue(afterPitStop: false);
      expect(r.storage.gameOversSinceInterstitial, 3);
    });

    test('interstitial constants match the spec', () {
      expect(interstitialEvery, 3);
      expect(interstitialMinGapMs, 90000);
    });
  });
}
