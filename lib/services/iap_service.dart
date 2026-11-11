import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/ad_config.dart';
import 'iap_gateway.dart';
import 'iap_rules.dart';
import 'storage_service.dart';

/// How long a restore waits for the store's replayed purchases after the
/// store says it is done, before it reports "nothing to restore".
const Duration iapRestoreTimeout = Duration(seconds: 6);

/// How long loading the product may take before it counts as unavailable
/// (offline, or the store never answers).
const Duration iapProductLoadTimeout = Duration(seconds: 12);

enum ProductState { loading, available, unavailable }

/// The Remove Ads purchase: product price, buying, restoring, and granting
/// the entitlement. [IapService.disabled] never touches a store and is the
/// default for tests and screens without purchases.
class IapService extends ChangeNotifier {
  final StorageService? _storage;
  final PurchaseGateway? _gateway;
  final Duration _restoreTimeout;
  final Duration _productTimeout;

  StreamSubscription<List<StorePurchase>>? _subscription;
  ProductState _productState = ProductState.loading;
  String? _price;
  bool _purchasing = false;
  PurchaseNotice? _notice;

  Future<RestoreOutcome>? _restoring;
  Completer<bool>? _restoreWaiter;
  bool _restoreFailed = false;

  IapService({
    required StorageService this._storage,
    required PurchaseGateway this._gateway,
    this._restoreTimeout = iapRestoreTimeout,
    this._productTimeout = iapProductLoadTimeout,
  });

  IapService.disabled()
    : _storage = null,
      _gateway = null,
      _restoreTimeout = iapRestoreTimeout,
      _productTimeout = iapProductLoadTimeout,
      _productState = ProductState.unavailable;

  ProductState get productState => _productState;

  /// The store's localized price; null until the product loaded.
  String? get price => _price;

  /// A purchase is in flight (the store sheet is up, or it is pending).
  bool get purchasing => _purchasing;

  bool get restoring => _restoring != null;

  /// The latest message for the player; null when there is none.
  PurchaseNotice? get notice => _notice;

  bool get ownsRemoveAds => _storage?.adsRemoved ?? false;

  /// Subscribes to purchase updates. Call at startup, before any UI, so a
  /// purchase that finished while the app was closed is handled.
  Future<void> start() async {
    final gateway = _gateway;
    if (gateway == null || _subscription != null) return;
    _subscription = gateway.purchaseUpdates.listen(
      _onUpdates,
      onError: (Object e, StackTrace st) {
        debugPrint('Purchase stream error: $e\n$st');
        _purchasing = false;
        _notice = PurchaseNotice.failed;
        notifyListeners();
      },
    );
  }

  /// Loads the product and its localized price. Never throws.
  Future<void> loadProduct() async {
    final gateway = _gateway;
    if (gateway == null) return;
    _productState = ProductState.loading;
    notifyListeners();
    StoreProduct? product;
    try {
      product = await _loadProductFromStore(gateway).timeout(_productTimeout);
    } catch (e) {
      debugPrint('Product load failed: $e');
    }
    _price = product?.price;
    _productState = product == null
        ? ProductState.unavailable
        : ProductState.available;
    notifyListeners();
  }

  Future<StoreProduct?> _loadProductFromStore(PurchaseGateway gateway) async {
    if (!await gateway.isAvailable()) return null;
    return gateway.loadProduct(removeAdsProductId);
  }

  /// Forgets the last message (when a sheet opens).
  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  /// Starts the purchase. The result arrives through the purchase stream.
  Future<void> buy() async {
    final gateway = _gateway;
    if (gateway == null ||
        _purchasing ||
        ownsRemoveAds ||
        _productState != ProductState.available) {
      return;
    }
    _purchasing = true;
    _notice = null;
    notifyListeners();
    var started = false;
    try {
      started = await gateway.buy(removeAdsProductId);
    } catch (e) {
      debugPrint('Purchase start failed: $e');
    }
    if (!started) {
      _purchasing = false;
      _notice = PurchaseNotice.failed;
      notifyListeners();
    }
  }

  /// Asks the store to restore earlier purchases. Concurrent calls share one
  /// attempt.
  Future<RestoreOutcome> restore() {
    if (_gateway == null) return Future.value(RestoreOutcome.failed);
    return _restoring ??= _doRestore().whenComplete(() {
      _restoring = null;
      _restoreWaiter = null;
      notifyListeners();
    });
  }

  Future<RestoreOutcome> _doRestore() async {
    final waiter = _restoreWaiter = Completer<bool>();
    _restoreFailed = false;
    notifyListeners();
    try {
      await _gateway!.restore();
    } catch (e) {
      debugPrint('Restore failed: $e');
      return RestoreOutcome.failed;
    }
    final restored = await waiter.future.timeout(
      _restoreTimeout,
      onTimeout: () => false,
    );
    return restoreOutcome(
      storeFailed: _restoreFailed,
      productRestored: restored || ownsRemoveAds,
    );
  }

  Future<void> _onUpdates(List<StorePurchase> purchases) async {
    if (purchases.isEmpty) {
      // The store finished a restore and found nothing.
      _restoreWaiter?.complete(false);
      return;
    }
    for (final purchase in purchases) {
      try {
        await _handle(purchase);
      } catch (e, st) {
        debugPrint('Purchase handling failed: $e\n$st');
      }
    }
  }

  Future<void> _handle(StorePurchase purchase) async {
    final storage = _storage!;
    final decision = decidePurchaseUpdate(
      status: purchase.status,
      productId: purchase.productId,
      pendingCompletePurchase: purchase.pendingCompletePurchase,
      alreadyOwned: storage.adsRemoved,
    );
    // Grant first, then complete: if the app dies in between, the store
    // redelivers the purchase at the next launch.
    if (decision.grantEntitlement) await storage.setAdsRemoved(true);
    if (decision.completePurchase) {
      try {
        await _gateway!.complete(purchase);
      } catch (e) {
        debugPrint('completePurchase failed: $e');
      }
    }
    if (purchase.productId == removeAdsProductId) {
      final waiter = _restoreWaiter;
      switch (purchase.status) {
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          _purchasing = false;
          if (waiter != null && !waiter.isCompleted) waiter.complete(true);
        case StorePurchaseStatus.error:
          _purchasing = false;
          if (waiter != null && !waiter.isCompleted) {
            _restoreFailed = true;
            waiter.complete(false);
          }
        case StorePurchaseStatus.canceled:
          _purchasing = false;
        case StorePurchaseStatus.pending:
          _purchasing = true;
      }
      _notice = decision.notice;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
