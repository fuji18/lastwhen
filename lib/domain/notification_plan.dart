import 'baseline_interval.dart';
import 'item.dart';

/// 通知する相対経過度のしきい値。経年ステージ「経過」(aged)の下端と同じ。
const double notificationRelativeElapsedThreshold = 1.5;

/// 通知する時刻(ローカルの時)。
const int notificationHourOfDay = 19;

/// 一度に予約する通知の上限。iOS の予約上限(64)に余裕を残す。
const int maxScheduledNotifications = 60;

/// 予約する通知 1 件。
final class PlannedNotification {
  const PlannedNotification({
    required this.itemId,
    required this.itemName,
    required this.elapsedDays,
    required this.fireAt,
  });

  final ItemId itemId;
  final String itemName;

  /// 通知する暦日の経過日数(最終実施日の暦日からの差)。
  final int elapsedDays;

  /// 通知する時刻(UTC)。
  final DateTime fireAt;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.itemId == itemId &&
      other.itemName == itemName &&
      other.elapsedDays == elapsedDays &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(itemId, itemName, elapsedDays, fireAt);
}

/// `n / baseline >= threshold` を満たす最小の整数 n(1 以上)を返す。
int daysUntilNotification(double baselineIntervalDays) {
  var n = (notificationRelativeElapsedThreshold * baselineIntervalDays).ceil();
  // 浮動小数の誤差で 1 つ大きくなった場合の補正
  while (n > 1 &&
      (n - 1) / baselineIntervalDays >= notificationRelativeElapsedThreshold) {
    n--;
  }
  return n < 1 ? 1 : n;
}

/// 項目の一覧から、これから予約すべき通知の計画を作る。
///
/// [now] より前に予定時刻を迎える項目は含めない(過ぎた予定を後から鳴らさない)。
/// 予定時刻の昇順(同時刻なら [ItemId.value] の昇順)に並べ、
/// 先頭 [maxScheduledNotifications] 件だけを返す。
List<PlannedNotification> planNotifications(
  List<Item> items, {
  required DateTime now,
}) {
  final plans = <PlannedNotification>[];
  for (final item in items) {
    final lastDoneAt = item.lastDoneAt;
    if (lastDoneAt == null) {
      continue;
    }
    final baseline = baselineIntervalDays(item.recentDoneAts);
    if (baseline == null) {
      continue;
    }
    final n = daysUntilNotification(baseline);
    final last = lastDoneAt.toLocal();
    final fireAt = DateTime(
      last.year,
      last.month,
      last.day + n,
      notificationHourOfDay,
    ).toUtc();
    if (!fireAt.isAfter(now)) {
      continue;
    }
    plans.add(
      PlannedNotification(
        itemId: item.id,
        itemName: item.name,
        elapsedDays: n,
        fireAt: fireAt,
      ),
    );
  }

  plans.sort((a, b) {
    final byFireAt = a.fireAt.compareTo(b.fireAt);
    return byFireAt != 0 ? byFireAt : a.itemId.value.compareTo(b.itemId.value);
  });

  return plans.length <= maxScheduledNotifications
      ? plans
      : plans.sublist(0, maxScheduledNotifications);
}

/// 項目 ID から通知 ID を導く。FNV-1a(32bit)の下位 31bit。
int notificationIdOf(ItemId id) {
  var hash = 0x811c9dc5;
  for (final unit in id.value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
