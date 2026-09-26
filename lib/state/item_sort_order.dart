import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item_order.dart';

/// 一覧の並び順(F15)。**保存しない**(再起動で経年順に戻る)。図鑑には効かない。
final itemSortOrderProvider =
    NotifierProvider<ItemSortOrderNotifier, ItemSortOrder>(
      ItemSortOrderNotifier.new,
    );

class ItemSortOrderNotifier extends Notifier<ItemSortOrder> {
  @override
  ItemSortOrder build() => ItemSortOrder.aging;

  void select(ItemSortOrder order) => state = order;
}
