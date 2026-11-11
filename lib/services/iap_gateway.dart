import 'package:in_app_purchase/in_app_purchase.dart';

import 'iap_rules.dart';

/// A product as the store describes it.
class StoreProduct {
  final String id;

  /// Localized price from the store, e.g. "$2.99". Never hard-coded.
  final String price;

  const StoreProduct({required this.id, required this.price});
}

/// One purchase update, free of plugin types so tests can build them.
class StorePurchase {
  final String productId;
  final StorePurchaseStatus status;

  /// The store still waits for `completePurchase` (see [decidePurchaseUpdate]).
  final bool pendingCompletePurchase;
  final String? errorMessage;

  /// The plugin object [PurchaseGateway.complete] needs.
  final Object? raw;

  const StorePurchase({
    required this.productId,
    required this.status,
    this.pendingCompletePurchase = false,
    this.errorMessage,
    this.raw,
  });
}

/// The slice of the store that [IapService] needs. A small interface so tests
/// can fake it.
abstract class PurchaseGateway {
  /// Every purchase update, including ones that finished while the app was
  /// closed. Listen as early as possible.
  Stream<List<StorePurchase>> get purchaseUpdates;

  Future<bool> isAvailable();

  /// The product, or null if the store does not know it.
  Future<StoreProduct?> loadProduct(String id);

  /// Starts the purchase flow; false if it could not start. The result
  /// arrives on [purchaseUpdates].
  Future<bool> buy(String id);

  /// Asks the store to replay owned purchases onto [purchaseUpdates].
  Future<void> restore();

  Future<void> complete(StorePurchase purchase);
}

/// [PurchaseGateway] over the `in_app_purchase` plugin (StoreKit on iOS,
/// Play Billing on Android).
class InAppPurchaseGateway implements PurchaseGateway {
  final InAppPurchase _iap;
  final Map<String, ProductDetails> _details = {};

  InAppPurchaseGateway([InAppPurchase? iap])
    : _iap = iap ?? InAppPurchase.instance;

  @override
  Stream<List<StorePurchase>> get purchaseUpdates =>
      _iap.purchaseStream.map((list) => [for (final p in list) _toPurchase(p)]);

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<StoreProduct?> loadProduct(String id) async {
    final response = await _iap.queryProductDetails({id});
    if (response.error != null) return null;
    for (final d in response.productDetails) {
      if (d.id != id) continue;
      _details[id] = d;
      return StoreProduct(id: id, price: d.price);
    }
    return null;
  }

  @override
  Future<bool> buy(String id) async {
    final details = _details[id];
    if (details == null) return false;
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(StorePurchase purchase) async {
    final raw = purchase.raw;
    if (raw is PurchaseDetails) await _iap.completePurchase(raw);
  }

  StorePurchase _toPurchase(PurchaseDetails p) => StorePurchase(
    productId: p.productID,
    status: switch (p.status) {
      PurchaseStatus.pending => StorePurchaseStatus.pending,
      PurchaseStatus.purchased => StorePurchaseStatus.purchased,
      PurchaseStatus.restored => StorePurchaseStatus.restored,
      PurchaseStatus.error => StorePurchaseStatus.error,
      PurchaseStatus.canceled => StorePurchaseStatus.canceled,
    },
    pendingCompletePurchase: p.pendingCompletePurchase,
    errorMessage: p.error?.message,
    raw: p,
  );
}
