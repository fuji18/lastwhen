import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/widgets/item_category_picker.dart';

import '../../support/fake_category_repository.dart';

void main() {
  late FakeCategoryRepository repository;
  setUp(() {
    repository = FakeCategoryRepository();
    addTearDown(repository.dispose);
  });

  Widget app({
    CategoryId? selected,
    bool enabled = true,
    ValueChanged<CategoryId?>? onChanged,
  }) => ProviderScope(
    overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: Scaffold(
        body: ItemCategoryPicker(
          selected: selected,
          enabled: enabled,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('未分類 + カテゴリ + 追加チップの順に出る', (tester) async {
    await repository.add('健康');
    await repository.add('趣味');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text(uncategorizedLabel), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
    expect(find.text('趣味'), findsOneWidget);
    expect(find.text('カテゴリを追加'), findsOneWidget);
  });

  testWidgets('selected に一致するチップが選択状態になる', (tester) async {
    final category = await repository.add('健康');
    await tester.pumpWidget(app(selected: category.id));
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '健康'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('削除済み(存在しない)id は未分類表示になる', (tester) async {
    await repository.add('健康');
    await tester.pumpWidget(app(selected: const CategoryId('missing')));
    await tester.pumpAndSettle();
    final uncategorized = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, uncategorizedLabel),
    );
    expect(uncategorized.selected, isTrue);
  });

  testWidgets('チップをタップすると onChanged にそのカテゴリの id が渡る', (tester) async {
    final category = await repository.add('健康');
    CategoryId? changed;
    await tester.pumpWidget(app(onChanged: (id) => changed = id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('健康'));
    expect(changed, category.id);
  });

  testWidgets('追加ダイアログで保存するとそのカテゴリの id で onChanged が呼ばれる', (tester) async {
    CategoryId? changed;
    await tester.pumpWidget(app(onChanged: (id) => changed = id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('カテゴリを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '健康');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('健康'), findsOneWidget);
    expect(changed, isNotNull);
  });

  testWidgets('重複名だとダイアログが閉じずに理由が出る', (tester) async {
    await repository.add('健康');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('カテゴリを追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '健康');
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('同じ名前のカテゴリがあります'), findsOneWidget);
  });

  testWidgets('enabled: false だとチップも追加チップも押せない', (tester) async {
    await repository.add('健康');
    var called = false;
    await tester.pumpWidget(
      app(enabled: false, onChanged: (_) => called = true),
    );
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, '健康'),
    );
    expect(chip.onSelected, isNull);
    final actionChip = tester.widget<ActionChip>(find.byType(ActionChip));
    expect(actionChip.onPressed, isNull);
    await tester.tap(find.text('健康'), warnIfMissed: false);
    expect(called, isFalse);
  });
}
