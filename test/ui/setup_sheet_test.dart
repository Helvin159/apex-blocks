import 'dart:io';

import 'package:apexblocks/config/links.dart';
import 'package:apexblocks/services/audio_service.dart';
import 'package:apexblocks/services/haptics_service.dart';
import 'package:apexblocks/ui/home_screen.dart';
import 'package:apexblocks/ui/setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<List<Uri>> pumpSetup(
  WidgetTester tester, {
  UrlOpener? openUrl,
  bool showDebugTools = true,
  bool realAds = false,
}) async {
  useScreen(tester, const Size(375, 812));
  final storage = await makeStorage();
  final opened = <Uri>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SetupSheet(
          storage: storage,
          audio: AudioService.silent(),
          haptics: HapticsService.silent(),
          openUrl:
              openUrl ??
              (url) async {
                opened.add(url);
                return true;
              },
          showDebugTools: showDebugTools,
          realAds: realAds,
        ),
      ),
    ),
  );
  return opened;
}

void main() {
  test('the links point at the published pages', () {
    expect(
      privacyPolicyUrl,
      'https://helvin159.github.io/apex-blocks/privacy.html',
    );
    expect(supportUrl, 'https://helvin159.github.io/apex-blocks/support.html');
  });

  testWidgets('Privacy policy and Help & support open their pages', (
    tester,
  ) async {
    final opened = await pumpSetup(tester);
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
    expect(opened, [Uri.parse(privacyPolicyUrl), Uri.parse(supportUrl)]);
    expect(find.byType(SelectableText), findsNothing);
  });

  for (final (name, opener) in <(String, UrlOpener)>[
    ('returns false', (_) async => false),
    ('throws', (_) async => throw StateError('no browser')),
  ]) {
    testWidgets('a link that cannot open shows its address ($name)', (
      tester,
    ) async {
      await pumpSetup(tester, openUrl: opener);
      await tester.tap(find.text('Help & support'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SelectableText, supportUrl), findsOneWidget);
      expect(find.text(privacyPolicyUrl), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the version row flags test ads, and only test ads', (
    tester,
  ) async {
    await pumpSetup(tester);
    expect(find.text('Test ads'), findsOneWidget);
    await pumpSetup(tester, realAds: true);
    expect(find.text('Test ads'), findsNothing);
    expect(find.text(appVersion), findsOneWidget);
  });

  testWidgets('debug rows are absent when debug tools are off', (tester) async {
    await pumpSetup(tester, showDebugTools: false);
    expect(find.textContaining('Debug:'), findsNothing);
    await pumpSetup(tester);
    await tester.ensureVisible(find.text('Debug: reset purchase'));
    expect(find.textContaining('Debug:'), findsNWidgets(2));
  });

  testWidgets('the Pole card long-press shortcut is off without debug tools', (
    tester,
  ) async {
    useScreen(tester, const Size(375, 812));
    final storage = await makeStorage();
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(storage: storage, showDebugTools: false)),
    );
    await tester.longPress(find.text('POLE'));
    await tester.pump();
    expect(storage.careerPoints, 0);

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(storage: storage, showDebugTools: true)),
    );
    await tester.longPress(find.text('POLE'));
    await tester.pump();
    expect(storage.careerPoints, 1000);
  });

  group('release safety', () {
    test('debug-only storage tools are only used behind kDebugMode', () {
      final tools = RegExp(
        r'debugAddCareerPoints|debugResetPurchase|debugResetAllProgress',
      );
      final unguarded = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('storage_service.dart')) continue;
        final text = f.readAsStringSync();
        if (tools.hasMatch(text) && !text.contains('kDebugMode')) {
          unguarded.add(f.path);
        }
      }
      expect(unguarded, isEmpty);
    });

    test('every debug storage method refuses to run outside debug', () {
      final text = File('lib/services/storage_service.dart').readAsStringSync();
      final methods = RegExp(
        r'Future<void> (debug\w+)\([^)]*\)[^{]*\{([^}]*)\}',
      ).allMatches(text);
      expect(methods, isNotEmpty);
      for (final m in methods) {
        expect(
          m.group(2),
          contains('if (!kDebugMode) return;'),
          reason: '${m.group(1)} must be a no-op in release builds',
        );
      }
    });

    test('the default for debug tools is kDebugMode, never true', () {
      for (final path in [
        'lib/ui/setup_sheet.dart',
        'lib/ui/home_screen.dart',
      ]) {
        final text = File(path).readAsStringSync();
        expect(
          text,
          contains('this.showDebugTools = kDebugMode'),
          reason: path,
        );
      }
    });
  });

  test('appVersion matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    expect(appVersion, version);
    expect(version, '1.0.0+7');
  });
}
