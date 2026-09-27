import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 同梱フォント(Zen Maru Gothic)。
///
/// `pubspec.yaml` の `fonts:` で Regular(400)/ Medium(500)/ Bold(700)を同梱している。
/// 適用は `AppTheme` の `ThemeData.fontFamily` の 1 箇所だけで、ウィジェットに `fontFamily` を書かない
/// (`docs/architecture.md`「同梱フォント」/ `docs/ui-design-guidelines.md` §7)。
abstract final class AppFonts {
  /// `pubspec.yaml` の `fonts:` に書いた family 名。
  static const String family = 'ZenMaruGothic';

  /// ライセンス一覧に出す名前。
  static const String displayName = 'Zen Maru Gothic';

  /// ライセンス全文のアセット(SIL OFL 1.1)。
  static const String licenseAsset = 'assets/fonts/ZenMaruGothic-OFL.txt';

  /// フォントのライセンスを [LicenseRegistry] に登録する。起動時に 1 回だけ呼ぶ。
  ///
  /// アセットは一覧が開かれたときに初めて読まれる(起動を遅らせない)。
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(licenseAsset);
      yield LicenseEntryWithLineBreaks(const [displayName], text);
    });
  }
}
