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

/// カードの繊維の密度(1000 平方ピクセルあたりの本数)。全ステージ共通。
const double _cardFibersPer1000 = 1.5;

/// カードの繊維の不透明度(`edge` の色に掛ける)。
const double _cardFiberOpacity = 0.06;

/// カードの斑点の不透明度(`edge` の色に掛ける)。
const double _cardSpeckOpacity = 0.06;

/// シミの輪染み(縁の濃い線)の太さ。
const double _stainRimWidth = 1.0;

/// 紙の繊維と斑点を描く。繊維・斑点はそれぞれ 1 本の Path にまとめて 1 回で塗る
/// (重なりで濃くならない)。個数は面積に比例させる。
void paintPaperFibers(
  Canvas canvas,
  Size size,
  math.Random random, {
  required double fibersPer1000,
  required double specksPer1000,
  required Color fiberColor,
  required Color speckColor,
}) {
  final area = size.width * size.height / 1000;
  final fibers = Path();
  for (var i = 0; i < (area * fibersPer1000).round(); i++) {
    final start = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final angle = random.nextDouble() * math.pi;
    final length = 4 + random.nextDouble() * 10;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final end = start + direction * length;
    final control = (start + end) / 2 + normal * (random.nextDouble() * 4 - 2);
    fibers
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }
  canvas.drawPath(
    fibers,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..color = fiberColor,
  );
  final specks = Path();
  for (var i = 0; i < (area * specksPer1000).round(); i++) {
    specks.addOval(
      Rect.fromCircle(
        center: Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        radius: 0.4 + random.nextDouble() * 0.6,
      ),
    );
  }
  canvas.drawPath(specks, Paint()..color = speckColor);
}

typedef _PaperParameters = ({
  double specksPer1000,
  int mottles,
  double mottleOpacity,
  int stains,
  double minRadius,
  double maxRadius,
  double burnWidth,
  double burnSigma,
  double burnOpacity,
  double amplitude,
  int chips,
});

_PaperParameters _parametersOf(AgingStage stage) => switch (stage) {
  AgingStage.fresh => const (
    specksPer1000: 0.5,
    mottles: 0,
    mottleOpacity: 0,
    stains: 0,
    minRadius: 0,
    maxRadius: 0,
    burnWidth: 4,
    burnSigma: 2,
    burnOpacity: 0.30,
    amplitude: 0,
    chips: 0,
  ),
  AgingStage.slightlyAged => const (
    specksPer1000: 1.0,
    mottles: 0,
    mottleOpacity: 0,
    stains: 2,
    minRadius: 5,
    maxRadius: 10,
    burnWidth: 5,
    burnSigma: 2,
    burnOpacity: 0.45,
    amplitude: 0,
    chips: 0,
  ),
  AgingStage.dueSoon => const (
    specksPer1000: 1.5,
    mottles: 2,
    mottleOpacity: 0.04,
    stains: 3,
    minRadius: 6,
    maxRadius: 14,
    burnWidth: 6,
    burnSigma: 2,
    burnOpacity: 0.65,
    amplitude: 0.8,
    chips: 0,
  ),
  AgingStage.aged => const (
    specksPer1000: 2.0,
    mottles: 3,
    mottleOpacity: 0.06,
    stains: 4,
    minRadius: 8,
    maxRadius: 18,
    burnWidth: 7,
    burnSigma: 2,
    burnOpacity: 0.80,
    amplitude: 1.5,
    chips: 0,
  ),
  AgingStage.heavilyAged => const (
    specksPer1000: 3.0,
    mottles: 4,
    mottleOpacity: 0.04,
    stains: 6,
    minRadius: 10,
    maxRadius: 22,
    burnWidth: 6,
    burnSigma: 2,
    burnOpacity: 0.90,
    amplitude: 2.5,
    chips: 2,
  ),
};

/// 経年ステージに応じた紙を描く。テキストは子ウィジェットが上に載せる。
///
/// 層は下から「紙の面 → 斑(まだら) → 繊維と斑点 → シミと輪染み → 縁の焼け → 1px の縁線」の順(判断B)。
/// 装飾の各層(繊維・斑点・シミ・輪染み)は 1 本の [Path] にまとめて 1 回だけ塗る。
/// 重なった部分の不透明度が積み上がらず、テキスト下の最暗部が読める範囲に収まる(判断C)。
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
    // 欠ける前の輪郭。焼けはこちらに沿って描き、欠けの斜辺がテキスト領域へ
    // 直接かかるのを避ける(判断 §9-2)。
    final burnOutline = outline;
    if (parameters.chips > 0) {
      final corners = [0, 1, 2, 3]..shuffle(random);
      for (final corner in corners.take(parameters.chips)) {
        final leg = 8 + random.nextDouble() * 4;
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
    if (parameters.mottles > 0) {
      // 円ごとに重ねて描くと重なりで濃さが積み上がるため、レイヤーごと
      // mottleOpacity を 1 回だけ掛ける(判断 §10-1)。ぼかしが円ごとに
      // 違うため、Path 1 本にはまとめない。
      canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..color = colors.edge.withValues(alpha: parameters.mottleOpacity),
      );
      for (var i = 0; i < parameters.mottles; i++) {
        final center = Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        );
        final radius = size.shortestSide * (0.25 + random.nextDouble() * 0.2);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = colors.edge
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              math.max(0.5, radius * 0.6),
            ),
        );
      }
      canvas.restore();
    }
    paintPaperFibers(
      canvas,
      size,
      random,
      fibersPer1000: _cardFibersPer1000,
      specksPer1000: parameters.specksPer1000,
      fiberColor: colors.edge.withValues(alpha: _cardFiberOpacity),
      speckColor: colors.edge.withValues(alpha: _cardSpeckOpacity),
    );
    if (parameters.stains > 0) {
      // まとめて一度だけ塗り、シミの重なりでコントラストを落とさない。
      final stains = Path();
      const vertexCount = 10;
      for (var i = 0; i < parameters.stains; i++) {
        final center = size.width <= 16 || size.height <= 16
            ? size.center(Offset.zero)
            : Offset(
                8 + random.nextDouble() * (size.width - 16),
                8 + random.nextDouble() * (size.height - 16),
              );
        final baseRadius =
            parameters.minRadius +
            random.nextDouble() * (parameters.maxRadius - parameters.minRadius);
        // 頂点を不定形に散らし、横方向だけ既存の楕円の縦横比を保つ倍率を掛ける。
        final vertices = List<Offset>.generate(vertexCount, (v) {
          final angle = 2 * math.pi * v / vertexCount;
          final radius = baseRadius * (0.8 + random.nextDouble() * 0.3);
          final aspect = 0.7 + random.nextDouble() * 0.6;
          return center +
              Offset(
                radius * aspect * math.cos(angle),
                radius * math.sin(angle),
              );
        });
        final midpoints = List<Offset>.generate(
          vertexCount,
          (v) => (vertices[v] + vertices[(v + 1) % vertexCount]) / 2,
        );
        // 隣り合う頂点の中点を通る 2 次ベジェで閉じた滑らかな形にする。
        stains.moveTo(midpoints[0].dx, midpoints[0].dy);
        for (var v = 0; v < vertexCount; v++) {
          final next = (v + 1) % vertexCount;
          stains.quadraticBezierTo(
            vertices[next].dx,
            vertices[next].dy,
            midpoints[next].dx,
            midpoints[next].dy,
          );
        }
        stains.close();
      }
      canvas.drawPath(
        stains,
        Paint()
          ..color = colors.stain
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
      // 輪染み(縁の濃い線)。
      canvas.drawPath(
        stains,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stainRimWidth
          ..color = colors.stain.withValues(alpha: colors.stain.a * 0.5),
      );
    }
    // 縁の焼け。欠ける前の輪郭に沿って描き、クリップ中なので内側の半分だけが
    // 残り、縁から内側へ減衰する。
    canvas.drawPath(
      burnOutline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = parameters.burnWidth * 2
        ..color = colors.burn.withValues(alpha: parameters.burnOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, parameters.burnSigma),
    );
    if (parameters.chips > 0) {
      // 欠けの切り口には焼けが乗らないので、細い焼けを足す。
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = colors.burn.withValues(alpha: parameters.burnOpacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
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
