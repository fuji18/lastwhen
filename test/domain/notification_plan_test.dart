import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/notification_plan.dart';

Item _item(
  String id, {
  DateTime? lastDoneAt,
  List<DateTime> recentDoneAts = const <DateTime>[],
}) => Item(
  id: ItemId(id),
  name: id,
  lastDoneAt: lastDoneAt,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  sortOrder: 0,
  recentDoneAts: recentDoneAts,
);

void main() {
  group('notificationRelativeElapsedThreshold', () {
    test('しきい値は aged の下端', () {
      expect(
        agingStageOf(notificationRelativeElapsedThreshold),
        AgingStage.aged,
      );
      expect(
        agingStageOf(notificationRelativeElapsedThreshold - 0.001),
        AgingStage.dueSoon,
      );
    });
  });

  group('daysUntilNotification', () {
    final cases = <double, int>{1: 2, 2: 3, 4: 6, 5: 8, 6.5: 10, 7: 11, 30: 45};

    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () {
        expect(daysUntilNotification(entry.key), entry.value);
      });

      test('${entry.key}: n で初めて相対経過度が 1.5 以上になる', () {
        final n = daysUntilNotification(entry.key);
        expect(
          n / entry.key,
          greaterThanOrEqualTo(notificationRelativeElapsedThreshold),
        );
        expect(
          (n - 1) / entry.key,
          lessThan(notificationRelativeElapsedThreshold),
        );
      });
    }
  });

  group('planNotifications', () {
    test('未実施は除外', () {
      final items = [_item('a')];
      expect(planNotifications(items, now: DateTime.utc(2026, 9, 1)), isEmpty);
    });

    test('記録 1 件は除外', () {
      final items = [
        _item(
          'a',
          lastDoneAt: DateTime.utc(2026, 9, 1),
          recentDoneAts: [DateTime.utc(2026, 9, 1)],
        ),
      ];
      expect(planNotifications(items, now: DateTime.utc(2026, 9, 20)), isEmpty);
    });

    test('同じ暦日に 2 件は除外', () {
      final items = [
        _item(
          'a',
          lastDoneAt: DateTime.utc(2026, 9, 1, 8),
          recentDoneAts: [
            DateTime.utc(2026, 9, 1, 8),
            DateTime.utc(2026, 9, 1, 20),
          ],
        ),
      ];
      expect(planNotifications(items, now: DateTime.utc(2026, 9, 20)), isEmpty);
    });

    test('基準間隔 7 日', () {
      final lastDoneAt = DateTime(2026, 9, 1, 8).toUtc();
      final items = [
        _item(
          'a',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime(2026, 8, 25).toUtc()],
        ),
      ];
      final plan = planNotifications(items, now: DateTime.utc(2026, 1, 1));
      expect(plan, hasLength(1));
      expect(plan.single.fireAt, DateTime(2026, 9, 12, 19).toUtc());
      expect(plan.single.elapsedDays, 11);
    });

    test('最終実施が夜でも暦日で数える', () {
      final lastDoneAt = DateTime(2026, 9, 1, 23, 30).toUtc();
      final items = [
        _item(
          'a',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime(2026, 8, 25).toUtc()],
        ),
      ];
      final plan = planNotifications(items, now: DateTime.utc(2026, 1, 1));
      expect(plan.single.fireAt, DateTime(2026, 9, 12, 19).toUtc());
    });

    test('予定時刻を過ぎたら除外', () {
      final lastDoneAt = DateTime(2026, 9, 1, 8).toUtc();
      final items = [
        _item(
          'a',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime(2026, 8, 25).toUtc()],
        ),
      ];
      expect(
        planNotifications(items, now: DateTime(2026, 9, 12, 19).toUtc()),
        isEmpty,
      );
      expect(
        planNotifications(items, now: DateTime(2026, 9, 12, 18, 59).toUtc()),
        hasLength(1),
      );
    });

    test('月をまたぐ', () {
      final lastDoneAt = DateTime(2026, 1, 28).toUtc();
      final items = [
        _item(
          'a',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime(2026, 1, 24).toUtc()],
        ),
      ];
      final plan = planNotifications(items, now: DateTime.utc(2025, 1, 1));
      expect(plan.single.fireAt, DateTime(2026, 2, 3, 19).toUtc());
    });

    test('並びと上限', () {
      final now = DateTime.utc(2026, 1, 1);
      final items = [
        for (var i = 0; i < 61; i++)
          _item(
            'item-${i.toString().padLeft(2, '0')}',
            lastDoneAt: DateTime.utc(2026, 9, 1, 8),
            recentDoneAts: [
              DateTime.utc(2026, 9, 1, 8).add(Duration(seconds: i)),
              DateTime.utc(2026, 8, 25),
            ],
          ),
      ];
      final plan = planNotifications(items, now: now);
      expect(plan, hasLength(maxScheduledNotifications));
      for (var i = 1; i < plan.length; i++) {
        expect(
          plan[i].fireAt.isAfter(plan[i - 1].fireAt) ||
              plan[i].fireAt.isAtSameMomentAs(plan[i - 1].fireAt),
          isTrue,
        );
      }
    });

    test('同時刻は itemId 順', () {
      final lastDoneAt = DateTime.utc(2026, 9, 1, 8);
      final items = [
        _item(
          'b',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime.utc(2026, 8, 25)],
        ),
        _item(
          'a',
          lastDoneAt: lastDoneAt,
          recentDoneAts: [lastDoneAt, DateTime.utc(2026, 8, 25)],
        ),
      ];
      final plan = planNotifications(items, now: DateTime.utc(2026, 1, 1));
      expect(plan.map((p) => p.itemId.value), ['a', 'b']);
    });
  });

  group('notificationIdOf', () {
    test('同じ ID は同じ値', () {
      expect(notificationIdOf(ItemId('x')), notificationIdOf(ItemId('x')));
    });

    test('0 以上 0x7fffffff 以下', () {
      final value = notificationIdOf(ItemId('some-item-id'));
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(0x7fffffff));
    });

    test('FNV-1a の期待値と一致', () {
      expect(notificationIdOf(ItemId('a')), 0xe40c292c & 0x7fffffff);
    });
  });
}
