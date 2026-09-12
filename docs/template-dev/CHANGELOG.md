# ハーネス変更ログ

このリポジトリの**ハーネス層**(`.claude/` / `.husky/` / `.codex/` / `.github/workflows/` /
`AGENTS.md`)への変更を記録する。CI の `record-hygiene` ジョブが、これらを変更した PR で
このファイルの更新を機械的に要求する(判定の実体は `.claude/scripts/check-record-hygiene.sh`、
逃げ道ラベルは `no-changelog`)。

> **なぜ `docs/template-dev/` に残っているか**: `/kickoff` はこのディレクトリの削除を勧めるが、
> `check-record-hygiene.sh` がこのパスを直書きしているため、丸ごと消すとハーネスを触る PR が
> 毎回赤くなる。スクリプトはテンプレート所有(`/sync-template` で上書きされる)なので、
> スクリプト側を直すのではなくこのファイルを残す形で整合を取っている。
> 記入例やコストモデルなど、テンプレート開発向けの資料は削除済み(原本はテンプレートリポジトリにある)。

## 2026-09-12

- **技術スタックを Flutter / Dart に置換**(`/kickoff` フェーズ1)。
  - `package.json` をハーネス専用(husky / lint-staged / secretlint)に縮退。
    TypeScript ツールチェーンは削除
  - `.github/workflows/ci.yml` の `quality` ジョブを Flutter 化。
    **ジョブ名は変更していない** —— ルールセットの required status check が context 名で紐づくため
  - `.claude/scripts/lint-on-edit.sh` を Dart 向けに書き換え。Flutter SDK 未導入なら黙って
    exit 0 する(フェイルオープンを維持)
  - `.claude/settings.json`: PostToolUse の整形 hook を `dart format`(`*.dart` のみ)に、
    `permissions.allow` を `flutter:*` / `dart:*` に置換
  - `.claude/hooks/session-start.sh`: リモート環境の依存インストールに `flutter pub get` を追加。
    serena 規模検知の対象拡張子を `*.dart` に
  - `.devcontainer/`: Flutter SDK を `post_create.sh` で導入(公式 feature が無く、コミュニティ
    feature への依存を増やさないため)。Node feature は残す(Claude Code 本体・Codex CLI・
    MCP・husky がすべて npm 経由)
  - `post_create.sh` の Playwright ステップをハーネス依存の導入(`npm ci`)に差し替え。
    これが無いと `core.hooksPath` が設定されず `.husky/` のガードレールが一切動かない
  - `.github/dependabot.yml` をプロダクト向け(monthly + `pub` 追加 + minor/patch グループ化)に
- **リポジトリを public 化し、ルールセット `protect-main` を作成。**
  直接 push 禁止 / PR 必須 / force push・削除禁止 / required status checks
  (`branch-policy`・`harness-integrity`・`quality`)/ bypass list は空。
  Secret scanning と Push protection も有効化
- テンプレート追従の基準 SHA を `.claude/template-manifest.json` に記録
- テンプレート由来の `.steering/*/`(47 件)と `docs/template-dev/` の資料を削除
