# タスクリスト: アプリアイコンとロゴの差し替え(Issue #35)

> 設計は `design.md`。判断番号はそちらを参照。**新規依存の追加を含むため Codex に委託しない。**
> 入力画像 `assets/branding/*` は用意済み。加工・再生成しない。

## フェーズ1: 依存と生成

- [x] 1. `flutter pub add --dev flutter_launcher_icons flutter_native_splash` を実行し、`pubspec.yaml` の位置とコメントを整える(判断1)
- [x] 2. `flutter_launcher_icons.yaml` を作り、`dart run flutter_launcher_icons` を実行する(判断2)
- [x] 3. `flutter_native_splash.yaml` を作り、`dart run flutter_native_splash:create` を実行する。`lib/main.dart` が変わっていれば戻す(判断3)
- [x] 4. 表示名を `LastWhen` に揃える(生成の後に行う)(判断4)

## フェーズ2: ドキュメント

- [x] 5. `docs/architecture.md` の 2 つの表に行を足す(判断5)
- [x] 6. `docs/repository-structure.md` のツリーと設定ファイル表を更新する(判断5)

## フェーズ3: 検証

- [x] 7. format / analyze / test を通す(判断6)
- [x] 8. `flutter build apk --debug` を通し、`AppIcon.appiconset/Contents.json` に 1024 のエントリがあることを確認する(判断6)
- [x] 9. `git status --short` が判断7 の範囲に収まっていることを確認する(判断7)

## 申し送り

- 判断待ち 1 回: `flutter_launcher_icons` による `project.pbxproj` の書き換えが判断7 の範囲外だった。生成物として受け入れ、design.md 判断7 に追記した
- レビュー(code-reviewer)の Minor 3 件はいずれも修正不要(版の下限と lock の乖離 / `cli_util` の降格 = `build_runner` を再実行して差分なし / iOS の旧世代アイコンサイズ = ツール既定)
- **iOS は未検証。** macOS で実機・シミュレータのアイコンとスプラッシュを確認する
- 生成ツールで生成物を作り直すときは、判断7 の範囲(`project.pbxproj` の 1 設定を含む)が再び出るのが正常
