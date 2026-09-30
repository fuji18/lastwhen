/// カテゴリ ID。素の String と取り違えないための型。
extension type const CategoryId(String value) {}

/// 項目を分けるためのカテゴリ。ユーザーが追加・名前変更・削除できる(F13)。
final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final CategoryId id;

  /// 前後の空白を除いた 1〜10 文字。検証は `validateCategoryName` が行う。
  final String name;

  /// 表示順。追加時は末尾(`MAX(sort_order) + 1`)。カテゴリの管理で並び替えると 0 始まりで振り直す。
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is Category &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
}
