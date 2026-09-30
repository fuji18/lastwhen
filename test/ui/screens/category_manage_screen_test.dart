import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/category_manage_screen.dart';
import 'package:lastwhen/ui/widgets/paper_background.dart';

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
    child: const MaterialApp(
      // ドラッグ並び替えの組み込みカスタム操作(先頭に移動・上に移動…)は
      // ja ロケールで日本語文言になる(design.md 判断7)。
      locale: Locale('ja'),
      supportedLocales: [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: CategoryManageScreen(),
    ),
  );

  testWidgets('カテゴリが一覧に表示される', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('趣味'), findsOneWidget);
  });

  testWidgets('管理画面の根に PaperBackground がある', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(PaperBackground), findsOneWidget);
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

  testWidgets('ドラッグハンドルで並び替えると保存され、その順で表示される', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await repository.add('その他');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(3));

    // 先頭行のハンドルを下へドラッグして最後尾へ移動させる。
    await tester.drag(handles.first, const Offset(0, 300));
    await tester.pumpAndSettle();

    final names = (await repository.watchAll().first)
        .map((c) => c.name)
        .toList();
    expect(names, ['趣味', 'その他', '健康']);

    final texts = [
      '趣味',
      'その他',
      '健康',
    ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
    expect(texts, [texts[0], texts[1], texts[2]]..sort());
  });

  testWidgets('並び替えに失敗すると SnackBar が出て並びは変わらない', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await repository.add('その他');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    repository.writeError = StateError('write failed');

    final handles = find.byIcon(Icons.drag_handle);
    await tester.drag(handles.first, const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.text('並び替えを保存できませんでした。もう一度お試しください'), findsOneWidget);
    final names = (await repository.watchAll().first)
        .map((c) => c.name)
        .toList();
    expect(names, ['健康', '趣味', 'その他']);
  });

  testWidgets('各行に読み上げの並び替え操作がある', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await repository.add('その他');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    final node = tester.getSemantics(find.text('趣味'));
    final actionIds =
        node.getSemanticsData().customSemanticsActionIds ?? const <int>[];
    final labels = actionIds
        .map((id) => CustomSemanticsAction.getAction(id)!.label)
        .toSet();
    expect(labels, containsAll(['上に移動', '下に移動']));

    const downAction = CustomSemanticsAction(label: '下に移動');
    final downActionId = CustomSemanticsAction.getIdentifier(downAction);
    // RendererBinding.rootPipelineOwner 経由では実行してもテスト用のセマンティクスツリーに
    // 反映されなかった(実測)。テストバインディングが直接持つ pipelineOwner を使う。
    // ignore: deprecated_member_use
    tester.binding.pipelineOwner.semanticsOwner!.performAction(
      node.id,
      SemanticsAction.customAction,
      downActionId,
    );
    await tester.pumpAndSettle();

    final names = (await repository.watchAll().first)
        .map((c) => c.name)
        .toList();
    expect(names, ['健康', 'その他', '趣味']);

    handle.dispose();
  });
}
