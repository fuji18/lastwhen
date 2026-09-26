import 'elapsed_days.dart';

/// 日付の選択で選ばれた暦日([pickedDate]、ローカル)が、[now] から見て未来か。
bool isFuturePickedDate(DateTime pickedDate, {required DateTime now}) =>
    calendarDateOf(pickedDate).isAfter(calendarDateOf(now.toLocal()));

/// 選ばれた暦日を記録日時(UTC)に直す(F16)。
///
/// - **今日なら [now] そのもの**(「やった」と同じ時刻の意味にする)
/// - 過去日なら**その日のローカル 12:00**。0:00 にするとタイムゾーンを西へまたいだとき
///   前日の暦日に読めてしまう。正午なら ±12 時間まで同じ暦日に収まる
///
/// 未来日かどうかは見ない(呼び出し側が [isFuturePickedDate] で弾く)。
DateTime doneAtOfPickedDate(DateTime pickedDate, {required DateTime now}) {
  if (calendarDateOf(pickedDate) == calendarDateOf(now.toLocal())) {
    return now.toUtc();
  }
  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    12,
  ).toUtc();
}
