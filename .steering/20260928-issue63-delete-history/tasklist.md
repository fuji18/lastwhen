# タスクリスト: 記録の履歴を日付ごとに削除する(Issue #63)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメインとデータ

- [x] `DoneLog` を `lib/domain/item.dart` に追加し、`ItemRepository` に `removeDoneLogsBetween` / `restoreDoneLogs` を宣言する(design §1)
- [x] `ItemRepositoryImpl` に 2 メソッドを実装する(§2)
- [x] `FakeItemRepository` に 2 メソッドを実装する(`_insertLog` に `logId` 引数を足す)(§3)
- [x] 共有シナリオのテストを足す(§6-1)

## フェーズ2: 状態

- [x] `HistoryDayKey` と `DoneHistoryEntry.shortDateText` / `dayKey` を追加し、`ItemView.from` で埋める(§4)
- [x] `delete_history_day_result.dart` を作り、`ItemListNotifier` に `deleteHistoryDay` / `undoDeleteHistoryDay` を足す(§4)
- [x] `item_view_test.dart` / `item_detail_screen_test.dart` の既存 `DoneHistoryEntry` に引数を足し、`item_view_test.dart` に 1 ケース足す(§6-3)
- [x] `item_list_notifier_test.dart` にテストを足す(§6-2)

## フェーズ3: UI

- [x] `item_navigation.dart` に `deleteHistoryDayWithUndo` / `_undoDeleteHistoryDay` を足す(§5)
- [x] `item_detail_screen.dart`: `historyDeleteButtonLabel`・doc コメント・`_HistoryRow` の削除ボタン(§5)
- [x] `item_detail_screen_test.dart` に「記録の削除」group を足す(§6-4)
- [x] `accessibility_test.dart` の 200% テストに削除ボタンの検証を足す(§6-5)

## フェーズ4: docs

- [x] `docs/product-requirements.md`(F29 / 追記 #63)(§7)
- [x] `docs/functional-design.md`(記録の詳細節・統合テスト表・ウィジェットテスト表)(§7)
- [x] `docs/glossary.md`(履歴・記録の詳細)(§7)

## フェーズ5: 検証

- [x] `dart format` / `flutter analyze --fatal-infos` を通す(sandbox で実行できない場合は理由を書いて検収側に委ねる) — 変更した 14 Dart ファイルの format 確認 pass。キャッシュ内 Dart SDK で変更ファイルを analyze したが、package_config.json が存在しない Windows の Pub / Flutter パスを参照し依存を解決できないため解析完了不可。環境復旧後の解析をホスト委任(解析 pass ではない)。
- [x] `flutter test` を通す(委託先で実行できない場合は「ホスト委任」と記録して検収側に委ねる) — ホスト委任。AGENTS.md に従い sandbox では実行していない。関連テスト: test/data/item_repository_impl_test.dart、test/state/item_view_test.dart、test/state/item_list_notifier_test.dart、test/ui/screens/item_detail_screen_test.dart、test/ui/accessibility_test.dart。
- [x] `lib/data/database` / `lib/data/migrations` / `pubspec.yaml` に差分が無いことを確認する(§8)

## 実装後の振り返り

(司令塔が記入)
