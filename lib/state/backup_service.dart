import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/backup.dart';
import '../domain/backup_file_transfer.dart';
import '../domain/backup_repository.dart';
import '../domain/clock.dart';
import 'providers.dart';

/// 復元するファイルを選んだ結果。
sealed class RestorePreparation {
  const RestorePreparation();
}

/// ファイル選択をキャンセルした。
final class RestoreCanceled extends RestorePreparation {
  const RestoreCanceled();
}

/// 検証を通り、復元できる状態になった。
final class RestoreReady extends RestorePreparation {
  const RestoreReady(this.snapshot);

  final BackupSnapshot snapshot;
}

/// 検証に落ちた。
final class RestoreRejected extends RestorePreparation {
  const RestoreRejected(this.error);

  final BackupFormatError error;
}

/// ファイルを読めなかった(権限の取り消し・クラウド上のファイルの取得失敗など)。
final class RestoreReadFailed extends RestorePreparation {
  const RestoreReadFailed();
}

/// バックアップの書き出し・復元の手順。
final class BackupService {
  // 外部公開の引数名(repository / transfer / clock)をフィールド名と変える都合で
  // initializing formal は使わない(`NotificationSync` と同じ書き方)。
  BackupService({
    required BackupRepository repository,
    required BackupFileTransfer transfer,
    required Clock clock,
    // ignore: prefer_initializing_formals
  }) : _repository = repository,
       // ignore: prefer_initializing_formals
       _transfer = transfer,
       // ignore: prefer_initializing_formals
       _clock = clock;

  final BackupRepository _repository;
  final BackupFileTransfer _transfer;
  final Clock _clock;

  /// 全データを書き出して共有シートを開く。失敗は例外のまま投げる(UI が SnackBar を出す)。
  Future<void> export() async {
    final now = _clock.now();
    final snapshot = await _repository.readAll();
    final json = encodeBackup(snapshot, exportedAt: now);
    await _transfer.share(
      fileName: backupFileNameOf(now.toLocal()),
      bytes: utf8.encode(json),
    );
  }

  /// ファイルを選ばせて検証する。**DB には触らない。** 例外は投げない。
  Future<RestorePreparation> prepareRestore() async {
    final List<int>? bytes;
    try {
      bytes = await _transfer.pick();
    } on BackupFormatException catch (e) {
      return RestoreRejected(e.error);
    } catch (error, stackTrace) {
      developer.log(
        'バックアップの読み込みに失敗しました',
        error: error,
        stackTrace: stackTrace,
        name: 'BackupService',
      );
      return const RestoreReadFailed();
    }
    if (bytes == null) {
      return const RestoreCanceled();
    }
    try {
      return RestoreReady(decodeBackup(bytes));
    } on BackupFormatException catch (e) {
      return RestoreRejected(e.error);
    }
  }

  /// [snapshot] で全データを置き換える。失敗は例外のまま投げる(既存データは変わっていない)。
  Future<void> restore(BackupSnapshot snapshot) =>
      _repository.replaceAll(snapshot);
}

/// バックアップの読み書きの手順。テストは各 provider をフェイクに差し替える。
final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    repository: ref.watch(backupRepositoryProvider),
    transfer: ref.watch(backupFileTransferProvider),
    clock: ref.watch(clockProvider),
  ),
);
