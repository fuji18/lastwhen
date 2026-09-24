import 'item_icon.dart';

/// 項目 ID。素の String と取り違えないための型。
///
/// `rename(name, id)` のような引数の取り違えがコンパイルエラーになる。
extension type const ItemId(String value) {}

/// 管理する生活行動 1 件。
final class Item {
  const Item({
    required this.id,
    required this.name,
    required this.lastDoneAt,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
    this.recentDoneAts = const <DateTime>[],
    this.icon,
  });

  final ItemId id;

  /// 前後の空白を除いた 1〜50 文字。検証は `validateItemName` が行う。
  final String name;

  /// 最終実施日時(UTC)。**null は一度も記録がないこと(未実施)を表す。**
  final DateTime? lastDoneAt;

  /// 登録日時(UTC)。
  final DateTime createdAt;

  /// 最後に書き込みが起きた日時(UTC)。記録の取り消しでも前進させる。
  final DateTime updatedAt;

  /// 表示順。MVP では常に登録順と一致する。
  final int sortOrder;

  /// 直近の実施日時(UTC)。**新しい順**、最大 [recentDoneAtsLimit] 件。
  /// 未実施なら空。先頭は [lastDoneAt] と一致する。
  final List<DateTime> recentDoneAts;

  /// 項目のアイコン。**null は未選択**(UI が既定アイコンを描く)。
  final ItemIcon? icon;

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.name == name &&
      other.lastDoneAt == lastDoneAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.sortOrder == sortOrder &&
      _listEquals(other.recentDoneAts, recentDoneAts) &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    lastDoneAt,
    createdAt,
    updatedAt,
    sortOrder,
    Object.hashAll(recentDoneAts),
    icon,
  );
}

/// `package:collection` を使わない要素比較(`lib/domain/` はレイヤー依存テストの対象)。
bool _listEquals(List<DateTime> a, List<DateTime> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
