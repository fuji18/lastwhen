import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/elapsed_days.dart';
import 'category_filter.dart';
import 'item_view.dart';

/// 図鑑の絞り込み。**null は「すべて」。一覧の [categoryFilterProvider] とは独立**で、保存しない。
final collectionCategoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, CategoryId?>(
      CategoryFilterNotifier.new,
    );

/// 図鑑に載せる項目を、**入力順を保って**返す(F31)。
///
/// 1. 未実施(`NeverDone`)を除く。図鑑に載るのは 1 回以上記録した項目だけ
/// 2. [category] で絞る(null は「すべて」。[filterByCategory] に任せる)
/// 3. [query] を前後の空白を除いて、項目名の部分一致で絞る。英字の大文字小文字を区別しない。
///    空文字(空白だけを含む)なら絞らない
List<ItemView> collectionOf(
  List<ItemView> views, {
  CategoryId? category,
  String query = '',
}) {
  final recorded = views
      .where((view) => view.elapsed is! NeverDone)
      .toList(growable: false);
  final byCategory = filterByCategory(recorded, category);
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return byCategory;
  }
  return byCategory
      .where((view) => view.name.toLowerCase().contains(needle))
      .toList(growable: false);
}
