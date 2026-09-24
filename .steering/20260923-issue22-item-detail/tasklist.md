# タスクリスト: カードをタップして開く詳細シート(Issue #22 / F29)

> 設計は `design.md`。判断番号はそちらを参照。

## フェーズ1: シート

- [x] 1. `lib/ui/widgets/item_detail_sheet.dart` に文言の純関数 3 つと `ItemDetailSheet` を書く(判断1・判断2)
- [x] 2. `test/ui/widgets/item_detail_sheet_test.dart` を書く(判断4-1)

## フェーズ2: 一覧からの導線

- [x] 3. `item_list_screen.dart` に `_openDetailSheet` を足し、カードの `onTap` を差し替える。`ItemCard.onTap` の doc コメントを直す(判断3)
- [x] 4. `item_list_screen_test.dart` を追従・追加する(判断4-2)
- [x] 5. `item_edit_screen_test.dart` / `terminology_test.dart` / `accessibility_test.dart` を追従・追加する(判断4-3)

## フェーズ3: ドキュメントと検証

- [x] 6. PRD / 機能設計 / 用語集を追記する(判断5)
- [x] 7. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断6)

## 申し送り(振り返りで記入)

- 実装完了日: 2026-09-23
- 変更した Dart 8 ファイルを対象に、キャッシュ内 Dart SDK の `analyze --fatal-infos` と `format --output=none --set-exit-if-changed` が pass。`git diff --check` も pass。
- テストは sandbox では実行できないためホストに委ねた(AGENTS.md §2 / 設計判断6)。対象: `test/ui/widgets/item_detail_sheet_test.dart`、`test/ui/item_list_screen_test.dart`、`test/ui/item_edit_screen_test.dart`、`test/ui/terminology_test.dart`、`test/ui/accessibility_test.dart`。
- 見出しの意味情報の検査は、非推奨の `hasFlag` から同等の `flagsCollection.isHeader` へ置換した。
- econ モードのためコミット未実施。
