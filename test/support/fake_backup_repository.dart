import 'package:lastwhen/domain/backup.dart';
import 'package:lastwhen/domain/backup_repository.dart';

/// メモリ上の [BackupRepository]。上位層のテストで Drift を起動しないために置く。
final class FakeBackupRepository implements BackupRepository {
  FakeBackupRepository({
    this.snapshot = const BackupSnapshot(
      categories: [],
      items: [],
      doneLogs: [],
    ),
  });

  /// `readAll` が返すスナップショット。
  BackupSnapshot snapshot;

  /// `replaceAll` に渡されたスナップショットの記録。
  final List<BackupSnapshot> replaced = <BackupSnapshot>[];

  /// 非 null のとき、`replaceAll` がこの値を投げる。
  Object? replaceError;

  @override
  Future<BackupSnapshot> readAll() async => snapshot;

  @override
  Future<void> replaceAll(BackupSnapshot snapshot) async {
    final error = replaceError;
    if (error != null) {
      throw error;
    }
    replaced.add(snapshot);
  }
}
