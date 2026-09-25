import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import 'item_view.dart';

/// 一覧の絞り込み。**null は「すべて」。** 保存しない(再起動で「すべて」に戻る)。
final categoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, CategoryId?>(
      CategoryFilterNotifier.new,
    );

class CategoryFilterNotifier extends Notifier<CategoryId?> {
  @override
  CategoryId? build() => null;

  void select(CategoryId? id) => state = id;
}

/// [id] が [categories] に存在すればそのまま、無ければ null(削除済みのカテゴリを未分類・
/// 「すべて」として扱う)。
CategoryId? resolveCategoryId(CategoryId? id, List<Category> categories) {
  if (id == null) {
    return null;
  }
  return categories.any((category) => category.id == id) ? id : null;
}

/// [filter] が null なら [views] をそのまま返す。そうでなければ categoryId が一致するものだけを、
/// **入力順を保って**返す。
List<ItemView> filterByCategory(List<ItemView> views, CategoryId? filter) {
  if (filter == null) {
    return views;
  }
  return views
      .where((view) => view.categoryId == filter)
      .toList(growable: false);
}
