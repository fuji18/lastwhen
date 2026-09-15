# 要件: Flutter プロジェクトの初期化とテーマ設定(#2)

## 背景

`/kickoff` でツールチェーンを Flutter に切り替えたが、**Flutter プロジェクトの実体がまだ無い**。
`pubspec.yaml` が存在しないため、CI の `quality` ジョブは暫定ガード(`Check Flutter project presence`)
で全ステップを飛ばしている。`quality` はルールセット `protect-main` の required status check なので、
このガードを外せるようになるまで品質検査が 1 つも働かない。

このチケットで雛形・依存・テーマ・レイヤーディレクトリを用意し、暫定ガードを削除して
CI の 3 ジョブ(`branch-policy` / `harness-integrity` / `quality`)を実質的に緑にする。

## スコープ

| # | 要件 | 根拠 |
| --- | --- | --- |
| R1 | `flutter create` で雛形を生成する(org `com.lastwhen` / project `lastwhen`) | Issue #2 スコープ |
| R2 | プラットフォームは `android/` と `ios/` のみ。`web/` `linux/` `macos/` `windows/` を作らない | Issue #2 受け入れ条件 / `docs/repository-structure.md`「プロジェクト構造」 |
| R3 | `pubspec.yaml` に `docs/architecture.md`「依存関係管理」表どおりの依存を書く | `docs/architecture.md` |
| R4 | `analysis_options.yaml` で `flutter_lints` を継承し、`**/*.g.dart` / `**/*.drift.dart` を除外する | Issue #2 スコープ |
| R5 | `lib/main.dart`(`ProviderScope` + `App` の起動のみ)と `lib/app.dart`(`MaterialApp`・テーマ)を作る | `docs/repository-structure.md`「プロジェクト構造」 |
| R6 | `lib/ui/theme/app_theme.dart` に `ColorScheme.fromSeed` ベースの light / dark テーマを置く。**シード色は 1 つ** | `docs/ui-design-guidelines.md` §7 |
| R7 | `lib/` に空のレイヤーディレクトリ(`domain/` `data/` `state/` `ui/`)を用意する | `docs/architecture.md`「レイヤードアーキテクチャ」 |
| R8 | `flutter create` が生成した英語のサンプルカウンターアプリのコードを残さない | Issue #2 受け入れ条件 |
| R9 | `.github/workflows/ci.yml` の暫定ガード(`Check Flutter project presence` step と各 step の `if: steps.probe.outputs.present`)を削除する | Issue #2 受け入れ条件 |
| R10 | 対応 OS(iOS 15 以上 / Android 8.0 = API 26 以上)をプラットフォーム設定に反映する | `docs/architecture.md`「環境要件」 |

## スコープ外

- 一覧・登録・編集の画面(#5 以降)
- ドメインモデルと経過日数の算出(#3)
- Drift のスキーマとリポジトリ(#4)。**`lib/data/database/` `lib/data/migrations/` にファイルを置かない**
- `test/architecture/layer_dependency_test.dart`(検査対象のレイヤーがまだ空。#3 以降で実体が入ってから書く)
- アプリアイコン・スプラッシュ画面・ストア用アセット
- ストア掲載名の確定(`docs/product-requirements.md`「未決定リスト」#3)。`android:label` / `CFBundleDisplayName` は `flutter create` の生成値のまま置く
- iOS の署名設定(macOS が必要)
- タイポグラフィトークンの作り込み(検証対象の画面が無い。#5 で行を組むときに実値を決める)

## 受け入れ条件

- [ ] `flutter pub get` がエラーなく完了する
- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が指摘ゼロで通る
- [ ] `flutter test` が通る
- [ ] `pubspec.lock` がコミットされている
- [ ] `web/` `linux/` `macos/` `windows/` が存在しない
- [ ] `lib/app.dart` で `useMaterial3: true` が有効
- [ ] light / dark が 1 つのシード色から生成されている
- [ ] カウンターアプリのコードが残っていない
- [ ] `ci.yml` の暫定ガードが削除されている
- [ ] `flutter build apk --debug` が通る(起動可能なことの機械的な代替確認。実機起動は devcontainer で行えない)
