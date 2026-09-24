import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/item_icon.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/item_icon_picker.dart';

Widget _app({
  ItemIcon? selected,
  required ValueChanged<ItemIcon?> onChanged,
  bool enabled = true,
}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: ItemIconPicker(
      selected: selected,
      onChanged: onChanged,
      enabled: enabled,
    ),
  ),
);

void main() {
  testWidgets('「指定なし」を含めて25個のタイルが出る', (tester) async {
    await tester.pumpWidget(_app(onChanged: (_) {}));
    // 25 = 「指定なし」1 個 + ItemIcon.values 24 個。
    expect(find.byType(IconButton), findsNWidgets(25));
  });

  testWidgets('タップすると onChanged に値が渡る', (tester) async {
    ItemIcon? received;
    var called = false;
    await tester.pumpWidget(
      _app(
        onChanged: (value) {
          called = true;
          received = value;
        },
      ),
    );
    await tester.tap(find.byTooltip('風呂'));
    expect(called, isTrue);
    expect(received, ItemIcon.bath);
  });

  testWidgets('「指定なし」をタップすると null が渡る', (tester) async {
    ItemIcon? received = ItemIcon.bath;
    await tester.pumpWidget(
      _app(selected: ItemIcon.bath, onChanged: (value) => received = value),
    );
    await tester.tap(find.byTooltip(noItemIconLabel));
    expect(received, isNull);
  });

  testWidgets('選択中のタイルの semantics が isSelected: true', (tester) async {
    await tester.pumpWidget(_app(selected: ItemIcon.bath, onChanged: (_) {}));
    final semantics = tester.getSemantics(find.byTooltip('風呂'));
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);

    final unselected = tester.getSemantics(find.byTooltip('掃除'));
    expect(unselected.flagsCollection.isSelected.toBoolOrNull(), isFalse);
  });

  testWidgets('enabled: false でタップしても呼ばれない', (tester) async {
    var called = false;
    await tester.pumpWidget(
      _app(enabled: false, onChanged: (_) => called = true),
    );
    await tester.tap(find.byTooltip('風呂'), warnIfMissed: false);
    expect(called, isFalse);
  });

  testWidgets('各タイルは48x48以上のタップ領域を持つ', (tester) async {
    await tester.pumpWidget(_app(onChanged: (_) {}));
    for (final element in find.byType(IconButton).evaluate()) {
      final size = (element.renderObject! as RenderBox).size;
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
