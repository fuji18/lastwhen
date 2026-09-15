# タスクリスト: ドメイン層(Issue #3)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**

## 実装

- [ ] `lib/domain/item.dart` を作成する(`ItemId` / `Item`。design.md §2.1)
- [ ] `lib/domain/item_name.dart` を作成する(`validateItemName` と結果型。§2.2)
- [ ] `lib/domain/clock.dart` を作成する(`Clock` / `SystemClock`。§2.3)
- [ ] `lib/domain/elapsed_days.dart` を作成する(`calendarDateOf` / `elapsedDays` / `ElapsedLabel` / `elapsedLabel`。§2.4)
- [ ] `lib/domain/item_repository.dart` を作成する(**インターフェースのみ**。§2.5)
- [ ] `lib/domain/.gitkeep` を削除する

## テスト

- [ ] `test/support/fake_clock.dart` を作成する(§2.6)
- [ ] `test/domain/elapsed_days_test.dart` を作成する(§3.1 の 3 グループ・全ケース)
- [ ] `test/domain/item_name_test.dart` を作成する(§3.2)
- [ ] `test/domain/clock_test.dart` を作成する(§3.3)
- [ ] `test/domain/item_test.dart` を作成する(§3.4。`==` の分岐を 1 つずつ潰す)
- [ ] `test/architecture/layer_dependency_test.dart` を作成する(§3.5。domain の検査のみ)

## 検証

- [ ] `dart format .` を実行し、差分が出ない状態にする
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る
- [ ] `flutter test --coverage` + §4 の awk で `lib/domain/` の未カバー行が 0 であることを確認する
- [ ] `coverage/` が `.gitignore` にあることを確認する(無ければ追記)
