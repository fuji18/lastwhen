import 'category.dart';
import 'item.dart';
import 'item_icon.dart';

/// 項目の永続化。実装はデータレイヤー(#4)に置く。
///
/// **すべての書き込みが `now` を引数で受け取る。** データレイヤーは `Clock` に依存できない
/// ため(`docs/architecture.md`「データレイヤー」)、時刻の出どころを呼び出し元に一本化する。
abstract interface class ItemRepository {
  /// 表示順に並んだ全項目を流す。DB の変更で自動的に再送出される。
  /// 各 [Item.recentDoneAts] も同時に埋めて流す。
  Stream<List<Item>> watchAll();

  /// 項目を追加する。id は UUID v4 で実装側が採番する。[icon] が null なら未選択。
  /// [categoryId] が null なら未分類。
  Future<Item> add(
    String name, {
    ItemIcon? icon,
    CategoryId? categoryId,
    required DateTime now,
  });

  /// 項目名・アイコン・カテゴリを変更する。**最終実施日と履歴は変えない。**
  /// [icon] / [categoryId] に null を渡すと未選択 / 未分類に戻す(「変更しない」の意味ではない)。
  Future<void> edit(
    ItemId id, {
    required String name,
    required ItemIcon? icon,
    required CategoryId? categoryId,
    required DateTime now,
  });

  /// 項目を削除する。**履歴(`done_logs`)も一緒に消える**(外部キーの CASCADE)。
  Future<void> delete(ItemId id);

  /// 最終実施日時を記録する。`updatedAt` も [doneAt] と同じ値になる。
  /// **`done_logs` への追加と同一トランザクションで書く。**
  Future<void> markDone(ItemId id, DateTime doneAt);

  /// [markDone] の取り消し。最終実施日時を直前の値([previous])に戻す。
  /// **`done_logs` の直近 1 行の削除と同一トランザクションで書く。** 履歴が
  /// 0 件のときは削除を何もしない(例外にしない)。
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  });

  /// 過去の日付で記録する(F16)。`done_logs` に 1 行追加し、最終実施日時を
  /// **履歴の最大値**に揃える([doneAt] が最新でなければ最終実施日は動かない)。
  /// `updatedAt` は [now]。**同一トランザクションで書く。**
  ///
  /// 追加した履歴の ID を返す。対象の項目が無ければ何も書かずに null を返す(例外にしない)。
  Future<DoneLogId?> addDoneLog(
    ItemId id,
    DateTime doneAt, {
    required DateTime now,
  });

  /// [addDoneLog] の取り消し。[logId] の 1 行だけを消し、最終実施日時を残りの履歴の
  /// 最大値(無ければ null)に揃える。`updatedAt` は [now]。**同一トランザクションで書く。**
  ///
  /// 対象の項目や行が無くても例外にしない。
  Future<void> removeDoneLog(
    ItemId id,
    DoneLogId logId, {
    required DateTime now,
  });
}
