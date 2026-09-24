import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item_icon.dart';

void main() {
  group('ItemIcon', () {
    test('キーはすべて一意', () {
      final keys = ItemIcon.values.map((value) => value.key).toSet();
      expect(keys.length, ItemIcon.values.length);
    });

    test('fromKey はキーから戻る', () {
      for (final value in ItemIcon.values) {
        expect(ItemIcon.fromKey(value.key), value);
      }
    });

    test('fromKey(null) は null', () {
      expect(ItemIcon.fromKey(null), isNull);
    });

    test('fromKey(未知のキー) は null', () {
      expect(ItemIcon.fromKey('unknown'), isNull);
    });
  });
}
