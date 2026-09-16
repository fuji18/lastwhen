/// ローカル時刻の暦日を、UTC 上の点として取り直す。
///
/// ローカルの DateTime 同士で `difference()` を取ると実時間差になる。夏時間のある地域では
/// 1 日が 23/25 時間になるため、**深夜 0 時に正規化しても `inDays` が 1 日ずれる**。
/// UTC の点として持ち直せば 1 日が常に 24 時間になり、差分が暦日数と一致する。
DateTime calendarDateOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// 最終実施日から [now] までの**暦日の差**を返す。
///
/// 24 時間単位の経過時間ではない。端末時計が巻き戻った場合に備え、負数は 0 に丸める。
int elapsedDays({required DateTime lastDoneAt, required DateTime now}) {
  final lastDate = calendarDateOf(lastDoneAt.toLocal());
  final todayDate = calendarDateOf(now.toLocal());
  final difference = todayDate.difference(lastDate).inDays;
  return difference < 0 ? 0 : difference;
}

/// 経過日数の表示ラベル。文字列の組み立ては UI 層の責務。
sealed class ElapsedLabel {
  const ElapsedLabel();
}

/// 未実施(一度も記録がない)。**「0日前」と表示しない。**
final class NeverDone extends ElapsedLabel {
  const NeverDone();
}

/// 今日。
final class Today extends ElapsedLabel {
  const Today();
}

/// 昨日。
final class Yesterday extends ElapsedLabel {
  const Yesterday();
}

/// 2 日以上前。
final class DaysAgo extends ElapsedLabel {
  const DaysAgo(this.days);

  /// 2 以上の暦日数。
  final int days;

  // 同じ日数なら同じラベル。値等価が無いと、内容の変わっていない一覧が
  // 毎回「変わった」と判定され、更新フィルタが効かない。
  @override
  bool operator ==(Object other) => other is DaysAgo && other.days == days;

  @override
  int get hashCode => days.hashCode;
}

/// 最終実施日を表示ラベルへ分類する。
///
/// [lastDoneAt] が null(= 一度も記録がない)なら [NeverDone]。
ElapsedLabel elapsedLabel({
  required DateTime? lastDoneAt,
  required DateTime now,
}) {
  if (lastDoneAt == null) {
    return const NeverDone();
  }
  final days = elapsedDays(lastDoneAt: lastDoneAt, now: now);
  return switch (days) {
    0 => const Today(),
    1 => const Yesterday(),
    _ => DaysAgo(days),
  };
}
