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

ItemView _named(
  String id, {
  String? name,
  ElapsedLabel elapsed = const NeverDone(),
}) => ItemView(
  id: ItemId(id),
  name: name ?? id,
  elapsed: elapsed,
  lastDoneText: null,
);

void main() {
  group('sortItemViews', () {
    test('経年順は sortByRelativeElapsed と同じになる', () {
      final views = [_view('n1', null), _view('a', 1), _view('b', 2)];
      expect(
        sortItemViews(views, ItemSortOrder.aging),
        sortByRelativeElapsed(views),
      );
    });
    test('経過日数順は日数の降順で未実施は下部に登録順でまとまる', () {
      final views = [
        _named('n1'),
        _named('b', elapsed: const DaysAgo(3)),
        _named('c', elapsed: const Today()),
        _named('d', elapsed: const DaysAgo(10)),
        _named('n2'),
        _named('e', elapsed: const Yesterday()),
      ];
      expect(
        sortItemViews(views, ItemSortOrder.elapsedDays).map((v) => v.name),
        ['d', 'b', 'e', 'c', 'n1', 'n2'],
      );
    });
    test('経過日数順で同じ日数は登録順を保つ', () {
      final views = [
        for (final id in ['a', 'b', 'c']) _named(id, elapsed: const DaysAgo(5)),
      ];
      expect(sortItemViews(views, ItemSortOrder.elapsedDays), views);
    });
    test('名前順はかなの表記を畳んで五十音に並ぶ', () {
      final views = [
        for (final name in ['ゴミ出し', '洗濯', 'ごはん', 'ｂａｎａｎａ', 'あさ', 'Apple'])
          _named(name),
      ];
      expect(sortItemViews(views, ItemSortOrder.name).map((v) => v.name), [
        'Apple',
        'ｂａｎａｎａ',
        'あさ',
        'ごはん',
        'ゴミ出し',
        '洗濯',
      ]);
    });
    test('名前順で同じ名前は登録順を保つ', () {
      final views = [
        _named('a', name: '掃除'),
        _named('b', name: '掃除'),
        _named('c', name: 'あ'),
      ];
      expect(sortItemViews(views, ItemSortOrder.name).map((v) => v.id), [
        const ItemId('c'),
        const ItemId('a'),
        const ItemId('b'),
      ]);
    });
    test('名前順は未実施を区別しない', () {
      final views = [
        _named('a', name: 'い', elapsed: const DaysAgo(3)),
        _named('b', name: 'あ'),
      ];
      expect(sortItemViews(views, ItemSortOrder.name), [views[1], views[0]]);
    });
    test('登録順は入力順のまま', () {
      final views = [
        _named('a', name: 'う', elapsed: const Today()),
        _named('b', name: 'あ'),
        _named('c', name: 'い', elapsed: const DaysAgo(5)),
      ];
      expect(sortItemViews(views, ItemSortOrder.registered), views);
    });
    test('空リストは全ての並び順で空になる', () {
      for (final order in ItemSortOrder.values) {
        expect(sortItemViews([], order), isEmpty);
      }
    });
    test('全ての並び順で入力を変更せず新しいリストを返す', () {
      final views = [_named('b'), _named('a', elapsed: const DaysAgo(3))];
      final before = [...views];
      for (final order in ItemSortOrder.values) {
        expect(identical(sortItemViews(views, order), views), isFalse);
        expect(views, before);
      }
    });
  });
  group('nameSortKey', () {
    for (final entry in {
      'ＡＢＣ　ｘ１': 'abc x1',
      'カタカナ': 'かたかな',
      'ヴ': 'ゔ',
      'コーヒー': 'こーひー',
      'ｶﾀ': 'ｶﾀ',
      '洗濯': '洗濯',
    }.entries) {
      test('${entry.key} は ${entry.value} になる', () {
        expect(nameSortKey(entry.key), entry.value);
      });
    }
  });

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
