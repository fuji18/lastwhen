import '../domain/item.dart';

/// 記録の履歴から 1 日分を削除した結果(#63)。**例外を投げない。**
sealed class DeleteHistoryDayResult {
  const DeleteHistoryDayResult();
}

/// 削除まで成功した。[undo] を取り消し導線へ渡す。
final class DeleteHistoryDaySucceeded extends DeleteHistoryDayResult {
  const DeleteHistoryDaySucceeded(this.undo);

  final DeleteHistoryDayUndo undo;
}

/// 対象の項目、またはその日の記録が無かった(同時操作)。**何も書いていない。** UI は何も表示しない。
final class DeleteHistoryDayIgnored extends DeleteHistoryDayResult {
  const DeleteHistoryDayIgnored();
}

/// 書き込みに失敗した。履歴は直前の値のまま。
final class DeleteHistoryDayFailed extends DeleteHistoryDayResult {
  const DeleteHistoryDayFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。**UI はこの中身を読まない。**
final class DeleteHistoryDayUndo {
  const DeleteHistoryDayUndo({required this.id, required this.logs});

  /// 削除した項目。
  final ItemId id;

  /// 消した履歴の行(元の ID・日時)。
  final List<DoneLog> logs;
}
