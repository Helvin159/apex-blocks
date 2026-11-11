import 'package:apexblocks/services/haptics_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a placement without a clear is one light impact', () {
    expect(hapticStepsFor(linesCleared: 0, comboAfter: 0), [
      (kind: HapticKind.light, delayMs: 0),
    ]);
  });

  test('any clear is one medium impact', () {
    for (final combo in [1, 2]) {
      expect(hapticStepsFor(linesCleared: 1, comboAfter: combo), [
        (kind: HapticKind.medium, delayMs: 0),
      ]);
    }
    expect(hapticStepsFor(linesCleared: 3, comboAfter: 1), [
      (kind: HapticKind.medium, delayMs: 0),
    ]);
  });

  test('a clear with combo 3+ adds the rumble strip', () {
    for (final combo in [3, 4, 9]) {
      final steps = hapticStepsFor(linesCleared: 1, comboAfter: combo);
      expect(steps.first, (kind: HapticKind.medium, delayMs: 0));
      final rumble = steps.skip(1).toList();
      expect(rumble.length, rumbleLightCount);
      expect(rumble.every((s) => s.kind == HapticKind.light), isTrue);
      expect(rumble.map((s) => s.delayMs), [
        for (var i = 1; i <= rumbleLightCount; i++) i * rumbleGapMs,
      ]);
    }
    expect(rumbleLightCount, 4);
    expect(rumbleGapMs, 45);
  });

  test('a combo without a clear never rumbles', () {
    expect(hapticStepsFor(linesCleared: 0, comboAfter: 5).length, 1);
  });

  testWidgets('fires the platform haptics and respects the enabled flag', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final haptics = HapticsService();
    haptics.onPlacement(linesCleared: 0, comboAfter: 0);
    haptics.onPlacement(linesCleared: 1, comboAfter: 3);
    await tester.pump(const Duration(milliseconds: rumbleGapMs * 5));
    expect(calls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      ...List.filled(rumbleLightCount, 'HapticFeedbackType.lightImpact'),
    ]);

    calls.clear();
    haptics.enabled.value = false;
    haptics.onPlacement(linesCleared: 1, comboAfter: 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(calls, isEmpty);
    haptics.dispose();
  });
}
