# タスクリスト: Flutter プロジェクトの初期化とテーマ設定(#2)

手順の詳細とコード全文は `design.md` にある。**設計判断は一切しない。**
判断が要る場面に出たら `design.md`「停止して報告する条件」に従って停止する。

## フェーズ1: 雛形

- [x] `flutter create --org com.lastwhen --project-name lastwhen --platforms=android,ios .` を実行(design.md 手順1)
- [x] `git status` で `README.md` / `.gitignore` が変更されていないか確認し、変更されていたら戻す
- [x] `web/` `linux/` `macos/` `windows/` が存在しないことを確認(あれば削除)

## フェーズ2: 依存と lint

- [x] `pubspec.yaml` の依存を design.md 手順2 の内容に置き換える(`cupertino_icons` は削る)
- [x] `flutter pub get` が通る
- [x] `pubspec.lock` が生成されていることを確認(コミット対象)
- [x] `analysis_options.yaml` を design.md 手順3 の内容にする

## フェーズ3: アプリ本体

- [x] `lib/ui/theme/app_theme.dart` を design.md 手順4 の内容で作る
- [x] `lib/app.dart` を design.md 手順5 の内容で作る
- [x] `lib/main.dart` を design.md 手順6 の内容で上書きする
- [x] `lib/domain/.gitkeep` `lib/data/.gitkeep` `lib/state/.gitkeep` を作る
- [x] `flutter create` が生成したカウンターアプリのコードが `lib/` に残っていないことを確認

## フェーズ4: テスト

- [x] `test/widget_test.dart` を design.md 手順8 の内容で丸ごと置き換える
- [x] `flutter test` が通る

## フェーズ5: プラットフォーム設定

- [x] Android の `minSdk` を `26` にする(design.md 手順9)
- [x] iOS の最低バージョンを `15.0` にする(`AppFrameworkInfo.plist` と `project.pbxproj` の全箇所)

## フェーズ6: CI とドキュメント

- [x] `.github/workflows/ci.yml` の暫定ガードを削除する(design.md 手順10。probe step + `if` 5 行のみ)
- [x] `docs/architecture.md` に判断1・判断2 を反映する(design.md 手順11)

## フェーズ7: 検証

- [x] `dart format .` を実行する
- [x] `dart format --output=none --set-exit-if-changed .` が通る
- [x] `flutter analyze --fatal-infos` が指摘ゼロで通る
- [x] `flutter test` が通る
- [x] `flutter build apk --debug` が通る(失敗した場合は design.md 判断2 のフォールバック条件に該当するか確認する)

## 振り返り(申し送り)

- **devcontainer に Android SDK が入っていない。** `flutter build apk --debug` を通すため、
  実装 fork がセッション内でのみ `/opt/android-sdk` に command-line tools / platform 36 /
  build-tools 36.0.0 を導入した。`devcontainer.json` と `post_create.sh` は触っていないため、
  **コンテナをリビルドすると再び失われる**。CI の `quality` ジョブは APK をビルドしない
  (`pub get` / `format` / `analyze` / `test` のみ)ので CI は緑のままだが、ローカルで
  Android 実機・エミュレータ確認をする段になると必ず詰まる。→ 別チケット化する
- `ios/Flutter/AppFrameworkInfo.plist` に `MinimumOSVersion` キーが**元から無かった**
  (現行 Flutter の生成物には含まれない)ため新規追加した。`project.pbxproj` は生成時点で
  既に `15.0` だったので変更不要だった
- `analysis_options.yaml` の `exclude` 3 行は Flutter SDK の自動追記(`design.md`
  「検収で判明した追記」参照)。消さないこと
- 計画時に依存の最新版を pub.dev で実地確認したことで、`sqlite3_flutter_libs` の提供終了を
  実装前に拾えた。**`docs/` に書いたバージョン方針は書いた時点のスナップショット**であり、
  最初にその依存を実際に入れるチケットで必ず裏を取る
