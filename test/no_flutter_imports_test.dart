import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/game has no package:flutter imports', () {
    final files = Directory('lib/game')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        f.readAsStringSync().contains('package:flutter'),
        isFalse,
        reason: '${f.path} imports Flutter',
      );
    }
  });
}
