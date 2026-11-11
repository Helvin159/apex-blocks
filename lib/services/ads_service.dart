import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';
import 'ad_rules.dart';
import 'audio_service.dart';
import 'consent_service.dart';
import 'storage_service.dart';

// Ad policy for this app: no banners, no ads near tappable game controls,
// nothing mid-run, never auto-click, and never reward a click. Interstitials
// show only when leaving the Chequered flag; rewarded ads only on request.

/// The two rewarded placements. Each has its own ad unit so AdMob reports
/// demand for each separately.
enum RewardedPlacement { pitStop, liveryUnlock }

/// Delay before the first reload attempt after a failed load; doubles each
/// time up to [adRetryMaxMs].
const int adRetryBaseMs = 5000;
const int adRetryMaxMs = 60000;

/// Failed loads in a row before retrying stops (until [AdsService.refresh]).
const int adMaxRetries = 5;

/// A loaded full-screen ad.
abstract class LoadedAd {
  /// Shows the ad and completes when it closes. For a rewarded ad the result
  /// is true only if the user earned the reward; the reward is decided in
  /// `onUserEarnedReward`, never by the ad merely closing.
  Future<bool> show();

  void dispose();
}

/// Loads an ad for a unit ID; null if it failed.
typedef AdLoader = Future<LoadedAd?> Function(String unitId);

class _Slot {
  final String unitId;
  final AdLoader loader;
  LoadedAd? ad;
  bool loading = false;
  int failures = 0;
  Timer? retry;

  _Slot(this.unitId, this.loader);
}

/// Consent-gated rewarded and interstitial ads. [AdsService.disabled] never
/// loads or shows anything and is the default for tests.
class AdsService extends ChangeNotifier {
  final AdConfig? _config;
  final StorageService? _storage;
  final AudioService? _audio;
  final DateTime Function() _now;
  final Future<void> Function() _initSdk;

  /// UMP consent; the Setup sheet reads its privacy options entry point.
  final ConsentService consent;

  final Map<RewardedPlacement, _Slot> _rewarded = {};
  _Slot? _interstitial;
  bool _initialized = false;
  bool _showing = false;
  DateTime? _lastInterstitial;

  AdsService({
    required AdConfig this._config,
    required StorageService this._storage,
    required AudioService this._audio,
    ConsentService? consent,
    AdLoader? rewardedLoader,
    AdLoader? interstitialLoader,
    Future<void> Function()? initializer,
    DateTime Function()? now,
  }) : consent = consent ?? ConsentService(),
       _now = now ?? DateTime.now,
       _initSdk = initializer ?? _initMobileAds {
    final rewardedLoad = rewardedLoader ?? _loadGoogleRewarded;
    final ids = _config!.ids;
    _rewarded[RewardedPlacement.pitStop] = _Slot(ids.pitStop, rewardedLoad);
    _rewarded[RewardedPlacement.liveryUnlock] = _Slot(
      ids.liveryUnlock,
      rewardedLoad,
    );
    _interstitial = _Slot(
      ids.betweenRaces,
      interstitialLoader ?? _loadGoogleInterstitial,
    );
  }

  AdsService.disabled()
    : _config = null,
      _storage = null,
      _audio = null,
      consent = ConsentService(_NoConsentGateway()),
      _now = DateTime.now,
      _initSdk = _initMobileAds;

  static Future<void> _initMobileAds() => MobileAds.instance.initialize();

  bool get _enabled => _config != null && _config.usable;

  /// Ads may be requested: consent given, SDK initialized, config usable.
  bool get adsAllowed =>
      _enabled && _initialized && consent.canRequestAds.value;

  bool get _adsRemoved => _storage?.adsRemoved ?? false;

  /// Runs the consent flow, then initializes the SDK and preloads the three
  /// units, but only if UMP allows ad requests. Never throws.
  Future<void> start() async {
    final config = _config;
    if (config == null) return;
    if (kDebugMode) debugPrint('Ads: ${config.modeLabel}');
    if (!config.usable) {
      debugPrint('Ads: real IDs are still placeholders, ads stay off');
      return;
    }
    try {
      await consent.gatherConsent();
      if (!consent.canRequestAds.value) return;
      await _initSdk();
      _initialized = true;
      consent.canRequestAds.addListener(notifyListeners);
      refresh();
      notifyListeners();
    } catch (e, st) {
      debugPrint('Ads start failed: $e\n$st');
    }
  }

  /// Starts loading any unit that has no ad and is not loading.
  void refresh() {
    if (!adsAllowed) return;
    for (final slot in _rewarded.values) {
      slot.failures = 0;
      _load(slot);
    }
    final interstitial = _interstitial!;
    interstitial.failures = 0;
    if (!_adsRemoved) _load(interstitial);
  }

  void _load(_Slot slot) {
    if (!adsAllowed || slot.ad != null || slot.loading) return;
    slot.retry?.cancel();
    slot.loading = true;
    notifyListeners();
    _finishLoad(slot);
  }

  Future<void> _finishLoad(_Slot slot) async {
    LoadedAd? ad;
    try {
      ad = await slot.loader(slot.unitId);
    } catch (e) {
      debugPrint('Ad load threw: $e');
    }
    slot.loading = false;
    if (ad == null) {
      slot.failures++;
      if (slot.failures <= adMaxRetries) {
        final delay = math.min(
          adRetryBaseMs * (1 << (slot.failures - 1)),
          adRetryMaxMs,
        );
        slot.retry = Timer(Duration(milliseconds: delay), () => _load(slot));
      }
    } else {
      slot.failures = 0;
      slot.ad = ad;
    }
    notifyListeners();
  }

  /// A loaded rewarded ad is ready to show.
  bool isRewardedReady(RewardedPlacement placement) =>
      adsAllowed && _rewarded[placement]?.ad != null;

  /// Ready, or loading for the first time: used to decide whether to mention
  /// ad options at all (a failed or offline load hides them).
  bool isRewardedAvailable(RewardedPlacement placement) {
    final slot = _rewarded[placement];
    if (!adsAllowed || slot == null) return false;
    return slot.ad != null || (slot.loading && slot.failures == 0);
  }

  /// Shows the rewarded ad for [placement]. True only if the user earned the
  /// reward; closing early or a failed show gives nothing.
  Future<bool> showRewarded(RewardedPlacement placement) async {
    final slot = _rewarded[placement];
    final ad = slot?.ad;
    if (slot == null || ad == null || !adsAllowed || _showing) return false;
    slot.ad = null;
    var earned = false;
    try {
      earned = await _present(ad);
    } finally {
      ad.dispose();
      _load(slot);
    }
    return earned;
  }

  /// Shows the interstitial if one is due. Call only when leaving the
  /// Chequered flag. Skipped right after a Pit Stop ad in the same run.
  Future<void> showInterstitialIfDue({required bool afterPitStop}) async {
    final storage = _storage;
    final slot = _interstitial;
    if (storage == null || slot == null || !adsAllowed || _showing) return;
    if (afterPitStop) return;
    final last = _lastInterstitial;
    final due = shouldShowInterstitial(
      gameOversSinceLast: storage.gameOversSinceInterstitial,
      msSinceLast: last == null ? null : _now().difference(last).inMilliseconds,
      isFirstSession: storage.isFirstSession,
      adsRemoved: storage.adsRemoved,
    );
    if (!due) return;
    final ad = slot.ad;
    if (ad == null) {
      _load(slot);
      return;
    }
    slot.ad = null;
    try {
      await _present(ad);
      _lastInterstitial = _now();
      await storage.resetInterstitialCounter();
    } finally {
      ad.dispose();
      _load(slot);
    }
  }

  /// Shows [ad] with game audio muted; restores audio afterwards.
  Future<bool> _present(LoadedAd ad) async {
    _showing = true;
    _audio?.setMuted(true);
    try {
      return await ad.show();
    } catch (e, st) {
      debugPrint('Ad show failed: $e\n$st');
      return false;
    } finally {
      _showing = false;
      _audio?.setMuted(false);
    }
  }

  @override
  void dispose() {
    for (final slot in [..._rewarded.values, ?_interstitial]) {
      slot.retry?.cancel();
      slot.ad?.dispose();
    }
    super.dispose();
  }
}

class _NoConsentGateway implements ConsentGateway {
  @override
  Future<bool> canRequestAds() async => false;

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<bool> requestInfoUpdate() async => false;

  @override
  Future<bool> showFormIfRequired() async => false;

  @override
  Future<bool> showPrivacyOptionsForm() async => false;
}

Future<LoadedAd?> _loadGoogleRewarded(String unitId) {
  final done = Completer<LoadedAd?>();
  RewardedAd.load(
    adUnitId: unitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) => done.complete(_GoogleRewarded(ad)),
      onAdFailedToLoad: (error) {
        debugPrint('Rewarded load failed: ${error.message}');
        done.complete(null);
      },
    ),
  );
  return done.future;
}

Future<LoadedAd?> _loadGoogleInterstitial(String unitId) {
  final done = Completer<LoadedAd?>();
  InterstitialAd.load(
    adUnitId: unitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (ad) => done.complete(_GoogleInterstitial(ad)),
      onAdFailedToLoad: (error) {
        debugPrint('Interstitial load failed: ${error.message}');
        done.complete(null);
      },
    ),
  );
  return done.future;
}

class _GoogleRewarded implements LoadedAd {
  final RewardedAd _ad;

  _GoogleRewarded(this._ad);

  @override
  Future<bool> show() {
    final closed = Completer<bool>();
    var earned = false;
    _ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) => closed.complete(earned),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Rewarded show failed: ${error.message}');
        closed.complete(false);
      },
    );
    // The only place a reward is granted.
    _ad.show(onUserEarnedReward: (_, _) => earned = true);
    return closed.future;
  }

  @override
  void dispose() => _ad.dispose();
}

class _GoogleInterstitial implements LoadedAd {
  final InterstitialAd _ad;

  _GoogleInterstitial(this._ad);

  @override
  Future<bool> show() {
    final closed = Completer<bool>();
    _ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (_) => closed.complete(true),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial show failed: ${error.message}');
        closed.complete(false);
      },
    );
    _ad.show();
    return closed.future;
  }

  @override
  void dispose() => _ad.dispose();
}
