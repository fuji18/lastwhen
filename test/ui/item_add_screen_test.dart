import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/domain/item_template.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/item_name_error_text.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';
import 'package:lastwhen/ui/widgets/item_category_picker.dart';
import 'package:lastwhen/ui/widgets/item_icon_picker.dart';
import 'package:lastwhen/ui/widgets/item_template_chips.dart';
import 'package:lastwhen/ui/widgets/paper_background.dart';

import '../support/fake_category_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  FakeCategoryRepository? categoryRepository,
}) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(
      categoryRepository ?? FakeCategoryRepository(),
    ),
    clockProvider.overrideWithValue(clock),
  ],
  child: const App(),
);

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Future<void> openAddScreen(WidgetTester tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('項目を追加'));
    await tester.pumpAndSettle();
  }

  testWidgets('空状態の項目を追加から登録画面へ進める', (tester) async {
    await openAddScreen(tester);
    expect(find.byType(ItemAddScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('登録画面の根に PaperBackground がある', (tester) async {
    await openAddScreen(tester);
    expect(
      find.descendant(
        of: find.byType(ItemAddScreen),
        matching: find.byType(PaperBackground),
      ),
      findsOneWidget,
    );
  });

  testWidgets('項目がある一覧の FAB から登録画面へ進める', (tester) async {
    await repository.add('歯ブラシ交換', now: now);
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsOneWidget);
  });

  testWidgets('登録画面を開くと入力欄にフォーカスしてキーボードが出る', (tester) async {
    await openAddScreen(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('項目名だけを保存すると一覧に未実施で日付のないカードが出る', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsNothing);
    expect(find.byType(ItemCard), findsOneWidget);
    expect(find.text('美容院'), findsOneWidget);
    expect(find.text('未実施'), findsOneWidget);
    expect(find.textContaining('年'), findsNothing);
  });

  testWidgets('前後に空白のある名前は空白を除いて一覧に出る', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), '  美容院  ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsNothing);
    expect(find.text('美容院'), findsOneWidget);
    expect(find.text('  美容院  '), findsNothing);
  });

  for (final rawName in ['', '   ']) {
    testWidgets('空文字または空白のみ（長さ ${rawName.length}）なら入力を保持して理由が出る', (
      tester,
    ) async {
      await openAddScreen(tester);
      await tester.enterText(find.byType(TextField), rawName);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemAddScreen), findsOneWidget);
      expect(find.text('項目名を入力してください'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        rawName,
      );
      expect(await repository.watchAll().first, isEmpty);
    });
  }

  testWidgets('51文字を入力すると50文字に制限される', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), 'あ' * 51);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'あ' * 50,
    );
  });

  testWidgets('キャンセルすると項目を増やさず空の一覧へ戻る', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.byTooltip('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    expect(await repository.watchAll().first, isEmpty);
  });

  testWidgets('保存失敗なら入力と画面を保持して SnackBar を表示する', (tester) async {
    await openAddScreen(tester);
    repository.writeError = StateError('write failed');
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '美容院',
    );
    expect(await repository.watchAll().first, isEmpty);
  });

  testWidgets('アイコンを選ばずに保存すると一覧のカードは既定アイコン', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.event_repeat), findsOneWidget);
  });

  testWidgets('「風呂」を選んで保存すると一覧のカードに bathtub アイコンが出る', (tester) async {
    await openAddScreen(tester);
    await tester.enterText(find.byType(TextField), '風呂掃除');
    await tester.tap(find.byTooltip('風呂'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ItemCard),
        matching: find.byIcon(Icons.bathtub),
      ),
      findsOneWidget,
    );
  });

  testWidgets('アイコンピッカーが表示される', (tester) async {
    await openAddScreen(tester);
    expect(find.byType(ItemIconPicker), findsOneWidget);
  });

  testWidgets('カテゴリを選んで保存すると項目に反映される', (tester) async {
    final categoryRepository = FakeCategoryRepository(items: repository);
    addTearDown(categoryRepository.dispose);
    final category = await categoryRepository.add('健康');
    await tester.pumpWidget(
      _app(repository, FakeClock(now), categoryRepository: categoryRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('項目を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.text('健康'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await repository.watchAll().first).single;
    expect(saved.categoryId, category.id);
  });

  testWidgets('カテゴリを選ばずに保存すると未分類(null)になる', (tester) async {
    final categoryRepository = FakeCategoryRepository(items: repository);
    addTearDown(categoryRepository.dispose);
    await categoryRepository.add('健康');
    await tester.pumpWidget(
      _app(repository, FakeClock(now), categoryRepository: categoryRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('項目を追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '美容院');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final saved = (await repository.watchAll().first).single;
    expect(saved.categoryId, isNull);
  });

  testWidgets('カテゴリピッカーが表示される', (tester) async {
    await openAddScreen(tester);
    expect(find.byType(ItemCategoryPicker), findsOneWidget);
  });

  test('入力拒否の理由を入力欄の文言に変換する', () {
    expect(itemNameErrorText(ItemNameReason.empty), '項目名を入力してください');
    expect(itemNameErrorText(ItemNameReason.tooLong), '50文字以内で入力してください');
  });
  testWidgets('よくある項目のタップで項目名とアイコンが入り保存で登録される', (tester) async {
    await openAddScreen(tester);
    final chip = find.widgetWithText(ActionChip, 'エアコン掃除');
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'エアコン掃除',
    );
    expect(
      tester.widget<ItemIconPicker>(find.byType(ItemIconPicker)).selected,
      ItemIcon.airConditioner,
    );
    expect(await repository.watchAll().first, isEmpty);
    await tester.ensureVisible(find.text('保存'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    final items = await repository.watchAll().first;
    expect(items, hasLength(1));
    expect(items.single.name, 'エアコン掃除');
    expect(items.single.icon, ItemIcon.airConditioner);
  });

  testWidgets('登録済みと同名のよくある項目は出ない', (tester) async {
    await repository.add('美容院', now: now);
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    // カテゴリ選択欄にも ActionChip があるため、よくある項目の欄に絞る。
    expect(
      find.descendant(
        of: find.byType(ItemTemplateChips),
        matching: find.byType(ActionChip),
      ),
      findsNWidgets(maxAddScreenTemplates),
    );
    expect(find.widgetWithText(ActionChip, '美容院'), findsNothing);
    expect(find.widgetWithText(ActionChip, '歯医者'), findsOneWidget);
  });

  testWidgets('よくある項目がすべて登録済みなら欄を出さない', (tester) async {
    for (final template in itemTemplates) {
      await repository.add(template.name, now: now);
    }
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('よくある項目から選ぶ'), findsNothing);
    expect(find.byType(ItemTemplateChips), findsNothing);
  });

  testWidgets('登録画面のよくある項目は先頭から上限の件数だけ出る', (tester) async {
    await openAddScreen(tester);
    expect(
      find.descendant(
        of: find.byType(ItemTemplateChips),
        matching: find.byType(ActionChip),
      ),
      findsNWidgets(maxAddScreenTemplates),
    );
    for (final template in itemTemplates.take(maxAddScreenTemplates)) {
      expect(find.widgetWithText(ActionChip, template.name), findsOneWidget);
    }
    for (final template in itemTemplates.skip(maxAddScreenTemplates)) {
      expect(
        find.descendant(
          of: find.byType(ItemTemplateChips),
          matching: find.text(template.name),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('小さい画面でキーボード表示中も保存が見える', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await openAddScreen(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, '保存');
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(640 - 280));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), '洗車');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect((await repository.watchAll().first).single.name, '洗車');
  });
}
