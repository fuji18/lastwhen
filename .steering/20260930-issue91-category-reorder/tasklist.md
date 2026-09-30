# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**
- `lib/data/database/` / `lib/data/migrations/` は一切変えない。変更が要りそうなら停止して報告する

---

## フェーズ1: ドメイン・データ

- [x] `lib/domain/category_repository.dart` に `reorder` を追加し `add` の doc を更新(design §1)
- [x] `lib/domain/category.dart` の `sortOrder` の doc(design §2)
- [x] `lib/data/category_repository_impl.dart` に `reorder`(design §3)
- [x] `test/support/fake_category_repository.dart` に `reorder`(design §4)
- [x] `test/data/category_repository_impl_test.dart` にテスト 1〜5
- [x] `test/data/backup_repository_impl_test.dart` にテスト 6

## フェーズ2: 状態管理

- [x] `lib/state/category_results.dart` に `ReorderCategoryResult` 系(design §5)
- [x] `lib/state/category_list_notifier.dart` に `reorderCategories`(design §6)
- [x] `test/state/category_list_notifier_test.dart` にテスト 7〜9

## フェーズ3: UI

- [x] `lib/ui/screens/category_manage_screen.dart` を `ReorderableListView` に(design §7)
- [x] `test/ui/screens/category_manage_screen_test.dart` にテスト 10〜12(13 の既存テストが通ること)
- [x] `test/ui/item_list_screen_test.dart` にテスト 14

## フェーズ4: docs

- [x] `docs/product-requirements.md` F13 行
- [x] `docs/functional-design.md`(Category / CategoryRepository / カテゴリの絞り込み / 新節「カテゴリの並び替え」)
- [x] `docs/glossary.md` カテゴリ行

## フェーズ5: 検証

- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` がすべて通る

## 申し送り(振り返り)

- 実装は implement-ticket の Sonnet fork に 2 回で渡した。1 回目は design.md どおり `onReorder` + 自前の index 補正で実装され、fork が非推奨を `ignore` で抑えていた。司令塔が判断 9 を `onReorderItem`(補正済みの newIndex)に改め、追補として 2 回目で置き換えた。**設計時に使う API の非推奨を確かめていなかったのが往復の原因**
- 読み上げの並び替えは `ReorderableListView` 組み込みのカスタム操作で足りた。テストは `performAction` で実行まで確かめている(`tester.binding.pipelineOwner` は非推奨だが `rootPipelineOwner` では反映されず、テストに限り ignore で使う)
- `/check` と `code-reviewer`(ui-design-guidelines §6)はモード B のため未実施。CI に委ねる。fork の手元ではフルスイート 902 件通過

## 追補(司令塔・fork 1 回目の後)

- [x] `category_manage_screen.dart` の `onReorder` + 自前の index 補正 + `ignore: deprecated_member_use` を `onReorderItem`(補正なし)に置き換える(design 判断 9)。ウィジェットテスト 10〜12 が通ること。format / analyze / 関連テストを回す
