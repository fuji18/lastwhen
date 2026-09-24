import 'dart:async';

import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/category_repository.dart';

import 'fake_item_repository.dart';

/// メモリ上の [CategoryRepository]。上位層のテストで Drift を起動しないために置く。
///
/// **`CategoryRepositoryImpl` と同じ振る舞いを保つこと。** ずれると上位層のテストが
/// 「通るのに本番で壊れる」形で嘘をつく。同じシナリオを両方に当てるテストが
/// `test/data/category_repository_impl_test.dart` にある。
final class FakeCategoryRepository implements CategoryRepository {
  /// [items] を渡すと `delete` の際にそのカテゴリの項目を未分類にする(実装の
  /// ON DELETE SET NULL に相当)。
  // ignore: prefer_initializing_formals
  FakeCategoryRepository({FakeItemRepository? items}) : _items = items;

  final FakeItemRepository? _items;

  final List<Category> _categories = <Category>[];
  final StreamController<List<Category>> _controller =
      StreamController<List<Category>>.broadcast();

  int _idSequence = 0;

  /// 非 null のとき、**すべての書き込み**がこの値を投げる。DB 書き込み失敗の再現用。
  Object? writeError;

  @override
  Stream<List<Category>> watchAll() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<Category> add(String name) async {
    _failIfConfigured();
    // 実装と同じ MAX + 1 採番にする(空なら 0)。
    final sortOrder =
        _categories.fold<int>(
          -1,
          (max, e) => e.sortOrder > max ? e.sortOrder : max,
        ) +
        1;
    final category = Category(
      id: CategoryId('fake-category-${_idSequence++}'),
      name: name,
      sortOrder: sortOrder,
    );
    _categories.add(category);
    _emit();
    return category;
  }

  @override
  Future<void> rename(CategoryId id, String name) async {
    _failIfConfigured();
    final index = _categories.indexWhere((c) => c.id == id);
    if (index < 0) {
      return;
    }
    final current = _categories[index];
    _categories[index] = Category(
      id: current.id,
      name: name,
      sortOrder: current.sortOrder,
    );
    _emit();
  }

  @override
  Future<void> delete(CategoryId id) async {
    _failIfConfigured();
    _items?.clearCategory(id);
    _categories.removeWhere((c) => c.id == id);
    _emit();
  }

  /// 購読を終了する。テストの `addTearDown` で呼ぶ。
  Future<void> dispose() => _controller.close();

  void _failIfConfigured() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  List<Category> _snapshot() {
    final sorted = [..._categories]
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.id.value.compareTo(b.id.value);
      });
    return List<Category>.unmodifiable(sorted);
  }
}
