import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/category_manage_screen.dart';
import 'package:lastwhen/ui/screens/collection_screen.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/screens/item_edit_screen.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';
import 'package:lastwhen/ui/widgets/item_detail_sheet.dart';

import '../support/fake_category_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

/// docs/glossary.md「表記ゆれの禁止一覧」。
const List<String> _bannedTerms = [
  'タスク',
  '習慣',
  'アイテム',
  'エントリ',
  '完了する',
  'チェックする',
  '達成する',
  '最終更新日',
  '前回日',
  '実施日',
  '経過時間',
  '日数差',
  'インターバル',
  '未完了',
  '未着手',
  '0日前',
  '推奨間隔',
  'サイクル',
  '周期',
];

/// ソースのコメントを誤検出しないよう、描画された文字列だけを見る。
List<String> _renderedTexts(WidgetTester tester) {
  final found = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph) {
      found.add(object.text.toPlainText());
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return found;
}

String _stripAllowed(String text) => text.replaceAll('最終実施日', '');

void _expectAllowed(Iterable<String> texts) {
  expect(texts, isNotEmpty);
  for (final text in texts) {
    for (final banned in _bannedTerms) {
      expect(_stripAllowed(text), isNot(contains(banned)), reason: text);
    }
  }
}

void main() {
  final now = DateTime(2026, 9, 16, 12);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Widget app() => ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
      clockProvider.overrideWithValue(FakeClock(now)),
    ],
    child: const App(),
  );

  group('用語', () {
    for (final screen in [
      '一覧(項目あり)',
      '一覧(空)',
      '登録',
      '詳細',
      '編集',
      '削除確認',
      'カテゴリ管理',
      '図鑑',
    ]) {
      testWidgets('$screen の描画文字列が表記ゆれの禁止一覧に違反しない', (tester) async {
        tester.view.physicalSize = const Size(360 * 3, 640 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        if (screen != '一覧(空)') {
          final item = await repository.add('美容院', now: now);
          await repository.markDone(item.id, DateTime(2026, 9, 12, 12));
          await repository.add('歯ブラシ交換', now: now);
        }
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        switch (screen) {
          case '一覧(項目あり)':
            expect(find.byType(ItemCard), findsNWidgets(2));
          case '一覧(空)':
            expect(find.byType(EmptyState), findsOneWidget);
          case '登録':
            await tester.tap(find.byType(FloatingActionButton));
            await tester.pumpAndSettle();
            expect(find.byType(ItemAddScreen), findsOneWidget);
          case '詳細':
            await tester.tap(find.text('美容院'));
            await tester.pumpAndSettle();
            expect(find.byType(ItemDetailSheet), findsOneWidget);
          case '編集':
          case '削除確認':
            await tester.tap(find.text('美容院'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('編集'));
            await tester.pumpAndSettle();
            expect(find.byType(ItemEditScreen), findsOneWidget);
            if (screen == '削除確認') {
              // カテゴリピッカーが増え、この画面サイズでは「削除」が画面外に出る。
              await tester.ensureVisible(find.text('削除'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('削除'));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
            }
          case 'カテゴリ管理':
            await tester.tap(find.byTooltip('カテゴリを管理'));
            await tester.pumpAndSettle();
            expect(find.byType(CategoryManageScreen), findsOneWidget);
          case '図鑑':
            await tester.tap(find.text('図鑑'));
            await tester.pumpAndSettle();
            expect(find.byType(CollectionScreen), findsOneWidget);
        }
        _expectAllowed(_renderedTexts(tester));
        expect(tester.takeException(), isNull);
      });
    }

    test('読み上げラベルが表記ゆれの禁止一覧に違反しない', () {
      final labels = [
        itemCardSemanticsLabel(
          const ItemView(
            id: ItemId('never'),
            name: '歯ブラシ交換',
            elapsed: NeverDone(),
            lastDoneText: null,
          ),
        ),
        itemCardSemanticsLabel(
          const ItemView(
            id: ItemId('done'),
            name: '美容院',
            elapsed: DaysAgo(4),
            lastDoneText: '2026年9月12日',
          ),
        ),
        itemCardSemanticsLabel(
          const ItemView(
            id: ItemId('aged'),
            name: '風呂掃除',
            elapsed: DaysAgo(14),
            lastDoneText: '2026年9月2日',
            agingStage: AgingStage.heavilyAged,
          ),
        ),
        doneButtonSemanticsLabel('美容院'),
      ];
      _expectAllowed(labels);
    });
  });
}
