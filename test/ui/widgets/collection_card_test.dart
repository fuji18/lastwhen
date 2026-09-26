import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/collection_card.dart';

ItemView _view({double? baselineIntervalDays, AgingStage? stage}) => ItemView(
  id: const ItemId('item-1'),
  name: '風呂掃除',
  elapsed: const DaysAgo(14),
  lastDoneText: '2026年9月2日',
  baselineIntervalDays: baselineIntervalDays,
  agingStage: stage ?? AgingStage.fresh,
);

Widget _app(ItemView item, {VoidCallback? onTap}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: CollectionCard(item: item, onTap: onTap ?? () {}),
  ),
);

void main() {
  group('collectionIntervalText', () {
    test('7.0 は 平均7日', () {
      expect(collectionIntervalText(7), '平均7日');
    });

    test('6.5 は四捨五入で 平均7日', () {
      expect(collectionIntervalText(6.5), '平均7日');
    });

    test('6.4 は四捨五入で 平均6日', () {
      expect(collectionIntervalText(6.4), '平均6日');
    });

    test('null は 学習中', () {
      expect(collectionIntervalText(null), '学習中');
    });
  });

  group('collectionColumnCount', () {
    test('等倍は 3 列', () {
      expect(collectionColumnCount(TextScaler.noScaling), 3);
    });

    test('2倍は 2 列', () {
      expect(collectionColumnCount(TextScaler.linear(2)), 2);
    });
  });

  testWidgets('カードに項目名と平均N日が出て、経過日数とやったが出ない', (tester) async {
    await tester.pumpWidget(_app(_view(baselineIntervalDays: 7)));
    expect(find.text('風呂掃除'), findsOneWidget);
    expect(find.text('平均7日'), findsOneWidget);
    expect(find.text('14日前'), findsNothing);
    expect(find.text('2026年9月2日'), findsNothing);
    expect(find.text('やった'), findsNothing);
  });

  testWidgets('タップで onTap が呼ばれる', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _app(_view(baselineIntervalDays: 7), onTap: () => tapped = true),
    );
    await tester.tap(find.byType(CollectionCard));
    expect(tapped, isTrue);
  });

  test('読み上げ文が 項目名、平均7日 の形になる', () {
    expect(
      collectionCardSemanticsLabel(_view(baselineIntervalDays: 7)),
      '風呂掃除、平均7日',
    );
  });

  test('読み上げ文は学習中でも成立する', () {
    expect(collectionCardSemanticsLabel(_view()), '風呂掃除、学習中');
  });
}
