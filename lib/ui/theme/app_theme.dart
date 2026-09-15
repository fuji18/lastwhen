import 'package:flutter/material.dart';

/// アプリ全体のテーマ。
///
/// 色は **1 つのシード色**から light / dark の両方を生成する
/// (`docs/ui-design-guidelines.md` §7)。ウィジェット側に生の色・余白・
/// タイポの値を書かず、必ず `Theme.of(context)` 経由で参照すること。
///
/// `TextTheme` の実値は一覧の行(#5)を組むときに決める。
abstract final class AppTheme {
  /// テーマのシード色。
  ///
  /// 青系を選んでいるのは、P1 の状態表示(F10)で「そろそろ / 経過」を
  /// 色 + ラベルで示す予定があり、赤・橙・緑を意味色として空けておくため。
  /// MVP は状態を色で分けない(`docs/functional-design.md`「色の使い方」)。
  static const Color seedColor = Color(0xFF2F6690);

  /// ライトテーマ。
  static ThemeData light() => _build(Brightness.light);

  /// ダークテーマ。
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
  );
}
