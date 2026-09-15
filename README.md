# 最後にいつ(LastWhen)

「最後にやったのはいつだっけ?」を **1 タップで記録・確認**できる生活管理アプリ。

美容院、歯医者、エアコン掃除、歯ブラシ交換、布団干し —— 毎日ではないが定期的に行う生活行動は、
やった記憶はあっても「いつだったか」が抜け落ちる。このアプリは項目を並べ、やった日に 1 タップ
押すだけ。開けば経過日数が並ぶ。**予定を管理しない**ことで軽さを得ている。

## 特徴

- **1 タップで記録** —— 確認ダイアログも日付入力も挟まない。誤操作は取り消しで救う
- **経過日数が主役** —— 画面で最も大きいのは日付ではなく「42日前」。判断に使うのはこちら
- **オフライン完結** —— アカウント登録なし。データは端末内の SQLite にだけ保存する
- **設定を求めない** —— 項目名を入れるだけで使い始められる

## 開発状況

MVP(P0 機能)を実装中。進捗は [Issues](../../issues?q=is%3Aissue+label%3Aticket) を参照。

| フェーズ | 内容 | チケット |
| --- | --- | --- |
| 1 | 基盤(プロジェクト初期化・ドメイン層・データ層) | #2 #3 #4 |
| 2 | 縦串(一覧・登録・記録・編集と削除) | #5 #6 #7 #8 |
| 3 | 非機能要件の仕上げ(アクセシビリティ・パフォーマンス) | #9 |

## 技術スタック

| 分類 | 技術 |
| --- | --- |
| フレームワーク | Flutter(stable)/ Dart 3 |
| UI | Material 3(組み込み。追加の UI パッケージを入れない) |
| ローカル DB | Drift(SQLite) |
| 状態管理 | Riverpod |
| 対応 OS | iOS 15 以上 / Android 8.0(API 26)以上 |

詳細と選定理由は [`docs/architecture.md`](docs/architecture.md)。

## セットアップ

devcontainer で開くと、Flutter SDK・Node(ハーネス用)・JDK 17・Claude Code・Codex CLI が
自動で入る。

```bash
# 1. Dart 依存を取得する
flutter pub get

# 2. Drift の生成物を作る(スキーマを変えたときも同じ)
dart run build_runner build --delete-conflicting-outputs

# 3. 検証が通ることを確かめる
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

**git hook が効いているかを確認する**:

```bash
git config core.hooksPath   # .husky/_ が返れば有効
```

空なら `npm ci` を実行する。これが無いと保護ブランチ検査と機密検出が動かない。

> **iOS のビルドは devcontainer ではできない。** Linux コンテナに Xcode を置けないため。
> テスト・静的解析・Android ビルドは devcontainer で行い、iOS のビルドと実機確認は
> macOS 上で別途行う。

## ドキュメント

| ファイル | 内容 |
| --- | --- |
| [`docs/product-requirements.md`](docs/product-requirements.md) | 何を作るか。機能の受け入れ条件と非機能要件 |
| [`docs/functional-design.md`](docs/functional-design.md) | どう動くか。データモデル・経過日数の算出・エラー処理 |
| [`docs/architecture.md`](docs/architecture.md) | 何で作るか。依存の選定理由・マイグレーション方針 |
| [`docs/repository-structure.md`](docs/repository-structure.md) | どこに置くか。レイヤー構成と命名規則 |
| [`docs/development-guidelines.md`](docs/development-guidelines.md) | どう進めるか。コーディング規約・Git 運用・レビュー基準 |
| [`docs/glossary.md`](docs/glossary.md) | 用語集。**表記ゆれの禁止一覧**を含む |
| [`docs/ui-design-guidelines.md`](docs/ui-design-guidelines.md) | UI 品質基準。§7 に Flutter への翻訳表 |

## 開発フロー

```
/next-ticket           次のチケットを選び、design.md まで書く
  ↓
実装(委託)            Codex または implement-ticket の fork
  ↓
/check                 lint・解析・テストを一括実行
  ↓
code-reviewer          スペック整合とコード品質のレビュー
  ↓
/commit → push → PR    Closes #N を書く
  ↓
CI(3 ジョブ)+ Claude 自動レビュー
  ↓
マージ → /clear → 次のチケットへ
```

基本は普通に会話で依頼する(ドキュメント編集・調査・相談など)。定型フローのみスラッシュ
コマンドを使う。

### コマンド早見表

| コマンド | タイミング | 内容 |
| --- | --- | --- |
| `/next-ticket` | 日常 | 次のチケットに着手する |
| `/add-feature [機能]` | 日常 | 機能追加の全自動フロー |
| `/fix-issue [番号]` | 日常 | Issue 修正と PR 作成 |
| `/check` | 日常 | 品質チェック一括実行と自動修正 |
| `/commit` | 日常 | 適切な粒度でのコミット |
| `/resume-work` | 日常 | 中断した作業の再開 |
| `/status` | 随時 | 現在地と次の一手 |
| `/sync-docs` | 定期 | 実装と `docs/` の同期 |
| `/review-docs [パス]` | 随時 | ドキュメントの詳細レビュー |
| `/sync-template` | 随時 | テンプレートの更新差分を取り込む |

## ブランチ運用

GitHub Flow(`main` 単一)。**単一ソースは `.claude/branch-policy.json`。**

`main` は GitHub のルールセット `protect-main` で保護されている:

- 直接 push の禁止 / PR 必須 / force push と削除の禁止
- required status checks: `branch-policy` / `harness-integrity` / `quality`
- **bypass list は空**(管理者も迂回できない)

ローカルでも 3 層のガードレールが効く(`.husky/pre-commit` と `.husky/prepare-commit-msg` は
ベンダー非依存で、Codex・手動 git・他ツールにも効く)。

## CI

PR(全ベース)と `main` への push で 3 ジョブが走る。

| ジョブ | 内容 |
| --- | --- |
| `branch-policy` | PR の base とブランチ名の検証 |
| `harness-integrity` | ハーネスの自壊検知・委託禁止領域の記述ずれ検査 |
| `quality` | `dart format` / `flutter analyze` / `flutter test` / secretlint |

`main` 向け PR のオープン時に Claude の自動レビューが 1 回だけ走る
(Actions シークレット `CLAUDE_CODE_OAUTH_TOKEN` が必要)。

## ディレクトリ構造

```
lib/        アプリ本体。domain / data / state / ui の 4 レイヤー
test/       テスト。lib/ と同じ階層を写す
docs/       永続ドキュメント(北極星ドキュメント群)+ UI ガイドライン
.steering/  作業単位の計画とタスクリスト(履歴としてコミットする)
.claude/    Claude Code のハーネス設定
.husky/     git hook(ベンダー非依存のガードレール)
```

詳細は [`docs/repository-structure.md`](docs/repository-structure.md)。

## ライセンス

MIT License。詳細は [`LICENSE`](LICENSE) を参照。
