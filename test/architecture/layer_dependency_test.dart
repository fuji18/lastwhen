import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('domain は Flutter / Drift / Riverpod に依存しない', () {
    final files = Directory('lib/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final banned in const [
        "import 'package:flutter/",
        "import 'package:drift/",
        "import 'package:flutter_riverpod/",
      ]) {
        expect(src, isNot(contains(banned)), reason: f.path);
      }
    }
  });
}
