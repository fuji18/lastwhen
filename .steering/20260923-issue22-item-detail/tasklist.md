# タスクリスト: カードをタップして開く詳細シート(Issue #22 / F29)

> 設計は `design.md`。判断番号はそちらを参照。

## フェーズ1: シート

- [ ] 1. `lib/ui/widgets/item_detail_sheet.dart` に文言の純関数 3 つと `ItemDetailSheet` を書く(判断1・判断2)
- [ ] 2. `test/ui/widgets/item_detail_sheet_test.dart` を書く(判断4-1)

## フェーズ2: 一覧からの導線

- [ ] 3. `item_list_screen.dart` に `_openDetailSheet` を足し、カードの `onTap` を差し替える。`ItemCard.onTap` の doc コメントを直す(判断3)
- [ ] 4. `item_list_screen_test.dart` を追従・追加する(判断4-2)
- [ ] 5. `item_edit_screen_test.dart` / `terminology_test.dart` / `accessibility_test.dart` を追従・追加する(判断4-3)

## フェーズ3: ドキュメントと検証

- [ ] 6. PRD / 機能設計 / 用語集を追記する(判断5)
- [ ] 7. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断6)

## 申し送り(振り返りで記入)
