import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item.dart';

void main() {
  group('Item の値比較', () {
    Item baseItem() => Item(
      id: const ItemId('item-1'),
      name: '歯ブラシ交換',
      lastDoneAt: DateTime.utc(2026, 1, 10, 3, 0),
      createdAt: DateTime.utc(2026, 1, 1, 0, 0),
      updatedAt: DateTime.utc(2026, 1, 10, 3, 0),
      sortOrder: 0,
    );

    test('同じ値の項目は等しい', () {
      final a = baseItem();
      final b = baseItem();
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('id が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: const ItemId('item-2'),
        name: a.name,
        lastDoneAt: a.lastDoneAt,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('名前が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: a.id,
        name: '別の項目',
        lastDoneAt: a.lastDoneAt,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('最終実施日が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: a.id,
        name: a.name,
        lastDoneAt: DateTime.utc(2026, 1, 11, 3, 0),
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('登録日時が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: a.id,
        name: a.name,
        lastDoneAt: a.lastDoneAt,
        createdAt: DateTime.utc(2026, 1, 2, 0, 0),
        updatedAt: a.updatedAt,
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('更新日時が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: a.id,
        name: a.name,
        lastDoneAt: a.lastDoneAt,
        createdAt: a.createdAt,
        updatedAt: DateTime.utc(2026, 1, 11, 3, 0),
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('表示順が違えば等しくない', () {
      final a = baseItem();
      final b = Item(
        id: a.id,
        name: a.name,
        lastDoneAt: a.lastDoneAt,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
        sortOrder: 1,
      );
      expect(a == b, isFalse);
    });

    test('未実施の項目は最終実施日が null', () {
      final item = Item(
        id: const ItemId('item-3'),
        name: '観葉植物の水やり',
        lastDoneAt: null,
        createdAt: DateTime.utc(2026, 1, 1, 0, 0),
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0),
        sortOrder: 0,
      );
      expect(item.lastDoneAt, isNull);
    });

    test('ItemId は同じ文字列なら等しい', () {
      // extension type の const コンストラクタは定数畳み込みされ実行時に呼ばれないため、
      // カバレッジ計測のためにあえて非 const な値から生成する。
      final value = 'a';
      expect(ItemId(value) == ItemId(value), isTrue);
    });
  });
}
