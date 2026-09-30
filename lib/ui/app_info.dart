/// 設定画面の「このアプリについて」に出す情報。
abstract final class AppInfo {
  /// アプリ名(ブランド表記)。
  static const String name = 'LastWhen';

  /// `pubspec.yaml` の `version` と同じ値。**バージョンを上げるときは両方を直す。**
  /// 食い違いは `test/ui/app_info_test.dart` が検出する。
  static const String version = '1.0.0+1';

  /// 画面に出すバージョン(`+` より前 = versionName)。
  static String get versionName => version.split('+').first;

  /// プライバシーポリシーの公開先(原稿は `site/privacy-policy/index.html`)。
  static const String privacyPolicyUrl =
      'https://fuji18.github.io/lastwhen/privacy-policy/';
}
