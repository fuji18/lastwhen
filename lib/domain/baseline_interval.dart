import 'elapsed_days.dart';

/// 一覧で項目ごとに読み出す直近履歴の件数。
const int recentDoneAtsLimit = 10;

/// 基準間隔の算出に使う間隔の最大数。
const int baselineIntervalSampleSize = 5;

/// 実施日時(新しい順・UTC)から、**暦日の間隔**を新しい順に返す。
///
/// - 各日時はローカルの暦日に直してから比べる(`calendarDateOf(x.toLocal())`)。
///   `elapsedDays` と同じ規則で、夏時間の切替をまたいでも 1 日ずれない
/// - **同じ暦日の記録は 1 つにまとめる**(同日に 2 回押しても間隔 0 日を作らない)
/// - 暦日は降順に並べ直してから差を取る(端末時計の巻き戻りで順序が崩れても負の間隔を作らない)
/// - 結果の各要素は 1 以上。暦日が 1 つ以下なら空リスト
List<int> intervalDaysOf(List<DateTime> doneAtsNewestFirst) {
  final calendarDates = <DateTime>{
    for (final doneAt in doneAtsNewestFirst) calendarDateOf(doneAt.toLocal()),
  }.toList()..sort((a, b) => b.compareTo(a));

  if (calendarDates.length <= 1) {
    return const <int>[];
  }

  final intervals = <int>[];
  for (var i = 0; i < calendarDates.length - 1; i++) {
    intervals.add(calendarDates[i].difference(calendarDates[i + 1]).inDays);
  }
  return intervals;
}

/// 前回間隔: 直近 2 つの暦日の差。取れなければ null。
int? previousIntervalDays(List<DateTime> doneAtsNewestFirst) {
  final intervals = intervalDaysOf(doneAtsNewestFirst);
  return intervals.isEmpty ? null : intervals.first;
}

/// 基準間隔: 直近最大 [baselineIntervalSampleSize] 個の間隔の**中央値**。取れなければ null。
///
/// 個数が偶数なら中央 2 つの平均(例: 6 と 7 → 6.5)。**丸めない**。
///
/// **中央値を採る理由**: 1 回だけ極端に空いた間隔に基準が引っ張られないようにするため。
double? baselineIntervalDays(List<DateTime> doneAtsNewestFirst) {
  final intervals = intervalDaysOf(
    doneAtsNewestFirst,
  ).take(baselineIntervalSampleSize).toList()..sort();

  if (intervals.isEmpty) {
    return null;
  }

  final middle = intervals.length ~/ 2;
  if (intervals.length.isOdd) {
    return intervals[middle].toDouble();
  }
  return (intervals[middle - 1] + intervals[middle]) / 2;
}

/// 相対経過度: 経過日数 ÷ 基準間隔。どちらかが null なら null。**丸めない。**
double? relativeElapsed({
  required int? elapsedDays,
  required double? baselineIntervalDays,
}) {
  if (elapsedDays == null || baselineIntervalDays == null) {
    return null;
  }
  return elapsedDays / baselineIntervalDays;
}
