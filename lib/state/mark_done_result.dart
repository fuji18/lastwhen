import '../domain/item.dart';

/// 「やった」の記録結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class MarkDoneResult {
  const MarkDoneResult();
}

/// 保存まで成功した。[undo] を取り消し導線へ渡す。
final class MarkDoneSucceeded extends MarkDoneResult {
  const MarkDoneSucceeded(this.undo);

  final MarkDoneUndo undo;
}

/// 対象が一覧に無かった(削除と同時操作)。**書き込みを試みていない。**
///
/// `docs/functional-design.md`「エラーの分類」に従い、UI は何も表示しない。
final class MarkDoneIgnored extends MarkDoneResult {
  const MarkDoneIgnored();
}

/// 書き込みに失敗した。一覧は直前の値のまま。
final class MarkDoneFailed extends MarkDoneResult {
  const MarkDoneFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。
///
/// **UI はこの中身を読まない。** 受け取って `ItemListNotifier.undoMarkDone` に返すだけ
/// (design.md 判断3)。日時の解釈を状態管理層に閉じる約束を、取り消し経路でも崩さないため。
final class MarkDoneUndo {
  const MarkDoneUndo({required this.id, required this.previousLastDoneAt});

  /// 記録した項目。
  final ItemId id;

  /// 記録する直前の最終実施日時(UTC)。**未実施だったなら null。**
  final DateTime? previousLastDoneAt;
}

/// 取り消しの結果。
sealed class UndoResult {
  const UndoResult();
}

/// 直前の値に戻した。
final class UndoSucceeded extends UndoResult {
  const UndoSucceeded();
}

/// 書き込みに失敗した。一覧は「今日」のまま。
final class UndoFailed extends UndoResult {
  const UndoFailed();
}
