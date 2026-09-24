import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/item_edit_screen.dart';
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

  Future<void> pumpItems(WidgetTester tester) async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await repository.add('歯ブラシ交換', now: now);
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
  }

  Future<void> openEditScreen(WidgetTester tester, String name) async {
    await pumpItems(tester);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
  }

  Future<void> saveName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, '削除'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '削除'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('詳細シートの編集から現在の項目名が入った編集画面が開く', (tester) async {
    await openEditScreen(tester, '美容院');
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '美容院',
    );
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
  });

  testWidgets('名前を変えて保存すると一覧に新しい名前が出る', (tester) async {
    await openEditScreen(tester, '美容院');
    await saveName(tester, 'シャンプー');
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.text('シャンプー'), findsOneWidget);
    expect(find.text('美容院'), findsNothing);
    expect((await repository.watchAll().first).first.name, 'シャンプー');
  });

  testWidgets('保存しても最終実施日と経過日数は変わらない', (tester) async {
    await openEditScreen(tester, '美容院');
    await saveName(tester, 'シャンプー');
    expect(find.text('4日前'), findsOneWidget);
    expect(find.text('2026年9月12日'), findsOneWidget);
    expect(
      (await repository.watchAll().first).first.lastDoneAt,
      DateTime.utc(2026, 9, 12, 3),
    );
  });

  for (final rawName in ['', '   ']) {
    testWidgets('空文字または空白のみ（長さ ${rawName.length}）なら理由を出して画面に留まる', (
      tester,
    ) async {
      await openEditScreen(tester, '美容院');
      await saveName(tester, rawName);
      expect(find.byType(ItemEditScreen), findsOneWidget);
      expect(find.text('項目名を入力してください'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        rawName,
      );
      expect((await repository.watchAll().first).first.name, '美容院');
    });
  }

  testWidgets('キャンセルで戻ると編集中の名前は保存されない', (tester) async {
    await openEditScreen(tester, '美容院');
    await tester.enterText(find.byType(TextField), 'シャンプー');
    await tester.tap(find.byTooltip('キャンセル'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.text('美容院'), findsOneWidget);
    expect(find.text('シャンプー'), findsNothing);
    expect((await repository.watchAll().first).first.name, '美容院');
  });

  testWidgets('保存失敗なら入力と画面を保持して SnackBar を表示する', (tester) async {
    await openEditScreen(tester, '美容院');
    repository.writeError = StateError('write failed');
    await saveName(tester, 'シャンプー');
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'シャンプー',
    );
    expect((await repository.watchAll().first).first.name, '美容院');
  });

  testWidgets('削除ボタンは確認を出し確認前には項目を消さない', (tester) async {
    await openEditScreen(tester, '美容院');
    await openDeleteDialog(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('項目を削除しますか?'), findsOneWidget);
    expect(find.text('「美容院」とこれまでの記録を削除します。元に戻せません。'), findsOneWidget);
    expect((await repository.watchAll().first).map((item) => item.name), [
      '美容院',
      '歯ブラシ交換',
    ]);
  });

  testWidgets('確認をキャンセルすると削除せず編集画面に留まる', (tester) async {
    await openEditScreen(tester, '美容院');
    await openDeleteDialog(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'キャンセル'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect((await repository.watchAll().first).map((item) => item.name), [
      '美容院',
      '歯ブラシ交換',
    ]);
  });

  testWidgets('削除を確認すると編集画面が閉じ対象が一覧から消える', (tester) async {
    await openEditScreen(tester, '美容院');
    await openDeleteDialog(tester);
    await confirmDelete(tester);
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.byType(ItemCard), findsOneWidget);
    expect(find.text('美容院'), findsNothing);
    expect(find.text('歯ブラシ交換'), findsOneWidget);
    expect((await repository.watchAll().first).single.name, '歯ブラシ交換');
  });

  testWidgets('削除後も他の項目の名前と未実施表示は残る', (tester) async {
    await openEditScreen(tester, '美容院');
    await openDeleteDialog(tester);
    await confirmDelete(tester);
    final remainingRow = find.ancestor(
      of: find.text('歯ブラシ交換'),
      matching: find.byType(ItemCard),
    );
    expect(remainingRow, findsOneWidget);
    expect(
      find.descendant(of: remainingRow, matching: find.text('未実施')),
      findsOneWidget,
    );
    expect((await repository.watchAll().first).single.lastDoneAt, isNull);
  });

  testWidgets('現在のアイコンが選択状態で開く', (tester) async {
    final item = await repository.add('風呂掃除', icon: ItemIcon.bath, now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('風呂掃除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(find.byTooltip('風呂'));
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  });

  testWidgets('アイコンを変えて保存すると一覧に反映し経過日数は変わらない', (tester) async {
    await openEditScreen(tester, '美容院');
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
    expect(find.text('4日前'), findsOneWidget);
    expect((await repository.watchAll().first).first.icon, ItemIcon.bath);
  });

  testWidgets('「指定なし」で保存すると既定アイコンに戻る', (tester) async {
    final item = await repository.add('風呂掃除', icon: ItemIcon.bath, now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('風呂掃除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('指定なし'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ItemCard),
        matching: find.byIcon(Icons.event_repeat),
      ),
      findsOneWidget,
    );
    expect((await repository.watchAll().first).first.icon, isNull);
  });

  testWidgets('アイコンピッカーが表示される', (tester) async {
    await openEditScreen(tester, '美容院');
    expect(find.byType(ItemIconPicker), findsOneWidget);
  });

  testWidgets('削除失敗なら対象を残して編集画面にエラーを表示する', (tester) async {
    await openEditScreen(tester, '美容院');
    repository.writeError = StateError('write failed');
    await openDeleteDialog(tester);
    await confirmDelete(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect(find.text('削除できませんでした。もう一度お試しください'), findsOneWidget);
    expect((await repository.watchAll().first).map((item) => item.name), [
      '美容院',
      '歯ブラシ交換',
    ]);
  });
}
