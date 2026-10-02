import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/item.dart';
import '../state/item_view.dart';
import '../state/link_mark_done_result.dart';
import '../state/delete_history_day_result.dart';
import '../state/item_list_notifier.dart';
import '../state/mark_done_result.dart';
import '../state/record_past_date_result.dart';
import 'screens/item_detail_screen.dart';
import 'screens/item_edit_screen.dart';

/// 記録の詳細・編集画面を開く関数と、記録の結果を出す関数。一覧・図鑑・記録の詳細から使う。

/// 記録の詳細画面を開く。編集画面と「日付を指定して記録」への入口はこの画面のメニューにある。
void openItemDetailScreen(BuildContext context, ItemId id) {
  // 画面遷移と同じく、取り消し導線を閉じる。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: id)),
  );
}

/// 日付を選ばせて記録し、取り消し導線を出す(F16)。**確認ダイアログは出さない。**
Future<void> recordPastDateWithUndo(BuildContext context, ItemId id) async {
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
  final result = await notifier.recordPastDate(id, picked);
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

/// 記録の履歴から 1 日分の記録を削除し、取り消し導線を出す(#63)。
///
/// **確認ダイアログを出す**(削除には確認を入れる)。確認後の誤りは取り消しで救う。
Future<void> deleteHistoryDayWithUndo(
  BuildContext context,
  ItemId id,
  DoneHistoryEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${entry.shortDateText}の記録を削除しますか?'),
      content: const Text('この日の記録をすべて削除します。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  // バリアタップ・戻る操作は null。true 以外はすべて「削除しない」。
  if (confirmed != true) {
    return;
  }
  final result = await notifier.deleteHistoryDay(id, entry.dayKey);
  switch (result) {
    case DeleteHistoryDaySucceeded(:final undo):
      // キューに積ませない。「直近 1 件のみ」を保つ(「やった」と同じ)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${entry.shortDateText}の記録を削除しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoDeleteHistoryDay(messenger, notifier, undo),
          ),
        ),
      );
    // 同時操作。何も出さない。
    case DeleteHistoryDayIgnored():
      break;
    case DeleteHistoryDayFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('削除できませんでした。もう一度お試しください')),
      );
  }
}

/// 記録の削除を取り消す。失敗したら知らせる。
void _undoDeleteHistoryDay(
  ScaffoldMessengerState messenger,
  ItemListNotifier notifier,
  DeleteHistoryDayUndo undo,
) {
  unawaited(() async {
    final result = await notifier.undoDeleteHistoryDay(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}

/// 「やった」を記録し、直後に取り消し導線を出す。
///
/// **確認ダイアログを挟まない**(`docs/product-requirements.md` F3)。
Future<void> markDoneWithUndo(BuildContext context, ItemId id) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final result = await notifier.markDone(id);
  switch (result) {
    case MarkDoneSucceeded(:final undo):
      // キューに積ませない。積むと前の導線が先に出て「直近 1 件のみ」が崩れる。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoMarkDone(messenger, notifier, undo),
          ),
        ),
      );
    // 削除と同時操作。何も出さない(`docs/functional-design.md`「エラーの分類」)。
    case MarkDoneIgnored():
      break;
    case MarkDoneFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
  }
}

/// 直前の「やった」を取り消す。
///
/// **`WidgetRef` を受け取らない。** 取り消しは `SnackBar` のアクションから走るため、
/// 押された時点で呼び出し元の画面(記録の詳細)が閉じている可能性がある。
void _undoMarkDone(
  ScaffoldMessengerState messenger,
  ItemListNotifier notifier,
  MarkDoneUndo undo,
) {
  unawaited(() async {
    final result = await notifier.undoMarkDone(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}

/// 記録のリンク(NFC タグ)から記録し、結果を出す(F32)。**確認ダイアログは出さない。**
///
/// [id] が null = 形式が不正なリンク。見つからないときと同じ表示にする(design.md 判断5)。
Future<void> recordFromDoneLink(BuildContext context, ItemId? id) async {
  final messenger = ScaffoldMessenger.of(context);
  if (id == null) {
    _showDoneLinkMessage(messenger, 'この項目は見つかりませんでした');
    return;
  }
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final result = await notifier.markDoneFromLink(id);
  switch (result) {
    case LinkMarkDoneSucceeded(:final itemName, :final undo):
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('「$itemName」を記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoMarkDone(messenger, notifier, undo),
          ),
        ),
      );
    case LinkMarkDoneAlreadyToday(:final itemName):
      _showDoneLinkMessage(messenger, '「$itemName」は今日すでに記録しています');
    case LinkMarkDoneNotFound():
      _showDoneLinkMessage(messenger, 'この項目は見つかりませんでした');
    case LinkMarkDoneFailed():
      _showDoneLinkMessage(messenger, '保存できませんでした。もう一度お試しください');
  }
}

/// 記録のリンクの結果を 1 件だけ出す。
void _showDoneLinkMessage(ScaffoldMessengerState messenger, String message) {
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(message)));
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
