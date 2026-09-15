import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';

void main() {
  testWidgets('起動すると Material 3 のテーマが適用された空の画面が出る', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  test('light と dark が同じ 1 つのシード色から生成されている', () {
    expect(
      AppTheme.light().colorScheme,
      ColorScheme.fromSeed(seedColor: AppTheme.seedColor),
    );
    expect(
      AppTheme.dark().colorScheme,
      ColorScheme.fromSeed(
        seedColor: AppTheme.seedColor,
        brightness: Brightness.dark,
      ),
    );
  });
}
