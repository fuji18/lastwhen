/// カテゴリ名の最大文字数(前後の空白を除いたコードポイント数)。チップに収まる長さ。
const int maxCategoryNameLength = 10;

/// カテゴリ名の検証結果。
///
/// **例外を投げない。** 呼び出し元が理由を見て入力欄に表示する
/// (`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class CategoryNameResult {
  const CategoryNameResult();
}

/// 検証を通ったカテゴリ名。[value] は前後の空白を除いた文字列。
final class ValidCategoryName extends CategoryNameResult {
  const ValidCategoryName(this.value);

  final String value;
}

/// 検証を通らなかったカテゴリ名。
final class InvalidCategoryName extends CategoryNameResult {
  const InvalidCategoryName(this.reason);

  final CategoryNameReason reason;
}

/// 検証に落ちた理由。UI 文言の組み立ては UI 層の責務。
enum CategoryNameReason {
  /// 空文字、または空白のみ。
  empty,

  /// 前後の空白を除いて [maxCategoryNameLength] を超えた。
  tooLong,

  /// 前後の空白を除いた名前が、既存のカテゴリ名と完全に一致した。
  duplicate,
}

/// カテゴリ名を検証する。[existingNames] は**自分以外の**既存カテゴリ名(呼び出し元が除く)。
///
/// 判定順: empty → tooLong → duplicate。長さはコードポイント数で測る。
/// 重複判定は**トリム後の完全一致**(大文字小文字・全角半角の正規化はしない)。
CategoryNameResult validateCategoryName(
  String raw, {
  required Iterable<String> existingNames,
}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const InvalidCategoryName(CategoryNameReason.empty);
  }
  if (trimmed.runes.length > maxCategoryNameLength) {
    return const InvalidCategoryName(CategoryNameReason.tooLong);
  }
  if (existingNames.contains(trimmed)) {
    return const InvalidCategoryName(CategoryNameReason.duplicate);
  }
  return ValidCategoryName(trimmed);
}
