import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/collection_screen.dart';
import 'package:lastwhen/ui/screens/item_list_screen.dart';
import 'package:lastwhen/ui/widgets/category_filter_bar.dart';
import 'package:lastwhen/ui/widgets/collection_card.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';
import 'package:lastwhen/ui/widgets/item_detail_sheet.dart';

import '../../support/fake_category_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_item_repository.dart';

Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  FakeCategoryRepository? categoryRepository,
  double textScale = 1,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(
        categoryRepository ?? FakeCategoryRepository(),
      ),
      clockProvider.overrideWithValue(clock),
    ],
    child: const App(),
  ),
);

Future<void> _openCollection(WidgetTester tester) async {
  await tester.tap(find.text('図鑑'));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Future<void> pumpItems(WidgetTester tester) async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await repository.add('歯ブラシ交換', now: now);
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
  }

  testWidgets('起動直後はホーム(一覧)で、下部ナビにホームと図鑑がある', (tester) async {
    await pumpItems(tester);
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(CollectionScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('ホーム'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('図鑑'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('図鑑には記録済みの項目だけがカードで並び、未実施は出ない', (tester) async {
    await pumpItems(tester);
    await _openCollection(tester);
    expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
    expect(find.widgetWithText(CollectionCard, '歯ブラシ交換'), findsNothing);
  });

  testWidgets('記録済み 0 件なら専用の文言が出る', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await _openCollection(tester);
    expect(find.text('まだ図鑑にカードがありません'), findsOneWidget);
  });

  group('カテゴリの絞り込み', () {
    late FakeCategoryRepository categoryRepository;

    setUp(() {
      categoryRepository = FakeCategoryRepository(items: repository);
      addTearDown(categoryRepository.dispose);
    });

    Future<void> pumpWithCategories(WidgetTester tester) async {
      final health = await categoryRepository.add('健康');
      await categoryRepository.add('趣味');
      final beauty = await repository.add(
        '美容院',
        categoryId: health.id,
        now: now,
      );
      await repository.markDone(beauty.id, DateTime.utc(2026, 9, 12, 3));
      final laundry = await repository.add('洗濯', now: now);
      await repository.markDone(laundry.id, DateTime.utc(2026, 9, 10, 3));
      await tester.pumpWidget(
        _app(
          repository,
          FakeClock(now),
          categoryRepository: categoryRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('チップで絞り込める', (tester) async {
      await pumpWithCategories(tester);
      await _openCollection(tester);
      expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
      expect(find.widgetWithText(CollectionCard, '洗濯'), findsOneWidget);
      await tester.tap(find.text('健康'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
      expect(find.widgetWithText(CollectionCard, '洗濯'), findsNothing);
    });

    testWidgets('ホームで選んだ絞り込みは図鑑に移らない', (tester) async {
      await pumpWithCategories(tester);
      await tester.tap(find.text('健康'));
      await tester.pumpAndSettle();
      await _openCollection(tester);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, allCategoriesLabel),
      );
      expect(chip.selected, isTrue);
      expect(find.widgetWithText(CollectionCard, '洗濯'), findsOneWidget);
    });
  });

  group('検索', () {
    /// `SystemNavigator.pop`(アプリの終了)が呼ばれた回数を数える。
    List<String> recordSystemPops(WidgetTester tester) {
      final pops = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            pops.add(call.method);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return pops;
    }

    testWidgets('検索ボタンから入力すると部分一致に絞れる', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '美容');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
    });

    testWidgets('一致が無ければ専用の文言が出る', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '存在しない項目名');
      await tester.pumpAndSettle();
      expect(find.text('条件に合う項目はありません'), findsOneWidget);
    });

    testWidgets('検索を閉じると全件に戻る', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '存在しない項目名');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('検索を閉じる'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
    });

    testWidgets('検索中にシステムの戻るを押すと検索が閉じ、アプリは閉じない', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      final pops = recordSystemPops(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '存在しない項目名');
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(pops, isEmpty);
      expect(find.byTooltip('検索'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.widgetWithText(CollectionCard, '美容院'), findsOneWidget);
    });

    testWidgets('検索中でなければシステムの戻るはアプリの既定の動き(終了)になる', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      final pops = recordSystemPops(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(pops, hasLength(1));
    });

    testWidgets('図鑑で検索を開いたままホームへ移ると、戻るを横取りしない', (tester) async {
      await pumpItems(tester);
      await _openCollection(tester);
      final pops = recordSystemPops(tester);
      await tester.tap(find.byTooltip('検索'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('ホーム'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(pops, hasLength(1));
    });
  });

  testWidgets('図鑑から開いた詳細シートに日付を指定して記録の入口がある', (tester) async {
    await pumpItems(tester);
    await _openCollection(tester);
    await tester.tap(find.widgetWithText(CollectionCard, '美容院'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ItemDetailSheet),
        matching: find.text('日付を指定して記録'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('カードをタップすると詳細シートが開く', (tester) async {
    await pumpItems(tester);
    await _openCollection(tester);
    await tester.tap(find.text('美容院'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailSheet), findsOneWidget);
  });

  testWidgets('ホームで記録した直後に図鑑を開くと取り消し導線が消える', (tester) async {
    await pumpItems(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ItemCard, '歯ブラシ交換'),
        matching: find.byType(DoneButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await _openCollection(tester);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('記録直後に登録画面へ遷移しても例外が出ない(#34 判断9)', (tester) async {
    await pumpItems(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ItemCard, '歯ブラシ交換'),
        matching: find.byType(DoneButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ホームに戻ると一覧が表示される', (tester) async {
    await pumpItems(tester);
    await _openCollection(tester);
    await tester.tap(find.text('ホーム'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemCard), findsWidgets);
  });

  testWidgets('文字サイズ200%で図鑑を開いても例外が出ない', (tester) async {
    await repository.add('美容院', now: now);
    final item = await repository.add('歯ブラシ交換', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await tester.pumpWidget(_app(repository, FakeClock(now), textScale: 2));
    await tester.pumpAndSettle();
    await _openCollection(tester);
    expect(tester.takeException(), isNull);
  });
}
