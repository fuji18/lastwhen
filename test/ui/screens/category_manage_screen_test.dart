import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/category_manage_screen.dart';

import '../../support/fake_category_repository.dart';
import '../../support/fake_item_repository.dart';

void main() {
  late FakeCategoryRepository repository;
  late FakeItemRepository itemRepository;
  setUp(() {
    itemRepository = FakeItemRepository();
    repository = FakeCategoryRepository(items: itemRepository);
    addTearDown(repository.dispose);
    addTearDown(itemRepository.dispose);
  });

  Widget app() => ProviderScope(
    overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: CategoryManageScreen()),
  );

  testWidgets('カテゴリが一覧に表示される', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('趣味'), findsOneWidget);
  });

  testWidgets('0件なら専用の文言が出る', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('カテゴリはありません'), findsOneWidget);
  });

  testWidgets('FAB から追加できる', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '健康');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('健康'), findsOneWidget);
  });

  testWidgets('タップして名前を変更できる', (tester) async {
    await repository.add('健康');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('健康'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '健康2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('健康2'), findsOneWidget);
    expect(find.text('健康'), findsNothing);
  });

  testWidgets('削除確認でキャンセルすると残る', (tester) async {
    await repository.add('健康');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('「健康」を削除'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'キャンセル'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('健康'), findsOneWidget);
  });

  testWidgets('削除を確認すると消え、その項目が未分類になる', (tester) async {
    final category = await repository.add('健康');
    final item = await itemRepository.add(
      '美容院',
      categoryId: category.id,
      now: DateTime.utc(2026, 9, 16, 3),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('「健康」を削除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '削除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('健康'), findsNothing);
    final updated = (await itemRepository.watchAll().first).single;
    expect(updated.id, item.id);
    expect(updated.categoryId, isNull);
  });

  testWidgets('削除に失敗すると SnackBar が出る', (tester) async {
    await repository.add('健康');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    repository.writeError = StateError('write failed');
    await tester.tap(find.byTooltip('「健康」を削除'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, '削除'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('削除できませんでした。もう一度お試しください'), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
  });
}
