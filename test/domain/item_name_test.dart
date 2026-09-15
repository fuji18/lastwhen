import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item_name.dart';

void main() {
  group('項目名の検証', () {
    test('空文字は通らない', () {
      final result = validateItemName('');
      expect(result, isA<InvalidItemName>());
      expect((result as InvalidItemName).reason, ItemNameReason.empty);
    });

    test('半角空白のみは通らない', () {
      final result = validateItemName('   ');
      expect(result, isA<InvalidItemName>());
      expect((result as InvalidItemName).reason, ItemNameReason.empty);
    });

    test('全角空白のみは通らない', () {
      final result = validateItemName('　');
      expect(result, isA<InvalidItemName>());
      expect((result as InvalidItemName).reason, ItemNameReason.empty);
    });

    test('前後の空白は除去される', () {
      final result = validateItemName('  歯ブラシ交換  ');
      expect(result, isA<ValidItemName>());
      expect((result as ValidItemName).value, '歯ブラシ交換');
    });

    test('1 文字は通る', () {
      final result = validateItemName('A');
      expect(result, isA<ValidItemName>());
      expect((result as ValidItemName).value, 'A');
    });

    test('50 文字は通る', () {
      final result = validateItemName('あ' * 50);
      expect(result, isA<ValidItemName>());
    });

    test('51 文字は通らない', () {
      final result = validateItemName('あ' * 51);
      expect(result, isA<InvalidItemName>());
      expect((result as InvalidItemName).reason, ItemNameReason.tooLong);
    });

    test('空白を除いて 50 文字なら通る', () {
      final result = validateItemName(' ${'あ' * 50} ');
      expect(result, isA<ValidItemName>());
      expect((result as ValidItemName).value.runes.length, 50);
    });

    test('絵文字は 1 文字として数える', () {
      final result = validateItemName('🙂' * 50);
      expect(result, isA<ValidItemName>());
    });
  });
}
