# リポジトリ構造定義書 (Repository Structure Document)

## プロジェクト構造

```
lastwhen/
├── lib/                      # アプリ本体(Dart)
│   ├── main.dart             # エントリポイント。ProviderScope と App の起動のみ
│   ├── app.dart              # MaterialApp・テーマ・ルーティング
│   ├── domain/               # ドメインレイヤー(純 Dart。Flutter に依存しない)
│   ├── data/                 # データレイヤー(Drift・リポジトリ実装)
│   ├── state/                # 状態管理レイヤー(Riverpod Notifier・表示モデル)
│   └── ui/                   # UI レイヤー(画面・ウィジェット)
├── test/                     # テスト(lib/ と同じ階層を写す)
├── android/                  # Android のプラットフォームコード
├── ios/                      # iOS のプラットフォームコード
├── docs/                     # 永続ドキュメント(この文書を含む 6 つ + UI ガイド)
│   ├── ideas/                # 下書き・アイデア(自由形式)
│   └── template-dev/         # ハーネス変更ログのみ(理由は下記「特殊ディレクトリ」)
├── .steering/                # 作業単位の計画とタスクリスト(履歴としてコミットする)
├── .claude/                  # Claude Code のハーネス設定
├── .codex/                   # Codex 併用時の設定
├── .harness/                 # ハーネスの運用状態と実測ログ
├── .husky/                   # git hook(ベンダー非依存のガードレール)
├── .github/                  # CI ワークフローと Dependabot
├── .devcontainer/            # 開発環境の定義
├── pubspec.yaml              # Dart/Flutter の依存定義
├── pubspec.lock              # 依存解決の固定(追跡する)
├── analysis_options.yaml     # lint ルール
├── package.json              # ハーネス専用(husky / lint-staged / secretlint)
├── AGENTS.md                 # Codex 向けの指示。委託禁止領域の定義を含む
└── CLAUDE.md                 # Claude Code 向けのプロジェクトメモリ
```

## ディレクトリ詳細

### lib/ (ソースコードディレクトリ)

レイヤーごとにトップレベルのディレクトリを分ける。**依存の向きは
`ui → state → domain ← data` の一方向**で、`domain` は誰にも依存しない。

#### lib/domain/

```
domain/
├── item.dart              # Item エンティティと ItemId
├── elapsed_days.dart      # 経過日数の算出と ElapsedLabel
├── clock.dart             # Clock 抽象と SystemClock 実装
├── item_name.dart         # 項目名のバリデーション(トリム・長さ)
└── item_repository.dart   # リポジトリのインターフェース(実装は data/ に置く)
```

- **依存してよいもの**: Dart 標準ライブラリのみ
- **依存してはいけないもの**: Flutter、Drift、Riverpod
- **ここに置くもの**: ビジネスルールと、それを表す型
- **ここに置かないもの**: 表示用の文字列整形(`ui/` の責務)、SQL(`data/` の責務)

> リポジトリの**インターフェースをここに置く**のは依存性逆転のため。
> `state/` は `domain/item_repository.dart` だけを見て、Drift の存在を知らない。

#### lib/data/

```
data/
├── database/
│   ├── app_database.dart      # Drift の DB 定義・テーブル・schemaVersion
│   └── app_database.g.dart    # 生成物(追跡する)
├── migrations/
│   └── migrations.dart        # MigrationStrategy
└── item_repository_impl.dart  # ItemRepository の Drift 実装
```

- **依存してよいもの**: `domain/`、Drift、`path_provider`
- **依存してはいけないもの**: `state/`、`ui/`、Flutter のウィジェット
- **`database/` と `migrations/` は Codex への委託禁止領域**(`AGENTS.md` §4)

#### lib/state/

```
state/
├── providers.dart           # Riverpod の Provider 定義(DB・リポジトリ・Clock)
├── item_list_notifier.dart  # 一覧の状態と操作(追加・記録・取り消し・削除)
└── item_view.dart           # UI 向けの表示モデル
```

- **依存してよいもの**: `domain/`、`data/`(Provider の組み立てのみ)、Riverpod
- **依存してはいけないもの**: `ui/`、`BuildContext`、`Widget`
- **理由**: Flutter のウィジェットツリーなしでテストできる状態に保つ

#### lib/ui/

```
ui/
├── theme/
│   └── app_theme.dart        # ColorScheme.fromSeed とタイポグラフィ
├── screens/
│   ├── item_list_screen.dart # 一覧(F1・F3・F5)
│   ├── item_add_screen.dart  # 新規登録(F2)
│   └── item_edit_screen.dart # 編集・削除(F6・F7)
└── widgets/
    ├── item_row.dart         # 一覧の 1 行。経過日数を最大要素として組む
    ├── done_button.dart      # 「やった」ボタン(56dp 以上)
    └── empty_state.dart      # 項目 0 件のときの表示
```

- **依存してよいもの**: `state/`、Flutter、Material 3
- **依存してはいけないもの**: `data/`、Drift の生成型、`DateTime.now()` の直呼び
- **色・余白・タイポは `Theme.of(context)` 経由**で取る。ウィジェット内に生の値を書かない

### test/ (テストディレクトリ)

`lib/` の階層をそのまま写す。ファイル名は対象ファイル名 + `_test.dart`。

```
test/
├── domain/
│   ├── elapsed_days_test.dart   # 境界条件(日またぎ・うるう年・夏時間・時計巻き戻し)
│   └── item_name_test.dart      # バリデーション
├── state/
│   └── item_list_notifier_test.dart  # フェイクリポジトリ + 固定 Clock
├── data/
│   └── item_repository_impl_test.dart # インメモリ DB での CRUD と移行
├── ui/
│   └── item_list_screen_test.dart     # ウィジェットテスト(主要導線)
└── support/
    ├── fake_clock.dart          # 任意の時刻を返す Clock
    └── fake_item_repository.dart
```

- **`support/` はテスト用のフェイクとヘルパ置き場**。本体のコードから参照しない
- **統合テストは `data/` のテストとして書く**。専用ディレクトリを分けない
  (MVP の規模では分割のコストが利得を上回る)

### docs/ (ドキュメントディレクトリ)

```
docs/
├── product-requirements.md   # 何を作るか(PRD)
├── functional-design.md      # どう動くか(機能設計)
├── architecture.md           # 何で作るか(技術仕様)
├── repository-structure.md   # どこに置くか(この文書)
├── development-guidelines.md # どう進めるか(開発ガイドライン)
├── glossary.md               # 用語集
├── ui-design-guidelines.md   # UI 品質基準(スタック非依存 + §7 の翻訳表)
├── ui-design-request-template.md
├── ideas/                    # 下書き。initial-requirements.md が起点
└── template-dev/
    └── CHANGELOG.md          # ハーネス変更ログ(CI が更新を要求する)
```

上 6 つは「北極星」であり、頻繁には更新しない。実装との乖離は `/sync-docs` で検出する。

## ファイル配置規則

### ソースファイル

| 判断 | 置き場所 |
| --- | --- |
| ビジネスルール・型・純粋な計算 | `lib/domain/` |
| 永続化・SQL・スキーマ | `lib/data/` |
| 画面の状態・非同期の調停・入力検証 | `lib/state/` |
| 描画・タップの受付 | `lib/ui/` |
| 2 画面以上で使うウィジェット | `lib/ui/widgets/` |
| 1 画面でしか使わないウィジェット | その画面ファイル内に private クラスとして置く |

> **「共通だから」で `ui/widgets/` に上げない。** 2 箇所目の利用が現れてから移す。
> 先回りの共通化は、要件が分岐したときに条件分岐まみれのウィジェットを生む。

### テストファイル

- 対象ファイルと同じ相対パスに `_test.dart` を付けて置く
- 1 テストファイルが 1 対象ファイルに対応する。複数対象をまとめない

### 設定ファイル

| ファイル | 役割 |
| --- | --- |
| `pubspec.yaml` | Dart/Flutter の依存とアセット |
| `analysis_options.yaml` | lint ルール。`flutter_lints` を継承して追加ルールを書く |
| `package.json` | **ハーネス専用**。アプリのビルドに関与しない |
| `.claude/settings.json` | hook と permissions。**Codex への委託禁止領域** |
| `.claude/branch-policy.json` | ブランチ戦略の単一ソース。**委託禁止領域** |

## 命名規則

### ディレクトリ名

- 小文字のスネークケース(`item_list`)。Dart の慣習に合わせる
- 単数形と複数形は意味に従う: レイヤーは単数(`domain`・`data`)、
  同種のものの集まりは複数(`screens`・`widgets`・`migrations`)

### ファイル名

- 小文字のスネークケース + `.dart`(`item_list_screen.dart`)
- **1 ファイル 1 公開型**を原則とし、ファイル名はその型のスネークケース表記にする
- 生成物は `<元のファイル名>.g.dart` / `.drift.dart`。手で編集しない

### テストファイル名

- `<対象ファイル名>_test.dart`
- テストグループ名は日本語で「何を検証しているか」を書く
  (例: `group('経過日数の算出', ...)` / `test('日付をまたぐと 昨日 になる', ...)`)

### クラス・変数名

| 対象 | 規則 | 例 |
| --- | --- | --- |
| クラス・型・enum | アッパーキャメル | `ItemListNotifier` / `ElapsedLabel` |
| 変数・関数・パラメータ | ローワーキャメル | `lastDoneAt` / `elapsedDays` |
| 定数 | ローワーキャメル | `maxItemNameLength` |
| private | 先頭にアンダースコア | `_buildRow` |

## 依存関係のルール

### レイヤー間の依存

| from → to | 可否 |
| --- | --- |
| `ui` → `state` | ✅ |
| `ui` → `domain` | ✅(表示モデルが持つ型の参照のみ) |
| `ui` → `data` | ❌ |
| `state` → `domain` | ✅ |
| `state` → `data` | ⚠️ Provider の組み立てのみ。ロジックからは呼ばない |
| `domain` → いずれか | ❌(何にも依存しない) |
| `data` → `domain` | ✅ |
| `data` → `state` / `ui` | ❌ |

**この規則の検査**: `analysis_options.yaml` に import 制限のルールを書く。
MVP の規模ではレビューでも追えるが、レイヤー違反は静かに増えるため機械化する。

### モジュール間の依存

- 循環参照を作らない。Dart は許容するが、テストの分離が崩れる
- `domain` 内のファイル同士は依存してよい(`item.dart` → `item_name.dart` 等)
- **`main.dart` と `app.dart` にロジックを書かない**。起動と配線のみ

## スケーリング戦略

### 機能の追加

新機能は「どのレイヤーに何が増えるか」を先に決めてから書く。

| 例(P1 の目安期間) | 増えるもの |
| --- | --- |
| `domain/` | `interval_days` フィールド、状態判定の純関数 |
| `data/` | スキーマ変更とマイグレーション 1 本 |
| `state/` | `ItemView` に状態フィールドを追加 |
| `ui/` | 行に状態表示を追加、編集画面に入力欄を追加 |

**レイヤーを増やさない。** 機能が増えてもディレクトリの第 1 階層は 4 つのまま。
新しい関心事(例: 通知)が出たら `lib/notification/` のような**機能軸**ではなく、
既存レイヤーの中に置き場所を作る。

### ファイルサイズの管理

| 対象 | 目安 | 超えたときの分割方針 |
| --- | --- | --- |
| ウィジェット | 200 行 | 子ウィジェットを `widgets/` へ切り出す |
| Notifier | 250 行 | 画面単位で Notifier を分ける |
| リポジトリ実装 | 300 行 | エンティティ単位でファイルを分ける |
| 生成物(`*.g.dart`) | 制限なし | 分割しない |

> 目安であって規則ではない。**行数を理由に意味のない分割をしない。**

## 特殊ディレクトリ

### .steering/ (ステアリングファイル)

作業単位で `[YYYYMMDD]-[タスク名]/` を作り、`requirements.md` / `design.md` /
`tasklist.md` を置く。**履歴としてコミットして保持する。**

テンプレート由来の記録は `/kickoff` フェーズ5 で削除済み。残っているのは
このプロジェクト自身の作業記録だけ。

### .claude/ (Claude Code設定)

| パス | 所有 | 備考 |
| --- | --- | --- |
| `.claude/rules/` | テンプレート | `/sync-template` で上書きされる。**編集しない** |
| `.claude/rules/lead/` | テンプレート | 司令塔にのみ注入される |
| `.claude/commands/` / `skills/` / `agents/` / `hooks/` / `scripts/` | テンプレート | 同上 |
| `.claude/docs/` | テンプレート | MCP 導入・serena 再導入の判断ガイド |
| `.claude/settings.json` | 共同(merge) | プロジェクト固有の permissions を追記する |
| `.claude/settings.local.json` | ローカル | 追跡しない |

**プロジェクト固有のルールは `CLAUDE.md` の「プロジェクト固有ルール」節に書く。**
`.claude/rules/` に書くと `/sync-template` で失われる。

### .harness/ (ハーネスの運用状態)

| パス | 追跡 | 内容 |
| --- | --- | --- |
| `.harness/decisions.jsonl` | ✅ | 委託の実測ログ。**削除禁止・追記のみ** |
| `.harness/mode` | ❌ | 運用モード(A/B/C)。環境ごとに異なる |
| `.harness/codex-runs/` | ❌ | 委託の実行記録 |

### docs/template-dev/

**`CHANGELOG.md` だけを残している。** `/kickoff` はこのディレクトリごとの削除を勧めるが、
`.claude/scripts/check-record-hygiene.sh` がこのパスを直書きしており、消すと
ハーネスを変更する PR が毎回 CI で赤くなる。スクリプトはテンプレート所有
(`/sync-template` で上書きされる)ため、スクリプト側ではなくファイル側で整合を取っている。

## 除外設定

### .gitignore

追跡しないもの:

| 分類 | 例 |
| --- | --- |
| Dart/Flutter の生成物 | `.dart_tool/`・`build/`・`.flutter-plugins*` |
| ネイティブのビルド成果物 | `ios/Pods/`・`android/.gradle/`・`android/local.properties` |
| 署名鍵 | `android/key.properties`・`*.jks`・`*.keystore`・`*.p12`・`*.mobileprovision` |
| Node(ハーネス) | `node_modules/` |
| ローカル設定 | `.claude/settings.local.json`・`.idea/`・`.vscode/` |
| ハーネスの一時状態 | `.harness/mode`・`.harness/codex-runs/` |

**追跡するもの**(誤って無視しない):

- `pubspec.lock` —— アプリケーションなので依存解決を固定する
- `*.g.dart` / `*.drift.dart` —— CI でコード生成を回さず、差分をレビューで見るため
- `.steering/` —— 作業記録は履歴として残す
- `.harness/decisions.jsonl` —— 追記のみの永続ログ

### 静的解析の除外

`analysis_options.yaml` の `analyzer.exclude` で生成物を除外する:

```yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.drift.dart"
```

**フォーマット(`dart format`)からは除外しない。** 生成物も整形済みで
コミットされるため、`--set-exit-if-changed` の検査が安定する。
