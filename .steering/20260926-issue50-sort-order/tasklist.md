# タスクリスト: 一覧の並び替え(F15 / Issue #50)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: 計画時に司令塔が実施済み

- [x] `docs/functional-design.md` / `docs/glossary.md` / `docs/architecture.md` に F15 の振る舞いを追記

## フェーズ1: 状態管理層

- [x] `lib/state/item_order.dart` に `ItemSortOrder` / `_stableSort` / `sortItemViews` / `nameSortKey` を追加し、`sortByRelativeElapsed` を共通化(design.md §1)
- [x] `test/state/item_order_test.dart` に `sortItemViews` / `nameSortKey` のテストを追加(§6-1)
- [x] `lib/state/item_sort_order.dart` を新規作成(§2)
- [x] `lib/state/item_list_notifier.dart` に選んだ並びと経年順の二重確定・`ref.listen`・`_reconfirm` を追加(§3)
- [x] `lib/state/collection.dart` に `collectionItemsProvider` を追加(§4)
- [x] `test/state/item_list_notifier_test.dart` に「並び順の選択(F15)」グループを追加(§6-2)

## フェーズ2: UI 層

- [x] `lib/ui/widgets/item_sort_menu_button.dart` を新規作成(§5-1)
- [x] `lib/ui/screens/item_list_screen.dart` の AppBar に並び順ボタンを追加(§5-2)
- [x] `lib/ui/screens/collection_screen.dart` の供給源を `collectionItemsProvider` に変更(§5-3)
- [x] `test/ui/item_list_screen_test.dart` に「並び順の選択(F15)」グループを追加(§6-4)

## フェーズ3: 品質チェック

- [x] `dart format --output=none --set-exit-if-changed` が変更した Dart ファイルのみで通る(AGENTS.md に従い全体フォーマットは実施しない)
- [x] キャッシュ内 Dart SDK の `dart analyze --fatal-infos` が変更した Dart ファイルのみで通る(AGENTS.md に従いラッパーは使用しない)
- [x] ~~変更に関連するテストが通る~~(理由: AGENTS.md により sandbox でのテスト実行は禁止。ループバックのサーバーソケットを使用できないため、検収側へ実行を委ねる。対象: test/state/item_order_test.dart、test/state/item_list_notifier_test.dart、test/state/collection_test.dart、test/ui/item_list_screen_test.dart、test/ui/screens/collection_screen_test.dart。追加テストの静的解析は pass、実行結果は未確認)

## フェーズ4: 検収での追加

- [x] AppBar タイトルを `FittedBox(fit: BoxFit.scaleDown)` で包む(design.md §7-1)。`flutter test test/ui/accessibility_test.dart` が通る
- [x] 並び順メニューのタップ対象を `CheckedPopupMenuItem` の finder に変え、tap の警告を消す(design.md §7-2)。`flutter test test/ui/item_list_screen_test.dart` が警告なしで通る
