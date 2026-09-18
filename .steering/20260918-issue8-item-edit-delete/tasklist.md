# タスクリスト: 項目の編集と削除(Issue #8)

<!-- status: ready -->

> 進捗は実装中に随時更新する(`- [ ]` → `- [x]`)。技術的理由で不要になった項目は
> `- [x] ~~項目~~ (理由: ...)` の形で残す。**理由なくスキップしない。**
> 設計判断が要るものが出たら、推測せず停止して司令塔に戻す(`design.md` に無い判断は書かない)。

## バッチ1: 共通部品の移設と結果型

- [ ] `lib/ui/item_name_error_text.dart` を新規作成し、`item_add_screen.dart` の `itemNameErrorText` を**中身を変えずに**移す(`design.md` §3 / 判断5)
- [ ] `lib/ui/screens/item_add_screen.dart` から定義を削り、移設先を import する(`../../domain/item_name.dart` の import は残す)
- [ ] `test/ui/item_add_screen_test.dart` に移設先の import を足す(**テストの中身は変えない**)
- [ ] `lib/state/edit_item_result.dart` を新規作成する(§4。`add_item_result.dart` と同じ粒度のコメントを付ける)

## バッチ2: 状態管理層

- [ ] `ItemListNotifier.renameItem` を足す(§5)。**`state` を書かない**。検証 → 存在確認の順(判断8)
- [ ] `ItemListNotifier.deleteItem` を足す(§5)。**`Clock` を使わない**(判断11)
- [ ] `test/state/item_list_notifier_test.dart` に §9-1 の 14 ケースを足す(既存ヘルパーを使う。`FakeItemRepository` は変更しない。**呼ぶ前に `itemListProvider.future` を通す**)

## バッチ3: UI 層

- [ ] `lib/ui/widgets/item_row.dart` に必須の `onTap` を足し、`Padding` を `InkWell` で包む(§6 / 判断4)。**中のレイアウトは変えない**
- [ ] `lib/ui/screens/item_edit_screen.dart` を新規作成する(§7 のコードをそのまま使ってよい)
- [ ] `lib/ui/screens/item_list_screen.dart` に `onTap` の結線と `_openEditScreen` を足す(§8。遷移前に `clearSnackBars()`)
- [ ] `test/ui/item_edit_screen_test.dart` を新規作成し §9-2 の 12 ケースを書く(**ダイアログ内の「削除」は `AlertDialog` の子孫として特定する**)
- [ ] `test/ui/item_list_screen_test.dart` に §9-3 の 2 ケースを足す

## バッチ4: 仕上げ

- [ ] `dart format --output=none --set-exit-if-changed` が通る(AGENTS.md に従い変更した Dart ファイルのみ確認)
- [ ] `dart analyze --fatal-infos` が通る(AGENTS.md に従いキャッシュ内 Dart SDK で変更した Dart ファイルを個別に確認)
- [ ] `flutter test` が通る(**委託先では実行できない。検収側 / CI が回す**)
- [ ] `requirements.md` の受け入れ条件を上から照合し、満たしていない行が無いことを確認する

## 変更しないもの(触ったら設計違反)

- `lib/domain/` / `lib/data/`(`rename` / `delete` / `validateItemName` は #3・#4 で完成済み)
- `lib/ui/theme/` / `lib/ui/widgets/done_button.dart` / `lib/ui/widgets/empty_state.dart`
- `lib/app.dart` / `pubspec.yaml` / `docs/` / `test/support/`
