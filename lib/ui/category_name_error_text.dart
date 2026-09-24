import '../domain/category_name.dart';

/// 検証に落ちた理由を入力欄の文言へ変換する。
///
/// **文字列への変換は UI 層の責務**(`itemNameErrorText` と同じ置き方)。
String categoryNameErrorText(CategoryNameReason reason) => switch (reason) {
  CategoryNameReason.empty => 'カテゴリ名を入力してください',
  CategoryNameReason.tooLong => '$maxCategoryNameLength文字以内で入力してください',
  CategoryNameReason.duplicate => '同じ名前のカテゴリがあります',
};
