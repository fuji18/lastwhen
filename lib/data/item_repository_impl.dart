import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/baseline_interval.dart' show recentDoneAtsLimit;
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
    // done_logs は常に items と同じトランザクションで書かれる(markDone /
    // restoreLastDoneAt)。そのため items の変更通知だけを契機にすれば
    // 履歴の変化も取りこぼさない。
    return query.watch().asyncMap((rows) async {
      final recentDoneAtsByItem = await _recentDoneAtsByItem();
      return rows
          .map(
            (row) => _toDomain(
              row,
              recentDoneAtsByItem[row.id] ?? const <DateTime>[],
            ),
          )
          .toList(growable: false);
    });
  }

  /// 全項目の直近 [recentDoneAtsLimit] 件を**1 本の SQL**でまとめて取る(N+1 にしない)。
  Future<Map<String, List<DateTime>>> _recentDoneAtsByItem() async {
    final rows = await _db
        .customSelect(
          '''
SELECT item_id, done_at FROM (
  SELECT item_id, done_at,
         ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY done_at DESC, rowid DESC) AS rn
  FROM done_logs
) WHERE rn <= ?
ORDER BY item_id, done_at DESC, rn
''',
          variables: [Variable.withInt(recentDoneAtsLimit)],
          readsFrom: {_db.doneLogs},
        )
        .get();

    final result = <String, List<DateTime>>{};
    for (final row in rows) {
      final itemId = row.read<String>('item_id');
      final doneAt = _toUtc(row.read<int>('done_at'));
      (result[itemId] ??= <DateTime>[]).add(doneAt);
    }
    return result;
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
      return _toDomain(row, const <DateTime>[]);
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
    // items の更新と done_logs への追加を同じトランザクションに入れる。
    // 片方だけ成功する状態を作らない。
    await _db.transaction(() async {
      final updatedRows =
          await (_db.update(
            _db.items,
          )..where((t) => t.id.equals(id.value))).write(
            ItemsCompanion(
              lastDoneAt: Value(timestamp),
              updatedAt: Value(timestamp),
            ),
          );
      // 対象が無い(= 削除と同時操作)なら done_logs にも書かない。存在しない
      // item_id への INSERT は外部キー制約違反になる。
      if (updatedRows == 0) {
        return;
      }
      await _db
          .into(_db.doneLogs)
          .insert(
            DoneLogRow(id: _uuid.v4(), itemId: id.value, doneAt: timestamp),
          );
    });
  }

  @override
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  }) async {
    // done_logs の直近 1 行の削除と items の更新を同じトランザクションに入れる。
    await _db.transaction(() async {
      // Drift の型付き API は暗黙の SQLite rowid を公開しないため、生の SQL で
      // 直近 1 行の id を取る(同じ doneAt が複数あっても最後に挿入された行を選ぶ)。
      final latest = await _db
          .customSelect(
            'SELECT id FROM done_logs WHERE item_id = ? '
            'ORDER BY done_at DESC, rowid DESC LIMIT 1',
            variables: [Variable.withString(id.value)],
            readsFrom: {_db.doneLogs},
          )
          .getSingleOrNull();
      // 履歴が 0 件なら DELETE は何もしない(例外にしない)。
      if (latest != null) {
        await (_db.delete(
          _db.doneLogs,
        )..where((t) => t.id.equals(latest.read<String>('id')))).go();
      }

      await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
        ItemsCompanion(
          // previous が null なら未実施へ戻す。Value(null) が NULL を書く。
          lastDoneAt: Value(previous == null ? null : _toEpochMillis(previous)),
          // 取り消しも書き込みなので updated_at は前進させる(巻き戻さない)。
          updatedAt: Value(_toEpochMillis(now)),
        ),
      );
    });
  }
}

/// ドメインの日時を保存形式(UTC のエポックミリ秒)へ変換する。
int _toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// 保存形式をドメインの日時(UTC)へ戻す。
DateTime _toUtc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

/// Drift の行をドメインモデルへ変換する。[recentDoneAts] は新しい順・UTC。
Item _toDomain(ItemRow row, List<DateTime> recentDoneAts) {
  final lastDoneAt = row.lastDoneAt;
  return Item(
    id: ItemId(row.id),
    name: row.name,
    lastDoneAt: lastDoneAt == null ? null : _toUtc(lastDoneAt),
    createdAt: _toUtc(row.createdAt),
    updatedAt: _toUtc(row.updatedAt),
    sortOrder: row.sortOrder,
    recentDoneAts: recentDoneAts,
  );
}
