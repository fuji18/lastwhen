import 'dart:async';

import 'package:lastwhen/domain/baseline_interval.dart' show recentDoneAtsLimit;
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/domain/item_repository.dart';

/// メモリ上の [ItemRepository]。#5 以降の上位層テストで Drift を起動しないために置く。
///
/// **`ItemRepositoryImpl` と同じ振る舞いを保つこと。** ずれると上位層のテストが
/// 「通るのに本番で壊れる」形で嘘をつく。同じシナリオを両方に当てるテストが
/// `test/data/item_repository_impl_test.dart` にある。
final class FakeItemRepository implements ItemRepository {
  final List<Item> _items = <Item>[];
  final StreamController<List<Item>> _controller =
      StreamController<List<Item>>.broadcast();

  /// 項目ごとの履歴(新しい順)。`ItemRepositoryImpl` の `done_logs` に相当する。
  final Map<ItemId, List<_FakeDoneLog>> _doneLogs =
      <ItemId, List<_FakeDoneLog>>{};

  int _idSequence = 0;
  int _logSequence = 0;

  /// 非 null のとき、**すべての書き込み**がこの値を投げる。DB 書き込み失敗の再現用。
  ///
  /// **読み取り(`watchAll`)には影響しない。** 「一覧は生きたまま書き込みだけ失敗する」
  /// という `docs/functional-design.md`「エラーハンドリング」の状況を作るため。
  Object? writeError;

  @override
  Stream<List<Item>> watchAll() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<Item> add(
    String name, {
    ItemIcon? icon,
    CategoryId? categoryId,
    required DateTime now,
  }) async {
    _failIfConfigured();
    final timestamp = _normalize(now);
    // 実装と同じ MAX + 1 採番にする(空なら 0)。
    final sortOrder =
        _items.fold<int>(
          -1,
          (max, e) => e.sortOrder > max ? e.sortOrder : max,
        ) +
        1;
    final item = Item(
      id: ItemId('fake-item-${_idSequence++}'),
      name: name,
      lastDoneAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      sortOrder: sortOrder,
      icon: icon,
      categoryId: categoryId,
    );
    _items.add(item);
    _emit();
    return item;
  }

  @override
  Future<void> edit(
    ItemId id, {
    required String name,
    required ItemIcon? icon,
    required CategoryId? categoryId,
    required DateTime now,
  }) async {
    _failIfConfigured();
    _update(
      id,
      (item) => _copy(
        item,
        name: name,
        icon: icon,
        categoryId: categoryId,
        updatedAt: _normalize(now),
      ),
    );
  }

  @override
  Future<void> delete(ItemId id) async {
    _failIfConfigured();
    _items.removeWhere((item) => item.id == id);
    // 履歴も一緒に消える(実装の外部キー CASCADE に相当)。
    _doneLogs.remove(id);
    _emit();
  }

  @override
  Future<void> markDone(ItemId id, DateTime doneAt) async {
    _failIfConfigured();
    // 対象が無ければ履歴も作らない(実装の「対象なし」と揃える)。
    if (!_items.any((item) => item.id == id)) {
      return;
    }
    final timestamp = _normalize(doneAt);
    _insertLog(id, timestamp);
    _update(
      id,
      (item) => _copy(item, lastDoneAt: timestamp, updatedAt: timestamp),
    );
  }

  @override
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  }) async {
    _failIfConfigured();
    // 履歴が 0 件なら何もしない(例外にしない。実装と同じ)。
    final logs = _doneLogs[id];
    if (logs != null && logs.isNotEmpty) {
      logs.removeAt(0);
    }
    _update(
      id,
      (item) => _copy(
        item,
        lastDoneAt: previous == null ? null : _normalize(previous),
        updatedAt: _normalize(now),
      ),
    );
  }

  /// 実装の ORDER BY done_at DESC, rowid DESC と同じ位置に入れる。
  DoneLogId _insertLog(ItemId id, DateTime doneAt) {
    final logs = _doneLogs[id] ??= <_FakeDoneLog>[];
    final log = _FakeDoneLog(DoneLogId('fake-log-${_logSequence++}'), doneAt);
    final index = logs.indexWhere((e) => !e.doneAt.isAfter(doneAt));
    logs.insert(index < 0 ? logs.length : index, log);
    return log.id;
  }

  @override
  Future<DoneLogId?> addDoneLog(
    ItemId id,
    DateTime doneAt, {
    required DateTime now,
  }) async {
    _failIfConfigured();
    if (!_items.any((item) => item.id == id)) {
      return null;
    }
    final logId = _insertLog(id, _normalize(doneAt));
    _update(
      id,
      (item) => _copy(
        item,
        lastDoneAt: _doneLogs[id]!.first.doneAt,
        updatedAt: _normalize(now),
      ),
    );
    return logId;
  }

  @override
  Future<void> removeDoneLog(
    ItemId id,
    DoneLogId logId, {
    required DateTime now,
  }) async {
    _failIfConfigured();
    final logs = _doneLogs[id];
    logs?.removeWhere((e) => e.id == logId);
    _update(
      id,
      (item) => _copy(
        item,
        lastDoneAt: logs == null || logs.isEmpty ? null : logs.first.doneAt,
        updatedAt: _normalize(now),
      ),
    );
  }

  /// 購読を終了する。テストの `addTearDown` で呼ぶ。
  Future<void> dispose() => _controller.close();

  /// [id] のカテゴリを持つ項目をすべて未分類(null)にして emit する。`updatedAt` は変えない。
  ///
  /// `FakeCategoryRepository.delete` から呼ばれる(実装の ON DELETE SET NULL に相当)。
  /// `writeError` は見ない(呼び出し元が見る)。
  void clearCategory(CategoryId id) {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].categoryId == id) {
        _items[i] = _copy(_items[i], categoryId: null);
        changed = true;
      }
    }
    if (changed) {
      _emit();
    }
  }

  /// 書き込み失敗が仕込まれていれば投げる。
  void _failIfConfigured() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }

  /// 対象が無ければ何もしない(実装の「対象なし」と揃える)。
  void _update(ItemId id, Item Function(Item) transform) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    _items[index] = transform(_items[index]);
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  List<Item> _snapshot() {
    final sorted = [..._items]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.value.compareTo(b.id.value);
      });
    return List<Item>.unmodifiable(
      sorted.map((item) {
        final logs = _doneLogs[item.id] ?? const <_FakeDoneLog>[];
        final recentDoneAts = logs.length <= recentDoneAtsLimit
            ? logs
            : logs.sublist(0, recentDoneAtsLimit);
        return _copy(
          item,
          recentDoneAts: List<DateTime>.unmodifiable(
            recentDoneAts.map((e) => e.doneAt),
          ),
        );
      }),
    );
  }

  /// 実装は epoch ミリ秒を往復するのでマイクロ秒が落ちる。同じ精度に丸める。
  DateTime _normalize(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
    value.toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );

  /// `Item` に `copyWith` を作らない方針(#3 判断7)なので、ここで組み直す。
  /// `lastDoneAt` は null 自体が意味を持つため、名前付き引数で置き換えない。
  Item _copy(
    Item source, {
    String? name,
    Object? lastDoneAt = _unset,
    DateTime? updatedAt,
    List<DateTime>? recentDoneAts,
    Object? icon = _unset,
    Object? categoryId = _unset,
  }) {
    return Item(
      id: source.id,
      name: name ?? source.name,
      lastDoneAt: identical(lastDoneAt, _unset)
          ? source.lastDoneAt
          : lastDoneAt as DateTime?,
      createdAt: source.createdAt,
      updatedAt: updatedAt ?? source.updatedAt,
      sortOrder: source.sortOrder,
      recentDoneAts: recentDoneAts ?? source.recentDoneAts,
      icon: identical(icon, _unset) ? source.icon : icon as ItemIcon?,
      categoryId: identical(categoryId, _unset)
          ? source.categoryId
          : categoryId as CategoryId?,
    );
  }
}

/// 「引数が渡されなかった」を `null` と区別するための番兵。
const Object _unset = Object();

/// フェイクの履歴 1 行。実装の done_logs の行に相当する。
final class _FakeDoneLog {
  const _FakeDoneLog(this.id, this.doneAt);

  final DoneLogId id;
  final DateTime doneAt;
}
