import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/aged_paper.dart';

void main() {
  test('シードは同じIDで再現され、異なるIDで変わる', () {
    expect(stableSeedOf('abc'), stableSeedOf('abc'));
    expect(stableSeedOf('abc'), isNot(stableSeedOf('abd')));
  });
  test('描画の入力が変わったときだけ再描画する', () {
    final original = AgedPaperPainter(
      stage: AgingStage.fresh,
      colors: AgingPalette.light.fresh,
      seed: 1,
    );
    expect(
      AgedPaperPainter(
        stage: AgingStage.fresh,
        colors: AgingPalette.light.fresh,
        seed: 1,
      ).shouldRepaint(original),
      isFalse,
    );
    expect(
      AgedPaperPainter(
        stage: AgingStage.aged,
        colors: AgingPalette.light.fresh,
        seed: 1,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      AgedPaperPainter(
        stage: AgingStage.fresh,
        colors: AgingPalette.dark.fresh,
        seed: 1,
      ).shouldRepaint(original),
      isTrue,
    );
    expect(
      AgedPaperPainter(
        stage: AgingStage.fresh,
        colors: AgingPalette.light.fresh,
        seed: 2,
      ).shouldRepaint(original),
      isTrue,
    );
  });
  for (final stage in AgingStage.values) {
    for (final size in [const Size(360, 72), const Size(10, 10)]) {
      test('${stage.name} を $size に例外なく描画できる', () {
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = AgedPaperPainter(
          stage: stage,
          colors: AgingPalette.light.colorsOf(stage),
          seed: stableSeedOf('item-1'),
        );
        try {
          expect(() => painter.paint(canvas, size), returnsNormally);
        } finally {
          recorder.endRecording().dispose();
        }
      });
    }
  }
}
