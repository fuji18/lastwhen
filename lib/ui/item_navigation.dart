import 'package:flutter/material.dart';

import '../state/item_view.dart';
import 'screens/item_edit_screen.dart';
import 'widgets/item_detail_sheet.dart';

/// 詳細シート・編集画面を開く関数。一覧と図鑑の両方から開くため、画面から切り出した(#34)。

/// 詳細シートを開く。編集画面への入口はシートの中にある。
Future<void> openItemDetailSheet(BuildContext context, ItemView item) async {
  // 画面遷移と同じく、取り消し導線を閉じる。
  ScaffoldMessenger.of(context).clearSnackBars();
  final openEdit = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ItemDetailSheet(
      item: item,
      onEditPressed: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  if (openEdit == true && context.mounted) {
    openItemEditScreen(context, item);
  }
}

/// 編集画面へ遷移する。**削除の入口でもある**(`docs/product-requirements.md` F7)。
void openItemEditScreen(BuildContext context, ItemView item) {
  // ScaffoldMessenger は Navigator の上にあり、閉じないと遷移後も導線が残る(判断13)。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => ItemEditScreen(
        itemId: item.id,
        initialName: item.name,
        initialIcon: item.icon,
        initialCategoryId: item.categoryId,
      ),
    ),
  );
}
