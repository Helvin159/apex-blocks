import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// (file, min ms, max ms)
const _expected = <(String, int, int)>[
  ('place.wav', 35, 45),
  ('clear_1.wav', 240, 260),
  ('clear_2.wav', 240, 260),
  ('clear_3.wav', 240, 260),
  ('clear_4.wav', 240, 260),
  ('clear_5.wav', 240, 260),
  ('clear_6.wav', 240, 260),
  ('light.wav', 110, 130),
  ('lights_out.wav', 390, 410),
];

void main() {
  for (final (name, minMs, maxMs) in _expected) {
    test('$name: 44.1 kHz mono 16-bit, right length, peak below -3 dBFS', () {
      final bytes = File('assets/sfx/$name').readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), 44100);
      expect(data.getUint16(34, Endian.little), 16);

      // Walk the chunks to find "data".
      var offset = 12;
      var start = -1;
      var length = 0;
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = data.getUint32(offset + 4, Endian.little);
        if (id == 'data') {
          start = offset + 8;
          length = size;
          break;
        }
        offset += 8 + size;
      }
      expect(start, greaterThan(0), reason: 'data chunk');

      final count = length ~/ 2;
      final ms = count * 1000 / 44100;
      expect(ms, inInclusiveRange(minMs, maxMs));

      var peak = 0;
      for (var i = 0; i < count; i++) {
        peak = max(peak, data.getInt16(start + i * 2, Endian.little).abs());
      }
      final dbfs = 20 * log(peak / 32768) / ln10;
      expect(dbfs, lessThan(-3));
      expect(dbfs, greaterThan(-12), reason: 'not unusably quiet');
      // 5 ms fades: first and last samples are silent.
      expect(data.getInt16(start, Endian.little).abs(), lessThan(100));
      expect(
        data.getInt16(start + (count - 1) * 2, Endian.little).abs(),
        lessThan(100),
      );
    });
  }
}
