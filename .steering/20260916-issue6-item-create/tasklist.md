# タスクリスト: 項目の新規登録(Issue #6)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。
§5「触らないもの」に手を入れない。

## 実装: 状態管理層

- [ ] `lib/state/add_item_result.dart` を作成する(`AddItemResult` の 3 バリアント。§2.1)
- [ ] `lib/state/item_list_notifier.dart` に `addItem` を追記する(`build()` は変更しない。§2.2)

## 実装: UI 層

- [ ] `lib/ui/screens/item_add_screen.dart` を作成する(`ItemAddScreen` / `itemNameErrorText`。§2.3)
- [ ] `lib/ui/screens/item_list_screen.dart` を書き換える(FAB・遷移・`ListView` の下余白。§2.4)
- [ ] `lib/app.dart` の名前付きルートに関するコメントを直す(**コードは変更しない**。§2.5)

## 実装: テスト支援

- [ ] `test/support/fake_item_repository.dart` に `writeError` と `_failIfConfigured` を追記し、全書き込みメソッドの先頭で呼ぶ(§2.6)

## テスト

- [ ] `test/state/item_list_notifier_test.dart` に `addItem` の group を追記する(§3.1 のシナリオ 1〜8)
- [ ] `test/state/add_item_result_test.dart` を作成する(§3.2)
- [ ] `test/ui/item_add_screen_test.dart` を作成する(§3.3 のシナリオ 1〜11)
- [ ] `test/ui/item_list_screen_test.dart` に FAB の有無を 2 本追記する(§3.4)

## 検証

- [ ] 変更した Dart ファイルのみ `dart format --output=none --set-exit-if-changed` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る(sandbox で起動できない場合は報告して止める。design.md §4)
- [ ] 受け入れ条件の自己点検: 「項目名のみで登録が完了する」「エラー時に画面が閉じず入力が残る」「51 文字以上を入力できない」「登録直後は未実施」「保存失敗で一覧が変わらない」がテストで押さえられていることを確認する

## 振り返り(申し送り)

<!-- 実装後に司令塔が記載する -->
