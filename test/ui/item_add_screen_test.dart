import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/item_name.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/item_name_error_text.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';
import 'package:lastwhen/ui/widgets/item_icon_picker.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

Widget _app(FakeItemRepository repository, Clock clock) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
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

  test('入力拒否の理由を入力欄の文言に変換する', () {
    expect(itemNameErrorText(ItemNameReason.empty), '項目名を入力してください');
    expect(itemNameErrorText(ItemNameReason.tooLong), '50文字以内で入力してください');
  });
}
