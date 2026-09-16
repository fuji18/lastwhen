import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/elapsed_days.dart';

void main() {
  test('DaysAgo は日数が同じなら等しい', () {
    expect(const DaysAgo(42), const DaysAgo(42));
    expect(const DaysAgo(42).hashCode, const DaysAgo(42).hashCode);
    expect(const DaysAgo(42), isNot(const DaysAgo(7)));
  });

  group('経過日数の算出', () {
    test('同じ日に記録して同じ日に表示すると 0 日', () {
      final last = DateTime.utc(2026, 1, 10, 3, 0);
      final now = DateTime.utc(2026, 1, 10, 3, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 0);
    });

    test('日付をまたぐと 24 時間未満でも 1 日', () {
      // ローカルリテラルで書く: elapsedDays は内部で toLocal() するため
      // UTC リテラルで深夜をまたぐ値を書くと JST では同じ暦日に丸まり 0 になる(実測)。
      final last = DateTime(2026, 1, 10, 23, 0);
      final now = DateTime(2026, 1, 11, 2, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 1);
    });

    test('同じ日の 23:59 は 0 日', () {
      // ローカルリテラルで書く: 理由は上のテストと同じ(design.md §3.1 の注記)。
      final last = DateTime(2026, 1, 10, 23, 59);
      final now = DateTime(2026, 1, 10, 23, 59);
      expect(elapsedDays(lastDoneAt: last, now: now), 0);
    });

    test('月をまたぐと暦日で数える', () {
      final last = DateTime.utc(2026, 1, 31, 6, 0);
      final now = DateTime.utc(2026, 2, 1, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 1);
    });

    test('うるう年の 2月28日から 3月1日は 2 日', () {
      final last = DateTime.utc(2024, 2, 28, 6, 0);
      final now = DateTime.utc(2024, 3, 1, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 2);
    });

    test('年をまたぐと暦日で数える', () {
      final last = DateTime.utc(2025, 12, 31, 6, 0);
      final now = DateTime.utc(2026, 1, 1, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 1);
    });

    test('夏時間の切替日をまたいでも暦日どおり', () {
      final last = DateTime.utc(2026, 3, 8, 6, 0);
      final now = DateTime.utc(2026, 3, 9, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 1);
    });

    test('端末時計が巻き戻っても負数を返さない', () {
      final last = DateTime.utc(2026, 1, 10, 6, 0);
      final now = DateTime.utc(2026, 1, 5, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 0);
    });

    test('離れた日付は日数をそのまま返す', () {
      final last = DateTime.utc(2026, 1, 1, 6, 0);
      final now = DateTime.utc(2026, 2, 12, 6, 0);
      expect(elapsedDays(lastDoneAt: last, now: now), 42);
    });
  });

  group('暦日の取り直し', () {
    test('暦日は UTC の点として返る', () {
      final result = calendarDateOf(DateTime(2026, 3, 8, 23, 30));
      expect(result.isUtc, isTrue);
    });

    test('時刻成分は落ちる', () {
      final result = calendarDateOf(DateTime(2026, 3, 8, 23, 30));
      expect(result, DateTime.utc(2026, 3, 8));
    });
  });

  group('経過日数のラベル分類', () {
    test('最終実施日が null なら未実施', () {
      final label = elapsedLabel(
        lastDoneAt: null,
        now: DateTime.utc(2026, 1, 10, 3, 0),
      );
      expect(label, isA<NeverDone>());
    });

    test('0 日なら今日', () {
      final now = DateTime.utc(2026, 1, 10, 3, 0);
      final label = elapsedLabel(lastDoneAt: now, now: now);
      expect(label, isA<Today>());
    });

    test('1 日なら昨日', () {
      final last = DateTime.utc(2026, 1, 9, 3, 0);
      final now = DateTime.utc(2026, 1, 10, 3, 0);
      final label = elapsedLabel(lastDoneAt: last, now: now);
      expect(label, isA<Yesterday>());
    });

    test('2 日なら 2日前', () {
      final last = DateTime.utc(2026, 1, 8, 3, 0);
      final now = DateTime.utc(2026, 1, 10, 3, 0);
      final label = elapsedLabel(lastDoneAt: last, now: now);
      expect(label, isA<DaysAgo>());
      expect((label as DaysAgo).days, 2);
    });

    test('42 日なら 42日前', () {
      final last = DateTime.utc(2026, 1, 1, 6, 0);
      final now = DateTime.utc(2026, 2, 12, 6, 0);
      final label = elapsedLabel(lastDoneAt: last, now: now);
      expect(label, isA<DaysAgo>());
      expect((label as DaysAgo).days, 42);
    });

    test('端末時計が巻き戻っていても今日になる', () {
      final last = DateTime.utc(2026, 1, 10, 6, 0);
      final now = DateTime.utc(2026, 1, 5, 6, 0);
      final label = elapsedLabel(lastDoneAt: last, now: now);
      expect(label, isA<Today>());
    });
  });
}
