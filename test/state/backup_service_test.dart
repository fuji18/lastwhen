import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/backup.dart';
import 'package:lastwhen/state/backup_service.dart';

import '../support/fake_backup_file_transfer.dart';
import '../support/fake_backup_repository.dart';
import '../support/fake_clock.dart';

void main() {
  late FakeBackupRepository repository;
  late FakeBackupFileTransfer transfer;
  late FakeClock clock;
  late BackupService service;

  setUp(() {
    repository = FakeBackupRepository();
    transfer = FakeBackupFileTransfer();
    clock = FakeClock(DateTime.utc(2026, 9, 30, 12));
    service = BackupService(
      repository: repository,
      transfer: transfer,
      clock: clock,
    );
  });

  group('export', () {
    test('ローカル日付のファイル名でリポジトリの内容を共有する', () async {
      repository.snapshot = BackupSnapshot(
        categories: const [
          BackupCategory(id: 'cat-1', name: '生活', sortOrder: 0),
        ],
        items: const [],
        doneLogs: const [],
      );

      await service.export();

      expect(transfer.shared, hasLength(1));
      final shared = transfer.shared.single;
      expect(shared.fileName, backupFileNameOf(clock.now().toLocal()));
      final decoded = decodeBackup(shared.bytes);
      expect(decoded.categories, repository.snapshot.categories);
    });
  });

  group('prepareRestore', () {
    test('pick が null なら RestoreCanceled', () async {
      transfer.pickResult = null;
      final result = await service.prepareRestore();
      expect(result, isA<RestoreCanceled>());
      expect(repository.replaced, isEmpty);
    });

    test('不正なバイト列なら RestoreRejected(notBackupFile)', () async {
      transfer.pickResult = utf8.encode('not json');
      final result = await service.prepareRestore();
      expect(result, isA<RestoreRejected>());
      expect(
        (result as RestoreRejected).error,
        BackupFormatError.notBackupFile,
      );
      expect(repository.replaced, isEmpty);
    });

    test('pick が BackupFormatException を投げたら RestoreRejected', () async {
      transfer.pickError = const BackupFormatException(
        BackupFormatError.notBackupFile,
      );
      final result = await service.prepareRestore();
      expect(result, isA<RestoreRejected>());
      expect(
        (result as RestoreRejected).error,
        BackupFormatError.notBackupFile,
      );
      expect(repository.replaced, isEmpty);
    });

    test('pick が Exception を投げたら RestoreReadFailed', () async {
      transfer.pickError = Exception('読み込み失敗');
      final result = await service.prepareRestore();
      expect(result, isA<RestoreReadFailed>());
      expect(repository.replaced, isEmpty);
    });

    test('正常なファイルなら RestoreReady', () async {
      final snapshot = BackupSnapshot(
        categories: const [
          BackupCategory(id: 'cat-1', name: '生活', sortOrder: 0),
        ],
        items: const [],
        doneLogs: const [],
      );
      transfer.pickResult = utf8.encode(
        encodeBackup(snapshot, exportedAt: clock.now()),
      );
      final result = await service.prepareRestore();
      expect(result, isA<RestoreReady>());
      expect((result as RestoreReady).snapshot.categories, snapshot.categories);
      expect(repository.replaced, isEmpty);
    });
  });

  group('restore', () {
    test('replaceAll に同じ snapshot が渡る', () async {
      final snapshot = BackupSnapshot(
        categories: const [
          BackupCategory(id: 'cat-1', name: '生活', sortOrder: 0),
        ],
        items: const [],
        doneLogs: const [],
      );
      await service.restore(snapshot);
      expect(repository.replaced, [snapshot]);
    });
  });
}
