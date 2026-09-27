import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aged_paper.dart';

/// 背景の繊維の密度(1000 平方ピクセルあたり)。カードより疎にする。
const double _backgroundFibersPer1000 = 0.6;
const double _backgroundSpecksPer1000 = 0.4;

/// 背景の繊維・斑点の不透明度(`onSurface` に掛ける)。
const double paperGrainOpacity = 0.05;

/// 背景の繊維の配置を固定するシード(再描画しても動かない)。
const int _backgroundSeed = 0x5EED;

/// 画面の地(`surface` + ごく薄い紙の繊維)を敷く。
///
/// `Scaffold` の背景はテーマで透明にしてあるので、**各ルートの根に必ず置く**。
/// `MaterialApp.builder` で 1 枚だけ敷くと、画面遷移中に前の画面が透けて重なる。
/// 繊維は `RepaintBoundary` で内容と別レイヤーにし、スクロールのたびに描き直さない。
class PaperBackground extends StatelessWidget {
  /// 地を敷く。
  const PaperBackground({required this.child, super.key});

  /// 地の上に載せる画面。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PaperGrainPainter(
                  color: scheme.onSurface.withValues(alpha: paperGrainOpacity),
                ),
                isComplex: true,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 背景の紙の繊維を描く。
class PaperGrainPainter extends CustomPainter {
  /// 繊維の色(不透明度込み)で作る。
  const PaperGrainPainter({required this.color});

  /// 繊維と斑点の色。
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintPaperFibers(
      canvas,
      size,
      math.Random(_backgroundSeed),
      fibersPer1000: _backgroundFibersPer1000,
      specksPer1000: _backgroundSpecksPer1000,
      fiberColor: color,
      speckColor: color,
    );
  }

  @override
  bool shouldRepaint(PaperGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
