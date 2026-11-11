import 'package:apexblocks/config/ad_config.dart';
import 'package:apexblocks/services/iap_rules.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseDecision decide(
  StorePurchaseStatus status, {
  String product = removeAdsProductId,
  bool pendingComplete = false,
  bool owned = false,
}) => decidePurchaseUpdate(
  status: status,
  productId: product,
  pendingCompletePurchase: pendingComplete,
  alreadyOwned: owned,
);

void main() {
  test('the product ID is remove_ads', () {
    expect(removeAdsProductId, 'remove_ads');
  });

  group('decidePurchaseUpdate', () {
    test('purchased: grants, thanks, completes when flagged', () {
      final d = decide(StorePurchaseStatus.purchased, pendingComplete: true);
      expect(d.grantEntitlement, isTrue);
      expect(d.completePurchase, isTrue);
      expect(d.notice, PurchaseNotice.thankYou);
    });

    test('restored: grants and reports restored', () {
      final d = decide(StorePurchaseStatus.restored, pendingComplete: true);
      expect(d.grantEntitlement, isTrue);
      expect(d.completePurchase, isTrue);
      expect(d.notice, PurchaseNotice.restored);
    });

    test('pending: shows Processing, grants nothing', () {
      final d = decide(StorePurchaseStatus.pending);
      expect(d.grantEntitlement, isFalse);
      expect(d.notice, PurchaseNotice.processing);
    });

    test('error: friendly message, never grants', () {
      final d = decide(StorePurchaseStatus.error, pendingComplete: true);
      expect(d.grantEntitlement, isFalse);
      expect(d.notice, PurchaseNotice.failed);
      expect(d.completePurchase, isTrue);
    });

    test('canceled: silent, never grants', () {
      final d = decide(StorePurchaseStatus.canceled, pendingComplete: true);
      expect(d.grantEntitlement, isFalse);
      expect(d.notice, isNull);
      expect(d.completePurchase, isTrue);
    });

    test('completePurchase follows the flag for every status', () {
      for (final status in StorePurchaseStatus.values) {
        for (final owned in [false, true]) {
          expect(
            decide(
              status,
              pendingComplete: true,
              owned: owned,
            ).completePurchase,
            isTrue,
            reason: '$status owned=$owned',
          );
          expect(
            decide(
              status,
              pendingComplete: false,
              owned: owned,
            ).completePurchase,
            isFalse,
            reason: '$status owned=$owned',
          );
        }
      }
    });

    test('a duplicate purchased event grants once but still completes', () {
      final first = decide(
        StorePurchaseStatus.purchased,
        pendingComplete: true,
      );
      final repeat = decide(
        StorePurchaseStatus.purchased,
        pendingComplete: true,
        owned: true,
      );
      expect(first.grantEntitlement, isTrue);
      expect(repeat.grantEntitlement, isFalse);
      expect(repeat.notice, isNull);
      expect(repeat.completePurchase, isTrue);
    });

    test('only failed, canceled and pending never grant', () {
      for (final status in [
        StorePurchaseStatus.pending,
        StorePurchaseStatus.error,
        StorePurchaseStatus.canceled,
      ]) {
        expect(decide(status).grantEntitlement, isFalse, reason: '$status');
      }
    });

    test('another product is never granted (but is completed)', () {
      final d = decide(
        StorePurchaseStatus.purchased,
        product: 'something_else',
        pendingComplete: true,
      );
      expect(d.grantEntitlement, isFalse);
      expect(d.notice, isNull);
      expect(d.completePurchase, isTrue);
    });
  });

  group('restoreOutcome', () {
    test('restored, nothing to restore, failed', () {
      expect(
        restoreOutcome(storeFailed: false, productRestored: true),
        RestoreOutcome.restored,
      );
      expect(
        restoreOutcome(storeFailed: false, productRestored: false),
        RestoreOutcome.nothingToRestore,
      );
      expect(
        restoreOutcome(storeFailed: true, productRestored: false),
        RestoreOutcome.failed,
      );
    });
  });
}
