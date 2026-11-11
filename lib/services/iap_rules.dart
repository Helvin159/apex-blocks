// Purchase rules. Pure Dart (no Flutter or plugin imports), so they are
// unit-tested without a store.

import '../config/ad_config.dart' show removeAdsProductId;

/// What the store reported for one purchase update.
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

/// What the player should be told. The UI maps these to text.
enum PurchaseNotice { processing, thankYou, restored, failed }

/// What to do about one purchase update.
class PurchaseDecision {
  /// Turn Remove Ads on (idempotent: false for a repeat of an owned item).
  final bool grantEntitlement;

  /// Tell the store the purchase is handled (`completePurchase`).
  final bool completePurchase;

  /// Message for the player; null means stay silent.
  final PurchaseNotice? notice;

  const PurchaseDecision({
    this.grantEntitlement = false,
    this.completePurchase = false,
    this.notice,
  });

  @override
  String toString() =>
      'PurchaseDecision(grant: $grantEntitlement, complete: $completePurchase, '
      'notice: $notice)';
}

/// Decides what to do with a purchase update.
///
/// [completePurchase] follows [pendingCompletePurchase] for EVERY status: on
/// iOS an uncompleted transaction is redelivered at every launch, and on
/// Android an unacknowledged purchase is refunded after 3 days. The
/// entitlement is granted only for a purchased or restored [productId] that
/// is not [alreadyOwned], so duplicate events grant once. Canceled and failed
/// purchases never grant.
PurchaseDecision decidePurchaseUpdate({
  required StorePurchaseStatus status,
  required String productId,
  required bool pendingCompletePurchase,
  required bool alreadyOwned,
}) {
  final complete = pendingCompletePurchase;
  final ours = productId == removeAdsProductId;
  switch (status) {
    case StorePurchaseStatus.pending:
      return PurchaseDecision(
        completePurchase: complete,
        notice: ours ? PurchaseNotice.processing : null,
      );
    case StorePurchaseStatus.purchased:
    case StorePurchaseStatus.restored:
      final grant = ours && !alreadyOwned;
      return PurchaseDecision(
        grantEntitlement: grant,
        completePurchase: complete,
        notice: !grant
            ? null
            : status == StorePurchaseStatus.purchased
            ? PurchaseNotice.thankYou
            : PurchaseNotice.restored,
      );
    case StorePurchaseStatus.error:
      return PurchaseDecision(
        completePurchase: complete,
        notice: ours ? PurchaseNotice.failed : null,
      );
    case StorePurchaseStatus.canceled:
      return PurchaseDecision(completePurchase: complete);
  }
}

/// Result of a Restore Purchases attempt.
enum RestoreOutcome { restored, nothingToRestore, failed }

/// Outcome of a restore: [failed] if the store reported an error, else
/// [restored] if the product came back, else [nothingToRestore].
RestoreOutcome restoreOutcome({
  required bool storeFailed,
  required bool productRestored,
}) {
  if (storeFailed) return RestoreOutcome.failed;
  return productRestored
      ? RestoreOutcome.restored
      : RestoreOutcome.nothingToRestore;
}
