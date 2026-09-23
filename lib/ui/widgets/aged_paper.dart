import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/aging_stage.dart';
import '../theme/app_theme.dart';

/// 紙とタップ領域で共有する角丸半径。
const double agedPaperCornerRadius = 12;

/// 項目 ID から、実行をまたいでも変わらないシードを作る(FNV-1a 32bit)。
///
/// String.hashCode は実行ごとに同じ値を返す保証が無い。
int stableSeedOf(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

typedef _PaperParameters = ({
  int stains,
  double minRadius,
  double maxRadius,
  double edgeWidth,
  double amplitude,
  int chips,
});

_PaperParameters _parametersOf(AgingStage stage) => switch (stage) {
  AgingStage.fresh => const (
    stains: 0,
    minRadius: 0,
    maxRadius: 0,
    edgeWidth: 0,
    amplitude: 0,
    chips: 0,
  ),
  AgingStage.slightlyAged => const (
    stains: 2,
    minRadius: 6,
    maxRadius: 12,
    edgeWidth: 0,
    amplitude: 0,
    chips: 0,
  ),
  AgingStage.dueSoon => const (
    stains: 3,
    minRadius: 8,
    maxRadius: 16,
    edgeWidth: 4,
    amplitude: 0,
    chips: 0,
  ),
  AgingStage.aged => const (
    stains: 4,
    minRadius: 10,
    maxRadius: 20,
    edgeWidth: 6,
    amplitude: 1.5,
    chips: 0,
  ),
  AgingStage.heavilyAged => const (
    stains: 6,
    minRadius: 12,
    maxRadius: 24,
    edgeWidth: 8,
    amplitude: 2.5,
    chips: 2,
  ),
};

/// 経年ステージに応じた紙を描く。テキストは子ウィジェットが上に載せる。
class AgedPaperPainter extends CustomPainter {
  const AgedPaperPainter({
    required this.stage,
    required this.colors,
    required this.seed,
  });

  /// 形状の変化を決める経年ステージ。
  final AgingStage stage;

  /// テーマから受け取る紙と装飾の色。
  final AgingPaperColors colors;

  /// 再描画してもシミや欠けの位置を変えないための固定シード。
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final parameters = _parametersOf(stage);
    final random = math.Random(seed);
    var outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(agedPaperCornerRadius),
        ),
      );
    if (parameters.amplitude > 0) {
      final jagged = Path();
      final center = size.center(Offset.zero);
      for (final metric in outline.computeMetrics()) {
        var isFirst = true;
        for (double distance = 0; distance < metric.length; distance += 6) {
          final point = metric.getTangentForOffset(distance)!.position;
          final inward = center - point;
          final displacement = random.nextDouble() * parameters.amplitude;
          final shifted = inward.distance == 0
              ? point
              : point + inward / inward.distance * displacement;
          if (isFirst) {
            jagged.moveTo(shifted.dx, shifted.dy);
            isFirst = false;
          } else {
            jagged.lineTo(shifted.dx, shifted.dy);
          }
        }
        jagged.close();
      }
      outline = jagged;
    }
    if (parameters.chips > 0) {
      final corners = [0, 1, 2, 3]..shuffle(random);
      for (final corner in corners.take(parameters.chips)) {
        final leg = 12 + random.nextDouble() * 6;
        final isRight = corner == 1 || corner == 2;
        final isBottom = corner == 2 || corner == 3;
        final x = isRight ? size.width : 0.0;
        final y = isBottom ? size.height : 0.0;
        final triangle = Path()
          ..moveTo(x, y)
          ..lineTo(x + (isRight ? -leg : leg), y)
          ..lineTo(x, y + (isBottom ? -leg : leg))
          ..close();
        outline = Path.combine(PathOperation.difference, outline, triangle);
      }
    }
    canvas.drawPath(outline, Paint()..color = colors.paper);
    canvas.save();
    canvas.clipPath(outline);
    if (parameters.stains > 0) {
      // まとめて一度だけ塗り、シミの重なりでコントラストを落とさない。
      final stains = Path();
      for (var i = 0; i < parameters.stains; i++) {
        final center = size.width <= 16 || size.height <= 16
            ? size.center(Offset.zero)
            : Offset(
                8 + random.nextDouble() * (size.width - 16),
                8 + random.nextDouble() * (size.height - 16),
              );
        final radius =
            parameters.minRadius +
            random.nextDouble() * (parameters.maxRadius - parameters.minRadius);
        stains.addOval(
          Rect.fromCenter(
            center: center,
            width: 2 * radius * (0.7 + random.nextDouble() * 0.6),
            height: 2 * radius,
          ),
        );
      }
      canvas.drawPath(stains, Paint()..color = colors.stain);
    }
    if (parameters.edgeWidth > 0) {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = parameters.edgeWidth
          ..color = colors.edge.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.edge,
    );
  }

  @override
  bool shouldRepaint(AgedPaperPainter oldDelegate) =>
      oldDelegate.stage != stage ||
      oldDelegate.colors != colors ||
      oldDelegate.seed != seed;
}
