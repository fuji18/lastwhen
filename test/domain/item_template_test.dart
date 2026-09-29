import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/domain/item_template.dart';

void main() {
  group('よくある項目', () {
    test('名前は指定された表示順に並ぶ', () {
      expect(itemTemplates.map((template) => template.name), [
        '歯ブラシ交換',
        '美容院',
        'エアコン掃除',
        '歯医者',
        '洗車',
        '布団干し',
      ]);
    });

    test('すべての名前がトリムで変わらず検証を通る', () {
      for (final template in itemTemplates) {
        final result = validateItemName(template.name);
        expect(result, isA<ValidItemName>());
        expect((result as ValidItemName).value, template.name);
      }
    });

    test('名前に重複がない', () {
      expect(
        itemTemplates.map((template) => template.name).toSet().length,
        itemTemplates.length,
      );
    });

    test('登録済みの名前がなければすべて返す', () {
      expect(availableItemTemplates([]), itemTemplates);
    });

    test('前後の空白を除いて同名のものを除外し元の順序を保つ', () {
      expect(
        availableItemTemplates(['  美容院 ', '洗車', '散髪'])
            .map((template) => template.name),
        ['歯ブラシ交換', 'エアコン掃除', '歯医者', '布団干し'],
      );
    });
  });
}
