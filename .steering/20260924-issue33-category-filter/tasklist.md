# タスクリスト: カテゴリと絞り込み(Issue #33 / F13)

> 設計は `design.md`。判断番号はそちらを参照。**委託禁止領域に触れるため Codex に委託しない。**

## フェーズ1: ドメインとスキーマ

- [x] 1. `category.dart` / `category_name.dart` / `category_repository.dart` を作り、`Item.categoryId` と `ItemRepository` の引数を足す(判断1)。ドメインのテスト(判断8-2, 8-3)
- [x] 2. `Categories` テーブル・`items.category_id`・`schemaVersion => 4`(判断2)→ build_runner → make-migrations(判断3 手順)
- [x] 3. `onCreate` の初期カテゴリと `from3To4` を足し、`migration_test.dart` に v3→v4 のデータ検証テストを足す(判断3 / 判断8-4)

## フェーズ2: リポジトリ

- [x] 4. `CategoryRepositoryImpl` を作り、`ItemRepositoryImpl` に categoryId を通す(判断4)
- [x] 5. `FakeItemRepository` の追従と `clearCategory`、`FakeCategoryRepository` を作る(判断4)
- [x] 6. `category_repository_impl_test.dart` と `item_repository_impl_test.dart` の追加(判断8-5, 8-6)

## フェーズ3: 状態管理

- [x] 7. `categoryRepositoryProvider`・`category_results.dart`・`CategoryListNotifier`(判断5)とそのテスト(判断8-7)
- [x] 8. `category_filter.dart`(判断5)とそのテスト(判断8-8)
- [x] 9. `ItemView.categoryId`、`ItemListNotifier.addItem` / `editItem` の引数(判断5)とテストの追従(判断8-9)

## フェーズ4: UI

- [x] 10. 既存ウィジェットテストの `ProviderScope` に `categoryRepositoryProvider` の差し替えを足す(判断8-1)
- [x] 11. `category_name_error_text.dart` と `CategoryNameDialog`(判断6)
- [x] 12. `CategoryFilterBar` とそのテスト(判断6 / 判断8-10)
- [x] 13. `ItemCategoryPicker` とそのテスト(判断6 / 判断8-10)
- [x] 14. `CategoryManageScreen` とそのテスト(判断7 / 判断8-10)
- [x] 15. 一覧(チップ列・管理画面への導線・絞り込み・既定選択)と登録・編集画面(判断7)、画面テスト(判断8-10)
- [x] 16. `terminology_test.dart` の更新(判断8-11)

## フェーズ5: ドキュメントと検証

- [x] 17. PRD / glossary / functional-design / architecture を更新する(判断9)
- [x] 18. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断10)

## 申し送り(振り返りで記入)

- **実装完了日**: 2026-09-24(implement-ticket の fork。往復 1 回・判断待ちなし)
- **計画との差分**:
  - ユーザーが「カテゴリを追加できる」を選んだため、Issue の想定(固定の区分)よりスコープが広い。管理画面・名前ダイアログ・選択欄の追加チップを足した
  - `terminology_test.dart` の既存「削除確認」テストが、選択欄の追加で削除ボタンが画面外に出て `tap()` が当たらなくなった。`tester.ensureVisible()` を先に呼ぶ既存パターン(`accessibility_test.dart`)で直した(設計判断ではない)
- **検証**: fork 内で format / analyze pass。司令塔が `flutter test` を一括で再実行し 472 件 pass(fork が 5 回に分けた実行でも 481 件が pass)。`from1To2` / `from2To3` は変わらず、`migration_test.dart` は追記だけ、`package.json` / `pubspec` の差分は 0 行
- **申し送り**:
  - **モード B のため `/check` と `code-reviewer` は回していない。** マイグレーション(v4・初期カテゴリの投入)を含むので、枠が戻ったら優先してレビューする
  - 図鑑(#34)では `CategoryFilterBar` をそのまま使い回せる(provider を読まない作り)
  - 「未分類」だけで絞り込む機能とカテゴリの並び替えはスコープ外にした。要望が出たら P2 として切る
