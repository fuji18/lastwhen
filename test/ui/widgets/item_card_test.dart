import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/aged_paper.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';

ItemView _view({AgingStage? stage, ItemIcon? icon}) => ItemView(
  id: const ItemId('item-1'),
  name: '風呂掃除',
  elapsed: const DaysAgo(14),
  lastDoneText: '2026年9月2日',
  agingStage: stage ?? AgingStage.fresh,
  icon: icon,
);

Widget _app(ItemView item, {ThemeData? theme, double textScale = 1}) =>
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: ItemCard(item: item, onDonePressed: () {}, onTap: () {}),
        ),
      ),
    );

AgedPaperPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint && widget.painter is AgedPaperPainter,
              ),
            )
            .painter!
        as AgedPaperPainter;

Item _item(DateTime previousDoneAt) {
  final lastDoneAt = DateTime.utc(2026, 9, 2, 3);
  return Item(
    id: const ItemId('item-1'),
    name: '風呂掃除',
    lastDoneAt: lastDoneAt,
    createdAt: DateTime.utc(2026, 1, 1, 3),
    updatedAt: lastDoneAt,
    sortOrder: 0,
    recentDoneAts: [lastDoneAt, previousDoneAt],
  );
}

void main() {
  const stageTexts = <AgingStage?, String?>{
    null: null,
    AgingStage.fresh: null,
    AgingStage.slightlyAged: '少し経過',
    AgingStage.dueSoon: 'そろそろ',
    AgingStage.aged: '経過',
    AgingStage.heavilyAged: 'かなり経過',
  };
  for (final entry in stageTexts.entries) {
    testWidgets('${entry.key} の紙と読み上げを表示する', (tester) async {
      final item = _view(stage: entry.key);
      await tester.pumpWidget(_app(item));
      expect(_painter(tester).stage, entry.key ?? AgingStage.fresh);
      final suffix = entry.value == null ? '' : '、状態は${entry.value}';
      final label = '風呂掃除、最終実施日は2026年9月2日、14日経過$suffix';
      expect(itemCardSemanticsLabel(item), label);
      expect(find.bySemanticsLabel(label), findsOneWidget);
      if (entry.value == null) {
        expect(itemCardSemanticsLabel(item), isNot(contains('、状態は')));
      }
    });
  }
  testWidgets('同じ14日前でも基準間隔に応じて紙の見た目が違う', (tester) async {
    final now = DateTime.utc(2026, 9, 16, 3);
    await tester.pumpWidget(
      _app(ItemView.from(_item(DateTime.utc(2026, 8, 26, 3)), now: now)),
    );
    final shortInterval = _painter(tester);
    expect(shortInterval.stage, AgingStage.heavilyAged);
    expect(find.text('14日前'), findsOneWidget);
    await tester.pumpWidget(
      _app(ItemView.from(_item(DateTime.utc(2026, 3, 6, 3)), now: now)),
    );
    final longInterval = _painter(tester);
    expect(longInterval.stage, AgingStage.fresh);
    expect(longInterval.colors.paper, isNot(shortInterval.colors.paper));
    expect(find.text('14日前'), findsOneWidget);
  });
  testWidgets('ダークテーマの紙の色を使う', (tester) async {
    await tester.pumpWidget(
      _app(_view(stage: AgingStage.heavilyAged), theme: AppTheme.dark()),
    );
    expect(
      _painter(tester).colors,
      AgingPalette.dark.colorsOf(AgingStage.heavilyAged),
    );
  });
  testWidgets('文字サイズ200%でも経過日数を省略せずボタンが押せる', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(_view(stage: AgingStage.heavilyAged), textScale: 2),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(DoneButton).hitTestable(), findsOneWidget);
    final elapsed = tester.widget<Text>(find.text('14日前'));
    expect(elapsed.overflow, TextOverflow.visible);
    expect(elapsed.softWrap, isFalse);
    final name = tester.widget<Text>(find.text('風呂掃除'));
    final lastDone = tester.widget<Text>(find.text('2026年9月2日'));
    expect(elapsed.style!.fontSize, greaterThan(name.style!.fontSize!));
    expect(elapsed.style!.fontSize, greaterThan(lastDone.style!.fontSize!));
  });

  testWidgets('未選択は既定アイコン(event_repeat)を描く', (tester) async {
    await tester.pumpWidget(_app(_view()));
    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.icon, Icons.event_repeat);
  });

  testWidgets('ItemIcon.bath なら bathtub アイコンを描く', (tester) async {
    await tester.pumpWidget(_app(_view(icon: ItemIcon.bath)));
    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.icon, Icons.bathtub);
  });

  testWidgets('heavilyAged のアイコンの alpha は fresh より小さい', (tester) async {
    await tester.pumpWidget(_app(_view(stage: AgingStage.fresh)));
    final freshAlpha = tester.widget<Icon>(find.byType(Icon).first).color!.a;
    await tester.pumpWidget(_app(_view(stage: AgingStage.heavilyAged)));
    final heavilyAgedAlpha = tester
        .widget<Icon>(find.byType(Icon).first)
        .color!
        .a;
    expect(heavilyAgedAlpha, lessThan(freshAlpha));
  });

  testWidgets('アイコンを追加してもカードの読み上げラベルは変わらない', (tester) async {
    final withoutIcon = _view();
    final withIcon = _view(icon: ItemIcon.bath);
    expect(
      itemCardSemanticsLabel(withoutIcon),
      itemCardSemanticsLabel(withIcon),
    );
  });

  testWidgets('文字倍率1.19では横並びのまま経過日数999日前でも例外が出ない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = ItemView(
      id: const ItemId('item-1'),
      name: '風呂掃除',
      elapsed: const DaysAgo(999),
      lastDoneText: '2023年12月30日',
    );
    await tester.pumpWidget(_app(item, textScale: 1.19));
    expect(tester.takeException(), isNull);
    expect(find.text('999日前'), findsOneWidget);
  });

  testWidgets('文字倍率1.2では縦積みになる', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = ItemView(
      id: const ItemId('item-1'),
      name: '風呂掃除',
      elapsed: const DaysAgo(999),
      lastDoneText: '2023年12月30日',
    );
    await tester.pumpWidget(_app(item, textScale: 1.2));
    expect(tester.takeException(), isNull);
    final elapsedTop = tester.getTopLeft(find.text('999日前')).dy;
    final buttonTop = tester.getTopLeft(find.byType(DoneButton)).dy;
    // 縦積みでは経過日数がボタンより上の行に来る。
    expect(elapsedTop, lessThan(buttonTop));
  });
}
