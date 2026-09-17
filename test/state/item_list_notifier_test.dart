import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/state/add_item_result.dart';
import 'package:lastwhen/state/item_list_notifier.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/state/providers.dart';

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
  });
}
