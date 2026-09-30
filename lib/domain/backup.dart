import 'dart:convert';

import 'category_name.dart';
import 'item_name.dart';

/// バックアップファイルの形式の識別子。
const String backupFormatId = 'lastwhen-backup';

/// バックアップファイルの現在の形式バージョン。
const int backupFormatVersion = 1;

/// バックアップファイルの上限バイト数(10 MiB)。超えたら読まずに拒否する。
const int maxBackupFileBytes = 10 * 1024 * 1024;

/// バックアップに含めるカテゴリ 1 件。
final class BackupCategory {
  const BackupCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is BackupCategory &&
      other.id == id &&
      other.name == name &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, name, sortOrder);
}

/// バックアップに含める項目 1 件。
final class BackupItem {
  const BackupItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  final String id;
  final String name;

  /// `ItemIcon.key`。未知の値もそのまま持つ(DB と同じ扱い)。
  final String? icon;

  /// null = 未分類。
  final String? categoryId;

  /// UTC。
  final DateTime createdAt;

  /// UTC。
  final DateTime updatedAt;

  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is BackupItem &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.categoryId == categoryId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, name, icon, categoryId, createdAt, updatedAt, sortOrder);
}

/// バックアップに含める実施履歴 1 件。
final class BackupDoneLog {
  const BackupDoneLog({
    required this.id,
    required this.itemId,
    required this.doneAt,
  });

  final String id;
  final String itemId;

  /// UTC。
  final DateTime doneAt;

  @override
  bool operator ==(Object other) =>
      other is BackupDoneLog &&
      other.id == id &&
      other.itemId == itemId &&
      other.doneAt == doneAt;

  @override
  int get hashCode => Object.hash(id, itemId, doneAt);
}

/// 全データのスナップショット。書き出し・復元の受け渡しに使う。
final class BackupSnapshot {
  const BackupSnapshot({
    required this.categories,
    required this.items,
    required this.doneLogs,
  });

  final List<BackupCategory> categories;
  final List<BackupItem> items;
  final List<BackupDoneLog> doneLogs;
}

/// バックアップファイルの検証に落ちた理由。
enum BackupFormatError {
  /// JSON でない・UTF-8 でない・`format` が違う・`version` が整数でないか 1 未満・上限超え。
  notBackupFile,

  /// `version` が [backupFormatVersion] より大きい(新しいアプリで書き出された)。
  newerVersion,

  /// 形式は合っているが中身が壊れている(欠けた項目・型違い・ID の重複・参照切れ・名前の検証違反)。
  invalidContent,
}

/// バックアップファイルの検証に失敗したときに投げる。
///
/// **[decodeBackup] から出る例外はこれだけ。** 他の例外を漏らさない。
final class BackupFormatException implements Exception {
  const BackupFormatException(this.error);

  final BackupFormatError error;

  @override
  String toString() => 'BackupFormatException($error)';
}

/// [snapshot] を JSON 文字列にする。[exportedAt] は書き出した時刻(UTC に直して書く)。
String encodeBackup(BackupSnapshot snapshot, {required DateTime exportedAt}) {
  final map = <String, Object?>{
    'format': backupFormatId,
    'version': backupFormatVersion,
    'exportedAt': _toEpochMillis(exportedAt),
    'categories': [
      for (final category in snapshot.categories)
        <String, Object?>{
          'id': category.id,
          'name': category.name,
          'sortOrder': category.sortOrder,
        },
    ],
    'items': [
      for (final item in snapshot.items)
        <String, Object?>{
          'id': item.id,
          'name': item.name,
          'icon': item.icon,
          'categoryId': item.categoryId,
          'createdAt': _toEpochMillis(item.createdAt),
          'updatedAt': _toEpochMillis(item.updatedAt),
          'sortOrder': item.sortOrder,
        },
    ],
    'doneLogs': [
      for (final log in snapshot.doneLogs)
        <String, Object?>{
          'id': log.id,
          'itemId': log.itemId,
          'doneAt': _toEpochMillis(log.doneAt),
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// [bytes] を検証して読む。不正なら [BackupFormatException] を投げる(他の例外を漏らさない)。
BackupSnapshot decodeBackup(List<int> bytes) {
  if (bytes.length > maxBackupFileBytes) {
    throw const BackupFormatException(BackupFormatError.notBackupFile);
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const BackupFormatException(BackupFormatError.notBackupFile);
  }

  if (decoded is! Map<String, dynamic>) {
    throw const BackupFormatException(BackupFormatError.notBackupFile);
  }
  final top = decoded;

  if (top['format'] != backupFormatId) {
    throw const BackupFormatException(BackupFormatError.notBackupFile);
  }

  final version = top['version'];
  if (version is! int || version < 1) {
    throw const BackupFormatException(BackupFormatError.notBackupFile);
  }
  if (version > backupFormatVersion) {
    throw const BackupFormatException(BackupFormatError.newerVersion);
  }

  try {
    return _decodeContent(top);
  } on BackupFormatException {
    rethrow;
  } catch (_) {
    throw const BackupFormatException(BackupFormatError.invalidContent);
  }
}

/// 書き出すファイル名。[localNow] のローカル日付を使う(呼び出し側が toLocal() 済みで渡す)。
String backupFileNameOf(DateTime localNow) {
  final year = localNow.year.toString().padLeft(4, '0');
  final month = localNow.month.toString().padLeft(2, '0');
  final day = localNow.day.toString().padLeft(2, '0');
  return 'lastwhen-backup-$year$month$day.json';
}

int _toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime _toUtc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

const BackupFormatException _invalidContent = BackupFormatException(
  BackupFormatError.invalidContent,
);

BackupSnapshot _decodeContent(Map<String, dynamic> top) {
  // exportedAt は int であることだけ確かめる(値は使わない)。
  if (top['exportedAt'] is! int) {
    throw _invalidContent;
  }

  final categoriesRaw = top['categories'];
  final itemsRaw = top['items'];
  final doneLogsRaw = top['doneLogs'];
  if (categoriesRaw is! List || itemsRaw is! List || doneLogsRaw is! List) {
    throw _invalidContent;
  }

  final categories = <BackupCategory>[];
  final categoryNames = <String>[];
  final categoryIds = <String>{};
  for (final raw in categoriesRaw) {
    if (raw is! Map<String, dynamic>) {
      throw _invalidContent;
    }
    final id = _requireNonEmptyString(raw, 'id');
    if (!categoryIds.add(id)) {
      throw _invalidContent;
    }
    final rawName = _requireString(raw, 'name');
    final validated = validateCategoryName(
      rawName,
      existingNames: categoryNames,
    );
    if (validated is! ValidCategoryName) {
      throw _invalidContent;
    }
    // 重複判定はトリム後の名前で比べる。モデルには検証が通った元の文字列をそのまま
    // 入れる(トリムし直さない)。
    categoryNames.add(validated.value);
    final sortOrder = _requireInt(raw, 'sortOrder');
    categories.add(BackupCategory(id: id, name: rawName, sortOrder: sortOrder));
  }

  final items = <BackupItem>[];
  final itemIds = <String>{};
  for (final raw in itemsRaw) {
    if (raw is! Map<String, dynamic>) {
      throw _invalidContent;
    }
    final id = _requireNonEmptyString(raw, 'id');
    if (!itemIds.add(id)) {
      throw _invalidContent;
    }
    final rawName = _requireString(raw, 'name');
    if (validateItemName(rawName) is! ValidItemName) {
      throw _invalidContent;
    }
    final icon = _requireNullableString(raw, 'icon');
    final categoryId = _requireNullableString(raw, 'categoryId');
    if (categoryId != null && !categoryIds.contains(categoryId)) {
      throw _invalidContent;
    }
    final createdAtMs = _requireNonNegativeInt(raw, 'createdAt');
    final updatedAtMs = _requireNonNegativeInt(raw, 'updatedAt');
    final sortOrder = _requireInt(raw, 'sortOrder');
    items.add(
      BackupItem(
        id: id,
        name: rawName,
        icon: icon,
        categoryId: categoryId,
        createdAt: _toUtc(createdAtMs),
        updatedAt: _toUtc(updatedAtMs),
        sortOrder: sortOrder,
      ),
    );
  }

  final doneLogs = <BackupDoneLog>[];
  final doneLogIds = <String>{};
  for (final raw in doneLogsRaw) {
    if (raw is! Map<String, dynamic>) {
      throw _invalidContent;
    }
    final id = _requireNonEmptyString(raw, 'id');
    if (!doneLogIds.add(id)) {
      throw _invalidContent;
    }
    final itemId = _requireNonEmptyString(raw, 'itemId');
    if (!itemIds.contains(itemId)) {
      throw _invalidContent;
    }
    final doneAtMs = _requireNonNegativeInt(raw, 'doneAt');
    doneLogs.add(
      BackupDoneLog(id: id, itemId: itemId, doneAt: _toUtc(doneAtMs)),
    );
  }

  return BackupSnapshot(
    categories: categories,
    items: items,
    doneLogs: doneLogs,
  );
}

/// キーが無ければ違反。値が `String` でなければ違反。
String _requireString(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key)) {
    throw _invalidContent;
  }
  final value = map[key];
  if (value is! String) {
    throw _invalidContent;
  }
  return value;
}

/// [_requireString] に加え、空文字でないことを確かめる。
String _requireNonEmptyString(Map<String, dynamic> map, String key) {
  final value = _requireString(map, key);
  if (value.isEmpty) {
    throw _invalidContent;
  }
  return value;
}

/// キーが無ければ違反。値が `String` か `null` でなければ違反(キーの存在は必須)。
String? _requireNullableString(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key)) {
    throw _invalidContent;
  }
  final value = map[key];
  if (value != null && value is! String) {
    throw _invalidContent;
  }
  return value as String?;
}

/// キーが無ければ違反。値が `int` でなければ違反(`double` は不可)。
int _requireInt(Map<String, dynamic> map, String key) {
  if (!map.containsKey(key)) {
    throw _invalidContent;
  }
  final value = map[key];
  if (value is! int) {
    throw _invalidContent;
  }
  return value;
}

/// [_requireInt] に加え、0 以上であることを確かめる。
int _requireNonNegativeInt(Map<String, dynamic> map, String key) {
  final value = _requireInt(map, key);
  if (value < 0) {
    throw _invalidContent;
  }
  return value;
}
