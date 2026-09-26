import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/item_view.dart';
import '../state/item_list_notifier.dart';
import '../state/mark_done_result.dart';
import '../state/record_past_date_result.dart';
import 'screens/item_edit_screen.dart';
import 'widgets/item_detail_sheet.dart';

/// 詳細シート・編集画面を開く関数。一覧と図鑑の両方から開くため、画面から切り出した(#34)。

/// 詳細シートで押されたボタン。シートを閉じてから処理する。
enum _DetailSheetAction { edit, recordPastDate }

/// 詳細シートを開く。編集画面と「日付を指定して記録」への入口はシートの中にある。
Future<void> openItemDetailSheet(BuildContext context, ItemView item) async {
  // 画面遷移と同じく、取り消し導線を閉じる。
  ScaffoldMessenger.of(context).clearSnackBars();
  final action = await showModalBottomSheet<_DetailSheetAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ItemDetailSheet(
      item: item,
      onEditPressed: () =>
          Navigator.of(sheetContext).pop(_DetailSheetAction.edit),
      onRecordPastDatePressed: () =>
          Navigator.of(sheetContext).pop(_DetailSheetAction.recordPastDate),
    ),
  );
  if (!context.mounted) {
    return;
  }
  switch (action) {
    case _DetailSheetAction.edit:
      openItemEditScreen(context, item);
    case _DetailSheetAction.recordPastDate:
      await _recordPastDate(context, item);
    case null:
      break;
  }
}

/// 日付を選ばせて記録し、取り消し導線を出す(F16)。**確認ダイアログは出さない。**
Future<void> _recordPastDate(BuildContext context, ItemView item) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final today = notifier.todayLocalDate();
  final picked = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: DateTime(2000),
    // 未来日は選ばせない。
    lastDate: today,
    helpText: '記録する日を選ぶ',
    confirmText: '記録する',
  );
  if (picked == null) {
    return;
  }
  final result = await notifier.recordPastDate(item.id, picked);
  switch (result) {
    case RecordPastDateSucceeded(:final undo, :final dateText):
      // キューに積ませない。「直近 1 件のみ」を保つ(「やった」と同じ)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$dateTextで記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoRecordPastDate(messenger, notifier, undo),
          ),
        ),
      );
    // 削除と同時操作・未来日。何も出さない。
    case RecordPastDateIgnored():
    case RecordPastDateRejected():
      break;
    case RecordPastDateFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
  }
}

/// 過去の日付での記録を取り消す。失敗したら知らせる。
void _undoRecordPastDate(
  ScaffoldMessengerState messenger,
  ItemListNotifier notifier,
  RecordPastDateUndo undo,
) {
  unawaited(() async {
    final result = await notifier.undoRecordPastDate(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
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
