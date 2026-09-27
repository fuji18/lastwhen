/// OS に張る通知 1 件(文言は組み立て済み)。
final class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
  });

  final int id;
  final String title;
  final String body;

  /// UTC。
  final DateTime fireAt;

  @override
  bool operator ==(Object other) =>
      other is ScheduledNotification &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(id, title, body, fireAt);
}

/// 通知の予約。実装はデータレイヤーに置く(`ItemRepository` と同じ依存性逆転)。
abstract interface class NotificationScheduler {
  /// 通知の権限を要求する。許可されたら true。要求できない環境では false。
  Future<bool> requestPermission();

  /// 未配信の予約をすべて取り消し、[notifications] を予約し直す。
  Future<void> replaceAll(List<ScheduledNotification> notifications);
}
