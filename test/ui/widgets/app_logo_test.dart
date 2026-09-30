import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/app_info.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/app_logo.dart';

Widget _app(ThemeData theme) => MaterialApp(
  theme: theme,
  home: const Scaffold(body: Center(child: AppLogo())),
);

void main() {
  testWidgets('ライトテーマでは onSurface で塗る', (tester) async {
    final theme = AppTheme.light();
    await tester.pumpWidget(_app(theme));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, theme.colorScheme.onSurface);
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('ダークテーマでは onSurface で塗る', (tester) async {
    final theme = AppTheme.dark();
    await tester.pumpWidget(_app(theme));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.color, theme.colorScheme.onSurface);
    expect(image.colorBlendMode, BlendMode.srcIn);
  });

  testWidgets('高さは appLogoHeight', (tester) async {
    await tester.pumpWidget(_app(AppTheme.light()));
    final size = tester.getSize(find.byType(AppLogo));
    expect(size.height, appLogoHeight);
    expect(size.width, appLogoHeight * appLogoAspectRatio);
  });

  testWidgets('読み上げはアプリ名', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AppTheme.light()));
    expect(find.bySemanticsLabel(AppInfo.name), findsOneWidget);
    handle.dispose();
  });
}
