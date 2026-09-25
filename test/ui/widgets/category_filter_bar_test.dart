import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/ui/widgets/category_filter_bar.dart';

const _health = Category(id: CategoryId('health'), name: '健康', sortOrder: 0);
const _hobby = Category(id: CategoryId('hobby'), name: '趣味', sortOrder: 1);

void main() {
  Widget app({
    List<Category> categories = const [_health, _hobby],
    CategoryId? selected,
    required ValueChanged<CategoryId?> onSelected,
  }) => MaterialApp(
    home: Scaffold(
      body: CategoryFilterBar(
        categories: categories,
        selected: selected,
        onSelected: onSelected,
      ),
    ),
  );

  testWidgets('先頭が「すべて」で以降は categories の順に出る', (tester) async {
    await tester.pumpWidget(app(onSelected: (_) {}));
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.map((c) => (c.label as Text).data), [
      allCategoriesLabel,
      '健康',
      '趣味',
    ]);
  });

  testWidgets('selected に一致するチップが選択状態になる', (tester) async {
    await tester.pumpWidget(app(selected: _health.id, onSelected: (_) {}));
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.map((c) => c.selected), [false, true, false]);
  });

  testWidgets('selected が null なら「すべて」が選択状態になる', (tester) async {
    await tester.pumpWidget(app(onSelected: (_) {}));
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(chips.map((c) => c.selected), [true, false, false]);
  });

  testWidgets('タップすると対応する id が渡る', (tester) async {
    CategoryId? tapped;
    await tester.pumpWidget(app(onSelected: (id) => tapped = id));
    await tester.tap(find.text('趣味'));
    expect(tapped, _hobby.id);
  });

  testWidgets('選択済みのチップを押しても同じ id が渡る', (tester) async {
    CategoryId? tapped;
    await tester.pumpWidget(
      app(selected: _health.id, onSelected: (id) => tapped = id),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '健康'));
    expect(tapped, _health.id);
  });

  testWidgets('選択済みの「すべて」を押しても null が渡る', (tester) async {
    var called = false;
    CategoryId? tapped = _health.id;
    await tester.pumpWidget(
      app(
        onSelected: (id) {
          called = true;
          tapped = id;
        },
      ),
    );
    await tester.tap(find.text(allCategoriesLabel));
    expect(called, isTrue);
    expect(tapped, isNull);
  });
}
