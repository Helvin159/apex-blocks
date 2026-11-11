import '../services/iap_rules.dart';

/// Player-facing text for a purchase message. Canceled has none: silent.
String noticeText(PurchaseNotice notice) => switch (notice) {
  PurchaseNotice.processing => 'Processing…',
  PurchaseNotice.thankYou =>
    'Thank you! Ads are off and every livery is unlocked.',
  PurchaseNotice.restored =>
    'Purchase restored. Ads are off and every livery is unlocked.',
  PurchaseNotice.failed => "The purchase didn't go through. Try again.",
};

/// Player-facing text for the result of Restore Purchases.
String restoreText(RestoreOutcome outcome) => switch (outcome) {
  RestoreOutcome.restored => 'Purchase restored.',
  RestoreOutcome.nothingToRestore => 'Nothing to restore.',
  RestoreOutcome.failed => "Couldn't restore. Try again later.",
};
