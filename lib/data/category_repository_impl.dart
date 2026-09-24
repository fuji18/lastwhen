import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/category.dart';
import '../domain/category_repository.dart';
import 'database/app_database.dart';

/// [CategoryRepository] の Drift 実装。
///
/// **この層は `Clock` を持たない**(`docs/architecture.md`「データレイヤー」)。カテゴリは
/// 時刻の列を持たないため、書き込みは `now` を取らない。
final class CategoryRepositoryImpl implements CategoryRepository {
  /// [db] の `categories` テーブルを読み書きする。
  CategoryRepositoryImpl(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  @override
  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<Category> add(String name) {
    // 採番と INSERT を同じトランザクションに入れる。分けると同時追加で
    // sort_order が衝突する。
    return _db.transaction(() async {
      final maximum = _db.categories.sortOrder.max();
      final aggregate = await (_db.selectOnly(
        _db.categories,
      )..addColumns([maximum])).getSingle();
      final currentMax = aggregate.read(maximum);

      final row = CategoryRow(
        id: _uuid.v4(),
        name: name,
        sortOrder: currentMax == null ? 0 : currentMax + 1,
      );
      await _db.into(_db.categories).insert(row);
      return _toDomain(row);
    });
  }

  @override
  Future<void> rename(CategoryId id, String name) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id.value)))
        .write(CategoriesCompanion(name: Value(name)));
  }

  @override
  Future<void> delete(CategoryId id) async {
    // 1 トランザクションで次の 2 文を順に実行する。外部キーの SET NULL があっても
    // 明示的に書く。Drift の型付き update を通すことで items の購読
    // (ItemRepository.watchAll)に変更が確実に通知される。items.updated_at は
    // 動かさない(ユーザーが項目を編集したわけではない。now も持たない)。
    await _db.transaction(() async {
      await (_db.update(_db.items)..where((t) => t.categoryId.equals(id.value)))
          .write(const ItemsCompanion(categoryId: Value(null)));
      await (_db.delete(
        _db.categories,
      )..where((t) => t.id.equals(id.value))).go();
    });
  }
}

/// Drift の行をドメインモデルへ変換する。
Category _toDomain(CategoryRow row) =>
    Category(id: CategoryId(row.id), name: row.name, sortOrder: row.sortOrder);
