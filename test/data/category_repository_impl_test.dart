import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/data/category_repository_impl.dart';
import 'package:lastwhen/data/database/app_database.dart';
import 'package:lastwhen/data/item_repository_impl.dart';
import 'package:lastwhen/domain/category.dart';

/// テストで使う固定時刻。データ層は `Clock` を持たないので呼び出し側が時刻を決める。
final DateTime t0 = DateTime.utc(2026, 9, 15, 1, 0);

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

void main() {
  late AppDatabase db;
  late CategoryRepositoryImpl repository;
  late ItemRepositoryImpl itemRepository;

  setUp(() {
    db = _createDatabase();
    repository = CategoryRepositoryImpl(db);
    itemRepository = ItemRepositoryImpl(db);
  });

  test('新規 DB には初期4件がこの順で入っている', () async {
    final categories = await repository.watchAll().first;
    expect(categories.map((c) => c.name), ['生活', '健康', '趣味', 'その他']);
    expect(categories.map((c) => c.sortOrder), [0, 1, 2, 3]);
  });

  test('add の sort_order は既存の MAX + 1 になる', () async {
    final category = await repository.add('新しいカテゴリ');
    expect(category.sortOrder, 4);
    final categories = await repository.watchAll().first;
    expect(categories.last.name, '新しいカテゴリ');
    expect(categories.last.sortOrder, 4);
  });

  test('rename すると名前だけ変わり sort_order は変わらない', () async {
    final categories = await repository.watchAll().first;
    final target = categories.first;
    await repository.rename(target.id, '生活習慣');
    final updated = await repository.watchAll().first;
    expect(updated.first.name, '生活習慣');
    expect(updated.first.sortOrder, target.sortOrder);
  });

  test('存在しない id への rename は例外にならない', () async {
    await repository.rename(const CategoryId('missing'), '新しい名前');
    final categories = await repository.watchAll().first;
    expect(categories.map((c) => c.name), ['生活', '健康', '趣味', 'その他']);
  });

  test('delete すると該当項目の categoryId が null になり最終実施日・更新日時・履歴件数は不変', () async {
    final categories = await repository.watchAll().first;
    final target = categories.first;
    final other = categories[1];
    final item = await itemRepository.add('項目', categoryId: target.id, now: t0);
    await itemRepository.markDone(item.id, t0);
    final otherItem = await itemRepository.add(
      '他カテゴリの項目',
      categoryId: other.id,
      now: t0,
    );

    await repository.delete(target.id);

    final items = await itemRepository.watchAll().first;
    final updated = items.firstWhere((i) => i.id == item.id);
    expect(updated.categoryId, isNull);
    expect(updated.lastDoneAt, t0);
    expect(updated.updatedAt, t0);
    expect(updated.recentDoneAts, [t0]);

    final untouched = items.firstWhere((i) => i.id == otherItem.id);
    expect(untouched.categoryId, other.id);
  });

  test('delete 後に ItemRepositoryImpl.watchAll が未分類の項目を再送出する', () async {
    final categories = await repository.watchAll().first;
    final target = categories.first;
    await itemRepository.add('項目', categoryId: target.id, now: t0);

    final expectation = expectLater(
      itemRepository.watchAll(),
      emitsThrough(
        predicate<List<dynamic>>(
          (items) => items.every((i) => i.categoryId == null),
        ),
      ),
    );
    await pumpEventQueue();
    await repository.delete(target.id);
    await expectation;
  });

  test('delete で他のカテゴリは残る', () async {
    final categories = await repository.watchAll().first;
    await repository.delete(categories.first.id);
    final updated = await repository.watchAll().first;
    expect(updated.map((c) => c.name), ['健康', '趣味', 'その他']);
  });

  test('存在しない id への delete は例外にならない', () async {
    await repository.delete(const CategoryId('missing'));
    final categories = await repository.watchAll().first;
    expect(categories, hasLength(4));
  });

  test('reorder で sort_order が渡した順の 0 始まりに振り直される', () async {
    final categories = await repository.watchAll().first;
    final byName = {for (final c in categories) c.name: c.id};
    final newOrder = [
      byName['その他']!,
      byName['生活']!,
      byName['趣味']!,
      byName['健康']!,
    ];

    await repository.reorder(newOrder);

    final updated = await repository.watchAll().first;
    expect(updated.map((c) => c.name), ['その他', '生活', '趣味', '健康']);
    expect(updated.map((c) => c.sortOrder), [0, 1, 2, 3]);
  });

  test('reorder の後に add すると末尾に入る', () async {
    final categories = await repository.watchAll().first;
    final byName = {for (final c in categories) c.name: c.id};
    await repository.reorder([
      byName['その他']!,
      byName['生活']!,
      byName['趣味']!,
      byName['健康']!,
    ]);

    final added = await repository.add('新規');

    expect(added.sortOrder, 4);
    final updated = await repository.watchAll().first;
    expect(updated.last.name, '新規');
    expect(updated.last.sortOrder, 4);
  });

  test('集合が一致しない reorder は ArgumentError で何も変えない', () async {
    final categories = await repository.watchAll().first;
    final ids = categories.map((c) => c.id).toList();

    // (a) 1 件欠けた列
    await expectLater(
      repository.reorder(ids.sublist(0, 3)),
      throwsArgumentError,
    );

    // (b) 存在しない id を含む列
    await expectLater(
      repository.reorder([...ids, const CategoryId('missing')]),
      throwsArgumentError,
    );

    // (c) 重複を含む列
    await expectLater(
      repository.reorder([ids[0], ids[0], ids[1], ids[2]]),
      throwsArgumentError,
    );

    final untouched = await repository.watchAll().first;
    expect(untouched.map((c) => c.name), ['生活', '健康', '趣味', 'その他']);
    expect(untouched.map((c) => c.sortOrder), [0, 1, 2, 3]);
  });

  test('reorder が途中で失敗すると sort_order は元のまま(ロールバック)', () async {
    final categories = await repository.watchAll().first;
    final byName = {for (final c in categories) c.name: c.id};
    final newOrder = [
      byName['その他']!,
      byName['生活']!,
      byName['趣味']!,
      byName['健康']!,
    ];
    final thirdId = newOrder[2].value;

    await db.customStatement('''
CREATE TRIGGER fail_reorder BEFORE UPDATE OF sort_order ON categories
WHEN NEW.id = '$thirdId'
BEGIN SELECT RAISE(ABORT, 'boom'); END
''');

    await expectLater(repository.reorder(newOrder), throwsA(anything));

    final untouched = await repository.watchAll().first;
    expect(untouched.map((c) => c.name), ['生活', '健康', '趣味', 'その他']);
    expect(untouched.map((c) => c.sortOrder), [0, 1, 2, 3]);
  });

  test('reorder 後に watchAll が新しい順を再送出する', () async {
    final categories = await repository.watchAll().first;
    final byName = {for (final c in categories) c.name: c.id};
    final newOrder = [
      byName['その他']!,
      byName['生活']!,
      byName['趣味']!,
      byName['健康']!,
    ];

    final expectation = expectLater(
      repository.watchAll(),
      emitsThrough(
        predicate<List<Category>>(
          (list) =>
              list.map((c) => c.name).toList().join(',') == 'その他,生活,趣味,健康',
        ),
      ),
    );
    await pumpEventQueue();
    await repository.reorder(newOrder);
    await expectation;
  });
}
