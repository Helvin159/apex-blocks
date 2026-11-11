import 'package:apexblocks/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clear variant is the combo clamped to 1..6', () {
    expect(clearVariant(0), 1);
    expect(clearVariant(1), 1);
    expect(clearVariant(2), 2);
    expect(clearVariant(3), 3);
    expect(clearVariant(6), 6);
    expect(clearVariant(7), 6);
    expect(clearVariant(40), 6);
    expect(clearVariantCount, 6);
  });

  test(
    'is enabled by default; the silent service never touches plugins',
    () async {
      final audio = AudioService.silent();
      expect(audio.enabled.value, isTrue);
      await audio.init();
      audio
        ..playPlace()
        ..playClear(3)
        ..playLight()
        ..playPassbyFull()
        ..playPassbyShort();
      await audio.dispose();
    },
  );
}
