import 'package:flutter/material.dart';

import '../../state/item_order.dart';

/// 並び順の UI 文言。
String itemSortOrderLabel(ItemSortOrder order) => switch (order) {
  ItemSortOrder.aging => '経年順',
  ItemSortOrder.elapsedDays => '経過日数順',
  ItemSortOrder.name => '名前順',
  ItemSortOrder.registered => '登録順',
};

/// 一覧の AppBar に置く並び順のメニュー(F15)。選択中の候補にチェックを付ける。
///
/// provider を読まない(値とコールバックだけを受ける)。
class ItemSortMenuButton extends StatelessWidget {
  /// 並び順のメニューを作る。
  const ItemSortMenuButton({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 選択中の並び順。
  final ItemSortOrder selected;

  /// 並び順が選ばれたときの処理。
  final ValueChanged<ItemSortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ItemSortOrder>(
      icon: const Icon(Icons.sort),
      tooltip: '並び順',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final order in ItemSortOrder.values)
          CheckedPopupMenuItem<ItemSortOrder>(
            value: order,
            checked: order == selected,
            child: Text(itemSortOrderLabel(order)),
          ),
      ],
    );
  }
}
