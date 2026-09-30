import 'package:flutter/material.dart';

import '../app_info.dart';

/// ロゴの高さ(論理ピクセル)。AppBar のタイトル(`titleLarge`)の行の高さに揃える。
/// ロゴタイプなので文字サイズ設定では拡大しない(#92 判断5)。
const double appLogoHeight = 28;

/// ロゴ画像の縦横比(幅 / 高さ)。`logo_wordmark.png` の 619×120。画像を差し替えたら直す。
/// 読み込み前から幅を確保し、`FittedBox` の縮尺が決まるようにする(#92 判断10)。
const double appLogoAspectRatio = 619 / 120;

/// アプリの文字ロゴ。ホームの AppBar に出す(#92)。
///
/// 単色の画像を `onSurface` で塗るので、画像 1 枚でライト・ダークの両方に合う。
/// 読み上げではアプリ名が読まれる。
class AppLogo extends StatelessWidget {
  /// ロゴを作る。
  const AppLogo({super.key});

  /// ロゴ画像のアセットパス。`pubspec.yaml` にファイル単位で登録している。
  static const String assetPath = 'assets/branding/logo_wordmark.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    assetPath,
    height: appLogoHeight,
    width: appLogoHeight * appLogoAspectRatio,
    color: Theme.of(context).colorScheme.onSurface,
    colorBlendMode: BlendMode.srcIn,
    filterQuality: FilterQuality.medium,
    semanticLabel: AppInfo.name,
  );
}
