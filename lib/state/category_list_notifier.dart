import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/category_name.dart';
import 'category_results.dart';
import 'providers.dart';

/// カテゴリ一覧の状態。UI はこれを `AsyncValue<List<Category>>` として受ける。
final categoryListProvider =
    StreamNotifierProvider<CategoryListNotifier, List<Category>>(
      CategoryListNotifier.new,
    );

/// カテゴリ一覧を流す。
///
/// **`StreamNotifier` を継承する**(`ItemListNotifier` と同じ形)。追加・名前変更・削除は
/// 結果型を返し、一覧の更新は購読に任せる。**`state` を触らない。**
class CategoryListNotifier extends StreamNotifier<List<Category>> {
  /// 最後に流れてきたカテゴリの一覧。存在確認に使う。
  List<Category> _latestCategories = const <Category>[];

  @override
  Stream<List<Category>> build() => ref
      .watch(categoryRepositoryProvider)
      .watchAll()
      .map((categories) => _latestCategories = categories);

  /// カテゴリを追加する。検証を通ったときだけ保存し、結果を返す。
  Future<AddCategoryResult> addCategory(String rawName) async {
    // 最初の値が届く前は `_latestCategories` が空で、重複を見逃す。
    // 一度受け取っていれば、その後にストリームが失敗しても手元の一覧で確かめる。
    if (!state.hasValue) {
      try {
        await future;
      } catch (_) {
        return const AddCategoryFailed();
      }
    }
    switch (validateCategoryName(
      rawName,
      existingNames: _latestCategories.map((c) => c.name),
    )) {
      case InvalidCategoryName(:final reason):
        return AddCategoryRejected(reason);
      case ValidCategoryName(:final value):
        try {
          final category = await ref
              .read(categoryRepositoryProvider)
              .add(value);
          // ストリームの次の値が届くまでの間も、重複検査に今の名前を使う。
          _latestCategories = [..._latestCategories, category];
          return AddCategorySucceeded(category);
        } catch (error, stackTrace) {
          developer.log(
            'カテゴリの追加に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const AddCategoryFailed();
        }
    }
  }

  /// カテゴリの名前を変える。
  ///
  /// 検証(existingNames は自分以外の名前)→ 存在確認(無ければ Ignored)→ 保存
  /// (検証 → 存在確認の順は `editItem` と同じ)。
  Future<RenameCategoryResult> renameCategory(
    CategoryId id,
    String rawName,
  ) async {
    // 最初の値が届く前は `_latestCategories` が空で、重複を見逃す。
    // 一度受け取っていれば、その後にストリームが失敗しても手元の一覧で確かめる。
    if (!state.hasValue) {
      try {
        await future;
      } catch (_) {
        return const RenameCategoryFailed();
      }
    }
    switch (validateCategoryName(
      rawName,
      existingNames: _latestCategories
          .where((c) => c.id != id)
          .map((c) => c.name),
    )) {
      case InvalidCategoryName(:final reason):
        return RenameCategoryRejected(reason);
      case ValidCategoryName(:final value):
        if (!_latestCategories.any((c) => c.id == id)) {
          return const RenameCategoryIgnored();
        }
        try {
          await ref.read(categoryRepositoryProvider).rename(id, value);
          // ストリームの次の値が届くまでの間も、重複検査に今の名前を使う。
          _latestCategories = [
            for (final category in _latestCategories)
              if (category.id == id)
                Category(id: id, name: value, sortOrder: category.sortOrder)
              else
                category,
          ];
          return const RenameCategorySucceeded();
        } catch (error, stackTrace) {
          developer.log(
            'カテゴリの名前変更に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const RenameCategoryFailed();
        }
    }
  }

  /// カテゴリを削除する。**確認は UI の責務。** ここは確認済みの前提で呼ばれる。
  Future<DeleteCategoryResult> deleteCategory(CategoryId id) async {
    if (!_latestCategories.any((c) => c.id == id)) {
      return const DeleteCategoryIgnored();
    }
    try {
      await ref.read(categoryRepositoryProvider).delete(id);
      return const DeleteCategorySucceeded();
    } catch (error, stackTrace) {
      developer.log(
        'カテゴリの削除に失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const DeleteCategoryFailed();
    }
  }
}
