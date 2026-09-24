import '../domain/item_name.dart';

/// 項目の変更結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class EditItemResult {
  const EditItemResult();
}

/// 保存まで成功した。呼び出し元は一覧へ戻ってよい。
final class EditItemSucceeded extends EditItemResult {
  const EditItemSucceeded();
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class EditItemRejected extends EditItemResult {
  const EditItemRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final ItemNameReason reason;
}

/// 対象が一覧に無かった(削除と同時操作)。**書き込みを試みていない。**
///
/// `docs/functional-design.md`「エラーの分類」に従い、UI は何も表示せず一覧へ戻る。
final class EditItemIgnored extends EditItemResult {
  const EditItemIgnored();
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。一覧は元の値のまま。
final class EditItemFailed extends EditItemResult {
  const EditItemFailed();
}

/// 項目の削除結果。**例外を投げない。**
sealed class DeleteItemResult {
  const DeleteItemResult();
}

/// 削除まで成功した。呼び出し元は一覧へ戻ってよい。
final class DeleteItemSucceeded extends DeleteItemResult {
  const DeleteItemSucceeded();
}

/// 対象が一覧に無かった(既に消えている)。**書き込みを試みていない。**
final class DeleteItemIgnored extends DeleteItemResult {
  const DeleteItemIgnored();
}

/// 削除に失敗した。一覧から消えない。
final class DeleteItemFailed extends DeleteItemResult {
  const DeleteItemFailed();
}
