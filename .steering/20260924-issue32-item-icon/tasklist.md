# タスクリスト: 項目ごとのアイコン設定(Issue #32 / F14)

> 設計は `design.md`。判断番号はそちらを参照。**委託禁止領域に触れるため Codex に委託しない。**

## フェーズ1: ドメインとスキーマ

- [ ] 1. `lib/domain/item_icon.dart` を作り、`Item.icon` を足す(判断1)。`test/domain/item_icon_test.dart` と `item_test.dart` の追加(判断12-1, 12-2)
- [ ] 2. `items.icon` 列と `schemaVersion => 3`(判断2)→ build_runner → make-migrations(判断3 手順)
- [ ] 3. `from2To3` を足し、`migration_test.dart` に v2→v3 のデータ検証テストを足す(判断3 / 判断12-3)

## フェーズ2: リポジトリと状態管理

- [ ] 4. `ItemRepository` の `add` / `edit`(`rename` を置き換え)、`ItemRepositoryImpl`、`FakeItemRepository` を直す(判断4)
- [ ] 5. `test/data/item_repository_impl_test.dart` を追従・追加する(判断12-4)
- [ ] 6. `ItemView.icon`、`ItemListNotifier.addItem` / `editItem`、`EditItem*` へのリネーム(判断5)
- [ ] 7. `item_list_notifier_test.dart` / `item_view_test.dart` を追従・追加する(判断12-5, 12-6)

## フェーズ3: UI

- [ ] 8. `lib/ui/item_icon_glyph.dart` と `agingIconOpacity`(判断6 / 判断7)、`aging_palette_test.dart` の追加(判断12-12)
- [ ] 9. `ItemIconPicker` とそのテスト(判断10 / 判断12-7)
- [ ] 10. `ItemCard` にアイコンと掠れ、しきい値 1.2(判断8)、`item_card_test.dart`(判断12-8)
- [ ] 11. `ItemDetailSheet` の見出しにアイコン(判断9)、`item_detail_sheet_test.dart`(判断12-9)
- [ ] 12. 登録・編集画面にピッカー、一覧から `initialIcon` を渡す(判断11)、画面テスト(判断12-10, 12-11, 12-13)

## フェーズ4: ドキュメントと検証

- [ ] 13. glossary / functional-design / architecture を更新する(判断13)
- [ ] 14. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断14)

## 申し送り(振り返りで記入)
