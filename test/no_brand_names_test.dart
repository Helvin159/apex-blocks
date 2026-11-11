import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ uses no real series, team, circuit or brand names', () {
    final banned = RegExp(
      r'formula\s*(1|one)|\bF1\b|grand\s*prix|ferrari|mclaren|red\s*bull|'
      r'mercedes|pirelli|monaco|silverstone|monza|suzuka|spa-francorchamps',
      caseSensitive: false,
    );
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (banned.hasMatch(lines[i])) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty);
  });
}
