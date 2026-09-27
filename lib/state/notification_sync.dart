import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/clock.dart';
import '../domain/item.dart';
import '../domain/notification_plan.dart';
import '../domain/notification_scheduler.dart';
import 'providers.dart';

/// 通知の本文。[elapsedDays] は通知する暦日の経過日数。
String notificationBodyOf(int elapsedDays) =>
    '最後：$elapsedDays日前。いつもより間が空いているかも。';

/// 項目の一覧の変化に合わせて、通知の予約を張り直す。
final class NotificationSync {
  // 外部公開の引数名(scheduler / clock)をフィールド名(_scheduler / _clock)と変える
  // 都合で initializing formal は使わない(`prefer_initializing_formals` は無効化)。
  NotificationSync({
    required NotificationScheduler scheduler,
    required Clock clock,
    // ignore: prefer_initializing_formals
  }) : _scheduler = scheduler,
       // ignore: prefer_initializing_formals
       _clock = clock;

  final NotificationScheduler _scheduler;
  final Clock _clock;

  List<Item>? _pending;
  Future<void>? _draining;
  bool _permissionRequested = false;

  /// 項目の一覧が変わったときに呼ぶ。直列に処理し、処理中に来た分は最新の 1 回だけにまとめる。
  /// 返す Future は、その時点で溜まっている分を処理し終えたら完了する。
  Future<void> onItemsChanged(List<Item> items) {
    _pending = items;
    return _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final items = _pending!;
      _pending = null;
      await _syncOnce(items);
    }
  }

  Future<void> _syncOnce(List<Item> items) async {
    try {
      final plan = planNotifications(items, now: _clock.now());
      if (plan.isNotEmpty && !_permissionRequested) {
        _permissionRequested = true;
        await _scheduler.requestPermission();
      }
      await _scheduler.replaceAll([
        for (final p in plan)
          ScheduledNotification(
            id: notificationIdOf(p.itemId),
            title: p.itemName,
            body: notificationBodyOf(p.elapsedDays),
            fireAt: p.fireAt,
          ),
      ]);
    } catch (error, stackTrace) {
      developer.log(
        '通知の予約に失敗しました',
        error: error,
        stackTrace: stackTrace,
        name: 'NotificationSync',
      );
    }
  }
}

/// 項目の一覧を購読し、変わるたびに通知の予約を張り直す。**`main()` で 1 度 read して起動する。**
final notificationSyncProvider = Provider<NotificationSync>((ref) {
  final sync = NotificationSync(
    scheduler: ref.watch(notificationSchedulerProvider),
    clock: ref.watch(clockProvider),
  );
  final subscription = ref
      .watch(itemRepositoryProvider)
      .watchAll()
      .listen(
        sync.onItemsChanged,
        onError: (Object error, StackTrace stackTrace) => developer.log(
          '項目の購読に失敗しました',
          error: error,
          stackTrace: stackTrace,
          name: 'NotificationSync',
        ),
      );
  ref.onDispose(subscription.cancel);
  return sync;
});
