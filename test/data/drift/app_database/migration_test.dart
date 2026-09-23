// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:lastwhen/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            // AppDatabase() は本番用(実ファイルを開く)なので、テスト用の
            // `forTesting` でスキーマ検証用の接続を渡す。
            final db = AppDatabase.forTesting(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // v1 → v2 は「記録済みの最終実施日を done_logs へ 1 行として移す」データ移送を
  // 伴うため、スキーマの一致だけでなくデータの中身も検証する(design.md 判断9)。
  test('v1 から v2 への移行で items は変わらず done_logs に履歴が移る', () async {
    final oldItemsData = <v1.ItemsData>[
      const v1.ItemsData(
        id: 'item-done-1',
        name: '記録済み1',
        lastDoneAt: 1000,
        createdAt: 100,
        updatedAt: 1000,
        sortOrder: 0,
      ),
      const v1.ItemsData(
        id: 'item-done-2',
        name: '記録済み2',
        lastDoneAt: 2000,
        createdAt: 200,
        updatedAt: 2000,
        sortOrder: 1,
      ),
      const v1.ItemsData(
        id: 'item-never-done',
        name: '未実施',
        lastDoneAt: null,
        createdAt: 300,
        updatedAt: 300,
        sortOrder: 2,
      ),
    ];
    final expectedNewItemsData = <v2.ItemsData>[
      const v2.ItemsData(
        id: 'item-done-1',
        name: '記録済み1',
        lastDoneAt: 1000,
        createdAt: 100,
        updatedAt: 1000,
        sortOrder: 0,
      ),
      const v2.ItemsData(
        id: 'item-done-2',
        name: '記録済み2',
        lastDoneAt: 2000,
        createdAt: 200,
        updatedAt: 2000,
        sortOrder: 1,
      ),
      const v2.ItemsData(
        id: 'item-never-done',
        name: '未実施',
        lastDoneAt: null,
        createdAt: 300,
        updatedAt: 300,
        sortOrder: 2,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.forTesting,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.items, oldItemsData);
      },
      validateItems: (newDb) async {
        // items 側は全列不変。
        expect(expectedNewItemsData, await newDb.select(newDb.items).get());

        // done_logs には記録済みの 2 件だけが移送され、last_done_at と一致する。
        final logs = await newDb.select(newDb.doneLogs).get();
        expect(logs, hasLength(2));

        final byItemId = {for (final log in logs) log.itemId: log.doneAt};
        expect(byItemId['item-done-1'], 1000);
        expect(byItemId['item-done-2'], 2000);

        // 未実施の項目には履歴が作られない。
        expect(byItemId.containsKey('item-never-done'), isFalse);
      },
    );
  });
}
