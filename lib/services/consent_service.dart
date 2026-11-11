import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// The slice of the UMP SDK this app uses, so tests can fake it.
abstract class ConsentGateway {
  /// Asks UMP for the latest consent info; false if that failed.
  Future<bool> requestInfoUpdate();

  /// Shows the consent form if UMP says one is required. Returns false if
  /// loading or showing it failed.
  Future<bool> showFormIfRequired();

  Future<bool> canRequestAds();

  Future<bool> privacyOptionsRequired();

  /// Opens the privacy options form. Returns false on failure.
  Future<bool> showPrivacyOptionsForm();
}

class UmpConsentGateway implements ConsentGateway {
  @override
  Future<bool> requestInfoUpdate() {
    final done = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => done.complete(true),
      (error) {
        debugPrint('UMP info update failed: ${error.message}');
        done.complete(false);
      },
    );
    return done.future;
  }

  @override
  Future<bool> showFormIfRequired() {
    final done = Completer<bool>();
    ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) debugPrint('UMP form failed: ${error.message}');
      done.complete(error == null);
    });
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<bool> showPrivacyOptionsForm() {
    final done = Completer<bool>();
    ConsentForm.showPrivacyOptionsForm((error) {
      if (error != null) debugPrint('UMP options failed: ${error.message}');
      done.complete(error == null);
    });
    return done.future;
  }
}

/// UMP consent. Runs on every launch before any ad loads. Any failure or
/// decline leaves [canRequestAds] false and the game plays without ads.
class ConsentService {
  final ConsentGateway _gateway;

  /// True once UMP allows ad requests.
  final ValueNotifier<bool> canRequestAds = ValueNotifier(false);

  /// True when the Setup sheet must offer a "Privacy choices" row.
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  ConsentService([ConsentGateway? gateway])
    : _gateway = gateway ?? UmpConsentGateway();

  /// Updates consent info, shows the form if UMP requires it, and reads the
  /// result. Never throws.
  Future<void> gatherConsent() async {
    try {
      await _gateway.requestInfoUpdate();
      // Even if the update failed, consent from an earlier launch may still
      // allow ads, so the form and canRequestAds are checked regardless.
      await _gateway.showFormIfRequired();
      await _refresh();
    } catch (e, st) {
      debugPrint('Consent flow failed: $e\n$st');
      canRequestAds.value = false;
    }
  }

  /// Opens the UMP privacy options form, then re-reads the consent state.
  Future<void> showPrivacyOptions() async {
    try {
      await _gateway.showPrivacyOptionsForm();
      await _refresh();
    } catch (e, st) {
      debugPrint('Privacy options failed: $e\n$st');
    }
  }

  Future<void> _refresh() async {
    canRequestAds.value = await _gateway.canRequestAds();
    privacyOptionsRequired.value = await _gateway.privacyOptionsRequired();
  }

  void dispose() {
    canRequestAds.dispose();
    privacyOptionsRequired.dispose();
  }
}
