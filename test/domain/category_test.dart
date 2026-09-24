import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';

void main() {
  group('Category の値比較', () {
    Category baseCategory() =>
        const Category(id: CategoryId('category-1'), name: '健康', sortOrder: 0);

    test('同じ値のカテゴリは等しい', () {
      final a = baseCategory();
      final b = baseCategory();
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('id が違えば等しくない', () {
      final a = baseCategory();
      final b = Category(
        id: const CategoryId('category-2'),
        name: a.name,
        sortOrder: a.sortOrder,
      );
      expect(a == b, isFalse);
    });

    test('名前が違えば等しくない', () {
      final a = baseCategory();
      final b = Category(id: a.id, name: '趣味', sortOrder: a.sortOrder);
      expect(a == b, isFalse);
    });

    test('表示順が違えば等しくない', () {
      final a = baseCategory();
      final b = Category(id: a.id, name: a.name, sortOrder: 1);
      expect(a == b, isFalse);
    });

    test('CategoryId は同じ文字列なら等しい', () {
      final value = 'a';
      expect(CategoryId(value) == CategoryId(value), isTrue);
    });
  });
}
