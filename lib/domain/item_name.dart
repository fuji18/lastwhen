/// 項目名の最大文字数(前後の空白を除いたコードポイント数)。
const int maxItemNameLength = 50;

/// 項目名の検証結果。
///
/// **例外を投げない。** 呼び出し元が理由を見て入力欄に表示する
/// (`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class ItemNameResult {
  const ItemNameResult();
}

/// 検証を通った項目名。[value] は前後の空白を除いた文字列。
final class ValidItemName extends ItemNameResult {
  const ValidItemName(this.value);

  final String value;
}

/// 検証を通らなかった項目名。
final class InvalidItemName extends ItemNameResult {
  const InvalidItemName(this.reason);

  final ItemNameReason reason;
}

/// 検証に落ちた理由。UI 文言の組み立ては UI 層の責務。
enum ItemNameReason {
  /// 空文字、または空白のみ。
  empty,

  /// 前後の空白を除いて [maxItemNameLength] を超えた。
  tooLong,
}

/// 項目名を検証する。
///
/// 絵文字などのサロゲートペアを 2 文字と数えないため、長さはコードポイント数で測る。
ItemNameResult validateItemName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const InvalidItemName(ItemNameReason.empty);
  }
  if (trimmed.runes.length > maxItemNameLength) {
    return const InvalidItemName(ItemNameReason.tooLong);
  }
  return ValidItemName(trimmed);
}
