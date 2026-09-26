import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/collection.dart';
import 'package:lastwhen/state/item_view.dart';

const _health = Category(id: CategoryId('health'), name: '健康', sortOrder: 0);
const _hobby = Category(id: CategoryId('hobby'), name: '趣味', sortOrder: 1);

ItemView _view(
  String id, {
  String? name,
  ElapsedLabel elapsed = const DaysAgo(3),
  CategoryId? categoryId,
}) => ItemView(
  id: ItemId(id),
  name: name ?? id,
  elapsed: elapsed,
  lastDoneText: null,
  categoryId: categoryId,
);

void main() {
  group('collectionOf', () {
    test('未実施を除き、記録済みを入力順で返す', () {
      final a = _view('a');
      final b = _view('b', elapsed: const NeverDone());
      final c = _view('c');
      expect(collectionOf([a, b, c]).map((v) => v.id), [a.id, c.id]);
    });

    test('category を指定すると一致するものだけ返る', () {
      final a = _view('a', categoryId: _health.id);
      final b = _view('b', categoryId: _hobby.id);
      expect(collectionOf([a, b], category: _health.id).map((v) => v.id), [
        a.id,
      ]);
    });

    test('category が null なら全件返る', () {
      final a = _view('a', categoryId: _health.id);
      final b = _view('b', categoryId: _hobby.id);
      expect(collectionOf([a, b]).map((v) => v.id), [a.id, b.id]);
    });

    test('query で項目名を部分一致に絞る(大文字小文字を無視)', () {
      final abcd = _view('a', name: 'abcd');
      final xyz = _view('b', name: 'xyz');
      expect(collectionOf([abcd, xyz], query: 'ABC').map((v) => v.id), [
        abcd.id,
      ]);
    });

    test('query の前後の空白を無視する', () {
      final abcd = _view('a', name: 'abcd');
      expect(collectionOf([abcd], query: '  abcd  ').map((v) => v.id), [
        abcd.id,
      ]);
    });

    test('query が空白だけなら絞らない', () {
      final a = _view('a');
      final b = _view('b');
      expect(collectionOf([a, b], query: '   ').map((v) => v.id), [a.id, b.id]);
    });

    test('未実施の項目は名前が一致しても返らない', () {
      final neverDone = _view('a', name: 'abcd', elapsed: const NeverDone());
      expect(collectionOf([neverDone], query: 'abcd'), isEmpty);
    });
  });
}
