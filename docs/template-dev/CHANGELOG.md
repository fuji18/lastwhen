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

## 2026-09-25

- **`lib-forbidden.sh` の抽出を「箇条書きの説明ダッシュより前のコードスパン」に狭め、規約違反を警告するようにした**(#28)。
  - 以前は過剰(地の文の語が実在パスと衝突して誤爆)・過少(バックティックなしのパスが静かに保護から外れる)の両方が無通知だった
  - `AGENTS.md` §4 の地の文のバックティックを外した(`--print-forbidden` に `npx` などが混ざっていた)
  - **`lib-forbidden.sh` はテンプレート所有**。上流(`fuji18/claude-codex-template`)に同じ修正が入るまで、`/sync-template` で旧版に戻りうる

## 2026-09-23

- **`AGENTS.md` §4 スコープガードを「チケット単位の着手」と「範囲外の前倒し」に分けた**(#21 の申し送り)。
  旧文言「P0 以外を実装しない。P1/P2 の前倒しは禁止」は MVP 完了後の P1 チケットも区別せず、
  #21(P1・P0 全件 closed 後)の impl 委託が**ファイル変更なしの判断待ち**で停止した
  - 委託先は sandbox でネットワークが無く、P0 の完了状況(Issue の状態)を確認できない。
    確認できるのは司令塔だけなので、**`design.md` が ready で渡された時点で着手承認済み**とした
  - 前倒しの禁止は残す。対象を「チケット・`design.md` が P1/P2・将来対応・範囲外とする機能」に絞った
  - `.claude/rules/spec-driven.md` のスコープガード(P1/P2 の前倒しはユーザー承認を得てから)とは矛盾しない。
    承認の判断は司令塔が計画フェーズで下し、委託先には結果だけが渡る

## 2026-09-17

- **委託先の検証コマンドを sandbox で成立する形に差し替え**(#6 の申し送り)。
  `AGENTS.md` §2 を `flutter analyze` / `flutter test` から
  **キャッシュ内 Dart SDK の直叩き**(`"$DART" analyze --fatal-infos` /
  `"$DART" format`)へ変更し、**テストは委託先で実行しない**ことを明記した
  - 原因は 2 つあり、別々の制約だった。**(A)** `flutter` / `dart` のラッパーは
    起動のたびに SDK ルートの `bin/cache/` へ `engine.stamp` / `engine.realm` /
    `.upgrade_lock` を書く(`bin/internal/shared.sh` の `upgrade_flutter` と
    `update_engine_version.sh`)。SDK はワークツリー外にあるため `workspace-write` が
    書き込みを拒否し、**ツールが起動する前に落ちていた**。ファイル権限の問題ではない
    (`/opt/flutter` は `vscode` 所有で書き込み可)。**(B)** `flutter test` は
    テストランナーとの通信に `127.0.0.1` のサーバーソケットを作るが、sandbox は
    `network_access = false`。**ループバックだけを許可する設定は codex-cli 0.154.0 に無い**
    (`loopback` / `allow_local` / `allowed_domains` いずれも非対応)
  - この 2 つのせいで **impl 委託が毎回 `status=failed` で返っていた**(#5 は B、#6 は A で停止)。
    成果物の問題ではないのに失敗として返るため、検収の判断材料として機能していなかった
  - `dart analyze --fatal-infos` が代替になることは実測で確認した。`flutter analyze` と
    同じ結果を返し、`/opt/flutter` にも `$HOME` にも一切書き込まない。`analysis_options.yaml`
    を読むので `flutter_lints` の Flutter 固有ルールも拾う(`use_build_context_synchronously`
    違反を仕込んで検出を確認)
  - **B は直していない。** `network_access = true` にすれば `flutter test` は動くが、
    委託先に全ネットワークが開き「新規依存の追加を伴うタスクは委託対象外」という
    設計前提が崩れる。テストはホスト(`/check` / CI)の担当とする分担に倒した

- **`.codex/config.toml` に `writable_roots = ["/opt/flutter"]` を追加**(同上)。
  `flutter` 固有のサブコマンドがどうしても要るとき用の保険
  - **既定の経路はこれに依存しない。** 上の Dart SDK 直叩きだけで format と analyze は通る
  - 引き受けるリスク: 委託先が SDK を書き換えられる。SDK は次回以降ホスト上でも実行されるため、
    **ワークツリー外へ出る唯一の書き込み経路**になる。疑う理由があるときは
    `git -C /opt/flutter status` で確かめる(Flutter SDK は git チェックアウト)

- **司令塔側のルールに分担を明記**(同上)。`.claude/rules/lead/delegation-policy.md` と
  `CLAUDE.md`「Codex への委託禁止領域」節に、**委託先はテストを回さない / テストは検収側が回す**
  のが正規の分担であって委託の失敗ではない、と 1 項目ずつ追記した

## 2026-09-16

- **`AGENTS.md` の verify-probe を Flutter 用に差し替え**(#5)。
  `exists node_modules/.bin/eslint` → `exists .dart_tool/package_config.json`
  - テンプレート既定(Node.js / TypeScript)のまま残っていたもの。このプロジェクトに
    eslint は入らないため、**プローブは永久に失敗し、`delegate-codex.sh impl` が
    入口で必ず止まっていた**(「依存が未インストールの可能性があります」で exit)。
    #5 の実装委託で初めて踏んだ
  - `.dart_tool/package_config.json` は `flutter pub get` の生成物で、Dart における
    `node_modules/` の等価物。存在確認だけでプロセスを起動しない `exists` 形式は据え置き

- **`AGENTS.md` §2 の検証コマンド表を npm から Flutter へ差し替え**(#5)。
  `npm run lint` / `npm run typecheck` / `npm test` / `npm run format:check` を
  `flutter analyze --fatal-infos` / `flutter test` /
  `dart format --output=none --set-exit-if-changed .` に置換した
  - 委託先が読む唯一の検証手順がこの表。プローブだけ直しても、Codex は存在しない
    npm スクリプトを叩いて「検証した」と報告しうる状態だった
  - Node.js はハーネス専用(husky / lint-staged / secretlint)であることを表の前に明記した。
    §1 の `npm ci`(husky の復旧手順)は Node ハーネスの話なので**変更していない**
  - プローブの形式解説(許可される形式の一覧)はテンプレート所有の汎用説明なので触っていない

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
