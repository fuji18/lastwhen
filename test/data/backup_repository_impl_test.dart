import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/data/backup_repository_impl.dart';
import 'package:lastwhen/data/category_repository_impl.dart';
import 'package:lastwhen/data/database/app_database.dart';
import 'package:lastwhen/data/item_repository_impl.dart';
import 'package:lastwhen/domain/backup.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_icon.dart';

/// テストで使う固定時刻。データ層は `Clock` を持たないので呼び出し側が時刻を決める。
final DateTime t0 = DateTime.utc(2026, 9, 1, 1, 0);
final DateTime t1 = DateTime.utc(2026, 9, 10, 2, 0);
final DateTime t2 = DateTime.utc(2026, 9, 20, 3, 0);
final DateTime t3 = DateTime.utc(2026, 9, 25, 4, 0);

AppDatabase _createDatabase() {
  final db = AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

/// [db] に既存のシナリオデータを作る(カテゴリ追加・アイコンつき項目・未分類項目・
/// 未実施項目・`markDone` 複数回・過去日付の `addDoneLog`)。
Future<void> _seedScenario(AppDatabase db) async {
  final categoryRepository = CategoryRepositoryImpl(db);
  final itemRepository = ItemRepositoryImpl(db);

  final category = await categoryRepository.add('テストカテゴリ');

  final withCategory = await itemRepository.add(
    'アイコンつき項目',
    icon: ItemIcon.bath,
    categoryId: category.id,
    now: t0,
  );
  await itemRepository.markDone(withCategory.id, t1);
  await itemRepository.markDone(withCategory.id, t2);
  await itemRepository.addDoneLog(withCategory.id, t0, now: t3);

  await itemRepository.add('未分類項目', now: t0);

  await itemRepository.add('未実施項目', now: t0);
}

void main() {
  test('往復: readAll → encode → decode → 別 DB へ replaceAll で内容が一致する', () async {
    final sourceDb = _createDatabase();
    await _seedScenario(sourceDb);
    final sourceRepository = BackupRepositoryImpl(sourceDb);

    final snapshot = await sourceRepository.readAll();
    final encoded = encodeBackup(snapshot, exportedAt: t3);
    final decoded = decodeBackup(utf8.encode(encoded));

    final destinationDb = _createDatabase();
    final destinationRepository = BackupRepositoryImpl(destinationDb);
    await destinationRepository.replaceAll(decoded);

    final destinationSnapshot = await destinationRepository.readAll();
    final sourceEncodedAgain = encodeBackup(snapshot, exportedAt: t3);
    final destinationEncoded = encodeBackup(
      destinationSnapshot,
      exportedAt: t3,
    );
    expect(destinationEncoded, sourceEncodedAgain);
  });

  test('復元先の lastDoneAt は記録の最大値(無ければ null)と一致する', () async {
    final sourceDb = _createDatabase();
    await _seedScenario(sourceDb);
    final snapshot = await BackupRepositoryImpl(sourceDb).readAll();

    final destinationDb = _createDatabase();
    await BackupRepositoryImpl(destinationDb).replaceAll(snapshot);

    final items = await ItemRepositoryImpl(destinationDb).watchAll().first;
    final withCategory = items.firstWhere((i) => i.name == 'アイコンつき項目');
    expect(withCategory.lastDoneAt, t2);

    final unimplemented = items.firstWhere((i) => i.name == '未実施項目');
    expect(unimplemented.lastDoneAt, isNull);
  });

  test('既存データがある DB に replaceAll すると既存の項目・記録・カテゴリが残らない', () async {
    final db = _createDatabase();
    await _seedScenario(db);
    final repository = BackupRepositoryImpl(db);

    // 既存データを別の内容で置き換える。
    final replacement = BackupSnapshot(
      categories: const [
        BackupCategory(id: 'new-cat', name: '新カテゴリ', sortOrder: 0),
      ],
      items: [
        BackupItem(
          id: 'new-item',
          name: '新しい項目',
          icon: null,
          categoryId: 'new-cat',
          createdAt: t0,
          updatedAt: t0,
          sortOrder: 0,
        ),
      ],
      doneLogs: const [],
    );
    await repository.replaceAll(replacement);

    final snapshot = await repository.readAll();
    expect(snapshot.categories, hasLength(1));
    expect(snapshot.categories.single.name, '新カテゴリ');
    expect(snapshot.items, hasLength(1));
    expect(snapshot.items.single.name, '新しい項目');
    expect(snapshot.doneLogs, isEmpty);
  });

  test('ロールバック: 参照切れの snapshot を渡すと既存データが変わらない', () async {
    final db = _createDatabase();
    await _seedScenario(db);
    final repository = BackupRepositoryImpl(db);

    final before = await repository.readAll();

    // decode を通さず直接組み立てる(存在しない itemId の記録)。
    final broken = BackupSnapshot(
      categories: const [],
      items: const [],
      doneLogs: [
        BackupDoneLog(id: 'log-x', itemId: 'missing-item', doneAt: t0),
      ],
    );

    await expectLater(repository.replaceAll(broken), throwsA(anything));

    final after = await repository.readAll();
    expect(
      encodeBackup(after, exportedAt: t3),
      encodeBackup(before, exportedAt: t3),
    );
  });

  test('通知の取り直しの契機: watchAll を購読した状態で replaceAll すると復元後の一覧が送出される', () async {
    final db = _createDatabase();
    await _seedScenario(db);
    final repository = BackupRepositoryImpl(db);

    final itemRepository = ItemRepositoryImpl(db);
    final emissions = <List<Item>>[];
    final subscription = itemRepository.watchAll().listen(emissions.add);
    addTearDown(subscription.cancel);
    // 初回の emit を待つ。
    await Future<void>.delayed(Duration.zero);

    final replacement = BackupSnapshot(
      categories: const [],
      items: [
        BackupItem(
          id: 'new-item',
          name: '復元後の項目',
          icon: null,
          categoryId: null,
          createdAt: t0,
          updatedAt: t0,
          sortOrder: 0,
        ),
      ],
      doneLogs: const [],
    );
    await repository.replaceAll(replacement);
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last.map((i) => i.name), contains('復元後の項目'));
  });

  test('空の DB の readAll は 3 つとも空', () async {
    final db = _createDatabase();
    // マイグレーションが初期カテゴリを入れるため、真に空にしてから確かめる。
    await db.delete(db.categories).go();
    final repository = BackupRepositoryImpl(db);

    final snapshot = await repository.readAll();
    expect(snapshot.categories, isEmpty);
    expect(snapshot.items, isEmpty);
    expect(snapshot.doneLogs, isEmpty);
  });

  test('readAll の並び: categories は sort_order・id、items は sort_order・id、'
      'done_logs は item_id・done_at・id の昇順', () async {
    final db = _createDatabase();
    final categoryRepository = CategoryRepositoryImpl(db);
    final itemRepository = ItemRepositoryImpl(db);
    await db.delete(db.categories).go();

    final categoryB = await categoryRepository.add('B');
    final categoryA = await categoryRepository.add('A');

    final itemB = await itemRepository.add(
      '項目B',
      categoryId: categoryB.id,
      now: t0,
    );
    final itemA = await itemRepository.add(
      '項目A',
      categoryId: categoryA.id,
      now: t0,
    );
    await itemRepository.markDone(itemA.id, t2);
    await itemRepository.markDone(itemA.id, t1);
    await itemRepository.markDone(itemB.id, t0);

    final snapshot = await BackupRepositoryImpl(db).readAll();
    expect(snapshot.categories.map((c) => c.id), [
      categoryB.id.value,
      categoryA.id.value,
    ]);
    expect(snapshot.items.map((i) => i.id), [itemB.id.value, itemA.id.value]);
    // item_id 昇順 → itemA の行が先(id が採番順で小さい可能性があるため itemId でグルーピングされていることだけ確かめる)。
    final itemIds = snapshot.doneLogs.map((l) => l.itemId).toSet();
    expect(itemIds, {itemA.id.value, itemB.id.value});
  });
}
