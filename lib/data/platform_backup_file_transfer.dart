import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/backup.dart';
import '../domain/backup_file_transfer.dart';

/// [BackupFileTransfer] のプラットフォーム実装。share_plus / file_picker /
/// path_provider を叩くので**このクラスはユニットテストを書かない**(state 以上は
/// フェイクで差し替える)。
final class PlatformBackupFileTransfer implements BackupFileTransfer {
  @override
  Future<void> share({
    required String fileName,
    required List<int> bytes,
  }) async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}backup',
    );
    await directory.create(recursive: true);
    // 同名は上書きする。共有先が戻った後に読みに来ることがあるため消さない
    // (一時ディレクトリなので OS が片付ける)。
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    // 戻り値の ShareResult は使わない(成功と言い切れないことを言わないため)。
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [fileName],
      ),
    );
  }

  @override
  Future<List<int>?> pick() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) {
      return null;
    }
    final length = await picked.length();
    if (length != null && length > maxBackupFileBytes) {
      throw const BackupFormatException(BackupFormatError.notBackupFile);
    }
    final bytes = await picked.readAsBytes();
    if (bytes.length > maxBackupFileBytes) {
      throw const BackupFormatException(BackupFormatError.notBackupFile);
    }
    return bytes;
  }
}
