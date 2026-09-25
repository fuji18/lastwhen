import '../domain/category.dart';
import '../domain/category_name.dart';

/// カテゴリの登録結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class AddCategoryResult {
  const AddCategoryResult();
}

/// 保存まで成功した。
final class AddCategorySucceeded extends AddCategoryResult {
  const AddCategorySucceeded(this.category);

  /// 保存されたカテゴリ。呼び出し元が続けて選択する場合に使う。
  final Category category;
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class AddCategoryRejected extends AddCategoryResult {
  const AddCategoryRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final CategoryNameReason reason;
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。
final class AddCategoryFailed extends AddCategoryResult {
  const AddCategoryFailed();
}

/// カテゴリの名前変更結果。**例外を投げない。**
sealed class RenameCategoryResult {
  const RenameCategoryResult();
}

/// 保存まで成功した。
final class RenameCategorySucceeded extends RenameCategoryResult {
  const RenameCategorySucceeded();
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class RenameCategoryRejected extends RenameCategoryResult {
  const RenameCategoryRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final CategoryNameReason reason;
}

/// 対象が一覧に無かった(削除と同時操作)。**書き込みを試みていない。**
final class RenameCategoryIgnored extends RenameCategoryResult {
  const RenameCategoryIgnored();
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。
final class RenameCategoryFailed extends RenameCategoryResult {
  const RenameCategoryFailed();
}

/// カテゴリの削除結果。**例外を投げない。**
sealed class DeleteCategoryResult {
  const DeleteCategoryResult();
}

/// 削除まで成功した。
final class DeleteCategorySucceeded extends DeleteCategoryResult {
  const DeleteCategorySucceeded();
}

/// 対象が一覧に無かった(既に消えている)。**書き込みを試みていない。**
final class DeleteCategoryIgnored extends DeleteCategoryResult {
  const DeleteCategoryIgnored();
}

/// 削除に失敗した。一覧から消えない。
final class DeleteCategoryFailed extends DeleteCategoryResult {
  const DeleteCategoryFailed();
}
