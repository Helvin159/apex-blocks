import 'package:apexblocks/services/consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements ConsentGateway {
  bool updateOk = true;
  bool formOk = true;
  bool canRequest = true;
  bool optionsRequired = false;
  bool throwOnUpdate = false;
  final List<String> calls = [];

  @override
  Future<bool> requestInfoUpdate() async {
    calls.add('update');
    if (throwOnUpdate) throw StateError('boom');
    return updateOk;
  }

  @override
  Future<bool> showFormIfRequired() async {
    calls.add('form');
    return formOk;
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<bool> privacyOptionsRequired() async => optionsRequired;

  @override
  Future<bool> showPrivacyOptionsForm() async {
    calls.add('options');
    // Opting out in the form revokes ad consent.
    canRequest = false;
    return true;
  }
}

void main() {
  test('updates info, shows the form, then allows ads', () async {
    final gateway = FakeGateway();
    final consent = ConsentService(gateway);
    expect(consent.canRequestAds.value, isFalse); // nothing before the flow
    await consent.gatherConsent();
    expect(gateway.calls, ['update', 'form']);
    expect(consent.canRequestAds.value, isTrue);
  });

  test('declined consent leaves ads off', () async {
    final gateway = FakeGateway()..canRequest = false;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.canRequestAds.value, isFalse);
  });

  test('a failed update still honours cached consent', () async {
    final gateway = FakeGateway()..updateOk = false;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.canRequestAds.value, isTrue);
  });

  test('a failed update with no consent means no ads', () async {
    final gateway = FakeGateway()
      ..updateOk = false
      ..formOk = false
      ..canRequest = false;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.canRequestAds.value, isFalse);
  });

  test('an exception never escapes and means no ads', () async {
    final gateway = FakeGateway()..throwOnUpdate = true;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.canRequestAds.value, isFalse);
  });

  test('the privacy choices entry point follows UMP', () async {
    final gateway = FakeGateway()..optionsRequired = true;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.privacyOptionsRequired.value, isTrue);

    final none = ConsentService(FakeGateway());
    await none.gatherConsent();
    expect(none.privacyOptionsRequired.value, isFalse);
  });

  test('the privacy options form re-reads consent afterwards', () async {
    final gateway = FakeGateway()..optionsRequired = true;
    final consent = ConsentService(gateway);
    await consent.gatherConsent();
    expect(consent.canRequestAds.value, isTrue);
    await consent.showPrivacyOptions();
    expect(gateway.calls.last, 'options');
    expect(consent.canRequestAds.value, isFalse);
  });
}
