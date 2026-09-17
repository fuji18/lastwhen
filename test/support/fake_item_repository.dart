import 'dart:async';

import 'package:lastwhen/domain/item.dart';
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

  int _idSequence = 0;

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
  Future<Item> add(String name, {required DateTime now}) async {
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
    );
    _items.add(item);
    _emit();
    return item;
  }

  @override
  Future<void> rename(ItemId id, String name, {required DateTime now}) async {
    _failIfConfigured();
    _update(id, (item) => _copy(item, name: name, updatedAt: _normalize(now)));
  }

  @override
  Future<void> delete(ItemId id) async {
    _failIfConfigured();
    _items.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Future<void> markDone(ItemId id, DateTime doneAt) async {
    _failIfConfigured();
    final timestamp = _normalize(doneAt);
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
    _update(
      id,
      (item) => _copy(
        item,
        lastDoneAt: previous == null ? null : _normalize(previous),
        updatedAt: _normalize(now),
      ),
    );
  }

  /// 購読を終了する。テストの `addTearDown` で呼ぶ。
  Future<void> dispose() => _controller.close();

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
    return List<Item>.unmodifiable(sorted);
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
    );
  }
}

/// 「引数が渡されなかった」を `null` と区別するための番兵。
const Object _unset = Object();
