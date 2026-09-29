import 'item_icon.dart';

/// よくある項目(F17)。一覧の空状態からワンタップで追加し、登録画面では入力欄に入れる。
///
/// **カテゴリは持たない**(ユーザーが名前変更・削除できるため。design.md 判断F)。
final class ItemTemplate {
  const ItemTemplate({required this.name, required this.icon});

  /// 項目名。`validateItemName` を通る値(前後の空白なし・1〜50 文字)。
  final String name;

  /// 追加する項目のアイコン。
  final ItemIcon icon;
}

/// よくある項目の一覧。**表示順 = 宣言順。**
const List<ItemTemplate> itemTemplates = [
  ItemTemplate(name: '歯ブラシ交換', icon: ItemIcon.cleaning),
  ItemTemplate(name: '美容院', icon: ItemIcon.haircut),
  ItemTemplate(name: 'エアコン掃除', icon: ItemIcon.airConditioner),
  ItemTemplate(name: '歯医者', icon: ItemIcon.hospital),
  ItemTemplate(name: '洗車', icon: ItemIcon.car),
  ItemTemplate(name: '布団干し', icon: ItemIcon.bed),
];

/// [existingNames](登録済みの項目名)と同名のものを除いたよくある項目。順序は [itemTemplates] のまま。
///
/// 比較は前後の空白を除いた完全一致(項目名は保存前にトリムされるため)。
List<ItemTemplate> availableItemTemplates(Iterable<String> existingNames) {
  final names = {for (final name in existingNames) name.trim()};
  return [
    for (final template in itemTemplates)
      if (!names.contains(template.name)) template,
  ];
}
