import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';

Item _item(DateTime? lastDoneAt) => Item(
  id: const ItemId('item-1'),
  name: '美容院',
  lastDoneAt: lastDoneAt,
  createdAt: DateTime.utc(2026, 1, 1, 3),
  updatedAt: DateTime.utc(2026, 9, 12, 3),
  sortOrder: 0,
);

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);

  test('9月12日の記録はゼロ埋めせず日本語の日付になる', () {
    final view = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    expect(view.lastDoneText, '2026年9月12日');
  });

  test('1月5日の記録でも月と日をゼロ埋めしない', () {
    final view = ItemView.from(_item(DateTime.utc(2026, 1, 5, 3)), now: now);
    expect(view.lastDoneText, '2026年1月5日');
  });

  test('未実施なら最終実施日の文字列は null', () {
    expect(ItemView.from(_item(null), now: now).lastDoneText, isNull);
  });

  test('DaysAgo を含めて同じ内容の表示モデルは等しい', () {
    final first = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    final second = ItemView.from(_item(DateTime.utc(2026, 9, 12, 3)), now: now);
    expect(first.elapsed, const DaysAgo(4));
    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });
}
