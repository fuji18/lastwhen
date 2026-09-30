/// バックアップファイルの共有・選択。実装はデータレイヤー(#68)に置く。
abstract interface class BackupFileTransfer {
  /// [bytes] を [fileName] のファイルとして OS の共有シートに渡す。閉じられるまで待つ。
  Future<void> share({required String fileName, required List<int> bytes});

  /// OS のファイル選択を開き、選ばれたファイルの中身を返す。キャンセルは null。
  /// 大きさが `maxBackupFileBytes`(`backup.dart`)を超えたら読まずに
  /// `BackupFormatException(notBackupFile)` を投げる。
  Future<List<int>?> pick();
}
