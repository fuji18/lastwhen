import 'item.dart';

/// 項目の永続化。実装はデータレイヤー(#4)に置く。
///
/// **すべての書き込みが `now` を引数で受け取る。** データレイヤーは `Clock` に依存できない
/// ため(`docs/architecture.md`「データレイヤー」)、時刻の出どころを呼び出し元に一本化する。
abstract interface class ItemRepository {
  /// 表示順に並んだ全項目を流す。DB の変更で自動的に再送出される。
  Stream<List<Item>> watchAll();

  /// 項目を追加する。id は UUID v4 で実装側が採番する。
  Future<Item> add(String name, {required DateTime now});

  /// 項目名を変更する。
  Future<void> rename(ItemId id, String name, {required DateTime now});

  /// 項目を削除する。
  Future<void> delete(ItemId id);

  /// 最終実施日時を記録する。`updatedAt` も [doneAt] と同じ値になる。
  Future<void> markDone(ItemId id, DateTime doneAt);

  /// [markDone] の取り消し。最終実施日時を直前の値([previous])に戻す。
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  });
}
