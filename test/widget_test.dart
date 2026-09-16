import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/state/providers.dart';

import 'support/fake_clock.dart';
import 'support/fake_item_repository.dart';

void main() {
  testWidgets('起動すると Material 3 の light と dark テーマが適用される', (tester) async {
    final repository = FakeItemRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          itemRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FakeClock(DateTime.utc(2026, 9, 16, 3)),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
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
