# プロジェクトメモリ

> このファイルは**プロジェクト所有**です。自由に書き換えてください。
> 以下でインポートしている `.claude/rules/*.md` は**テンプレート所有**で、`/sync-template` 実行時に上書きされます。**編集しても同期で失われます。**上書きしたい場合はこのファイルの「プロジェクト固有ルール」節に例外を書いてください(後勝ち)。

## 共通ルール(テンプレート同期対象)

@.claude/rules/spec-driven.md

上記は**メインセッションと全サブエージェントに読み込まれる**共通ルール。司令塔だけが使うルール(モデル運用・コンテキスト管理・レビューの使い分け・ブランチ/チケット運用・計画フェーズ)は `.claude/rules/lead/*.md` にあり、**SessionStart hook がメインセッションにのみ注入する**(サブエージェントに載せると spawn のたびに課金されるため)。

## 技術スタック

- 開発環境: devcontainer(Flutter stable / Node 24 / JDK 17)
- アプリ本体: **Flutter(stable)/ Dart 3**
- UI: Material 3(組み込み)。**追加の UI パッケージを入れない**
- ローカル DB: Drift(SQLite)。状態管理: Riverpod
- 検証コマンド: `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test`
- Node.js v24 は**ハーネス専用**(husky / lint-staged / secretlint)。アプリのビルドには関与しない
- 対応 OS: iOS 15 以上 / Android 8.0(API 26)以上
- **iOS ビルドは devcontainer ではできない**(Xcode が要る)。テスト・解析・Android は devcontainer、iOS は macOS

詳細と選定理由は `docs/architecture.md`。

## プロジェクト固有ルール

<!-- ここはプロジェクト所有。テンプレート同期で消えません。
     追記先の例: MCP の使いどころ(/kickoff フェーズ1.5)、スポーク構成ルールへの参照(/setup-spoke-standards)、
     ハーネス層の検証コマンド(/harness-setup)、共通ルールの上書き・例外。 -->

### MCP の使いどころ

既定の **Context7 のみ**で開始している(`/kickoff` フェーズ1.5 で判断)。

- **引く**: Flutter / Drift / Riverpod の API 仕様が不確かなとき(メジャー更新直後・知識カットオフ以降のリリース)
- **引かない**: 確信があるとき。Dart 言語仕様や一般的な設計の相談
- Playwright MCP は導入しない(モバイルアプリで Web 画面が無い)。DB 系 MCP も導入しない(ローカル SQLite に開発時の外部接続をしない)

### UI を作るときの参照

画面を作る・変えるときは `docs/ui-design-guidelines.md` を読む。**§7「実装への翻訳」表がこのプロジェクトの確定事項**(Flutter / Material 3 / `ColorScheme.fromSeed` / Material Symbols)。

- **追加の UI パッケージを入れない。** Material 3 の組み合わせで表現できないときだけ自前ウィジェットを書く
- 色・余白・タイポは `Theme.of(context)` 経由で取る。ウィジェット内に生の値を書かない
- レビューは §6 のチェックリストを `code-reviewer` に当てる。**Design プラグインは未導入**(マーケットプレイスに見つからなかった)

### 譲らない設計判断(レビューで蒸し返さない)

いずれも `docs/product-requirements.md` / `docs/functional-design.md` に理由つきで記載がある。

| 判断 | 理由 |
| --- | --- |
| 「やった」に確認ダイアログを出さない | 1 タップという中心的価値と正面から衝突する。誤操作は**取り消し**で救う |
| 削除には確認を入れる | 基準は**元に戻せるか**。記録は取り消せるが、削除は蓄積した記録ごと失われる |
| 経過日数は**暦日の差**で数える | 24 時間単位だと朝に記録して翌朝開いたとき「0日前」になり、認識とずれる |
| 日時は UTC で保存する | タイムゾーンの解釈を表示側の 1 箇所に閉じる |
| **楽観的 UI 更新を採らない** | 記録の信頼性が製品価値そのもの。ローカル SQLite なら待っても 100ms 要件を満たせる |
| 通知と目安期間は P1 | 「設定を求めない」という MVP の中心方針と逆を向く |

### 用語

`docs/glossary.md`「表記ゆれの禁止一覧」に従う。コード・ドキュメント・UI 文言で表記を揃える。

**項目**(タスク・アイテムと呼ばない)/ **記録する・やった**(完了する・チェックすると呼ばない)/ **最終実施日** / **経過日数**(経過時間ではない)/ **未実施**(0日前と表示しない)

### Codex への委託禁止領域(パス)

事故のコストが高い領域は Codex に委託せず、**司令塔または `implement-ticket` の fork が直接書く**。対象は 3 系統 —— (1) 実行される実体、(2) コンテキストへ注入される実体、(3) 全層が読む判定データ。

- **このプロジェクト固有のパス**: `lib/data/database/` と `lib/data/migrations/`(Drift のスキーマとマイグレーション。一度出荷した移行は修正できず、失敗はユーザーの記録の全損になる)
- **一覧を出す**: `bash .claude/scripts/delegate-codex.sh --print-forbidden`(プロジェクト固有パスを含む全量)
- **単一ソースは 2 系統**: 汎用項目 = `delegate-codex.sh` の `FORBIDDEN_PATHS` / プロジェクト固有パス = `AGENTS.md` §4 の `<!-- kickoff:delegation-forbidden-paths -->` マーカー内。**追加・変更はこの 2 箇所だけを直す**(出口検査が委託の開始時に両方を抽出してマージし、前後の内容ハッシュ差分を `status=failed` / `exit 2` で止める)
- **振り分けの判断材料**(パス一覧と 1 行の理由)は `.claude/rules/lead/delegation-policy.md`
- **機密の送信禁止(`.claude/codex-denylist.txt`)とは別の層。** denylist は該当ファイルが存在するだけで委託を止めるフェイルクローズ検査、こちらは司令塔が「どのチケットを渡すか」を決める振り分け判断

## ディレクトリ構造(要点)

- `docs/ideas/`: 下書き・アイデア(自由形式。`/setup-project` が自動で読み込む)。プロジェクト開始の起点は `initial-requirements.md`
- `docs/template-dev/`: **`CHANGELOG.md` のみ**。ハーネス(`.claude/` / `.husky/` / `.codex/` / `.github/workflows/` / `AGENTS.md`)を変更した PR で、CI の `record-hygiene` が更新を要求する。ディレクトリごと消せない理由は `docs/repository-structure.md`「特殊ディレクトリ」節
- `docs/`: 正式版の永続ドキュメント6つ(PRD / 機能設計 / 技術仕様 / リポジトリ構造 / 開発ガイドライン / 用語集)。基本設計を記述し頻繁には更新しない「北極星」
  - `docs/ui-design-guidelines.md`: 上記6つとは別枠のテンプレート同梱・横断ガイド(スタック非依存の UI 品質基準)。画面/UI を作る場合に参照し、**§7「実装への翻訳」表は Flutter / Material 3 で記入済み**(このプロジェクトの確定事項)
  - `docs/ui-design-request-template.md`: AI に画面デザインを依頼するプロンプト雛形(ガイドライン §11 の単体版・記入例つき)
- `lib/`: アプリ本体。`domain/` / `data/` / `state/` / `ui/` の 4 レイヤー。**依存は一方向で `domain/` は何にも依存しない**(`docs/repository-structure.md`)
- `test/`: テスト。`lib/` と同じ階層を写す
- 実装チケット: GitHub Issues で管理(リポジトリ内にチケットファイルは置かない)
- `.claude/rules/`: テンプレート所有の共通ルール(全エージェント共通。上記でインポート)。`/sync-template` の同期対象
  - `.claude/rules/lead/`: 司令塔専用ルール(SessionStart hook が注入。サブエージェントには載らない)
- `.claude/docs/`: プロジェクト開始後も参照が続く判断ガイド(MCP 導入の判断 / serena 再導入の目安と手順)。テンプレート所有だが `/sync-template` で更新されても内容は参照ガイドのまま
- `.steering/`: 作業単位の計画とタスクリスト。作業ごとに新規作成し、**履歴としてコミットして保持する**

詳細は `README.md` を参照。

## 開発プロセス

### 日常的な使い方

基本は普通に会話で依頼する(ドキュメント編集・調査・相談など)。定型フローのみスラッシュコマンドを使う(各コマンドの説明はコマンド一覧に注入済み。早見表は `README.md` の「コマンド早見表」を参照)。

**ポイント**: スペック駆動開発の詳細を意識する必要はありません。Claude Codeが適切なスキルを判断してロードします。

### テンプレート更新の取り込み

テンプレート(`claude-code-template`)側で共通ルール・コマンド・スキル・ハーネスが更新されたら、**`/sync-template`** で差分を取り込む。同期対象・除外は `.claude/template-manifest.json` が単一ソース。

- 月次の `template-update-check` ワークフロー(毎月1日)が、テンプレートに未取り込みの更新があれば Issue を立てる
- `[manual]` 印の変更はプロジェクト側の対応が要るため、`/sync-template` の提示に従って個別に判断する
