import 'package:flutter/material.dart';

import '../../domain/aging_stage.dart';

/// アプリ全体のテーマ。
///
/// 基本色は **1 つのシード色**から light / dark の両方を生成する
/// (`docs/ui-design-guidelines.md` §7)。ウィジェット側に生の色・余白・
/// タイポの値を書かず、必ず `Theme.of(context)` 経由で参照すること。
///
/// P1 の経年変化(F28)は `AgingPalette` の紙の色と `ItemCard` の形状変化で示す。
/// シードの青は紙に使わない。
///
/// `TextTheme` の実値は一覧の行(#5)を組むときに決める。
abstract final class AppTheme {
  /// テーマのシード色。
  ///
  /// 経年変化(F28)は `AgingPalette` の紙の色と `ItemCard` の形状変化で示す。
  /// シードの青は紙に使わない。
  static const Color seedColor = Color(0xFF2F6690);

  /// ライトテーマ。
  static ThemeData light() => _build(Brightness.light);

  /// ダークテーマ。
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    extensions: [
      if (brightness == Brightness.dark)
        AgingPalette.dark
      else
        AgingPalette.light,
    ],
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
  );
}

/// 1 つの経年ステージの紙の色。
@immutable
final class AgingPaperColors {
  const AgingPaperColors({
    required this.paper,
    required this.edge,
    required this.stain,
  });

  /// 紙の面。テキストはこの上に載る。
  final Color paper;

  /// 縁の線と縁の焼け。
  final Color edge;

  /// シミ(半透明)。紙の上に重ねる。
  final Color stain;

  /// テーマ遷移時に紙と装飾の色を補間する。
  static AgingPaperColors lerp(
    AgingPaperColors a,
    AgingPaperColors b,
    double t,
  ) => AgingPaperColors(
    paper: Color.lerp(a.paper, b.paper, t)!,
    edge: Color.lerp(a.edge, b.edge, t)!,
    stain: Color.lerp(a.stain, b.stain, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is AgingPaperColors &&
      other.paper == paper &&
      other.edge == edge &&
      other.stain == stain;

  @override
  int get hashCode => Object.hash(paper, edge, stain);
}

/// 経年ステージごとの紙の色。
///
/// `ColorScheme.fromSeed` に黄ばみ・古紙のロールは無いので拡張で持つ。
/// 古びは彩度と明度で作り、テキストの色は変えない。
@immutable
final class AgingPalette extends ThemeExtension<AgingPalette> {
  const AgingPalette({
    required this.fresh,
    required this.slightlyAged,
    required this.dueSoon,
    required this.aged,
    required this.heavilyAged,
  });

  /// light テーマの紙の色。
  static const AgingPalette light = AgingPalette(
    fresh: AgingPaperColors(
      paper: Color(0xFFFBF8F1),
      edge: Color(0xFFE3DACA),
      stain: Color(0x298B6A2E),
    ),
    slightlyAged: AgingPaperColors(
      paper: Color(0xFFF6EFDF),
      edge: Color(0xFFD8C9A8),
      stain: Color(0x298B6A2E),
    ),
    dueSoon: AgingPaperColors(
      paper: Color(0xFFF0E3C4),
      edge: Color(0xFFC9B283),
      stain: Color(0x298B6A2E),
    ),
    aged: AgingPaperColors(
      paper: Color(0xFFE8D5AC),
      edge: Color(0xFFB4945C),
      stain: Color(0x298B6A2E),
    ),
    heavilyAged: AgingPaperColors(
      paper: Color(0xFFDDC393),
      edge: Color(0xFF97773F),
      stain: Color(0x298B6A2E),
    ),
  );

  /// dark テーマの紙の色。
  static const AgingPalette dark = AgingPalette(
    fresh: AgingPaperColors(
      paper: Color(0xFF1E1C18),
      edge: Color(0xFF3A342A),
      stain: Color(0x29C9A461),
    ),
    slightlyAged: AgingPaperColors(
      paper: Color(0xFF26221B),
      edge: Color(0xFF4A4030),
      stain: Color(0x29C9A461),
    ),
    dueSoon: AgingPaperColors(
      paper: Color(0xFF2F291E),
      edge: Color(0xFF5A4A33),
      stain: Color(0x29C9A461),
    ),
    aged: AgingPaperColors(
      paper: Color(0xFF3A3021),
      edge: Color(0xFF6E5A3A),
      stain: Color(0x29C9A461),
    ),
    heavilyAged: AgingPaperColors(
      paper: Color(0xFF463924),
      edge: Color(0xFF806640),
      stain: Color(0x29C9A461),
    ),
  );

  /// テーマの拡張が無ければ、明暗に合う既定値を返す。
  static AgingPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AgingPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  /// fresh の紙の色。
  final AgingPaperColors fresh;

  /// slightlyAged の紙の色。
  final AgingPaperColors slightlyAged;

  /// dueSoon の紙の色。
  final AgingPaperColors dueSoon;

  /// aged の紙の色。
  final AgingPaperColors aged;

  /// heavilyAged の紙の色。
  final AgingPaperColors heavilyAged;

  /// ステージに対応する色。
  AgingPaperColors colorsOf(AgingStage stage) => switch (stage) {
    AgingStage.fresh => fresh,
    AgingStage.slightlyAged => slightlyAged,
    AgingStage.dueSoon => dueSoon,
    AgingStage.aged => aged,
    AgingStage.heavilyAged => heavilyAged,
  };

  @override
  AgingPalette copyWith({
    AgingPaperColors? fresh,
    AgingPaperColors? slightlyAged,
    AgingPaperColors? dueSoon,
    AgingPaperColors? aged,
    AgingPaperColors? heavilyAged,
  }) => AgingPalette(
    fresh: fresh ?? this.fresh,
    slightlyAged: slightlyAged ?? this.slightlyAged,
    dueSoon: dueSoon ?? this.dueSoon,
    aged: aged ?? this.aged,
    heavilyAged: heavilyAged ?? this.heavilyAged,
  );

  @override
  AgingPalette lerp(covariant AgingPalette? other, double t) {
    if (other == null) return this;
    return AgingPalette(
      fresh: AgingPaperColors.lerp(fresh, other.fresh, t),
      slightlyAged: AgingPaperColors.lerp(slightlyAged, other.slightlyAged, t),
      dueSoon: AgingPaperColors.lerp(dueSoon, other.dueSoon, t),
      aged: AgingPaperColors.lerp(aged, other.aged, t),
      heavilyAged: AgingPaperColors.lerp(heavilyAged, other.heavilyAged, t),
    );
  }
}
