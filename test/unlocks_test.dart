import 'package:apexblocks/game/unlocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Night Race is always unlocked', () {
    expect(isLiveryUnlocked(0, 0), isTrue);
    expect(unlockedLiveries(0), [0]);
  });

  test('thresholds are inclusive', () {
    expect(isLiveryUnlocked(1, 4999), isFalse);
    expect(isLiveryUnlocked(1, 5000), isTrue);
    expect(isLiveryUnlocked(2, 14999), isFalse);
    expect(isLiveryUnlocked(2, 15000), isTrue);
    expect(unlockedLiveries(5000), [0, 1]);
    expect(unlockedLiveries(15000), [0, 1, 2]);
  });

  test('unknown livery indices are locked', () {
    expect(isLiveryUnlocked(-1, 99999), isFalse);
    expect(isLiveryUnlocked(3, 99999), isFalse);
  });

  test('progress is capped at the target', () {
    expect(liveryProgress(1, 3240), (current: 3240, target: 5000));
    expect(liveryProgress(2, 3240), (current: 3240, target: 15000));
    expect(liveryProgress(1, 9000), (current: 5000, target: 5000));
  });

  test('newlyUnlocked detects crossings', () {
    expect(newlyUnlocked(4990, 4999), isEmpty);
    expect(newlyUnlocked(4990, 5000), [1]);
    expect(newlyUnlocked(5000, 9000), isEmpty);
    expect(newlyUnlocked(14000, 16000), [2]);
    expect(newlyUnlocked(0, 15000), [1, 2]);
  });
}
