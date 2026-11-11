import 'package:apexblocks/services/iap_rules.dart';
import 'package:apexblocks/services/iap_service.dart';
import 'package:apexblocks/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/iap_service_test.dart' show FakePurchaseGateway, purchase;
import 'test_support.dart';

Future<({IapService iap, FakePurchaseGateway gateway})> makeIap(
  WidgetTester tester,
  storage,
) async {
  final gateway = FakePurchaseGateway();
  final iap = IapService(
    storage: storage,
    gateway: gateway,
    restoreTimeout: const Duration(milliseconds: 50),
  );
  addTearDown(iap.dispose);
  await iap.start();
  await iap.loadProduct();
  return (iap: iap, gateway: gateway);
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('CLEAN AIR · NO ADS'));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in phoneSizes) {
    testWidgets('CLEAN AIR sheet fits $size and shows the offer', (
      tester,
    ) async {
      useScreen(tester, size);
      final storage = await makeStorage();
      final (:iap, :gateway) = await makeIap(tester, storage);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage, iap: iap),
        ),
      );
      expect(tester.takeException(), isNull);
      await openSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('CLEAN AIR'), findsOneWidget);
      expect(find.text('No more ads between races'), findsOneWidget);
      expect(find.text('Unlocks every livery'), findsOneWidget);
      expect(
        find.text('Optional reward ads stay available, only if you tap them'),
        findsOneWidget,
      );
      expect(find.text(r'Remove ads · $2.99'), findsOneWidget); // store price
      expect(find.text('Restore purchase'), findsOneWidget);
    });
  }

  testWidgets('buying: store sheet, thank-you, then the button is ACTIVE', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final (:iap, :gateway) = await makeIap(tester, storage);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, iap: iap),
      ),
    );
    await openSheet(tester);

    await tester.tap(find.text(r'Remove ads · $2.99'));
    await tester.pump();
    expect(gateway.buyCalls, 1);
    expect(find.text('Processing…'), findsOneWidget);

    gateway.emit(purchase(StorePurchaseStatus.purchased));
    await tester.pumpAndSettle();
    expect(storage.adsRemoved, isTrue);
    expect(find.text('Thank you! CLEAN AIR is active.'), findsOneWidget);
    expect(find.textContaining('Remove ads'), findsNothing);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('CLEAN AIR · ACTIVE'), findsOneWidget);
    expect(storage.isLiveryUnlockedNow(1), isTrue);
    expect(storage.isLiveryUnlockedNow(2), isTrue);
  });

  testWidgets('a canceled purchase leaves the offer, with no message', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final (:iap, :gateway) = await makeIap(tester, storage);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, iap: iap),
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text(r'Remove ads · $2.99'));
    await tester.pump();
    gateway.emit(
      purchase(StorePurchaseStatus.canceled, pendingComplete: false),
    );
    await tester.pumpAndSettle();
    expect(storage.adsRemoved, isFalse);
    expect(find.text(r'Remove ads · $2.99'), findsOneWidget);
    expect(find.textContaining("didn't go through"), findsNothing);
  });

  testWidgets('a failed purchase shows a friendly message', (tester) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final (:iap, :gateway) = await makeIap(tester, storage);
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, iap: iap),
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text(r'Remove ads · $2.99'));
    await tester.pump();
    gateway.emit(purchase(StorePurchaseStatus.error));
    await tester.pumpAndSettle();
    expect(storage.adsRemoved, isFalse);
    expect(
      find.text("The purchase didn't go through. Try again."),
      findsOneWidget,
    );
  });

  testWidgets('offline: Unavailable right now, button disabled', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final gateway = FakePurchaseGateway()..available = false;
    final iap = IapService(storage: storage, gateway: gateway);
    addTearDown(iap.dispose);
    await iap.start();
    await iap.loadProduct();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, iap: iap),
      ),
    );
    await openSheet(tester);
    expect(find.text('Unavailable right now'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Unavailable right now'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    // The game still works: the start button is there and enabled.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('LIGHTS OUT →'), findsOneWidget);
  });

  testWidgets('without IAP wired in, the sheet says Unavailable', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
    await openSheet(tester);
    expect(find.text('Unavailable right now'), findsOneWidget);
  });

  testWidgets('Restore purchase in the sheet restores Remove Ads', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 667));
    final storage = await makeStorage();
    final (:iap, :gateway) = await makeIap(tester, storage);
    gateway.restoreReplay = [purchase(StorePurchaseStatus.restored)];
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(storage: storage, iap: iap),
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('Restore purchase'));
    await tester.pumpAndSettle();
    expect(storage.adsRemoved, isTrue);
    expect(find.text('Thank you! CLEAN AIR is active.'), findsOneWidget);
  });

  group('Setup sheet', () {
    Future<(IapService, FakePurchaseGateway)> openSetup(
      WidgetTester tester,
      storage,
    ) async {
      useScreen(tester, const Size(375, 667));
      final (:iap, :gateway) = await makeIap(tester, storage);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(storage: storage, iap: iap),
        ),
      );
      await tester.tap(find.text('SETUP'));
      await tester.pumpAndSettle();
      return (iap, gateway);
    }

    testWidgets('Restore Purchases: nothing to restore', (tester) async {
      final storage = await makeStorage();
      final (_, gateway) = await openSetup(tester, storage);
      gateway.restoreReplay = [];
      await tester.tap(find.text('Restore Purchases'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing to restore.'), findsOneWidget);
      expect(storage.adsRemoved, isFalse);
    });

    testWidgets('Restore Purchases: restored', (tester) async {
      final storage = await makeStorage();
      final (_, gateway) = await openSetup(tester, storage);
      gateway.restoreReplay = [purchase(StorePurchaseStatus.restored)];
      await tester.tap(find.text('Restore Purchases'));
      await tester.pumpAndSettle();
      expect(find.text('Purchase restored.'), findsOneWidget);
      expect(storage.adsRemoved, isTrue);
    });

    testWidgets('Restore Purchases: error', (tester) async {
      final storage = await makeStorage();
      final (_, gateway) = await openSetup(tester, storage);
      gateway.restoreError = StateError('offline');
      await tester.tap(find.text('Restore Purchases'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't restore. Try again later."), findsOneWidget);
      expect(storage.adsRemoved, isFalse);
    });

    testWidgets('no Restore row when purchases are not wired in', (
      tester,
    ) async {
      useScreen(tester, const Size(375, 667));
      final storage = await makeStorage();
      await tester.pumpWidget(MaterialApp(home: HomeScreen(storage: storage)));
      await tester.tap(find.text('SETUP'));
      await tester.pumpAndSettle();
      expect(find.text('Restore Purchases'), findsNothing);
    });

    testWidgets('debug rows reset the purchase and all progress', (
      tester,
    ) async {
      final storage = await makeStorage({'adsRemoved': true, 'bestScore': 700});
      await openSetup(tester, storage);
      await tester.ensureVisible(find.text('Debug: reset purchase'));
      await tester.tap(find.text('Debug: reset purchase'));
      await tester.pumpAndSettle();
      expect(storage.adsRemoved, isFalse);
      expect(storage.bestScore, 700);

      await tester.ensureVisible(find.text('Debug: reset all progress'));
      await tester.tap(find.text('Debug: reset all progress'));
      await tester.pumpAndSettle();
      expect(storage.bestScore, 0);
    });
  });
}
