# タスクリスト: カテゴリと絞り込み(Issue #33 / F13)

> 設計は `design.md`。判断番号はそちらを参照。**委託禁止領域に触れるため Codex に委託しない。**

## フェーズ1: ドメインとスキーマ

- [ ] 1. `category.dart` / `category_name.dart` / `category_repository.dart` を作り、`Item.categoryId` と `ItemRepository` の引数を足す(判断1)。ドメインのテスト(判断8-2, 8-3)
- [ ] 2. `Categories` テーブル・`items.category_id`・`schemaVersion => 4`(判断2)→ build_runner → make-migrations(判断3 手順)
- [ ] 3. `onCreate` の初期カテゴリと `from3To4` を足し、`migration_test.dart` に v3→v4 のデータ検証テストを足す(判断3 / 判断8-4)

## フェーズ2: リポジトリ

- [ ] 4. `CategoryRepositoryImpl` を作り、`ItemRepositoryImpl` に categoryId を通す(判断4)
- [ ] 5. `FakeItemRepository` の追従と `clearCategory`、`FakeCategoryRepository` を作る(判断4)
- [ ] 6. `category_repository_impl_test.dart` と `item_repository_impl_test.dart` の追加(判断8-5, 8-6)

## フェーズ3: 状態管理

- [ ] 7. `categoryRepositoryProvider`・`category_results.dart`・`CategoryListNotifier`(判断5)とそのテスト(判断8-7)
- [ ] 8. `category_filter.dart`(判断5)とそのテスト(判断8-8)
- [ ] 9. `ItemView.categoryId`、`ItemListNotifier.addItem` / `editItem` の引数(判断5)とテストの追従(判断8-9)

## フェーズ4: UI

- [ ] 10. 既存ウィジェットテストの `ProviderScope` に `categoryRepositoryProvider` の差し替えを足す(判断8-1)
- [ ] 11. `category_name_error_text.dart` と `CategoryNameDialog`(判断6)
- [ ] 12. `CategoryFilterBar` とそのテスト(判断6 / 判断8-10)
- [ ] 13. `ItemCategoryPicker` とそのテスト(判断6 / 判断8-10)
- [ ] 14. `CategoryManageScreen` とそのテスト(判断7 / 判断8-10)
- [ ] 15. 一覧(チップ列・管理画面への導線・絞り込み・既定選択)と登録・編集画面(判断7)、画面テスト(判断8-10)
- [ ] 16. `terminology_test.dart` の更新(判断8-11)

## フェーズ5: ドキュメントと検証

- [ ] 17. PRD / glossary / functional-design / architecture を更新する(判断9)
- [ ] 18. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断10)

## 申し送り(振り返りで記入)
