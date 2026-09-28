import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

Map<String, Color> _roles(ColorScheme c) => {
  'primary': c.primary,
  'onPrimary': c.onPrimary,
  'primaryContainer': c.primaryContainer,
  'onPrimaryContainer': c.onPrimaryContainer,
  'primaryFixed': c.primaryFixed,
  'primaryFixedDim': c.primaryFixedDim,
  'onPrimaryFixed': c.onPrimaryFixed,
  'onPrimaryFixedVariant': c.onPrimaryFixedVariant,
  'secondary': c.secondary,
  'onSecondary': c.onSecondary,
  'secondaryContainer': c.secondaryContainer,
  'onSecondaryContainer': c.onSecondaryContainer,
  'secondaryFixed': c.secondaryFixed,
  'secondaryFixedDim': c.secondaryFixedDim,
  'onSecondaryFixed': c.onSecondaryFixed,
  'onSecondaryFixedVariant': c.onSecondaryFixedVariant,
  'tertiary': c.tertiary,
  'onTertiary': c.onTertiary,
  'tertiaryContainer': c.tertiaryContainer,
  'onTertiaryContainer': c.onTertiaryContainer,
  'tertiaryFixed': c.tertiaryFixed,
  'tertiaryFixedDim': c.tertiaryFixedDim,
  'onTertiaryFixed': c.onTertiaryFixed,
  'onTertiaryFixedVariant': c.onTertiaryFixedVariant,
  'error': c.error,
  'onError': c.onError,
  'errorContainer': c.errorContainer,
  'onErrorContainer': c.onErrorContainer,
  'surface': c.surface,
  'onSurface': c.onSurface,
  'surfaceDim': c.surfaceDim,
  'surfaceBright': c.surfaceBright,
  'surfaceContainerLowest': c.surfaceContainerLowest,
  'surfaceContainerLow': c.surfaceContainerLow,
  'surfaceContainer': c.surfaceContainer,
  'surfaceContainerHigh': c.surfaceContainerHigh,
  'surfaceContainerHighest': c.surfaceContainerHighest,
  'onSurfaceVariant': c.onSurfaceVariant,
  'outline': c.outline,
  'outlineVariant': c.outlineVariant,
  'shadow': c.shadow,
  'scrim': c.scrim,
  'inverseSurface': c.inverseSurface,
  'onInverseSurface': c.onInverseSurface,
  'inversePrimary': c.inversePrimary,
  'surfaceTint': c.surfaceTint,
};

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    final colors = theme.colorScheme;
    final roles = _roles(colors);

    group('$name テーマに青系のロールが無い', () {
      for (final entry in roles.entries) {
        final hsl = HSLColor.fromColor(entry.value);
        final isSaturatedEnough = hsl.saturation >= 0.15;
        final isMidLightness = hsl.lightness >= 0.08 && hsl.lightness <= 0.95;
        test('$name ${entry.key} が青系でない', () {
          if (isSaturatedEnough && isMidLightness) {
            expect(
              hsl.hue,
              isNot(inInclusiveRange(180, 260)),
              reason: '$name ${entry.key}',
            );
          }
        });
      }
    });

    group('$name テーマのアイコン・枠線が3:1以上', () {
      final backgrounds = <String, Color>{
        'surface': colors.surface,
        'surfaceContainerLowest': colors.surfaceContainerLowest,
        'surfaceContainerLow': colors.surfaceContainerLow,
        'surfaceContainer': colors.surfaceContainer,
        'surfaceContainerHigh': colors.surfaceContainerHigh,
        'surfaceContainerHighest': colors.surfaceContainerHighest,
      };
      final foregrounds = <String, Color>{
        'primary': colors.primary,
        'outline': colors.outline,
      };
      for (final bg in backgrounds.entries) {
        for (final fg in foregrounds.entries) {
          test('$name ${fg.key} / ${bg.key} が3:1以上', () {
            expect(_contrast(fg.value, bg.value), greaterThanOrEqualTo(3.0));
          });
        }
      }
    });

    test('$name テーマの FAB がテラコッタ塗り', () {
      expect(theme.floatingActionButtonTheme.backgroundColor, colors.primary);
      expect(theme.floatingActionButtonTheme.foregroundColor, colors.onPrimary);
    });

    test('$name テーマの Scaffold 背景は透明(地は PaperBackground が塗る)', () {
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
    });

    test('$name テーマの AppBar は通常透明、下に潜ったときだけ不透明', () {
      final resolver = theme.appBarTheme.backgroundColor;
      expect(resolver, isA<WidgetStateColor>());
      expect(
        (resolver as WidgetStateColor).resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        resolver.resolve(<WidgetState>{WidgetState.scrolledUnder}),
        colors.surfaceContainer,
      );
    });
  }
}
