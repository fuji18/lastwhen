import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/state/providers.dart';

import 'support/fake_category_repository.dart';
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
          categoryRepositoryProvider.overrideWithValue(
            FakeCategoryRepository(),
          ),
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

  test('light と dark の primary がシード色と同じ色相(テラコッタ)', () {
    final seedHue = HSLColor.fromColor(AppTheme.seedColor).hue;
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(
        HSLColor.fromColor(theme.colorScheme.primary).hue,
        closeTo(seedHue, 5),
        reason: '${theme.brightness}',
      );
    }
  });
}
