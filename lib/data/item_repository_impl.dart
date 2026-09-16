import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/item.dart';
import '../domain/item_repository.dart';
import 'database/app_database.dart';

/// [ItemRepository] の Drift 実装。
///
/// **この層は `Clock` を持たない**(`docs/architecture.md`「データレイヤー」)。
/// 書き込み時刻はすべて呼び出し元から引数で受け取る。
final class ItemRepositoryImpl implements ItemRepository {
  /// [db] の `items` テーブルを読み書きする。
  ItemRepositoryImpl(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  @override
  Stream<List<Item>> watchAll() {
    final query = _db.select(_db.items)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        // sort_order は削除後に番号を再利用しうる。第 2 キーを固定して
        // 並びが実行ごとに揺れないようにする。
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<Item> add(String name, {required DateTime now}) {
    final timestamp = _toEpochMillis(now);
    // 採番と INSERT を同じトランザクションに入れる。分けると同時追加で
    // sort_order が衝突する。
    return _db.transaction(() async {
      final maximum = _db.items.sortOrder.max();
      final aggregate = await (_db.selectOnly(
        _db.items,
      )..addColumns([maximum])).getSingle();
      final currentMax = aggregate.read(maximum);

      final row = ItemRow(
        id: _uuid.v4(),
        name: name,
        lastDoneAt: null,
        createdAt: timestamp,
        updatedAt: timestamp,
        sortOrder: currentMax == null ? 0 : currentMax + 1,
      );
      await _db.into(_db.items).insert(row);
      return _toDomain(row);
    });
  }

  @override
  Future<void> rename(ItemId id, String name, {required DateTime now}) async {
    // last_done_at を companion に載せない = 変更しない。
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(name: Value(name), updatedAt: Value(_toEpochMillis(now))),
    );
  }

  @override
  Future<void> delete(ItemId id) async {
    await (_db.delete(_db.items)..where((t) => t.id.equals(id.value))).go();
  }

  @override
  Future<void> markDone(ItemId id, DateTime doneAt) async {
    final timestamp = _toEpochMillis(doneAt);
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(lastDoneAt: Value(timestamp), updatedAt: Value(timestamp)),
    );
  }

  @override
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  }) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(
        // previous が null なら未実施へ戻す。Value(null) が NULL を書く。
        lastDoneAt: Value(previous == null ? null : _toEpochMillis(previous)),
        // 取り消しも書き込みなので updated_at は前進させる(巻き戻さない)。
        updatedAt: Value(_toEpochMillis(now)),
      ),
    );
  }
}

/// ドメインの日時を保存形式(UTC のエポックミリ秒)へ変換する。
int _toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// 保存形式をドメインの日時(UTC)へ戻す。
DateTime _toUtc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

/// Drift の行をドメインモデルへ変換する。
Item _toDomain(ItemRow row) {
  final lastDoneAt = row.lastDoneAt;
  return Item(
    id: ItemId(row.id),
    name: row.name,
    lastDoneAt: lastDoneAt == null ? null : _toUtc(lastDoneAt),
    createdAt: _toUtc(row.createdAt),
    updatedAt: _toUtc(row.updatedAt),
    sortOrder: row.sortOrder,
  );
}
