import 'dart:math';

import 'package:apexblocks/ui/game_screen.dart';
import 'package:apexblocks/ui/home_screen.dart';
import 'package:apexblocks/ui/start_lights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

Future<RecordingAudio> pumpHome(WidgetTester tester) async {
  useScreen(tester, const Size(375, 667));
  final storage = await makeStorage();
  final audio = RecordingAudio();
  await tester.pumpWidget(
    MaterialApp(
      home: HomeScreen(storage: storage, audio: audio, random: Random(3)),
    ),
  );
  return audio;
}

int lit(WidgetTester tester) =>
    tester.widget<StartLightGantry>(find.byType(StartLightGantry)).litPods;

const step = Duration(milliseconds: lightStepMs);

void main() {
  testWidgets('idle: all pods unlit, no sound', (tester) async {
    final audio = await pumpHome(tester);
    expect(lit(tester), 0);
    expect(audio.events, isEmpty);
  });

  testWidgets(
    'pods light one at a time with a beep each, hold, lights out, go',
    (tester) async {
      final audio = await pumpHome(tester);
      await tester.tap(find.text('LIGHTS OUT →'));
      await tester.pump();
      expect(lit(tester), 1);
      expect(audio.events, ['light']);

      for (var n = 2; n <= gantryPods; n++) {
        await tester.pump(step - const Duration(milliseconds: 1));
        expect(lit(tester), n - 1);
        await tester.pump(const Duration(milliseconds: 1));
        expect(lit(tester), n);
      }
      expect(audio.events, List.filled(gantryPods, 'light'));

      // Held for at least holdMinMs: still lit, no whoosh, no race.
      await tester.pump(const Duration(milliseconds: holdMinMs - 1));
      expect(lit(tester), gantryPods);
      expect(audio.events, isNot(contains('passby_full')));
      expect(find.byType(GameScreen), findsNothing);

      // By holdMaxMs the lights are out with the whoosh.
      await tester.pump(
        const Duration(milliseconds: holdMaxMs - holdMinMs + 1),
      );
      expect(lit(tester), 0);
      expect(audio.events.last, 'passby_full');
      expect(find.byType(GameScreen), findsNothing);

      // The race starts after the beat.
      await tester.pump(const Duration(milliseconds: goDelayMs));
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(audio.events.where((e) => e == 'passby_full').length, 1);
    },
  );

  testWidgets('tapping anywhere mid-sequence skips straight to the race', (
    tester,
  ) async {
    final audio = await pumpHome(tester);
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump(step * 2);
    expect(lit(tester), 3);

    await tester.tapAt(const Offset(100, 300));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    // The pass-by plays on the skip, and no further beeps follow.
    expect(audio.events, [...List.filled(3, 'light'), 'passby_full']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the LIGHTS OUT button cannot start a second sequence', (
    tester,
  ) async {
    final audio = await pumpHome(tester);
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump(step);
    // The second tap lands on the skip layer, not the button.
    await tester.tap(find.text('LIGHTS OUT →'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    expect(audio.events.where((e) => e == 'light').length, 2);
  });

  testWidgets('the gantry is unlit again after coming back from the race', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump();
    await tester.tapAt(const Offset(100, 300));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GARAGE'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(lit(tester), 0);

    // And it can run again.
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump();
    expect(lit(tester), 1);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets('leaving the screen mid-sequence cancels the timers', (
    tester,
  ) async {
    await pumpHome(tester);
    await tester.tap(find.text('LIGHTS OUT →'));
    await tester.pump(step);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });
}
