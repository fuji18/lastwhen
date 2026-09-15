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

## 2026-09-15

- **`ci.yml` の `quality` ジョブから暫定ガードを削除**(#2)。`Check Flutter project presence`
  step と、各 step に付いていた `if: steps.probe.outputs.present == 'true'`(5 箇所)を撤去した
  - このガードは `pubspec.yaml` が無い間だけ検査を素通しさせるためのもので、`quality` が
    ルールセット `protect-main` の required status check である以上、これが無いと
    「Flutter プロジェクトを初期化する PR 自体がマージできない」デッドロックになっていた
  - #2 で `pubspec.yaml` が入ったため役目を終えた。**削除したのはこの 6 箇所だけ**で、
    secretlint 系の step(`Setup Node.js` 以降)は元から `if` を持たず、無変更

- **Codex CLI 用のハーネス層を追加**(`.codex/agents/` / `.codex/hooks/` / `.codex/hooks.json` /
  `.agents/skills/`)。`.claude/` の subagent 定義・SessionStart hook・スキル/コマンドを
  Codex が読める形式(TOML / `AGENTS.md` 系のスキル)へ写像したもの
  - `.codex/hooks.json`: PreToolUse / PostToolUse は `.claude/settings.json` と同じ判定
    スクリプト(`.claude/scripts/*.sh`)を直接指す。**判定の実体を二重化しない**ため
  - ただし SessionStart だけは `.codex/hooks/session-start.sh` が
    `.claude/hooks/session-start.sh` の**バイト同一のコピー**になっている(未解消)。
    片方だけ直すと静かに乖離するので、`.claude/` 側を指すよう寄せるか、差分を持たせる
    理由を明記するかを別途決める
  - `.codex/config.toml` に Context7 の MCP サーバ定義を追加。`network_access = false` は
    Codex 自身のシェル実行に効くもので、npx で起動する MCP サーバは対象外である旨を注記
  - 生成時の一括置換で壊れていた参照を修正(`.Codex/` → `.claude/` / `Codex-opus-5` →
    `claude-opus-5` / `Codex/*` ブランチ → `claude/*` / 属性表記のリンク先など)
  - `.codex/hooks.json` の SessionStart に埋まっていたホスト固有の絶対パスを
    `$CLAUDE_PROJECT_DIR` 相対へ修正。devcontainer では解決できなかった

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
- 委託禁止領域に**プロジェクト固有パス**を追加(`AGENTS.md` §4 のマーカー内)。
  `lib/data/database/` と `lib/data/migrations/` —— Drift のスキーマとマイグレーションで、
  一度出荷した移行は修正できず、失敗がユーザーの記録の全損になる
- チケット用ラベルを作成(`ticket` / `P0` / `P1` / `P2` / `in-progress` /
  `delegate:codex` / `no-changelog` / `no-decision-record`)
- **CI の `quality` ジョブに暫定ガードを追加。** `pubspec.yaml` が無い間、Flutter 系の
  step を飛ばす。`quality` はルールセットの required status check なので、
  Flutter プロジェクト未初期化の状態で失敗させると「初期化する PR 自体がマージできない」
  デッドロックになる。**secretlint は Flutter の有無と無関係に常に走る**
  (機密検出を暫定ガードで飛ばさない)。ガードの削除は #2 の受け入れ条件に入れてある
