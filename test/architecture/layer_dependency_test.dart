import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [directory] 配下の Dart ソースを集める。
Iterable<File> _dartFilesIn(String directory) =>
    Directory(directory)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

/// [directory] 配下のどのファイルにも [banned] が現れないことを検査する。
void _expectNoImports(String directory, List<String> banned) {
  for (final file in _dartFilesIn(directory)) {
    final source = file.readAsStringSync();
    for (final fragment in banned) {
      expect(source, isNot(contains(fragment)), reason: file.path);
    }
  }
}

void main() {
  test('domain は Flutter / Drift / Riverpod に依存しない', () {
    _expectNoImports('lib/domain', const [
      "import 'package:flutter/",
      "import 'package:drift/",
      "import 'package:flutter_riverpod/",
    ]);
  });

  test('ui は data / Drift に依存しない', () {
    // UI が Drift の型や SQL を直接触ると、表示の都合でスキーマが引きずられる
    // (`docs/repository-structure.md`「lib/ui/」)。
    _expectNoImports('lib/ui', const [
      "import 'package:drift/",
      "import 'package:sqlite3/",
      "import 'package:lastwhen/data/",
      "/data/",
    ]);
  });

  test('state は Flutter のウィジェットに依存しない', () {
    // `flutter_riverpod` は許可する。禁止するのは `BuildContext` / `Widget` を
    // 持ち込む `package:flutter/` の直接 import(`docs/architecture.md`「状態管理レイヤー」)。
    _expectNoImports('lib/state', const ["import 'package:flutter/"]);
  });
}
