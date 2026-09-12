# タスクリスト: プロジェクトキックオフ(Flutter 化)

<!-- main-edit-ok -->
<!-- テンプレート改修と同種の「司令塔が実装するのが正しい作業」。
     ハーネス層(.claude/ / .husky/ / .github/)の置換は implement-ticket に委託できない
     (委託禁止領域そのもの)ため、脱出弁を置く。 -->

## フェーズ0: 前提確認

- [x] `docs/ideas/initial-requirements.md` の内容を確認
- [x] `docs/` に正式版ドキュメントが無いことを確認
- [x] ブランチ保護の可否を確認(private + Free で 403 → public 化で解決)
- [x] リポジトリを public 化
- [x] Secret scanning + Push protection を有効化
- [x] ルールセット `protect-main` を作成(直接 push 禁止 / PR 必須 / required checks 3 つ / bypass 空)
- [x] テンプレート追従の基準 SHA を `.claude/template-manifest.json` に記録

## フェーズ1: 技術スタックの置換

- [x] TypeScript ツールチェーンを削除(tsconfig / vitest.config / eslint.config / .prettierrc / .prettierignore / src/)
- [x] `package.json` をハーネス専用に縮退(3 依存 + lint-staged を Dart 向けに)
- [x] `.github/workflows/ci.yml` の `quality` ジョブを Flutter 化(ジョブ名は変えない)
- [x] `.github/dependabot.yml` をプロダクト向け(monthly + pub 追加 + グループ化)に
- [x] `.claude/scripts/lint-on-edit.sh` を Dart 向けに
- [x] `.claude/settings.json` の PostToolUse hook と permissions を Dart/Flutter 向けに
- [x] `.claude/hooks/session-start.sh` の npm 前提と対象拡張子を Flutter 向けに
- [x] `.devcontainer/` に Flutter SDK を追加し `name` をプロダクト名に
- [x] `.gitignore` を Flutter の成果物向けに

## フェーズ1.5: MCP・UI ツール

- [x] MCP の追加要否を判断 → 既定の Context7 のみで開始(モバイルアプリのため Playwright MCP は不要、ローカル DB は開発時に外部接続しない)
- [x] `docs/ui-design-guidelines.md` §7「実装への翻訳」表を Flutter / Material 3 向けに記入(プロダクト固有の翻訳表も追加)
- [x] Design プラグイン: ユーザーは導入を承認したが、`claude-plugins-official` マーケットプレイスに `design` が見つからず**未導入**。UI レビューは `code-reviewer` + ガイドライン §6 で代替する(残課題)

## フェーズ2: 永続ドキュメントの作成

- [x] `docs/prd.md`
- [x] `docs/functional-design.md`
- [x] `docs/architecture.md`
- [x] `docs/repository-structure.md`
- [x] `docs/development-guidelines.md`
- [x] `docs/glossary.md`

## フェーズ2.5: スポーク開発構成ルール

- [x] ~~ハブ&スポーク構成の判定~~ (理由: 単一のモバイルアプリでハブ&スポーク構成ではないためスキップ)

## フェーズ3: 実装チケットへの分割

- [x] P0 機能を GitHub Issues に起票(#2〜#9 の 8 枚。`ticket` + `P0` ラベル)
- [x] P1 / P2 は backlog として区別(Issue 未発行。PRD に F9〜F26 として ID つきで記載)

## フェーズ4: ハーネス層

- [x] ハーネスの検証コマンドを Flutter に反映済み(フェーズ1)。Dependabot もプロダクト向けに再チューニング済み
- [x] 委託禁止領域に `lib/data/database/` と `lib/data/migrations/` を追記(`--print-forbidden` で出ることを確認)

## フェーズ5: リポジトリのプロダクト化

- [x] `README.md` をプロダクトの README に書き換え
- [x] `package.json` のメタデータ(name / description / keywords。package-lock.json も同期済み)
- [x] `.devcontainer/devcontainer.json` の `name` を `lastwhen` に
- [x] ライセンス: MIT で公開(LICENSE の Copyright 名義は既に正しく、変更不要)
- [x] `CLAUDE.md` の整合(初回セットアップ節を削除 / 技術スタックを Flutter に / 削除済み資料への参照を除去 / プロジェクト固有ルールを集約)
- [x] `docs/template-dev/` を削除(`CHANGELOG.md` のみ残置。理由はコミットメッセージと `docs/repository-structure.md`)
- [x] テンプレート由来の `.steering/*/` を 47 件すべて削除

## フェーズ6: 開始

- [x] 最初のチケットを提示 → #2(Flutter プロジェクトの初期化)
- [x] Step 0 の残課題を再掲(`CLAUDE_CODE_OAUTH_TOKEN` 未設定 / Design プラグイン未導入)
