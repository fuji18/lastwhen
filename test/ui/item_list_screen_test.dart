import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/item_list_screen.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_row.dart';

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

  testWidgets('0件なら空状態と項目を追加する導線が出る', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('まだ項目がありません'), findsOneWidget);
    expect(find.text('項目を追加'), findsOneWidget);
    expect(find.byType(ItemRow), findsNothing);
  });

  testWidgets('空状態の内容は画面中央に配置される', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    final content = find.descendant(
      of: find.byType(EmptyState),
      matching: find.byType(Column),
    );
    final center = tester.getCenter(content);
    final screenSize = tester.getSize(find.byType(Scaffold));
    expect(center.dx, closeTo(screenSize.width / 2, 1));
    expect(center.dy, closeTo(screenSize.height / 2, kToolbarHeight));
  });

  testWidgets('記録済みの行に日付が出て未実施の行には出ない', (tester) async {
    await pumpItems(tester);
    expect(find.text('美容院'), findsOneWidget);
    expect(find.text('歯ブラシ交換'), findsOneWidget);
    expect(find.text('4日前'), findsOneWidget);
    expect(find.text('2026年9月12日'), findsOneWidget);
    expect(find.text('未実施'), findsOneWidget);
    final neverDoneRow = find.ancestor(
      of: find.text('歯ブラシ交換'),
      matching: find.byType(ItemRow),
    );
    final texts = tester.widgetList<Text>(
      find.descendant(of: neverDoneRow, matching: find.byType(Text)),
    );
    expect(texts.map((text) => text.data), ['歯ブラシ交換', '未実施', 'やった']);
  });

  testWidgets('各行のやったボタンは幅と高さが56dp以上', (tester) async {
    await pumpItems(tester);
    final buttons = find.byType(DoneButton);
    expect(buttons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final size = tester.getSize(buttons.at(i));
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('経過日数は項目名と日付より大きく太字で出る', (tester) async {
    await pumpItems(tester);
    final elapsed = tester.widget<Text>(find.text('4日前'));
    final name = tester.widget<Text>(find.text('美容院'));
    final lastDone = tester.widget<Text>(find.text('2026年9月12日'));
    expect(elapsed.style?.fontWeight, FontWeight.bold);
    expect(elapsed.style?.fontSize, greaterThan(name.style!.fontSize!));
    expect(elapsed.style?.fontSize, greaterThan(lastDone.style!.fontSize!));
  });

  testWidgets('一覧は必要な行だけ構築する builder を使う', (tester) async {
    await pumpItems(tester);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
  });

  testWidgets('やったボタンは各行の項目名より右にある', (tester) async {
    await pumpItems(tester);
    for (final name in ['美容院', '歯ブラシ交換']) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(ItemRow),
      );
      final button = find.descendant(
        of: row,
        matching: find.byType(DoneButton),
      );
      expect(
        tester.getCenter(button).dx,
        greaterThan(tester.getCenter(find.text(name)).dx),
      );
    }
  });

  testWidgets('起動直後の home が一覧画面である', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.home, isA<ItemListScreen>());
    expect(find.byType(ItemListScreen), findsOneWidget);
  });

  testWidgets('項目が2件あれば FAB が1つ出る', (tester) async {
    await pumpItems(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('空状態では FAB が出ない', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });
  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ItemRow));

  Finder rowText(String name, String text) =>
      find.descendant(of: row(name), matching: find.text(text));

  Future<void> record(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: row(name), matching: find.byType(DoneButton)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> undo(WidgetTester tester) async {
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
  }

  testWidgets('記録で確認ダイアログが出ない', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('未実施の行を記録すると今日になる', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(rowText('歯ブラシ交換', '未実施'), findsNothing);
    expect(rowText('歯ブラシ交換', '今日'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '2026年9月16日'), findsOneWidget);
  });

  testWidgets('記録後に取り消し導線が1つ出る', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('記録しました'), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
  });

  testWidgets('未実施の記録を取り消すと未実施に戻り日付が消える', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await undo(tester);
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '今日'), findsNothing);
    expect(rowText('歯ブラシ交換', '2026年9月16日'), findsNothing);
  });

  testWidgets('記録済みの行は取り消すと元の日付に戻る', (tester) async {
    await pumpItems(tester);
    await record(tester, '美容院');
    expect(rowText('美容院', '今日'), findsOneWidget);
    await undo(tester);
    expect(rowText('美容院', '4日前'), findsOneWidget);
    expect(rowText('美容院', '2026年9月12日'), findsOneWidget);
  });

  testWidgets('2行続けて記録すると直近1件だけ取り消せる', (tester) async {
    await pumpItems(tester);
    await record(tester, '美容院');
    await record(tester, '歯ブラシ交換');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
    await undo(tester);
    expect(rowText('美容院', '今日'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
  });

  testWidgets('取り消し導線は4秒で消える', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('取り消す'), findsNothing);
  });

  testWidgets('書き込み失敗は一覧を残して伝える', (tester) async {
    await pumpItems(tester);
    repository.writeError = StateError('write failed');
    await record(tester, '歯ブラシ交換');
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
    expect(rowText('美容院', '4日前'), findsOneWidget);
    expect(find.byType(ItemRow), findsNWidgets(2));
    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
  });

  testWidgets('登録画面への遷移で取り消し導線を閉じる', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('記録と取り消しは画面遷移を伴わない', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(ItemAddScreen), findsNothing);
    await undo(tester);
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(ItemAddScreen), findsNothing);
  });
}
