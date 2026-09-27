import 'package:lastwhen/domain/notification_scheduler.dart';

/// メモリ上の [NotificationScheduler]。OS のプラグインを起動せずに上位層をテストするために置く。
final class FakeNotificationScheduler implements NotificationScheduler {
  /// `requestPermission` が呼ばれた回数。
  int requestPermissionCount = 0;

  /// `requestPermission` が返す値。
  bool permissionResult = true;

  /// `replaceAll` が呼ばれるたびに追加される。
  final List<List<ScheduledNotification>> replaced =
      <List<ScheduledNotification>>[];

  /// 非 null のとき、`replaceAll` がこの値を投げる。
  Object? failWith;

  /// 直近の `replaceAll` の呼び出し内容。
  List<ScheduledNotification> get last => replaced.last;

  @override
  Future<bool> requestPermission() async {
    requestPermissionCount++;
    return permissionResult;
  }

  @override
  Future<void> replaceAll(List<ScheduledNotification> notifications) async {
    final error = failWith;
    if (error != null) {
      throw error;
    }
    replaced.add(notifications);
  }
}
