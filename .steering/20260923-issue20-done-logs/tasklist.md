# タスクリスト: 実施履歴の保持と基準間隔の学習(Issue #20)

> 設計は `design.md`。判断番号はそちらを参照。**順序を守る**(1 → 2 は v1 スナップショットの取得のため入れ替え不可)。

## フェーズ1: マイグレーション基盤

- [ ] 1. `build.yaml` を作成し、**スキーマ変更前に** `dart run drift_dev make-migrations` で `drift_schema_v1.json` を取得する(判断1 手順1〜2)
- [ ] 2. `DoneLogs` テーブルを追加し `schemaVersion` を 2 にする(判断2)。`build_runner build` → `make-migrations` で v2 スナップショット・steps・テスト雛形を生成(判断1 手順3〜4)
- [ ] 3. `migrations.dart` に `stepByStep(from1To2)`・既存データの移送・`PRAGMA foreign_keys = ON` を実装する(判断3)
- [ ] 4. マイグレーションテスト(スキーマ一致 + データ検証)を書く(判断9)

## フェーズ2: ドメイン

- [ ] 5. `Item.recentDoneAts` を追加する(判断4)
- [ ] 6. `lib/domain/baseline_interval.dart` とユニットテストを書く(判断5・判断9)

## フェーズ3: データ・状態管理

- [ ] 7. `ItemRepositoryImpl` の `watchAll` / `markDone` / `restoreLastDoneAt` を変更し、インターフェースのコメントを更新する(判断6)
- [ ] 8. `FakeItemRepository` を実装と揃える(判断8)
- [ ] 9. リポジトリのテストを追記する(トランザクション・CASCADE・履歴件数を含む。判断9)
- [ ] 10. `ItemView` に 3 フィールドを足し、テストを追記する(判断7・判断9)

## フェーズ4: ドキュメントと検証

- [ ] 11. PRD / 機能設計 / 用語集を追記する(判断10)
- [ ] 12. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(生成物の除外が要れば判断1 手順6)

## 申し送り(振り返りで記入)
