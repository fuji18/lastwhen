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

- [ ] `lib/state/item_order.dart` に `ItemSortOrder` / `_stableSort` / `sortItemViews` / `nameSortKey` を追加し、`sortByRelativeElapsed` を共通化(design.md §1)
- [ ] `test/state/item_order_test.dart` に `sortItemViews` / `nameSortKey` のテストを追加(§6-1)
- [ ] `lib/state/item_sort_order.dart` を新規作成(§2)
- [ ] `lib/state/item_list_notifier.dart` に選んだ並びと経年順の二重確定・`ref.listen`・`_reconfirm` を追加(§3)
- [ ] `lib/state/collection.dart` に `collectionItemsProvider` を追加(§4)
- [ ] `test/state/item_list_notifier_test.dart` に「並び順の選択(F15)」グループを追加(§6-2)

## フェーズ2: UI 層

- [ ] `lib/ui/widgets/item_sort_menu_button.dart` を新規作成(§5-1)
- [ ] `lib/ui/screens/item_list_screen.dart` の AppBar に並び順ボタンを追加(§5-2)
- [ ] `lib/ui/screens/collection_screen.dart` の供給源を `collectionItemsProvider` に変更(§5-3)
- [ ] `test/ui/item_list_screen_test.dart` に「並び順の選択(F15)」グループを追加(§6-4)

## フェーズ3: 品質チェック

- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] 変更に関連するテストが通る(委託先でテストが回せない場合は理由を添えて検収側へ回す)
