import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/notification_plan.dart';
import 'package:lastwhen/state/notification_sync.dart';
import 'package:lastwhen/state/providers.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';
import '../support/fake_notification_scheduler.dart';

Item _item(
  String id, {
  DateTime? lastDoneAt,
  List<DateTime> recentDoneAts = const <DateTime>[],
  String? name,
}) => Item(
  id: ItemId(id),
  name: name ?? id,
  lastDoneAt: lastDoneAt,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  sortOrder: 0,
  recentDoneAts: recentDoneAts,
);

// 基準間隔 7 日、経過日数 11 で通知が張られる項目。
Item _plannedItem(String id, {String? name}) {
  final lastDoneAt = DateTime(2026, 9, 1, 8).toUtc();
  return _item(
    id,
    name: name,
    lastDoneAt: lastDoneAt,
    recentDoneAts: [lastDoneAt, DateTime(2026, 8, 25).toUtc()],
  );
}

void main() {
  group('NotificationSync', () {
    late FakeNotificationScheduler scheduler;
    late FakeClock clock;
    late NotificationSync sync;

    setUp(() {
      scheduler = FakeNotificationScheduler();
      clock = FakeClock(DateTime.utc(2026, 9, 10));
      sync = NotificationSync(scheduler: scheduler, clock: clock);
    });

    test('計画が空なら権限を要求しない', () async {
      await sync.onItemsChanged([_item('a')]);
      expect(scheduler.requestPermissionCount, 0);
      expect(scheduler.last, isEmpty);
    });

    test('計画が 1 件以上で権限を 1 回だけ要求', () async {
      await sync.onItemsChanged([_plannedItem('a')]);
      await sync.onItemsChanged([_plannedItem('a')]);
      expect(scheduler.requestPermissionCount, 1);
    });

    test('拒否されても予約は張る', () async {
      scheduler.permissionResult = false;
      await sync.onItemsChanged([_plannedItem('a')]);
      expect(scheduler.last, hasLength(1));
    });

    test('文言', () async {
      await sync.onItemsChanged([_plannedItem('a', name: '洗濯')]);
      expect(scheduler.last.single.title, '洗濯');
      expect(scheduler.last.single.body, '最後：11日前。いつもより間が空いているかも。');
    });

    test('ID', () async {
      final item = _plannedItem('a');
      await sync.onItemsChanged([item]);
      expect(scheduler.last.single.id, notificationIdOf(item.id));
    });

    test('例外を外に出さない', () async {
      scheduler.failWith = StateError('boom');
      await sync.onItemsChanged([_plannedItem('a')]);
    });

    test('まとめる', () async {
      final first = sync.onItemsChanged([_plannedItem('a')]);
      final second = sync.onItemsChanged([_plannedItem('b')]);
      final third = sync.onItemsChanged([_plannedItem('c')]);
      await Future.wait([first, second, third]);
      expect(scheduler.last.single.title, 'c');
      expect(scheduler.replaced.length, lessThan(3));
    });
  });

  group('notificationSyncProvider', () {
    late FakeItemRepository repository;
    late FakeClock clock;
    late FakeNotificationScheduler scheduler;
    late ProviderContainer container;

    setUp(() {
      repository = FakeItemRepository();
      clock = FakeClock(DateTime.utc(2026, 9, 10));
      scheduler = FakeNotificationScheduler();
      container = ProviderContainer.test(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(clock),
          notificationSchedulerProvider.overrideWithValue(scheduler),
        ],
      );
      addTearDown(repository.dispose);
    });

    test('記録で張り直す', () async {
      container.read(notificationSyncProvider);
      final item = await repository.add('洗濯', now: DateTime.utc(2026, 8, 25));
      await repository.markDone(item.id, DateTime(2026, 8, 25).toUtc());
      await pumpEventQueue();
      final before = scheduler.replaced.length;

      // 2 回目の記録(基準間隔が作れるようになる)。
      await repository.markDone(item.id, DateTime(2026, 9, 1, 8).toUtc());
      await pumpEventQueue();

      expect(scheduler.replaced.length, greaterThan(before));
      expect(
        scheduler.last.any((n) => n.id == notificationIdOf(item.id)),
        isTrue,
      );
    });

    test('削除で消える', () async {
      container.read(notificationSyncProvider);
      final item = await repository.add('洗濯', now: DateTime.utc(2026, 8, 25));
      await repository.markDone(item.id, DateTime(2026, 8, 25).toUtc());
      await repository.markDone(item.id, DateTime(2026, 9, 1, 8).toUtc());
      await pumpEventQueue();
      expect(
        scheduler.last.any((n) => n.id == notificationIdOf(item.id)),
        isTrue,
      );

      await repository.delete(item.id);
      await pumpEventQueue();

      expect(
        scheduler.last.any((n) => n.id == notificationIdOf(item.id)),
        isFalse,
      );
    });

    test('編集で文言が変わる', () async {
      container.read(notificationSyncProvider);
      final item = await repository.add('洗濯', now: DateTime.utc(2026, 8, 25));
      await repository.markDone(item.id, DateTime(2026, 8, 25).toUtc());
      await repository.markDone(item.id, DateTime(2026, 9, 1, 8).toUtc());
      await pumpEventQueue();

      await repository.edit(
        item.id,
        name: '掃除',
        icon: null,
        categoryId: null,
        now: DateTime.utc(2026, 9, 5),
      );
      await pumpEventQueue();

      expect(
        scheduler.last
            .firstWhere((n) => n.id == notificationIdOf(item.id))
            .title,
        '掃除',
      );
    });
  });
}
