import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/state/add_item_result.dart';
import 'package:lastwhen/state/edit_item_result.dart';
import 'package:lastwhen/state/item_list_notifier.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/state/mark_done_result.dart';
import 'package:lastwhen/state/record_past_date_result.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

final class _CountingClock implements Clock {
  _CountingClock(this._now);
  final DateTime _now;
  int calls = 0;

  @override
  DateTime now() {
    calls++;
    return _now;
  }
}

ProviderContainer _container(FakeItemRepository repository, Clock clock) {
  final container = ProviderContainer.test(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(clock),
    ],
  );
  container.listen(itemListProvider, (_, _) {});
  return container;
}

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  test('項目がなければ空リストになる', () async {
    final container = _container(repository, FakeClock(now));
    expect(await container.read(itemListProvider.future), isEmpty);
  });

  test('未実施の項目は NeverDone で日付がない', () async {
    await repository.add('美容院', now: now);
    final container = _container(repository, FakeClock(now));
    final view = (await container.read(itemListProvider.future)).single;
    expect(view.elapsed, isA<NeverDone>());
    expect(view.lastDoneText, isNull);
  });

  test('今日記録した項目は Today と今日の日付になる', () async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, now);
    final container = _container(repository, FakeClock(now));
    final view = (await container.read(itemListProvider.future)).single;
    expect(view.elapsed, isA<Today>());
    expect(view.lastDoneText, '2026年9月16日');
  });

  test('昨日記録した項目は Yesterday になる', () async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 15, 3));
    final container = _container(repository, FakeClock(now));
    expect(
      (await container.read(itemListProvider.future)).single.elapsed,
      isA<Yesterday>(),
    );
  });

  test('4日前の記録は DaysAgo(4) と9月12日の表示になる', () async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    final container = _container(repository, FakeClock(now));
    final view = (await container.read(itemListProvider.future)).single;
    expect(view.elapsed, const DaysAgo(4));
    expect(view.lastDoneText, '2026年9月12日');
  });

  test('Clock.now は3件あっても1回の変換につき1回だけ呼ばれる', () async {
    final clock = _CountingClock(now);
    await repository.add('美容院', now: DateTime.utc(2026, 9, 1, 3));
    await repository.add('歯ブラシ交換', now: DateTime.utc(2026, 9, 2, 3));
    await repository.add('シーツ洗濯', now: DateTime.utc(2026, 9, 3, 3));
    final container = _container(repository, clock);
    expect(await container.read(itemListProvider.future), hasLength(3));
    expect(clock.calls, 1);
  });

  test('初回読み込み後に追加すると2件の一覧が再通知される', () async {
    await repository.add('美容院', now: now);
    final container = _container(repository, FakeClock(now));
    expect(await container.read(itemListProvider.future), hasLength(1));
    final updated = Completer<List<ItemView>>();
    container.listen(itemListProvider, (_, next) {
      if (next case AsyncData(:final value) when value.length == 2) {
        if (!updated.isCompleted) updated.complete(value);
      }
    });
    // async* が初回 yield から watchAll の継続購読へ進むのを待つ。
    await Future<void>.delayed(Duration.zero);
    await repository.add('歯ブラシ交換', now: now);
    final views = await updated.future;
    expect(views.map((view) => view.name), ['美容院', '歯ブラシ交換']);
  });

  test('toItemViews は入力の並び順をそのまま保つ', () async {
    final first = await repository.add('美容院', now: now);
    final second = await repository.add('歯ブラシ交換', now: now);
    final views = toItemViews([second, first], now: now);
    expect(views.map((view) => view.id), [second.id, first.id]);
  });

  group('addItem', () {
    test('登録に成功すると未実施で日付のない項目が一覧に増える', () async {
      final container = _container(repository, FakeClock(now));
      expect(await container.read(itemListProvider.future), isEmpty);
      final updated = Completer<List<ItemView>>();
      container.listen(itemListProvider, (_, next) {
        if (next case AsyncData(:final value) when value.length == 1) {
          if (!updated.isCompleted) updated.complete(value);
        }
      });
      await Future<void>.delayed(Duration.zero);
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('美容院');
      expect(result, isA<AddItemSucceeded>());
      final view = (await updated.future).single;
      expect(view.name, '美容院');
      expect(view.elapsed, isA<NeverDone>());
      expect(view.lastDoneText, isNull);
    });

    test('前後に空白がある名前はトリムして保存される', () async {
      final container = _container(repository, FakeClock(now));
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('  美容院  ');
      expect(result, isA<AddItemSucceeded>());
      expect((await repository.watchAll().first).single.name, '美容院');
    });

    for (final rawName in ['', '   ']) {
      test('空文字または空白のみ（長さ ${rawName.length}）は保存されない', () async {
        final container = _container(repository, FakeClock(now));
        final result = await container
            .read(itemListProvider.notifier)
            .addItem(rawName);
        expect(
          result,
          isA<AddItemRejected>().having(
            (result) => result.reason,
            'reason',
            ItemNameReason.empty,
          ),
        );
        expect(await repository.watchAll().first, isEmpty);
        expect(await container.read(itemListProvider.future), isEmpty);
      });
    }

    test('50文字の名前は保存できる', () async {
      final container = _container(repository, FakeClock(now));
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('あ' * 50);
      expect(result, isA<AddItemSucceeded>());
      expect((await repository.watchAll().first).single.name, 'あ' * 50);
    });

    test('51文字の名前は保存されない', () async {
      final container = _container(repository, FakeClock(now));
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('あ' * 51);
      expect(
        result,
        isA<AddItemRejected>().having(
          (result) => result.reason,
          'reason',
          ItemNameReason.tooLong,
        ),
      );
      expect(await repository.watchAll().first, isEmpty);
      expect(await container.read(itemListProvider.future), isEmpty);
    });

    test('作成日時と更新日時は Clock の時刻になる', () async {
      final container = _container(repository, FakeClock(now));
      expect(
        await container.read(itemListProvider.notifier).addItem('美容院'),
        isA<AddItemSucceeded>(),
      );
      final item = (await repository.watchAll().first).single;
      expect(item.createdAt, now);
      expect(item.updatedAt, now);
    });

    test('保存に失敗しても一覧は AsyncData のまま既存項目を保持する', () async {
      await repository.add('歯ブラシ交換', now: now);
      final container = _container(repository, FakeClock(now));
      final before = await container.read(itemListProvider.future);
      repository.writeError = StateError('write failed');
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('美容院');
      expect(result, isA<AddItemFailed>());
      expect(
        container.read(itemListProvider),
        isA<AsyncData<List<ItemView>>>(),
      );
      expect(container.read(itemListProvider).requireValue, same(before));
      expect((await repository.watchAll().first).map((item) => item.name), [
        '歯ブラシ交換',
      ]);
    });

    test('アイコンを指定して登録するとそのアイコンで保存される', () async {
      final container = _container(repository, FakeClock(now));
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('風呂掃除', icon: ItemIcon.bath);
      expect(result, isA<AddItemSucceeded>());
      expect((await repository.watchAll().first).single.icon, ItemIcon.bath);
    });

    test('カテゴリを指定して登録するとそのカテゴリで保存される', () async {
      const categoryId = CategoryId('category-1');
      final container = _container(repository, FakeClock(now));
      final result = await container
          .read(itemListProvider.notifier)
          .addItem('風呂掃除', categoryId: categoryId);
      expect(result, isA<AddItemSucceeded>());
      expect((await repository.watchAll().first).single.categoryId, categoryId);
    });
  });
  group('記録と取り消し', () {
    Future<ProviderContainer> ready({DateTime? previous, Clock? clock}) async {
      final item = await repository.add('美容院', now: now);
      if (previous != null) await repository.markDone(item.id, previous);
      final container = _container(repository, clock ?? FakeClock(now));
      await container.read(itemListProvider.future);
      // async* が継続購読へ進んでから書き込む。
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    Future<MarkDoneResult> record(ProviderContainer container) => container
        .read(itemListProvider.notifier)
        .markDone(container.read(itemListProvider).requireValue.single.id);

    Future<ItemView> current(ProviderContainer container) async {
      await Future<void>.delayed(Duration.zero);
      return container.read(itemListProvider).requireValue.single;
    }

    test('記録すると Clock の現在日時が保存され今日になる', () async {
      final container = await ready();
      expect(await record(container), isA<MarkDoneSucceeded>());
      final view = await current(container);
      expect(view.elapsed, isA<Today>());
      expect(view.lastDoneText, '2026年9月16日');
      expect((await repository.watchAll().first).single.lastDoneAt, now);
    });

    test('未実施の取り消しハンドルは直前値が null', () async {
      final container = await ready();
      final result = await record(container) as MarkDoneSucceeded;
      expect(result.undo.previousLastDoneAt, isNull);
      expect(
        result.undo.id,
        container.read(itemListProvider).requireValue.single.id,
      );
    });

    test('記録済みの取り消しハンドルは元の日時を保持する', () async {
      final previous = DateTime.utc(2026, 9, 12, 3);
      final container = await ready(previous: previous);
      final result = await record(container) as MarkDoneSucceeded;
      expect(result.undo.previousLastDoneAt, previous);
    });

    test('取り消すと未実施に戻り日付がなくなる', () async {
      final container = await ready();
      final result = await record(container) as MarkDoneSucceeded;
      expect((await current(container)).elapsed, isA<Today>());
      expect(
        await container
            .read(itemListProvider.notifier)
            .undoMarkDone(result.undo),
        isA<UndoSucceeded>(),
      );
      final view = await current(container);
      expect(view.elapsed, isA<NeverDone>());
      expect(view.lastDoneText, isNull);
    });

    test('取り消すと直前の日付に戻る', () async {
      final previous = DateTime.utc(2026, 9, 12, 3);
      final container = await ready(previous: previous);
      final result = await record(container) as MarkDoneSucceeded;
      expect((await current(container)).elapsed, isA<Today>());
      expect(
        await container
            .read(itemListProvider.notifier)
            .undoMarkDone(result.undo),
        isA<UndoSucceeded>(),
      );
      final view = await current(container);
      expect(view.elapsed, const DaysAgo(4));
      expect(view.lastDoneText, '2026年9月12日');
      expect((await repository.watchAll().first).single.lastDoneAt, previous);
    });

    test('一覧に無い ID は書き込まず無視する', () async {
      final container = await ready();
      final before = await repository.watchAll().first;
      repository.writeError = StateError('書き込んだら失敗する');
      expect(
        await container
            .read(itemListProvider.notifier)
            .markDone(const ItemId('missing')),
        isA<MarkDoneIgnored>(),
      );
      expect(await repository.watchAll().first, before);
    });

    test('記録失敗でも一覧は AsyncData のまま値を保持する', () async {
      final container = await ready();
      final before = container.read(itemListProvider).requireValue;
      repository.writeError = StateError('write failed');
      expect(await record(container), isA<MarkDoneFailed>());
      expect(
        container.read(itemListProvider),
        isA<AsyncData<List<ItemView>>>(),
      );
      expect(container.read(itemListProvider).requireValue, same(before));
      expect((await repository.watchAll().first).single.lastDoneAt, isNull);
    });

    test('取り消し失敗では今日のまま残る', () async {
      final container = await ready();
      final result = await record(container) as MarkDoneSucceeded;
      expect((await current(container)).elapsed, isA<Today>());
      repository.writeError = StateError('write failed');
      expect(
        await container
            .read(itemListProvider.notifier)
            .undoMarkDone(result.undo),
        isA<UndoFailed>(),
      );
      expect((await current(container)).elapsed, isA<Today>());
      expect((await repository.watchAll().first).single.lastDoneAt, now);
    });

    test('記録時刻は Clock 経由で取得する', () async {
      final clock = _CountingClock(now);
      final container = await ready(clock: clock);
      final before = clock.calls;
      expect(await record(container), isA<MarkDoneSucceeded>());
      expect(clock.calls, greaterThan(before));
    });
  });
  group('過去の日付で記録', () {
    final local = now.toLocal();
    DateTime dateDaysAgo(int days) =>
        DateTime(local.year, local.month, local.day - days);

    Future<ProviderContainer> ready({DateTime? previous}) async {
      final item = await repository.add('美容院', now: now);
      if (previous != null) await repository.markDone(item.id, previous);
      final container = _container(repository, FakeClock(now));
      await container.read(itemListProvider.future);
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    Future<RecordPastDateResult> record(
      ProviderContainer container,
      int days,
    ) => container
        .read(itemListProvider.notifier)
        .recordPastDate(
          container.read(itemListProvider).requireValue.single.id,
          dateDaysAgo(days),
        );

    Future<ItemView> current(ProviderContainer container) async {
      await Future<void>.delayed(Duration.zero);
      return container.read(itemListProvider).requireValue.single;
    }

    test('未実施に4日前で記録すると DaysAgo(4) と日付文言を返す', () async {
      final container = await ready();
      final result = await record(container, 4) as RecordPastDateSucceeded;
      final picked = dateDaysAgo(4);
      expect(result.dateText, '${picked.month}月${picked.day}日');
      expect((await current(container)).elapsed, const DaysAgo(4));
    });

    test('今日を選ぶと Today になり現在時刻が保存される', () async {
      final container = await ready();
      expect(await record(container, 0), isA<RecordPastDateSucceeded>());
      expect((await current(container)).elapsed, isA<Today>());
      expect((await repository.watchAll().first).single.lastDoneAt, now);
    });

    test('2日前の記録に5日前を追加しても経過日数は動かず前回間隔は3日', () async {
      final date = dateDaysAgo(2);
      final container = await ready(
        previous: DateTime(date.year, date.month, date.day, 12).toUtc(),
      );
      expect(await record(container, 5), isA<RecordPastDateSucceeded>());
      final view = await current(container);
      expect(view.elapsed, const DaysAgo(2));
      expect(view.previousIntervalDays, 3);
    });

    test('未来日は拒否してリポジトリに書かない', () async {
      final container = await ready();
      final before = await repository.watchAll().first;
      repository.writeError = StateError('書き込んだら失敗する');
      expect(await record(container, -1), isA<RecordPastDateRejected>());
      expect((await current(container)).elapsed, isA<NeverDone>());
      expect(await repository.watchAll().first, before);
    });

    test('一覧に無い ID は書き込まず無視する', () async {
      final container = await ready();
      final before = await repository.watchAll().first;
      repository.writeError = StateError('書き込んだら失敗する');
      expect(
        await container
            .read(itemListProvider.notifier)
            .recordPastDate(const ItemId('missing'), dateDaysAgo(4)),
        isA<RecordPastDateIgnored>(),
      );
      expect(await repository.watchAll().first, before);
    });

    test('記録失敗でも一覧は AsyncData のまま元の値を保持する', () async {
      final container = await ready();
      final before = container.read(itemListProvider).requireValue;
      repository.writeError = StateError('write failed');
      expect(await record(container, 4), isA<RecordPastDateFailed>());
      expect(
        container.read(itemListProvider),
        isA<AsyncData<List<ItemView>>>(),
      );
      expect(container.read(itemListProvider).requireValue, same(before));
      expect((await repository.watchAll().first).single.lastDoneAt, isNull);
    });

    test('取り消すと未実施に戻る', () async {
      final container = await ready();
      final result = await record(container, 4) as RecordPastDateSucceeded;
      expect((await current(container)).elapsed, const DaysAgo(4));
      expect(
        await container
            .read(itemListProvider.notifier)
            .undoRecordPastDate(result.undo),
        isA<UndoSucceeded>(),
      );
      expect((await current(container)).elapsed, isA<NeverDone>());
      expect((await repository.watchAll().first).single.recentDoneAts, isEmpty);
    });

    test('取り消し失敗は UndoFailed で記録が残る', () async {
      final container = await ready();
      final result = await record(container, 4) as RecordPastDateSucceeded;
      await current(container);
      repository.writeError = StateError('write failed');
      expect(
        await container
            .read(itemListProvider.notifier)
            .undoRecordPastDate(result.undo),
        isA<UndoFailed>(),
      );
      expect((await current(container)).elapsed, const DaysAgo(4));
    });

    test('todayLocalDate は Clock のローカル暦日の0時', () async {
      final container = await ready();
      final today = container.read(itemListProvider.notifier).todayLocalDate();
      expect(today, dateDaysAgo(0));
      expect(today.isUtc, isFalse);
      expect(today.hour, 0);
    });
  });

  group('editItem', () {
    late Item item;
    late ProviderContainer container;

    setUp(() async {
      item = await repository.add('美容院', now: DateTime.utc(2026, 9, 1, 3));
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      container = _container(repository, FakeClock(now));
      await container.read(itemListProvider.future);
      await Future<void>.delayed(Duration.zero);
    });

    Future<EditItemResult> rename(String name) => container
        .read(itemListProvider.notifier)
        .editItem(item.id, name, icon: null, categoryId: null);

    test('名前を変えても最終実施日と経過日数は動かない', () async {
      expect(await rename('シャンプー'), isA<EditItemSucceeded>());
      await Future<void>.delayed(Duration.zero);
      final view = container.read(itemListProvider).requireValue.single;
      expect(view.elapsed, const DaysAgo(4));
      expect(view.lastDoneText, '2026年9月12日');
      expect(
        (await repository.watchAll().first).single.lastDoneAt,
        DateTime.utc(2026, 9, 12, 3),
      );
    });

    test('変更した名前が購読中の一覧に反映される', () async {
      final updated = Completer<List<ItemView>>();
      container.listen(itemListProvider, (_, next) {
        if (next case AsyncData(:final value)
            when value.single.name == 'シャンプー') {
          if (!updated.isCompleted) updated.complete(value);
        }
      });
      expect(await rename('シャンプー'), isA<EditItemSucceeded>());
      expect((await updated.future).single.name, 'シャンプー');
    });

    test('前後の空白をトリムする', () async {
      expect(await rename('  美容院  '), isA<EditItemSucceeded>());
      expect((await repository.watchAll().first).single.name, '美容院');
    });

    for (final rawName in ['', '   ']) {
      test('空文字または空白のみ（長さ ${rawName.length}）は保存しない', () async {
        expect(
          await rename(rawName),
          isA<EditItemRejected>().having(
            (result) => result.reason,
            'reason',
            ItemNameReason.empty,
          ),
        );
        expect((await repository.watchAll().first).single.name, '美容院');
      });
    }

    test('51文字は保存しない', () async {
      expect(
        await rename('あ' * 51),
        isA<EditItemRejected>().having(
          (result) => result.reason,
          'reason',
          ItemNameReason.tooLong,
        ),
      );
      expect((await repository.watchAll().first).single.name, '美容院');
    });

    test('50文字は保存できる', () async {
      expect(await rename('あ' * 50), isA<EditItemSucceeded>());
      expect((await repository.watchAll().first).single.name, 'あ' * 50);
    });

    test('一覧に無い ID は書き込まず他の項目も変えない', () async {
      final before = await repository.watchAll().first;
      repository.writeError = StateError('書き込んだら失敗する');
      expect(
        await container
            .read(itemListProvider.notifier)
            .editItem(
              const ItemId('missing'),
              'シャンプー',
              icon: null,
              categoryId: null,
            ),
        isA<EditItemIgnored>(),
      );
      expect(await repository.watchAll().first, before);
    });

    test('保存失敗でも一覧は AsyncData のまま元の名前を保持する', () async {
      final before = container.read(itemListProvider).requireValue;
      repository.writeError = StateError('write failed');
      expect(await rename('シャンプー'), isA<EditItemFailed>());
      expect(
        container.read(itemListProvider),
        isA<AsyncData<List<ItemView>>>(),
      );
      expect(container.read(itemListProvider).requireValue, same(before));
      expect((await repository.watchAll().first).single.name, '美容院');
    });

    test('更新日時は Clock の時刻になる', () async {
      expect(await rename('シャンプー'), isA<EditItemSucceeded>());
      expect((await repository.watchAll().first).single.updatedAt, now);
    });

    test('アイコンを指定すると保存される', () async {
      expect(
        await container
            .read(itemListProvider.notifier)
            .editItem(item.id, '美容院', icon: ItemIcon.bath, categoryId: null),
        isA<EditItemSucceeded>(),
      );
      expect((await repository.watchAll().first).single.icon, ItemIcon.bath);
    });

    test('カテゴリを指定すると保存され、null を渡すと未分類に戻る', () async {
      const categoryId = CategoryId('category-1');
      expect(
        await container
            .read(itemListProvider.notifier)
            .editItem(item.id, '美容院', icon: null, categoryId: categoryId),
        isA<EditItemSucceeded>(),
      );
      expect((await repository.watchAll().first).single.categoryId, categoryId);

      expect(
        await container
            .read(itemListProvider.notifier)
            .editItem(item.id, '美容院', icon: null, categoryId: null),
        isA<EditItemSucceeded>(),
      );
      expect((await repository.watchAll().first).single.categoryId, isNull);
    });
  });

  group('deleteItem', () {
    late Item item;
    late Item other;
    late ProviderContainer container;
    late _CountingClock clock;

    setUp(() async {
      item = await repository.add('美容院', now: now);
      other = await repository.add('歯ブラシ交換', now: now);
      clock = _CountingClock(now);
      container = _container(repository, clock);
      await container.read(itemListProvider.future);
      await Future<void>.delayed(Duration.zero);
    });

    Future<DeleteItemResult> delete() =>
        container.read(itemListProvider.notifier).deleteItem(item.id);

    test('削除すると購読中の一覧と保存先から消える', () async {
      expect(await delete(), isA<DeleteItemSucceeded>());
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(itemListProvider).requireValue.map((view) => view.id),
        [other.id],
      );
      expect((await repository.watchAll().first).map((item) => item.id), [
        other.id,
      ]);
    });

    test('残る項目の名前・最終実施日・並び順は変わらない', () async {
      expect(await delete(), isA<DeleteItemSucceeded>());
      final remaining = (await repository.watchAll().first).single;
      expect(remaining.id, other.id);
      expect(remaining.name, other.name);
      expect(remaining.lastDoneAt, other.lastDoneAt);
      expect(remaining.sortOrder, other.sortOrder);
    });

    test('一覧に無い ID は書き込まず件数も変えない', () async {
      final before = await repository.watchAll().first;
      repository.writeError = StateError('書き込んだら失敗する');
      expect(
        await container
            .read(itemListProvider.notifier)
            .deleteItem(const ItemId('missing')),
        isA<DeleteItemIgnored>(),
      );
      expect(await repository.watchAll().first, before);
    });

    test('削除失敗でも一覧に対象が残る', () async {
      final before = container.read(itemListProvider).requireValue;
      repository.writeError = StateError('write failed');
      expect(await delete(), isA<DeleteItemFailed>());
      expect(
        container.read(itemListProvider),
        isA<AsyncData<List<ItemView>>>(),
      );
      expect(container.read(itemListProvider).requireValue, same(before));
      expect((await repository.watchAll().first).map((item) => item.id), [
        item.id,
        other.id,
      ]);
    });

    test('削除処理は Clock を呼ばない', () async {
      // 書き込み時点で止め、watchAll 再通知による表示変換の Clock 呼び出しを分離する。
      repository.writeError = StateError('write failed');
      final before = clock.calls;
      expect(await delete(), isA<DeleteItemFailed>());
      expect(clock.calls, before);
    });
  });
  group('並び順(F30)', () {
    Future<ProviderContainer> ready() async {
      final car = await repository.add('車の点検', now: now);
      await repository.add('美容院', now: now);
      final bath = await repository.add('風呂掃除', now: now);
      for (final days in [540, 360, 180]) {
        await repository.markDone(car.id, now.subtract(Duration(days: days)));
      }
      for (final days in [28, 21, 14]) {
        await repository.markDone(bath.id, now.subtract(Duration(days: days)));
      }
      final container = _container(repository, FakeClock(now));
      await container.read(itemListProvider.future);
      await Future<void>.delayed(Duration.zero);
      return container;
    }

    Future<List<ItemView>> current(ProviderContainer container) async {
      await Future<void>.delayed(Duration.zero);
      return container.read(itemListProvider).requireValue;
    }

    test('登録順ではなく相対経過度の降順で null は末尾になる', () async {
      final container = await ready();
      expect(container.read(itemListProvider).requireValue.map((v) => v.name), [
        '風呂掃除',
        '車の点検',
        '美容院',
      ]);
    });

    test('記録後も順序を保ち記録した項目は今日になる', () async {
      final container = await ready();
      final id = container.read(itemListProvider).requireValue.first.id;
      expect(
        await container.read(itemListProvider.notifier).markDone(id),
        isA<MarkDoneSucceeded>(),
      );
      final views = await current(container);
      expect(views.map((v) => v.name), ['風呂掃除', '車の点検', '美容院']);
      expect(views.first.elapsed, isA<Today>());
    });

    test('記録後に refreshOrder を呼ぶと相対経過度順に確定し直す', () async {
      final container = await ready();
      final notifier = container.read(itemListProvider.notifier);
      await notifier.markDone(
        container.read(itemListProvider).requireValue.first.id,
      );
      await current(container);
      notifier.refreshOrder();
      final views = container.read(itemListProvider).requireValue;
      expect(views.map((v) => v.name), ['車の点検', '風呂掃除', '美容院']);
      expect(views[1].relativeElapsed, 0);
    });

    test('確定後に登録した項目は末尾に付く', () async {
      final container = await ready();
      expect(
        await container.read(itemListProvider.notifier).addItem('新しい項目'),
        isA<AddItemSucceeded>(),
      );
      expect((await current(container)).map((v) => v.name), [
        '風呂掃除',
        '車の点検',
        '美容院',
        '新しい項目',
      ]);
    });

    test('確定後に削除すると他の項目の順序を保つ', () async {
      final container = await ready();
      final id = container.read(itemListProvider).requireValue[1].id;
      expect(
        await container.read(itemListProvider.notifier).deleteItem(id),
        isA<DeleteItemSucceeded>(),
      );
      expect((await current(container)).map((v) => v.name), ['風呂掃除', '美容院']);
    });

    test('読み込み中の refreshOrder は例外を投げず何もしない', () async {
      final container = _container(repository, FakeClock(now));
      final before = container.read(itemListProvider);
      expect(before, isA<AsyncLoading<List<ItemView>>>());
      expect(
        container.read(itemListProvider.notifier).refreshOrder,
        returnsNormally,
      );
      expect(container.read(itemListProvider), same(before));
      await container.read(itemListProvider.future);
    });
  });
}
