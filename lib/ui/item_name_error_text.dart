import '../domain/item_name.dart';

/// 検証に落ちた理由を入力欄の文言へ変換する。
///
/// 文言は `docs/functional-design.md`「エラーの分類」が正。
/// **文字列への変換は UI 層の責務**(`elapsedText` と同じ置き方)。
String itemNameErrorText(ItemNameReason reason) => switch (reason) {
  ItemNameReason.empty => '項目名を入力してください',
  ItemNameReason.tooLong => '$maxItemNameLength文字以内で入力してください',
};
