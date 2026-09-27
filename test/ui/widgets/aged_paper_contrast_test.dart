import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/aged_paper.dart';
import 'package:lastwhen/ui/widgets/paper_background.dart';

/// sRGB(0-255)→線形光量の変換表(WCAG の相対輝度計算に使う)。
final List<double> _srgbToLinear = List<double>.generate(256, (i) {
  final c = i / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
});

double _relativeLuminance(int r, int g, int b) =>
    0.2126 * _srgbToLinear[r] +
    0.7152 * _srgbToLinear[g] +
    0.0722 * _srgbToLinear[b];

double _contrastWithColor(double luminance, Color color) {
  final other = color.computeLuminance();
  final lighter = math.max(luminance, other);
  final darker = math.min(luminance, other);
  return (lighter + 0.05) / (darker + 0.05);
}

/// [size] に塗った紙(`background` + `paint` の描画結果)の画素を、[rect] の範囲だけ走査して
/// 呼び出し元に渡す。
Future<void> _forEachPixelInRect(
  Size size,
  Rect rect,
  void Function(Canvas canvas) paint,
  void Function(int x, int y, int r, int g, int b) visit,
) async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas);
  final picture = recorder.endRecording();
  final width = size.width.round();
  final height = size.height.round();
  final image = await picture.toImage(width, height);
  picture.dispose();
  final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
  image.dispose();
  final bytes = byteData!.buffer.asUint8List();
  for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
    for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
      final index = (y * width + x) * 4;
      visit(x, y, bytes[index], bytes[index + 1], bytes[index + 2]);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cardSizes = [Size(336, 72), Size(112, 140)];

  for (final (name, theme, palette) in [
    ('light', AppTheme.light(), AgingPalette.light),
    ('dark', AppTheme.dark(), AgingPalette.dark),
  ]) {
    for (final stage in AgingStage.values) {
      for (final size in cardSizes) {
        test('$name ${stage.name} $size のテキスト領域は4.5以上', () async {
          var minOnSurface = double.infinity;
          var minOnSurfaceVariant = double.infinity;
          var minOnSurfaceCoord = const Offset(-1, -1);
          var minOnSurfaceVariantCoord = const Offset(-1, -1);
          final textRect = (Offset.zero & size).deflate(12);
          for (var i = 0; i < 16; i++) {
            final seed = stableSeedOf('item-$i');
            await _forEachPixelInRect(
              size,
              textRect,
              (canvas) {
                canvas.drawRect(
                  Offset.zero & size,
                  Paint()..color = theme.colorScheme.surface,
                );
                AgedPaperPainter(
                  stage: stage,
                  colors: palette.colorsOf(stage),
                  seed: seed,
                ).paint(canvas, size);
              },
              (x, y, r, g, b) {
                final luminance = _relativeLuminance(r, g, b);
                final onSurfaceContrast = _contrastWithColor(
                  luminance,
                  theme.colorScheme.onSurface,
                );
                final onSurfaceVariantContrast = _contrastWithColor(
                  luminance,
                  theme.colorScheme.onSurfaceVariant,
                );
                if (onSurfaceContrast < minOnSurface) {
                  minOnSurface = onSurfaceContrast;
                  minOnSurfaceCoord = Offset(x.toDouble(), y.toDouble());
                }
                if (onSurfaceVariantContrast < minOnSurfaceVariant) {
                  minOnSurfaceVariant = onSurfaceVariantContrast;
                  minOnSurfaceVariantCoord = Offset(x.toDouble(), y.toDouble());
                }
              },
            );
          }
          expect(
            minOnSurface,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${stage.name} $size onSurface とのコントラスト最小値 '
                '$minOnSurface (座標 $minOnSurfaceCoord)',
          );
          expect(
            minOnSurfaceVariant,
            greaterThanOrEqualTo(4.5),
            reason:
                '$name ${stage.name} $size onSurfaceVariant とのコントラスト最小値 '
                '$minOnSurfaceVariant (座標 $minOnSurfaceVariantCoord)',
          );
        });
      }
    }
  }

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    test('$name 背景の紙のテキスト領域は4.5以上', () async {
      const size = Size(360, 640);
      var minContrast = double.infinity;
      await _forEachPixelInRect(
        size,
        Offset.zero & size,
        (canvas) {
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = theme.colorScheme.surface,
          );
          PaperGrainPainter(
            color: theme.colorScheme.onSurface.withValues(
              alpha: paperGrainOpacity,
            ),
          ).paint(canvas, size);
        },
        (x, y, r, g, b) {
          final luminance = _relativeLuminance(r, g, b);
          final contrast = _contrastWithColor(
            luminance,
            theme.colorScheme.onSurfaceVariant,
          );
          if (contrast < minContrast) {
            minContrast = contrast;
          }
        },
      );
      expect(
        minContrast,
        greaterThanOrEqualTo(4.5),
        reason: '$name 背景 onSurfaceVariant とのコントラスト最小値 $minContrast',
      );
    });
  }
}
