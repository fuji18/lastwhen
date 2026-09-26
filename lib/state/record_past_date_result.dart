import '../domain/item.dart';

/// 過去の日付での記録結果(F16)。**例外を投げない。**
sealed class RecordPastDateResult {
  const RecordPastDateResult();
}

/// 保存まで成功した。[undo] を取り消し導線へ、[dateText](`9月14日`)を SnackBar の文言へ渡す。
final class RecordPastDateSucceeded extends RecordPastDateResult {
  const RecordPastDateSucceeded(this.undo, {required this.dateText});

  final RecordPastDateUndo undo;
  final String dateText;
}

/// 対象が一覧に無かった(削除と同時操作)。UI は何も表示しない。
final class RecordPastDateIgnored extends RecordPastDateResult {
  const RecordPastDateIgnored();
}

/// 未来日だった。**書き込みを試みていない。** 日付の選択が未来日を選ばせないため通常は届かない。
/// UI は何も表示しない。
final class RecordPastDateRejected extends RecordPastDateResult {
  const RecordPastDateRejected();
}

/// 書き込みに失敗した。一覧は直前の値のまま。
final class RecordPastDateFailed extends RecordPastDateResult {
  const RecordPastDateFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。**UI はこの中身を読まない。**
final class RecordPastDateUndo {
  const RecordPastDateUndo({required this.id, required this.logId});

  /// 記録した項目。
  final ItemId id;

  /// 追加した履歴の行。
  final DoneLogId logId;
}
