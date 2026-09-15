# タスクリスト: データ層(Issue #4)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。

## 実装

- [ ] `lib/data/database/app_database.dart` を作成する(`Items` テーブル / `AppDatabase` / `_openConnection`。design.md §2.1)
- [ ] `lib/data/migrations/migrations.dart` を作成する(`buildMigrationStrategy`。§2.2)
- [ ] `dart run build_runner build --delete-conflicting-outputs` を実行し、`app_database.g.dart` を生成する(§3)
- [ ] `lib/data/item_repository_impl.dart` を作成する(`ItemRepositoryImpl` と変換ヘルパ。§2.3)
- [ ] `lib/data/.gitkeep` を削除する

## テスト

- [ ] `test/support/fake_item_repository.dart` を作成する(§2.4)
- [ ] `test/data/item_repository_impl_test.dart` の共有シナリオ 1〜8 を書く(§2.5。**実装とフェイクの両方に流す**)
- [ ] 同ファイルの実装専用 group 9〜14 を書く(§2.5。生の SQL で保存形式を検証する)

## 検証

- [ ] `dart format .` を実行し、差分が出ない状態にする
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る
- [ ] `git status` で `lib/data/database/app_database.g.dart` が追跡対象になっていることを確認する(`.gitignore` で除外されていないこと)

## 振り返り(申し送り)

<!-- 実装後に司令塔が記入する -->
