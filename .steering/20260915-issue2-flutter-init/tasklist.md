# タスクリスト: Flutter プロジェクトの初期化とテーマ設定(#2)

手順の詳細とコード全文は `design.md` にある。**設計判断は一切しない。**
判断が要る場面に出たら `design.md`「停止して報告する条件」に従って停止する。

## フェーズ1: 雛形

- [ ] `flutter create --org com.lastwhen --project-name lastwhen --platforms=android,ios .` を実行(design.md 手順1)
- [ ] `git status` で `README.md` / `.gitignore` が変更されていないか確認し、変更されていたら戻す
- [ ] `web/` `linux/` `macos/` `windows/` が存在しないことを確認(あれば削除)

## フェーズ2: 依存と lint

- [ ] `pubspec.yaml` の依存を design.md 手順2 の内容に置き換える(`cupertino_icons` は削る)
- [ ] `flutter pub get` が通る
- [ ] `pubspec.lock` が生成されていることを確認(コミット対象)
- [ ] `analysis_options.yaml` を design.md 手順3 の内容にする

## フェーズ3: アプリ本体

- [ ] `lib/ui/theme/app_theme.dart` を design.md 手順4 の内容で作る
- [ ] `lib/app.dart` を design.md 手順5 の内容で作る
- [ ] `lib/main.dart` を design.md 手順6 の内容で上書きする
- [ ] `lib/domain/.gitkeep` `lib/data/.gitkeep` `lib/state/.gitkeep` を作る
- [ ] `flutter create` が生成したカウンターアプリのコードが `lib/` に残っていないことを確認

## フェーズ4: テスト

- [ ] `test/widget_test.dart` を design.md 手順8 の内容で丸ごと置き換える
- [ ] `flutter test` が通る

## フェーズ5: プラットフォーム設定

- [ ] Android の `minSdk` を `26` にする(design.md 手順9)
- [ ] iOS の最低バージョンを `15.0` にする(`AppFrameworkInfo.plist` と `project.pbxproj` の全箇所)

## フェーズ6: CI とドキュメント

- [ ] `.github/workflows/ci.yml` の暫定ガードを削除する(design.md 手順10。probe step + `if` 5 行のみ)
- [ ] `docs/architecture.md` に判断1・判断2 を反映する(design.md 手順11)

## フェーズ7: 検証

- [ ] `dart format .` を実行する
- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が指摘ゼロで通る
- [ ] `flutter test` が通る
- [ ] `flutter build apk --debug` が通る(失敗した場合は design.md 判断2 のフォールバック条件に該当するか確認する)
