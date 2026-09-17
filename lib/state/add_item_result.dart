import '../domain/item_name.dart';

/// 項目の登録結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
///
/// 呼び出し元(登録画面)は 3 分岐をそのまま画面の振る舞いに写す。
sealed class AddItemResult {
  const AddItemResult();
}

/// 保存まで成功した。呼び出し元は一覧へ戻ってよい。
final class AddItemSucceeded extends AddItemResult {
  const AddItemSucceeded();
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class AddItemRejected extends AddItemResult {
  const AddItemRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final ItemNameReason reason;
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。
final class AddItemFailed extends AddItemResult {
  const AddItemFailed();
}
