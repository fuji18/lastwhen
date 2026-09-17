import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/state/add_item_result.dart';

void main() {
  test('入力拒否の結果は理由を保持する', () {
    const result = AddItemRejected(ItemNameReason.tooLong);
    expect(result.reason, ItemNameReason.tooLong);
  });

  test('成功と保存失敗は異なる登録結果型になる', () {
    const succeeded = AddItemSucceeded();
    const failed = AddItemFailed();
    expect(succeeded, isA<AddItemResult>());
    expect(failed, isA<AddItemResult>());
    expect(succeeded.runtimeType, isNot(failed.runtimeType));
  });
}
