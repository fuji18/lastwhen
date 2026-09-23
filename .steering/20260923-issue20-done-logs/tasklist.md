# タスクリスト: 実施履歴の保持と基準間隔の学習(Issue #20)

> 設計は `design.md`。判断番号はそちらを参照。**順序を守る**(1 → 2 は v1 スナップショットの取得のため入れ替え不可)。

## フェーズ1: マイグレーション基盤

- [x] 1. `build.yaml` を作成し、**スキーマ変更前に** `dart run drift_dev make-migrations` で `drift_schema_v1.json` を取得する(判断1 手順1〜2)
- [x] 2. `DoneLogs` テーブルを追加し `schemaVersion` を 2 にする(判断2)。`build_runner build` → `make-migrations` で v2 スナップショット・steps・テスト雛形を生成(判断1 手順3〜4)
- [x] 3. `migrations.dart` に `stepByStep(from1To2)`・既存データの移送・`PRAGMA foreign_keys = ON` を実装する(判断3)
- [x] 4. マイグレーションテスト(スキーマ一致 + データ検証)を書く(判断9)

## フェーズ2: ドメイン

- [x] 5. `Item.recentDoneAts` を追加する(判断4)
- [x] 6. `lib/domain/baseline_interval.dart` とユニットテストを書く(判断5・判断9)

## フェーズ3: データ・状態管理

- [x] 7. `ItemRepositoryImpl` の `watchAll` / `markDone` / `restoreLastDoneAt` を変更し、インターフェースのコメントを更新する(判断6)
- [x] 8. `FakeItemRepository` を実装と揃える(判断8)
- [x] 9. リポジトリのテストを追記する(トランザクション・CASCADE・履歴件数を含む。判断9)
- [x] 10. `ItemView` に 3 フィールドを足し、テストを追記する(判断7・判断9)

## フェーズ4: ドキュメントと検証

- [x] 11. PRD / 機能設計 / 用語集を追記する(判断10)
- [x] 12. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(生成物の除外が要れば判断1 手順6)

## 申し送り(振り返りで記入)

- 実装は `implement-ticket`(Sonnet fork)。禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れるため Codex には委託していない。往復 1 回、判断待ちなし
- design.md に無かった判断を 1 つ補完し、判断6 に追記した: `markDone` で対象項目が無ければ `done_logs` に INSERT しない
- `make-migrations` が生成したテスト雛形は `AppDatabase(schema.newConnection())` を使うが、本番コンストラクタは引数なしの設計なので `AppDatabase.forTesting` に差し替えた。**次にスキーマを上げるときも、再生成後に同じ差し替えが要る**
- `item_view.dart` は `baseline_interval.dart` の関数名とフィールド名が衝突するため `import ... as baseline` にしている
- モード B(econ)のため `/check` と `code-reviewer` は回していない(fork 内では format / analyze / test 229 件が通過済み)。**マイグレーションを含むので、枠が戻ったら code-reviewer を当てる**
- 後続: #21(経年変化)・#22(詳細画面)・#23(並び順)が `ItemView` の前回間隔 / 基準間隔 / 相対経過度を使う
