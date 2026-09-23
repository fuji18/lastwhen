import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/baseline_interval.dart';

void main() {
  group('intervalDaysOf', () {
    test('記録 0 件なら空', () {
      expect(intervalDaysOf(const <DateTime>[]), isEmpty);
    });

    test('記録 1 件なら空', () {
      expect(intervalDaysOf([DateTime.utc(2026, 1, 10, 3)]), isEmpty);
    });

    test('記録 2 件なら間隔 1 つ', () {
      final doneAts = [
        DateTime.utc(2026, 1, 10, 3),
        DateTime.utc(2026, 1, 7, 3),
      ];
      expect(intervalDaysOf(doneAts), [3]);
    });

    test('同じ暦日の記録は 1 つにまとめる', () {
      final doneAts = [
        DateTime.utc(2026, 1, 10, 3),
        // 同日の 2 回目の記録。間隔 0 を作らない。
        DateTime.utc(2026, 1, 10, 20),
        DateTime.utc(2026, 1, 5, 3),
      ];
      expect(intervalDaysOf(doneAts), [5]);
    });

    test('端末時計の巻き戻りで入力の並びが崩れても負の間隔を作らない', () {
      // 本来は新しい順のはずが、古い日時が先頭に来ている(巻き戻り後の記録)。
      final scrambled = [
        DateTime.utc(2026, 1, 1, 3),
        DateTime.utc(2026, 1, 10, 3),
        DateTime.utc(2026, 1, 4, 3),
      ];
      final intervals = intervalDaysOf(scrambled);
      expect(intervals, everyElement(greaterThanOrEqualTo(1)));
      expect(intervals, [6, 3]);
    });

    test('夏時間の切替日をまたいでも暦日どおりの間隔', () {
      final doneAts = [
        DateTime.utc(2026, 3, 9, 6),
        DateTime.utc(2026, 3, 8, 6),
      ];
      expect(intervalDaysOf(doneAts), [1]);
    });

    test('件数の上限は課さない(サンプル数の上限は baselineIntervalDays 側で課す)', () {
      final doneAts = [
        DateTime.utc(2026, 4, 25),
        DateTime.utc(2026, 4, 21),
        DateTime.utc(2026, 4, 17),
        DateTime.utc(2026, 4, 13),
        DateTime.utc(2026, 4, 9),
        DateTime.utc(2026, 4, 5),
        DateTime.utc(2026, 4, 1),
      ];
      expect(intervalDaysOf(doneAts), [4, 4, 4, 4, 4, 4]);
    });
  });

  group('previousIntervalDays', () {
    test('記録 0 件なら null', () {
      expect(previousIntervalDays(const <DateTime>[]), isNull);
    });

    test('記録 1 件なら null', () {
      expect(previousIntervalDays([DateTime.utc(2026, 1, 10, 3)]), isNull);
    });

    test('直近 2 つの暦日の差', () {
      final doneAts = [
        DateTime.utc(2026, 1, 10, 3),
        DateTime.utc(2026, 1, 4, 3),
      ];
      expect(previousIntervalDays(doneAts), 6);
    });

    test('同日の多重記録は無視して次に古い暦日との差を返す', () {
      final doneAts = [
        DateTime.utc(2026, 1, 10, 3),
        DateTime.utc(2026, 1, 10, 20),
        DateTime.utc(2026, 1, 5, 3),
      ];
      expect(previousIntervalDays(doneAts), 5);
    });
  });

  group('baselineIntervalDays', () {
    test('記録 0 件なら null', () {
      expect(baselineIntervalDays(const <DateTime>[]), isNull);
    });

    test('記録 1 件なら null(間隔が取れない)', () {
      expect(baselineIntervalDays([DateTime.utc(2026, 1, 10, 3)]), isNull);
    });

    test('間隔が奇数個なら中央値そのもの', () {
      // 間隔: 7, 7, 7 (奇数個) → 中央値 7。
      final doneAts = [
        DateTime.utc(2026, 1, 22),
        DateTime.utc(2026, 1, 15),
        DateTime.utc(2026, 1, 8),
        DateTime.utc(2026, 1, 1),
      ];
      expect(baselineIntervalDays(doneAts), 7.0);
    });

    test('間隔が偶数個なら中央 2 つの平均を丸めずに返す', () {
      // 間隔: 6, 7 → 中央値 (6+7)/2 = 6.5。
      final doneAts = [
        DateTime.utc(2026, 1, 14),
        DateTime.utc(2026, 1, 8),
        DateTime.utc(2026, 1, 1),
      ];
      expect(baselineIntervalDays(doneAts), 6.5);
    });

    test('1 回だけ極端に空いた間隔に基準が引っ張られない', () {
      // 間隔(新しい順): 7, 7, 60, 7, 7 → 中央値 7。
      final doneAts = [
        DateTime.utc(2026, 4, 1),
        DateTime.utc(2026, 3, 25),
        DateTime.utc(2026, 3, 18),
        DateTime.utc(2026, 1, 17),
        DateTime.utc(2026, 1, 10),
        DateTime.utc(2026, 1, 3),
      ];
      expect(baselineIntervalDays(doneAts), 7.0);
    });

    test('直近 baselineIntervalSampleSize 個までしか使わない', () {
      // 間隔(新しい順): 1, 1, 1, 1, 1, 99 → サンプルは先頭 5 つだけ(中央値 1)。
      // 6 個目の 99 を含めていたら中央値がずれる。
      final doneAts = [
        DateTime.utc(2026, 6, 6),
        DateTime.utc(2026, 6, 5),
        DateTime.utc(2026, 6, 4),
        DateTime.utc(2026, 6, 3),
        DateTime.utc(2026, 6, 2),
        DateTime.utc(2026, 6, 1),
        DateTime.utc(2026, 2, 22),
      ];
      expect(baselineIntervalDays(doneAts), 1.0);
    });
  });

  group('relativeElapsed', () {
    test('経過日数が null なら null', () {
      expect(
        relativeElapsed(elapsedDays: null, baselineIntervalDays: 10),
        isNull,
      );
    });

    test('基準間隔が null なら null', () {
      expect(
        relativeElapsed(elapsedDays: 10, baselineIntervalDays: null),
        isNull,
      );
    });

    test('両方 null なら null', () {
      expect(
        relativeElapsed(elapsedDays: null, baselineIntervalDays: null),
        isNull,
      );
    });

    test('経過日数 ÷ 基準間隔を丸めずに返す', () {
      expect(relativeElapsed(elapsedDays: 10, baselineIntervalDays: 4), 2.5);
    });
  });
}
