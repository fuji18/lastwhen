# タスクリスト: 記録の詳細画面(Issue #58)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメインと状態

- [ ] `distinctCalendarDatesOf` を追加し、`intervalDaysOf` をそれで書き直す(design §1)
- [ ] `baseline_interval_test.dart` に `distinctCalendarDatesOf` のテストを足す(§5-1)
- [ ] `DoneHistoryEntry` と `ItemView.history` / `historyTruncated` を追加し、`==` / `hashCode` に含める(§2)
- [ ] `item_view_test.dart` に履歴のテストを足す(§5-2)

## フェーズ2: UI

- [ ] `item_navigation.dart`: `openItemDetailScreen` / `recordPastDateWithUndo` / `markDoneWithUndo` に改める(§3)
- [ ] `item_list_screen.dart` / `collection_screen.dart` を新しい関数に切り替え、コメントの「詳細シート」を直す(§3)
- [ ] `item_detail_screen.dart` を作る(本文・メニュー・記録するボタン・削除時の removeRoute・戻るときの clearSnackBars)(§4)
- [ ] `item_detail_sheet.dart` を削除する(§4)

## フェーズ3: テスト

- [ ] `item_detail_sheet_test.dart` を削除し、`item_detail_screen_test.dart` を作る(§5-3)
- [ ] 既存テスト(一覧・編集・図鑑・用語・アクセシビリティ)をシート → 画面に書き換える(§5-4)

## フェーズ4: docs

- [ ] `docs/product-requirements.md`(F29 / 追記 #58 / F23 / F31)(§6)
- [ ] `docs/functional-design.md`(記録の詳細節・画面遷移図・UC1b・通知・図鑑・テスト表)(§6)
- [ ] `docs/glossary.md`(§6)
- [ ] `docs/repository-structure.md`(§6)

## フェーズ5: 検証

- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る
- [ ] §7 の grep 条件を満たす

## 実装後の振り返り

(司令塔が記入)
