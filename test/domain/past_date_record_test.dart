import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/past_date_record.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  final yesterday = DateTime(local.year, local.month, local.day - 1);
  final tomorrow = DateTime(local.year, local.month, local.day + 1);

  test('今日の暦日は現在時刻を UTC で返す', () {
    final result = doneAtOfPickedDate(today, now: now);
    expect(result, now);
    expect(result.isUtc, isTrue);
  });

  test('昨日の暦日はローカル正午を UTC にして返す', () {
    final result = doneAtOfPickedDate(yesterday, now: now);
    expect(
      result,
      DateTime(yesterday.year, yesterday.month, yesterday.day, 12).toUtc(),
    );
    expect(result.isUtc, isTrue);
  });

  test('明日は未来日で、今日と昨日は未来日ではない', () {
    expect(isFuturePickedDate(tomorrow, now: now), isTrue);
    expect(isFuturePickedDate(today, now: now), isFalse);
    expect(isFuturePickedDate(yesterday, now: now), isFalse);
  });
}
