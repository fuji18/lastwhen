import 'package:drift/drift.dart';

import '../domain/backup.dart';
import '../domain/backup_repository.dart';
import 'database/app_database.dart';

/// [BackupRepository] の Drift 実装。
///
/// **Drift の型付き API だけを使う**(`customStatement` で書かない)。型付き API で
/// なければ `ItemRepositoryImpl.watchAll()` の購読に変更が通知されず、`replaceAll`
/// の後に通知の張り直しが起きない(design.md 判断9)。
final class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<BackupSnapshot> readAll() {
    return _db.transaction(() async {
      final categoryRows =
          await (_db.select(_db.categories)..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.id),
              ]))
              .get();
      final itemRows =
          await (_db.select(_db.items)..orderBy([
                (t) => OrderingTerm(expression: t.sortOrder),
                (t) => OrderingTerm(expression: t.id),
              ]))
              .get();
      final doneLogRows =
          await (_db.select(_db.doneLogs)..orderBy([
                (t) => OrderingTerm(expression: t.itemId),
                (t) => OrderingTerm(expression: t.doneAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
              .get();

      return BackupSnapshot(
        categories: [for (final row in categoryRows) _categoryOf(row)],
        items: [for (final row in itemRows) _itemOf(row)],
        doneLogs: [for (final row in doneLogRows) _doneLogOf(row)],
      );
    });
  }

  @override
  Future<void> replaceAll(BackupSnapshot snapshot) {
    return _db.transaction(() async {
      await _db.delete(_db.doneLogs).go();
      await _db.delete(_db.items).go();
      await _db.delete(_db.categories).go();

      final maxDoneAtByItemId = <String, int>{};
      for (final log in snapshot.doneLogs) {
        final millis = _toEpochMillis(log.doneAt);
        final current = maxDoneAtByItemId[log.itemId];
        if (current == null || millis > current) {
          maxDoneAtByItemId[log.itemId] = millis;
        }
      }

      await _db.batch((b) {
        b.insertAll(_db.categories, [
          for (final category in snapshot.categories)
            CategoryRow(
              id: category.id,
              name: category.name,
              sortOrder: category.sortOrder,
            ),
        ]);
        b.insertAll(_db.items, [
          for (final item in snapshot.items)
            ItemRow(
              id: item.id,
              name: item.name,
              lastDoneAt: maxDoneAtByItemId[item.id],
              createdAt: _toEpochMillis(item.createdAt),
              updatedAt: _toEpochMillis(item.updatedAt),
              sortOrder: item.sortOrder,
              icon: item.icon,
              categoryId: item.categoryId,
            ),
        ]);
        b.insertAll(_db.doneLogs, [
          for (final log in snapshot.doneLogs)
            DoneLogRow(
              id: log.id,
              itemId: log.itemId,
              doneAt: _toEpochMillis(log.doneAt),
            ),
        ]);
      });
    });
  }
}

int _toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime _toUtc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

BackupCategory _categoryOf(CategoryRow row) =>
    BackupCategory(id: row.id, name: row.name, sortOrder: row.sortOrder);

BackupItem _itemOf(ItemRow row) => BackupItem(
  id: row.id,
  name: row.name,
  icon: row.icon,
  categoryId: row.categoryId,
  createdAt: _toUtc(row.createdAt),
  updatedAt: _toUtc(row.updatedAt),
  sortOrder: row.sortOrder,
);

BackupDoneLog _doneLogOf(DoneLogRow row) =>
    BackupDoneLog(id: row.id, itemId: row.itemId, doneAt: _toUtc(row.doneAt));
