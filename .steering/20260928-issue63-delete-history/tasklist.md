# タスクリスト: 記録の履歴を日付ごとに削除する(Issue #63)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメインとデータ

- [ ] `DoneLog` を `lib/domain/item.dart` に追加し、`ItemRepository` に `removeDoneLogsBetween` / `restoreDoneLogs` を宣言する(design §1)
- [ ] `ItemRepositoryImpl` に 2 メソッドを実装する(§2)
- [ ] `FakeItemRepository` に 2 メソッドを実装する(`_insertLog` に `logId` 引数を足す)(§3)
- [ ] 共有シナリオのテストを足す(§6-1)

## フェーズ2: 状態

- [ ] `HistoryDayKey` と `DoneHistoryEntry.shortDateText` / `dayKey` を追加し、`ItemView.from` で埋める(§4)
- [ ] `delete_history_day_result.dart` を作り、`ItemListNotifier` に `deleteHistoryDay` / `undoDeleteHistoryDay` を足す(§4)
- [ ] `item_view_test.dart` / `item_detail_screen_test.dart` の既存 `DoneHistoryEntry` に引数を足し、`item_view_test.dart` に 1 ケース足す(§6-3)
- [ ] `item_list_notifier_test.dart` にテストを足す(§6-2)

## フェーズ3: UI

- [ ] `item_navigation.dart` に `deleteHistoryDayWithUndo` / `_undoDeleteHistoryDay` を足す(§5)
- [ ] `item_detail_screen.dart`: `historyDeleteButtonLabel`・doc コメント・`_HistoryRow` の削除ボタン(§5)
- [ ] `item_detail_screen_test.dart` に「記録の削除」group を足す(§6-4)
- [ ] `accessibility_test.dart` の 200% テストに削除ボタンの検証を足す(§6-5)

## フェーズ4: docs

- [ ] `docs/product-requirements.md`(F29 / 追記 #63)(§7)
- [ ] `docs/functional-design.md`(記録の詳細節・統合テスト表・ウィジェットテスト表)(§7)
- [ ] `docs/glossary.md`(履歴・記録の詳細)(§7)

## フェーズ5: 検証

- [ ] `dart format` / `flutter analyze --fatal-infos` を通す(sandbox で実行できない場合は理由を書いて検収側に委ねる)
- [ ] `flutter test` を通す(委託先で実行できない場合は「ホスト委任」と記録して検収側に委ねる)
- [ ] `lib/data/database` / `lib/data/migrations` / `pubspec.yaml` に差分が無いことを確認する(§8)

## 実装後の振り返り

(司令塔が記入)
