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

- [ ] `docs/prd.md`
- [ ] `docs/functional-design.md`
- [ ] `docs/architecture.md`
- [ ] `docs/repository-structure.md`
- [ ] `docs/development-guidelines.md`
- [ ] `docs/glossary.md`

## フェーズ2.5: スポーク開発構成ルール

- [x] ~~ハブ&スポーク構成の判定~~ (理由: 単一のモバイルアプリでハブ&スポーク構成ではないためスキップ)

## フェーズ3: 実装チケットへの分割

- [ ] P0 機能を GitHub Issues に起票(`ticket` + 優先度ラベル)
- [ ] P1 / P2 は backlog として区別

## フェーズ4: ハーネス層

- [ ] `/harness-setup` 相当の確認(フェーズ1 で検証コマンドを反映済みか)
- [ ] 委託禁止領域のプロジェクト固有パスを `AGENTS.md` §4 のマーカー内に追記

## フェーズ5: リポジトリのプロダクト化

- [ ] `README.md` をプロダクトの README に書き換え
- [ ] `package.json` のメタデータ(フェーズ1 と同時)
- [ ] `.devcontainer/devcontainer.json` の `name`(フェーズ1 と同時)
- [ ] ライセンス方針をユーザーに確認して反映
- [ ] `CLAUDE.md` の整合(初回セットアップ節の削除・技術スタック注記の削除・README 参照の整合)
- [ ] `docs/template-dev/` の削除を提案
- [ ] テンプレート由来の `.steering/*/` を削除(**auto mode の分類器にブロックされたため要ユーザー判断**)

## フェーズ6: 開始

- [ ] 最初のチケットを提示
- [ ] Step 0 の残課題を再掲(`CLAUDE_CODE_OAUTH_TOKEN` 未設定)
