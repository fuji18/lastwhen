import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), AgingPalette.light),
    ('dark', AppTheme.dark(), AgingPalette.dark),
  ]) {
    test('$name テーマにパレットが登録される', () {
      expect(theme.extension<AgingPalette>(), same(palette));
    });
    for (final stage in AgingStage.values) {
      final colors = palette.colorsOf(stage);
      for (final entry in {
        'onSurface': theme.colorScheme.onSurface,
        'onSurfaceVariant': theme.colorScheme.onSurfaceVariant,
      }.entries) {
        test('$name ${stage.name} ${entry.key} のコントラストが4.5以上', () {
          expect(
            _contrast(entry.value, colors.paper),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(
              entry.value,
              Color.alphaBlend(colors.stain, colors.paper),
            ),
            greaterThanOrEqualTo(4.5),
          );
        });
      }
    }
  }
  test('補間の両端は元のパレットの色と等しい', () {
    for (final stage in AgingStage.values) {
      expect(
        AgingPalette.light.lerp(AgingPalette.dark, 0).colorsOf(stage),
        AgingPalette.light.colorsOf(stage),
      );
      expect(
        AgingPalette.light.lerp(AgingPalette.dark, 1).colorsOf(stage),
        AgingPalette.dark.colorsOf(stage),
      );
    }
  });

  test('agingIconOpacity はステージ順に単調非増加', () {
    final opacities = AgingStage.values.map(agingIconOpacity).toList();
    for (var i = 1; i < opacities.length; i++) {
      expect(opacities[i], lessThanOrEqualTo(opacities[i - 1]));
    }
  });

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), AgingPalette.light),
    ('dark', AppTheme.dark(), AgingPalette.dark),
  ]) {
    for (final stage in AgingStage.values) {
      test('$name ${stage.name} のアイコンの掠れは紙に対して3:1以上', () {
        final colors = palette.colorsOf(stage);
        final iconColor = Color.alphaBlend(
          theme.colorScheme.onSurface.withValues(
            alpha: agingIconOpacity(stage),
          ),
          colors.paper,
        );
        expect(_contrast(iconColor, colors.paper), greaterThanOrEqualTo(3.0));
        expect(
          _contrast(iconColor, Color.alphaBlend(colors.stain, colors.paper)),
          greaterThanOrEqualTo(3.0),
        );
      });
    }
  }
}
