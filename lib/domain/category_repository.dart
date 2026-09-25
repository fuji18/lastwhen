import 'category.dart';

/// カテゴリの永続化。**書き込みは `now` を取らない**(カテゴリは時刻の列を持たない)。
abstract interface class CategoryRepository {
  /// 表示順(sort_order 昇順、同値は id 昇順)に並んだ全カテゴリを流す。
  Stream<List<Category>> watchAll();

  /// カテゴリを追加する。id は UUID v4、sort_order は MAX + 1(空なら 0)。
  Future<Category> add(String name);

  /// 名前を変える。対象が無ければ何もしない(例外にしない)。
  Future<void> rename(CategoryId id, String name);

  /// カテゴリを削除する。**そのカテゴリの項目は未分類になる。項目と記録は消えない。**
  Future<void> delete(CategoryId id);
}
