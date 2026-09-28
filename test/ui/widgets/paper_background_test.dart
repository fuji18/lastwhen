import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/paper_background.dart';

void main() {
  testWidgets('子が描画され、地の色は colorScheme.surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const PaperBackground(child: Text('中身')),
      ),
    );
    expect(find.text('中身'), findsOneWidget);
    final coloredBox = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(PaperBackground),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(coloredBox.color, AppTheme.light().colorScheme.surface);
  });

  testWidgets('繊維の CustomPaint は RepaintBoundary の子(判断H)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const PaperBackground(child: Text('中身')),
      ),
    );
    final grainPaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is PaperGrainPainter,
    );
    expect(grainPaint, findsOneWidget);
    expect(
      find.ancestor(of: grainPaint, matching: find.byType(RepaintBoundary)),
      findsWidgets,
    );
  });

  test('PaperGrainPainter.shouldRepaint は色の違いでだけ true', () {
    const color = Color(0xFF123456);
    const same = Color(0xFF123456);
    const different = Color(0xFF654321);
    expect(
      const PaperGrainPainter(color: same)
          .shouldRepaint(const PaperGrainPainter(color: color)),
      isFalse,
    );
    expect(
      const PaperGrainPainter(color: different)
          .shouldRepaint(const PaperGrainPainter(color: color)),
      isTrue,
    );
  });
}
