import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';

Item _item(DateTime? lastDoneAt, {List<DateTime> recentDoneAts = const []}) =>
    Item(
      id: const ItemId('item-1'),
      name: '美容院',
      lastDoneAt: lastDoneAt,
      createdAt: DateTime.utc(2026, 1, 1, 3),
      updatedAt: DateTime.utc(2026, 9, 12, 3),
      sortOrder: 0,
      recentDoneAts: recentDoneAts,
    );

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);

  test('9月12日の記録はゼロ埋めせず日本語の日付になる', () {
    final view = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    expect(view.lastDoneText, '2026年9月12日');
  });

  test('1月5日の記録でも月と日をゼロ埋めしない', () {
    final view = ItemView.from(_item(DateTime.utc(2026, 1, 5, 3)), now: now);
    expect(view.lastDoneText, '2026年1月5日');
  });

  test('未実施なら最終実施日の文字列は null', () {
    expect(ItemView.from(_item(null), now: now).lastDoneText, isNull);
  });

  test('DaysAgo を含めて同じ内容の表示モデルは等しい', () {
    final first = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    final second = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    expect(first.elapsed, const DaysAgo(4));
    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  group('前回間隔・基準間隔・相対経過度', () {
    test('履歴 0 件なら 3 フィールドとも null', () {
      final view = ItemView.from(_item(null), now: now);
      expect(view.previousIntervalDays, isNull);
      expect(view.baselineIntervalDays, isNull);
      expect(view.relativeElapsed, isNull);
    });

    test('履歴 1 件なら 3 フィールドとも null(間隔が取れない)', () {
      final lastDoneAt = DateTime.utc(2026, 9, 12, 3);
      final view = ItemView.from(
        _item(lastDoneAt, recentDoneAts: [lastDoneAt]),
        now: now,
      );
      expect(view.previousIntervalDays, isNull);
      expect(view.baselineIntervalDays, isNull);
      expect(view.relativeElapsed, isNull);
    });

    test('履歴 3 件なら前回間隔・基準間隔・相対経過度が算出される', () {
      final lastDoneAt = DateTime.utc(2026, 9, 12, 3);
      final view = ItemView.from(
        _item(
          lastDoneAt,
          recentDoneAts: [
            lastDoneAt,
            DateTime.utc(2026, 9, 5, 3),
            DateTime.utc(2026, 8, 29, 3),
          ],
        ),
        now: now,
      );
      // 間隔: 7, 7 → 前回間隔 7、基準間隔(中央値)7.0。
      expect(view.previousIntervalDays, 7);
      expect(view.baselineIntervalDays, 7.0);
      // 経過日数 4 ÷ 基準間隔 7.0。
      expect(view.relativeElapsed, 4 / 7.0);
    });
  });
}
