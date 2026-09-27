import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/theme/app_fonts.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';

const _styleNames = [
  'displayLarge',
  'displayMedium',
  'displaySmall',
  'headlineLarge',
  'headlineMedium',
  'headlineSmall',
  'titleLarge',
  'titleMedium',
  'titleSmall',
  'bodyLarge',
  'bodyMedium',
  'bodySmall',
  'labelLarge',
  'labelMedium',
  'labelSmall',
];

List<TextStyle?> _stylesOf(TextTheme textTheme) => [
  textTheme.displayLarge,
  textTheme.displayMedium,
  textTheme.displaySmall,
  textTheme.headlineLarge,
  textTheme.headlineMedium,
  textTheme.headlineSmall,
  textTheme.titleLarge,
  textTheme.titleMedium,
  textTheme.titleSmall,
  textTheme.bodyLarge,
  textTheme.bodyMedium,
  textTheme.bodySmall,
  textTheme.labelLarge,
  textTheme.labelMedium,
  textTheme.labelSmall,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pubspec の fonts に 3 ウェイトが同梱されている', () async {
    final manifestJson = await rootBundle.loadString('FontManifest.json');
    final manifest = jsonDecode(manifestJson) as List<dynamic>;
    final matches = manifest
        .cast<Map<String, dynamic>>()
        .where((entry) => entry['family'] == AppFonts.family)
        .toList();
    expect(matches, hasLength(1));

    final fonts = (matches.single['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final assets = fonts.map((f) => f['asset'] as String).toSet();
    expect(assets, {
      'assets/fonts/ZenMaruGothic-Regular.ttf',
      'assets/fonts/ZenMaruGothic-Medium.ttf',
      'assets/fonts/ZenMaruGothic-Bold.ttf',
    });

    final weightByAsset = {
      for (final f in fonts) f['asset'] as String: f['weight'] as int,
    };
    expect(weightByAsset['assets/fonts/ZenMaruGothic-Regular.ttf'], 400);
    expect(weightByAsset['assets/fonts/ZenMaruGothic-Medium.ttf'], 500);
    expect(weightByAsset['assets/fonts/ZenMaruGothic-Bold.ttf'], 700);

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  test('light / dark の全テキストスタイルが同梱フォントで描かれる', () {
    for (final theme in [
      ('light', AppTheme.light()),
      ('dark', AppTheme.dark()),
    ]) {
      final (label, themeData) = theme;
      for (final textTheme in [
        ('textTheme', themeData.textTheme),
        ('primaryTextTheme', themeData.primaryTextTheme),
      ]) {
        final (themeLabel, resolvedTextTheme) = textTheme;
        final styles = _stylesOf(resolvedTextTheme);
        for (var i = 0; i < styles.length; i += 1) {
          expect(
            styles[i]?.fontFamily,
            AppFonts.family,
            reason: '$label/$themeLabel/${_styleNames[i]}',
          );
        }
      }
    }
  });

  test('ライセンス一覧に Zen Maru Gothic の OFL が載る', () async {
    addTearDown(LicenseRegistry.reset);
    AppFonts.registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final matches = entries
        .where((entry) => entry.packages.contains(AppFonts.displayName))
        .toList();
    expect(matches, hasLength(1));

    final text = matches.single.paragraphs.map((p) => p.text).join();
    expect(text, contains('SIL Open Font License'));
  });

  testWidgets('App の画面で使うテーマも同梱フォントを当てている', (tester) async {
    late TextTheme captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) {
            captured = Theme.of(context).textTheme;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(captured.bodyLarge?.fontFamily, AppFonts.family);
    expect(captured.titleMedium?.fontFamily, AppFonts.family);
    expect(captured.headlineSmall?.fontFamily, AppFonts.family);
  });
}
