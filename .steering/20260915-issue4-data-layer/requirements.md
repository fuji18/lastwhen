# 要求: データ層(Drift スキーマとリポジトリ実装)

対象 Issue: #4(P0 / フェーズ1)
根拠: `docs/architecture.md`「データレイヤー」「データ永続化戦略」「マイグレーション戦略」「バックアップ戦略」/ `docs/functional-design.md`「データモデル定義」「コンポーネント設計」/ `docs/glossary.md`「items テーブル」

## 背景

F8「データの端末内保存」を満たす。アプリを終了・再起動しても記録が残る状態にする。
#3 で `ItemRepository` のインターフェースをドメインに置いたので、ここで実装を入れて
依存性逆転を閉じる。#5 以降の画面・Provider はこの実装の上に載る。

**このチケットは委託禁止領域を含む。** `lib/data/database/` と `lib/data/migrations/` は
一度出荷したマイグレーションを修正できず、失敗がユーザーの記録の全損になるため
Codex に渡さない(`AGENTS.md` §4 / `CLAUDE.md`「Codex への委託禁止領域」)。

## スコープ(やること)

| 成果物 | 内容 |
| --- | --- |
| `lib/data/database/app_database.dart` | Drift の DB 定義、`items` テーブル、`schemaVersion = 1`、接続の生成 |
| `lib/data/database/app_database.g.dart` | 生成物(コミットする) |
| `lib/data/migrations/migrations.dart` | `MigrationStrategy`(v1 の初期作成のみ) |
| `lib/data/item_repository_impl.dart` | `ItemRepository` の Drift 実装 |
| `test/data/item_repository_impl_test.dart` | インメモリ DB での統合テスト |
| `test/support/fake_item_repository.dart` | 上位層(#5 以降)のテスト用フェイク |

## スコープ外(やらないこと)

- 画面・Riverpod の Provider 定義(#5 以降)。**`AppDatabase` / `ItemRepositoryImpl` の Provider をここで作らない**
- `done_logs` テーブル(P1 の履歴機能)
- 目安期間の列(P1)
- データのエクスポート・インポート(P2)
- `setLastDoneAt`(最終実施日の手動修正。P1 の F16)
- `lib/main.dart` / `lib/app.dart` の書き換え(DB の起動時初期化は #5 の Provider 導入とセット)

## 受け入れ条件(Issue #4 より)

- [ ] `items` テーブルが `docs/glossary.md`「items テーブル」の定義どおりに作られている
- [ ] **日時は UTC のエポックミリ秒(整数)で保存される**。文字列で保存しない
- [ ] `last_done_at` が NULL 許容で、**NULL = 未実施**として扱われる
- [ ] `name` に NOT NULL 制約がある(状態管理層の検証と二重化)
- [ ] `ItemRepository` の全メソッドが実装されている(`watchAll` / `add` / `rename` / `delete` / `markDone` / `restoreLastDoneAt`)
- [ ] `watchAll` が Stream で、DB の変更時に自動で再送出される
- [ ] `markDone` が記録時刻を引数で受け取る(データ層は `Clock` に依存しない)
- [ ] `rename` が `last_done_at` を変化させない
- [ ] `markDone` と `rename` で `updated_at` が進む
- [ ] 統合テストで 6 シナリオが検証されている(追加 / 記録 / 取り消し / 名称変更 / 削除 / 100 件)
- [ ] `*.g.dart` がコミットされている
- [ ] `flutter analyze --fatal-infos` と `flutter test` が通る

## 制約

- **追加依存を入れない。** `pubspec.yaml` は #2 で確定した内容のまま触らない
  (`drift` / `sqlite3` / `path_provider` / `uuid` が既に入っている)。
  `package:path` は直接依存に無いため import しない(`depend_on_referenced_packages`)
- データレイヤーは `Clock`・経過日数の計算・表示用の文字列整形を持たない(`docs/architecture.md`「データレイヤー」)
- SQL を文字列連結で組まない。Drift のクエリビルダ経由のみ
- マイグレーション失敗時にテーブルを作り直さない(前進のみ / 破壊的変更を避ける)
- iOS / Android の自動バックアップから DB を除外しない(設定を足さない = 既定のまま)
- 統合テストは `NativeDatabase.memory()` を使い、実ファイルを触らない
- 用語は `docs/glossary.md`「表記ゆれの禁止一覧」に従う
- `dart format` の出力が正(80 桁)
