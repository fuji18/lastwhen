import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/data/database/app_database.dart';
import 'package:lastwhen/data/item_repository_impl.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_repository.dart';

import '../support/fake_item_repository.dart';

/// テストで使う固定時刻。データ層は `Clock` を持たないので呼び出し側が時刻を決める。
final DateTime t0 = DateTime.utc(2026, 9, 15, 1, 0);
final DateTime t1 = DateTime.utc(2026, 9, 15, 2, 0);
final DateTime t2 = DateTime.utc(2026, 9, 16, 3, 0);

void main() {
  _runSharedScenarios('ItemRepositoryImpl', _createRealRepository);
  _runSharedScenarios('FakeItemRepository', _createFakeRepository);

  group('ItemRepositoryImpl(永続化の詳細)', () {
    late AppDatabase db;
    late ItemRepositoryImpl repository;

    setUp(() {
      db = _createDatabase();
      repository = ItemRepositoryImpl(db);
    });

    test('日時は整数で保存される', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);

      final row = await db
          .customSelect(
            'SELECT typeof(last_done_at) AS l, '
            'typeof(created_at) AS c, '
            'typeof(updated_at) AS u FROM items',
          )
          .getSingle();

      expect(row.read<String>('l'), 'integer');
      expect(row.read<String>('c'), 'integer');
      expect(row.read<String>('u'), 'integer');
    });

    test('未実施は NULL で保存される', () async {
      await repository.add('項目', now: t0);

      final row = await db
          .customSelect('SELECT typeof(last_done_at) AS l FROM items')
          .getSingle();

      expect(row.read<String>('l'), 'null');
    });

    test('保存値は UTC のエポックミリ秒そのもの', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);

      final row = await db
          .customSelect('SELECT last_done_at AS l FROM items')
          .getSingle();

      expect(row.read<int>('l'), t1.millisecondsSinceEpoch);
    });

    test('name に NOT NULL 制約がある', () async {
      expect(
        () => db.customStatement(
          "INSERT INTO items (id, name, created_at, updated_at, sort_order) "
          "VALUES ('x', NULL, 0, 0, 0)",
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('watchAll は書き込みのたびに再送出される', () async {
      final expectation = expectLater(
        repository.watchAll(),
        emitsInOrder([isEmpty, hasLength(1), hasLength(2)]),
      );
      // 購読直後の初回フェッチが完了する前に書き込むと、drift 側で初回分と
      // 1 回目の更新が 1 通のイベントに合流してしまう。購読が確立する
      // 猶予を与えてから書き込む。
      await pumpEventQueue();
      await repository.add('項目1', now: t0);
      await repository.add('項目2', now: t0);
      await expectation;
    });

    test('schemaVersion は 1', () {
      expect(db.schemaVersion, 1);
    });
  });
}

AppDatabase _createDatabase() {
  final db = AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      // ウィジェットテストでのエラーを避けるための推奨設定。
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

ItemRepository _createRealRepository() => ItemRepositoryImpl(_createDatabase());

ItemRepository _createFakeRepository() {
  final repository = FakeItemRepository();
  addTearDown(repository.dispose);
  return repository;
}

/// 実装とフェイクの両方に流す共有シナリオ。
void _runSharedScenarios(String label, ItemRepository Function() create) {
  group(label, () {
    late ItemRepository repository;

    setUp(() {
      repository = create();
    });

    test('追加すると未実施の項目が登録順に並ぶ', () async {
      await repository.add('項目1', now: t0);
      await repository.add('項目2', now: t0);
      await repository.add('項目3', now: t0);

      final items = await repository.watchAll().first;

      expect(items.map((e) => e.name), ['項目1', '項目2', '項目3']);
      expect(items.every((e) => e.lastDoneAt == null), isTrue);
      expect(items.map((e) => e.sortOrder), [0, 1, 2]);
      expect(items.every((e) => e.createdAt == t0), isTrue);
      expect(items.every((e) => e.updatedAt == t0), isTrue);
    });

    test('記録すると最終実施日が更新される', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);

      final items = await repository.watchAll().first;

      expect(items.single.lastDoneAt, t1);
      expect(items.single.updatedAt, t1);
    });

    test('未実施の項目を記録して取り消すと未実施に戻る', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);
      await repository.restoreLastDoneAt(item.id, null, now: t2);

      final items = await repository.watchAll().first;

      expect(items.single.lastDoneAt, isNull);
      expect(items.single.updatedAt, t2);
    });

    test('記録済みの項目を取り消すと直前の値に戻る', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);
      await repository.markDone(item.id, t2);
      await repository.restoreLastDoneAt(item.id, t1, now: t2);

      final items = await repository.watchAll().first;

      expect(items.single.lastDoneAt, t1);
    });

    test('名称変更では名前だけが変わる', () async {
      final item = await repository.add('項目', now: t0);
      await repository.markDone(item.id, t1);
      await repository.rename(item.id, '新しい名前', now: t2);

      final items = await repository.watchAll().first;
      final updated = items.single;

      expect(updated.name, '新しい名前');
      expect(updated.lastDoneAt, t1);
      expect(updated.createdAt, t0);
      expect(updated.sortOrder, item.sortOrder);
      expect(updated.updatedAt, t2);
    });

    test('削除しても他の項目に影響しない', () async {
      final item1 = await repository.add('項目1', now: t0);
      final item2 = await repository.add('項目2', now: t0);
      final item3 = await repository.add('項目3', now: t0);

      await repository.delete(item2.id);

      final items = await repository.watchAll().first;

      expect(items.map((e) => e.id), [item1.id, item3.id]);
      expect(items.map((e) => e.name), [item1.name, item3.name]);
      expect(items.map((e) => e.sortOrder), [item1.sortOrder, item3.sortOrder]);
    });

    test('100 件を投入して一覧を取得できる', () async {
      for (var i = 0; i < 100; i++) {
        await repository.add('項目$i', now: t0);
      }

      final items = await repository.watchAll().first;

      expect(items.length, 100);
      expect(items.map((e) => e.sortOrder), List.generate(100, (i) => i));
      expect(items.first.name, '項目0');
      expect(items.last.name, '項目99');
    });

    test('存在しない項目への操作は例外にならない', () async {
      const missing = ItemId('missing');

      await repository.rename(missing, '新しい名前', now: t0);
      await repository.markDone(missing, t0);
      await repository.restoreLastDoneAt(missing, null, now: t0);
      await repository.delete(missing);

      final items = await repository.watchAll().first;
      expect(items, isEmpty);
    });
  });
}
