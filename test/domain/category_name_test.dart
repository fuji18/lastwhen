import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category_name.dart';

void main() {
  group('カテゴリ名の検証', () {
    test('空文字は通らない', () {
      final result = validateCategoryName('', existingNames: const []);
      expect(result, isA<InvalidCategoryName>());
      expect((result as InvalidCategoryName).reason, CategoryNameReason.empty);
    });

    test('半角空白のみは通らない', () {
      final result = validateCategoryName('   ', existingNames: const []);
      expect(result, isA<InvalidCategoryName>());
      expect((result as InvalidCategoryName).reason, CategoryNameReason.empty);
    });

    test('前後の空白は除去される', () {
      final result = validateCategoryName('  健康  ', existingNames: const []);
      expect(result, isA<ValidCategoryName>());
      expect((result as ValidCategoryName).value, '健康');
    });

    test('10 文字は通る', () {
      final result = validateCategoryName('あ' * 10, existingNames: const []);
      expect(result, isA<ValidCategoryName>());
    });

    test('11 文字は通らない', () {
      final result = validateCategoryName('あ' * 11, existingNames: const []);
      expect(result, isA<InvalidCategoryName>());
      expect(
        (result as InvalidCategoryName).reason,
        CategoryNameReason.tooLong,
      );
    });

    test('絵文字は 1 文字として数える', () {
      final result = validateCategoryName('🙂' * 10, existingNames: const []);
      expect(result, isA<ValidCategoryName>());
    });

    test('トリム後に既存カテゴリ名と完全一致すると重複になる', () {
      final result = validateCategoryName(
        '  健康  ',
        existingNames: const ['健康'],
      );
      expect(result, isA<InvalidCategoryName>());
      expect(
        (result as InvalidCategoryName).reason,
        CategoryNameReason.duplicate,
      );
    });

    test('既存カテゴリ名と一致しなければ重複にならない', () {
      final result = validateCategoryName('趣味', existingNames: const ['健康']);
      expect(result, isA<ValidCategoryName>());
    });

    test('空白のみは duplicate ではなく empty になる(判定順)', () {
      final result = validateCategoryName('   ', existingNames: const ['']);
      expect(result, isA<InvalidCategoryName>());
      expect((result as InvalidCategoryName).reason, CategoryNameReason.empty);
    });
  });
}
