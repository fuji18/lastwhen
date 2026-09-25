import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/category_filter.dart';
import 'package:lastwhen/state/item_view.dart';

const _health = Category(id: CategoryId('health'), name: '健康', sortOrder: 0);
const _hobby = Category(id: CategoryId('hobby'), name: '趣味', sortOrder: 1);

ItemView _view(String id, {CategoryId? categoryId}) => ItemView(
  id: ItemId(id),
  name: id,
  elapsed: const NeverDone(),
  lastDoneText: null,
  categoryId: categoryId,
);

void main() {
  group('resolveCategoryId', () {
    test('null はそのまま null', () {
      expect(resolveCategoryId(null, const [_health, _hobby]), isNull);
    });

    test('存在する id はそのまま返る', () {
      expect(
        resolveCategoryId(_health.id, const [_health, _hobby]),
        _health.id,
      );
    });

    test('存在しない id は null になる(削除済みカテゴリ)', () {
      expect(
        resolveCategoryId(const CategoryId('missing'), const [_health]),
        isNull,
      );
    });
  });

  group('filterByCategory', () {
    test('null はそのまま返す', () {
      final views = [_view('a'), _view('b')];
      expect(filterByCategory(views, null), same(views));
    });

    test('一致するものだけを入力順を保って返す', () {
      final a = _view('a', categoryId: _health.id);
      final b = _view('b', categoryId: _hobby.id);
      final c = _view('c', categoryId: _health.id);
      expect(filterByCategory([a, b, c], _health.id).map((v) => v.id), [
        a.id,
        c.id,
      ]);
    });

    test('一致するものが無ければ空になる', () {
      final views = [_view('a', categoryId: _hobby.id)];
      expect(filterByCategory(views, _health.id), isEmpty);
    });
  });

  group('CategoryFilterNotifier', () {
    test('初期値は null(すべて)', () {
      final container = ProviderContainer.test();
      expect(container.read(categoryFilterProvider), isNull);
    });

    test('select で選択が変わる', () {
      final container = ProviderContainer.test();
      container.read(categoryFilterProvider.notifier).select(_health.id);
      expect(container.read(categoryFilterProvider), _health.id);
      container.read(categoryFilterProvider.notifier).select(null);
      expect(container.read(categoryFilterProvider), isNull);
    });
  });
}
