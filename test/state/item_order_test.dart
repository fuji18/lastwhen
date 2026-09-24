import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_order.dart';
import 'package:lastwhen/state/item_view.dart';

ItemView _view(String id, double? relative) => ItemView(
  id: ItemId(id),
  name: id,
  elapsed: const NeverDone(),
  lastDoneText: null,
  relativeElapsed: relative,
);

void main() {
  group('sortByRelativeElapsed', () {
    test('空リストなら空になる', () {
      expect(sortByRelativeElapsed([]), isEmpty);
    });
    test('相対経過度の降順になる', () {
      final result = sortByRelativeElapsed([
        _view('a', 1),
        _view('b', 2),
        _view('c', 0.5),
      ]);
      expect(result.map((view) => view.name), ['b', 'a', 'c']);
    });
    test('null は下部に入力順でまとまる', () {
      final result = sortByRelativeElapsed([
        _view('n1', null),
        _view('a', 1),
        _view('n2', null),
        _view('b', 2),
      ]);
      expect(result.map((view) => view.name), ['b', 'a', 'n1', 'n2']);
    });
    test('同値は繰り返し呼んでも入力順を保つ', () {
      final views = [_view('a', 1.5), _view('b', 1.5), _view('c', 1.5)];
      for (var i = 0; i < 2; i++) {
        expect(sortByRelativeElapsed(views), views);
      }
    });
    test('入力リストは変更しない', () {
      final views = [_view('a', 1), _view('b', 2)];
      final before = [...views];
      final result = sortByRelativeElapsed(views);
      expect(views, before);
      expect(identical(result, views), isFalse);
    });
  });

  group('applyFixedOrder', () {
    test('入力順と無関係に確定済みの順序になる', () {
      final result = applyFixedOrder(
        [_view('a', 2), _view('b', 1)],
        [const ItemId('b'), const ItemId('a')],
      );
      expect(result.map((view) => view.name), ['b', 'a']);
    });
    test('削除された ID は飛ばす', () {
      final result = applyFixedOrder(
        [_view('a', 1)],
        [const ItemId('deleted'), const ItemId('a')],
      );
      expect(result.map((view) => view.name), ['a']);
    });
    test('新規項目は入力順で末尾に付く', () {
      final result = applyFixedOrder(
        [_view('n1', null), _view('a', 1), _view('n2', null)],
        [const ItemId('a')],
      );
      expect(result.map((view) => view.name), ['a', 'n1', 'n2']);
    });
  });

  group('パフォーマンス', () {
    test('各10件の履歴を持つ100項目の変換と並び替えが300ms未満', () {
      final now = DateTime.utc(2026, 9, 16, 3);
      final items = List.generate(100, (i) {
        final history = List.generate(
          10,
          (j) => now.subtract(Duration(days: (i + 1) * (j + 1))),
        );
        return Item(
          id: ItemId('item-$i'),
          name: '項目$i',
          lastDoneAt: history.first,
          createdAt: history.last,
          updatedAt: history.first,
          sortOrder: i,
          recentDoneAts: history,
        );
      });
      final stopwatch = Stopwatch()..start();
      final result = sortByRelativeElapsed(toItemViews(items, now: now));
      stopwatch.stop();
      expect(result, hasLength(100));
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });
  });
}
