import 'package:lastwhen/domain/backup_file_transfer.dart';

/// メモリ上の [BackupFileTransfer]。プラットフォームチャネルを叩かずにテストする。
final class FakeBackupFileTransfer implements BackupFileTransfer {
  /// `share` に渡された内容の記録。
  final List<({String fileName, List<int> bytes})> shared =
      <({String fileName, List<int> bytes})>[];

  /// 非 null のとき、`share` がこの値を投げる。
  Object? shareError;

  /// `pick` が返すバイト列。null はキャンセルを表す。
  List<int>? pickResult;

  /// 非 null のとき、`pick` がこの値を投げる。
  Object? pickError;

  @override
  Future<void> share({
    required String fileName,
    required List<int> bytes,
  }) async {
    final error = shareError;
    if (error != null) {
      throw error;
    }
    shared.add((fileName: fileName, bytes: bytes));
  }

  @override
  Future<List<int>?> pick() async {
    final error = pickError;
    if (error != null) {
      throw error;
    }
    return pickResult;
  }
}
