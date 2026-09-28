// 見た目の確認用プレビュー(CI では skip)。
//
// 実行方法: `PAPER_PREVIEW=1 flutter test test/ui/widgets/aged_paper_preview_test.dart`
// `build/paper_preview/paper_light.png` / `paper_dark.png` に 2 倍解像度の PNG を書き出す。
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart' show ThemeData;
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/aged_paper.dart';
import 'package:lastwhen/ui/widgets/paper_background.dart';

const double _outerMargin = 16;
const double _cardWidth = 336;
const double _cardHeightNormal = 72;
const double _tallCardWidth = 112;
const double _tallCardHeight = 140;
const double _columnWidth = _cardWidth + _outerMargin;
const double _logicalWidth = _outerMargin + 5 * _columnWidth;
const double _logicalHeight =
    _outerMargin +
    _cardHeightNormal +
    _outerMargin +
    _cardHeightNormal +
    _outerMargin +
    _tallCardHeight +
    _outerMargin;
const double _previewScale = 2;

Future<void> _writePreview(
  String path,
  ThemeData theme,
  AgingPalette palette,
) async {
  const size = Size(_logicalWidth, _logicalHeight);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_previewScale);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = theme.colorScheme.surface,
  );
  PaperGrainPainter(
    color: theme.colorScheme.onSurface.withValues(alpha: paperGrainOpacity),
  ).paint(canvas, size);

  final rows = [
    (const Size(_cardWidth, _cardHeightNormal), 'item-0', _outerMargin),
    (
      const Size(_cardWidth, _cardHeightNormal),
      'item-1',
      _outerMargin + _cardHeightNormal + _outerMargin,
    ),
    (
      const Size(_tallCardWidth, _tallCardHeight),
      'item-2',
      _outerMargin +
          _cardHeightNormal +
          _outerMargin +
          _cardHeightNormal +
          _outerMargin,
    ),
  ];
  for (final (cellSize, seedKey, y) in rows) {
    for (var column = 0; column < AgingStage.values.length; column++) {
      final stage = AgingStage.values[column];
      final x = _outerMargin + column * _columnWidth;
      canvas.save();
      canvas.translate(x, y);
      AgedPaperPainter(
        stage: stage,
        colors: palette.colorsOf(stage),
        seed: stableSeedOf(seedKey),
      ).paint(canvas, cellSize);
      canvas.restore();
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * _previewScale).round(),
    (size.height * _previewScale).round(),
  );
  picture.dispose();
  final byteData = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  final directory = Directory('build/paper_preview');
  await directory.create(recursive: true);
  await File(path).writeAsBytes(byteData!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('プレビュー PNG を生成する', () async {
    await _writePreview(
      'build/paper_preview/paper_light.png',
      AppTheme.light(),
      AgingPalette.light,
    );
    await _writePreview(
      'build/paper_preview/paper_dark.png',
      AppTheme.dark(),
      AgingPalette.dark,
    );
    expect(File('build/paper_preview/paper_light.png').existsSync(), isTrue);
    expect(File('build/paper_preview/paper_dark.png').existsSync(), isTrue);
  }, skip: !Platform.environment.containsKey('PAPER_PREVIEW'));
}
