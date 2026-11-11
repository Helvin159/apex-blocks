import 'dart:async';

import 'package:apexblocks/config/ad_config.dart';
import 'package:apexblocks/services/iap_gateway.dart';
import 'package:apexblocks/services/iap_rules.dart';
import 'package:apexblocks/services/iap_service.dart';
import 'package:apexblocks/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePurchaseGateway implements PurchaseGateway {
  final StreamController<List<StorePurchase>> controller =
      StreamController<List<StorePurchase>>.broadcast();
  bool available = true;
  StoreProduct? product = const StoreProduct(
    id: removeAdsProductId,
    price: r'$2.99',
  );
  bool loadThrows = false;
  bool buyStarts = true;
  bool completeThrows = false;
  Object? restoreError;

  /// What the store replays when Restore is called.
  List<StorePurchase>? restoreReplay;

  int buyCalls = 0;
  int restoreCalls = 0;
  final List<StorePurchase> completed = [];

  @override
  Stream<List<StorePurchase>> get purchaseUpdates => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<StoreProduct?> loadProduct(String id) async {
    if (loadThrows) throw StateError('offline');
    return product;
  }

  @override
  Future<bool> buy(String id) async {
    buyCalls++;
    return buyStarts;
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    final error = restoreError;
    if (error != null) throw error;
    final replay = restoreReplay;
    if (replay != null) controller.add(replay);
  }

  @override
  Future<void> complete(StorePurchase purchase) async {
    if (completeThrows) throw StateError('store down');
    completed.add(purchase);
  }

  void emit(StorePurchase p) => controller.add([p]);
}

StorePurchase purchase(
  StorePurchaseStatus status, {
  String id = removeAdsProductId,
  bool pendingComplete = true,
}) => StorePurchase(
  productId: id,
  status: status,
  pendingCompletePurchase: pendingComplete,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

class Rig {
  final StorageService storage;
  final FakePurchaseGateway gateway = FakePurchaseGateway();
  late final IapService iap;

  Rig(this.storage) {
    iap = IapService(
      storage: storage,
      gateway: gateway,
      restoreTimeout: const Duration(milliseconds: 50),
      productTimeout: const Duration(milliseconds: 200),
    );
    addTearDown(iap.dispose);
  }
}

Future<Rig> rig([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final storage = await StorageService.open(
    await SharedPreferences.getInstance(),
  );
  return Rig(storage);
}

void main() {
  group('purchase stream', () {
    test('is subscribed by start(), before any UI', () async {
      final r = await rig();
      expect(r.gateway.controller.hasListener, isFalse);
      await r.iap.start();
      expect(r.gateway.controller.hasListener, isTrue);
    });

    test('purchased: grants, persists, completes, thanks', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.emit(purchase(StorePurchaseStatus.purchased));
      await settle();
      expect(r.storage.adsRemoved, isTrue);
      expect(r.gateway.completed, hasLength(1));
      expect(r.iap.notice, PurchaseNotice.thankYou);
      expect(r.iap.purchasing, isFalse);
      // Persisted: a fresh storage on the same prefs sees it.
      final again = await StorageService.open(
        await SharedPreferences.getInstance(),
      );
      expect(again.adsRemoved, isTrue);
    });

    test('completePurchase is only called when the store asks', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.emit(
        purchase(StorePurchaseStatus.purchased, pendingComplete: false),
      );
      await settle();
      expect(r.storage.adsRemoved, isTrue);
      expect(r.gateway.completed, isEmpty);
    });

    test('restored grants and completes', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.emit(purchase(StorePurchaseStatus.restored));
      await settle();
      expect(r.storage.adsRemoved, isTrue);
      expect(r.gateway.completed, hasLength(1));
      expect(r.iap.notice, PurchaseNotice.restored);
    });

    test('pending shows Processing and grants nothing', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.emit(
        purchase(StorePurchaseStatus.pending, pendingComplete: false),
      );
      await settle();
      expect(r.storage.adsRemoved, isFalse);
      expect(r.gateway.completed, isEmpty);
      expect(r.iap.notice, PurchaseNotice.processing);
      expect(r.iap.purchasing, isTrue);
    });

    test('error: friendly message, no grant, still completed', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.emit(purchase(StorePurchaseStatus.error));
      await settle();
      expect(r.storage.adsRemoved, isFalse);
      expect(r.iap.notice, PurchaseNotice.failed);
      expect(r.gateway.completed, hasLength(1));
      expect(r.iap.purchasing, isFalse);
    });

    test('canceled: silent, no grant, nothing stuck', () async {
      final r = await rig();
      await r.iap.start();
      await r.iap.loadProduct();
      await r.iap.buy();
      expect(r.iap.purchasing, isTrue);
      r.gateway.emit(
        purchase(StorePurchaseStatus.canceled, pendingComplete: false),
      );
      await settle();
      expect(r.storage.adsRemoved, isFalse);
      expect(r.iap.notice, isNull);
      expect(r.iap.purchasing, isFalse);
    });

    test('duplicate purchased events grant once, complete each', () async {
      final r = await rig();
      await r.iap.start();
      var notifications = 0;
      r.storage.addListener(() => notifications++);
      r.gateway.emit(purchase(StorePurchaseStatus.purchased));
      r.gateway.emit(purchase(StorePurchaseStatus.purchased));
      await settle();
      expect(r.storage.adsRemoved, isTrue);
      expect(notifications, 1); // the second event wrote nothing
      expect(r.gateway.completed, hasLength(2));
    });

    test('a failure completing does not lose the grant', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.completeThrows = true;
      r.gateway.emit(purchase(StorePurchaseStatus.purchased));
      await settle();
      expect(r.storage.adsRemoved, isTrue);
    });
  });

  group('product', () {
    test('loads the localized price from the store', () async {
      final r = await rig();
      expect(r.iap.productState, ProductState.loading);
      await r.iap.loadProduct();
      expect(r.iap.productState, ProductState.available);
      expect(r.iap.price, r'$2.99');
    });

    test('store unavailable, product missing or load error', () async {
      final r = await rig();
      r.gateway.available = false;
      await r.iap.loadProduct();
      expect(r.iap.productState, ProductState.unavailable);

      r.gateway.available = true;
      r.gateway.product = null;
      await r.iap.loadProduct();
      expect(r.iap.productState, ProductState.unavailable);

      r.gateway.loadThrows = true;
      await r.iap.loadProduct();
      expect(r.iap.productState, ProductState.unavailable);
      expect(r.iap.price, isNull);
    });

    test('can load again after going unavailable', () async {
      final r = await rig();
      r.gateway.available = false;
      await r.iap.loadProduct();
      r.gateway.available = true;
      await r.iap.loadProduct();
      expect(r.iap.productState, ProductState.available);
    });

    test('buy does nothing without a loaded product', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.available = false;
      await r.iap.loadProduct();
      await r.iap.buy();
      expect(r.gateway.buyCalls, 0);
      expect(r.iap.purchasing, isFalse);
    });

    test('buy starts one purchase; a double tap is ignored', () async {
      final r = await rig();
      await r.iap.start();
      await r.iap.loadProduct();
      await r.iap.buy();
      await r.iap.buy();
      expect(r.gateway.buyCalls, 1);
    });

    test('a purchase that cannot start reports failure', () async {
      final r = await rig();
      await r.iap.start();
      await r.iap.loadProduct();
      r.gateway.buyStarts = false;
      await r.iap.buy();
      expect(r.iap.purchasing, isFalse);
      expect(r.iap.notice, PurchaseNotice.failed);
    });

    test('buy is ignored once owned', () async {
      final r = await rig({'adsRemoved': true});
      await r.iap.start();
      await r.iap.loadProduct();
      await r.iap.buy();
      expect(r.gateway.buyCalls, 0);
    });
  });

  group('restore', () {
    test(
      'with no prior purchase: nothing to restore, flag stays off',
      () async {
        final r = await rig();
        await r.iap.start();
        r.gateway.restoreReplay = []; // the store finished and found nothing
        expect(await r.iap.restore(), RestoreOutcome.nothingToRestore);
        expect(r.storage.adsRemoved, isFalse);
        expect(r.gateway.restoreCalls, 1);
      },
    );

    test('no reply at all times out as nothing to restore', () async {
      final r = await rig();
      await r.iap.start();
      expect(await r.iap.restore(), RestoreOutcome.nothingToRestore);
      expect(r.storage.adsRemoved, isFalse);
    });

    test('a replayed purchase restores Remove Ads', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.restoreReplay = [purchase(StorePurchaseStatus.restored)];
      expect(await r.iap.restore(), RestoreOutcome.restored);
      expect(r.storage.adsRemoved, isTrue);
      expect(r.gateway.completed, hasLength(1));
    });

    test('a store error is reported as failed, nothing granted', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.restoreError = StateError('no network');
      expect(await r.iap.restore(), RestoreOutcome.failed);
      expect(r.storage.adsRemoved, isFalse);
    });

    test('an error event during restore is reported as failed', () async {
      final r = await rig();
      await r.iap.start();
      r.gateway.restoreReplay = [purchase(StorePurchaseStatus.error)];
      expect(await r.iap.restore(), RestoreOutcome.failed);
      expect(r.storage.adsRemoved, isFalse);
    });

    test('restoring again while owned still reports restored', () async {
      final r = await rig({'adsRemoved': true});
      await r.iap.start();
      r.gateway.restoreReplay = [purchase(StorePurchaseStatus.restored)];
      expect(await r.iap.restore(), RestoreOutcome.restored);
      expect(r.storage.adsRemoved, isTrue);
    });
  });

  test('the disabled service never touches a store', () async {
    final iap = IapService.disabled();
    await iap.start();
    await iap.loadProduct();
    await iap.buy();
    expect(iap.productState, ProductState.unavailable);
    expect(await iap.restore(), RestoreOutcome.failed);
    iap.dispose();
  });
}
