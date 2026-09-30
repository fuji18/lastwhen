import 'backup.dart';

/// バックアップの読み書き。実装はデータレイヤー(#68)に置く。
abstract interface class BackupRepository {
  /// 全データを 1 トランザクションで読む(読み途中の書き込みで食い違わない)。
  Future<BackupSnapshot> readAll();

  /// 全データを [snapshot] で置き換える。**1 トランザクション。** 失敗したら何も変わらない。
  /// `items.last_done_at` は [snapshot] の記録の最大値(無ければ null)で埋める。
  Future<void> replaceAll(BackupSnapshot snapshot);
}
