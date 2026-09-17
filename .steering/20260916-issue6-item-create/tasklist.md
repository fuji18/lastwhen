# タスクリスト: 項目の新規登録(Issue #6)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。
§5「触らないもの」に手を入れない。

## 実装: 状態管理層

- [x] `lib/state/add_item_result.dart` を作成する(`AddItemResult` の 3 バリアント。§2.1)
- [x] `lib/state/item_list_notifier.dart` に `addItem` を追記する(`build()` は変更しない。§2.2)

## 実装: UI 層

- [x] `lib/ui/screens/item_add_screen.dart` を作成する(`ItemAddScreen` / `itemNameErrorText`。§2.3)
- [x] `lib/ui/screens/item_list_screen.dart` を書き換える(FAB・遷移・`ListView` の下余白。§2.4)
- [x] `lib/app.dart` の名前付きルートに関するコメントを直す(**コードは変更しない**。§2.5)

## 実装: テスト支援

- [x] `test/support/fake_item_repository.dart` に `writeError` と `_failIfConfigured` を追記し、全書き込みメソッドの先頭で呼ぶ(§2.6)

## テスト

- [x] `test/state/item_list_notifier_test.dart` に `addItem` の group を追記する(§3.1 のシナリオ 1〜8)
- [x] `test/state/add_item_result_test.dart` を作成する(§3.2)
- [x] `test/ui/item_add_screen_test.dart` を作成する(§3.3 のシナリオ 1〜11)
- [x] `test/ui/item_list_screen_test.dart` に FAB の有無を 2 本追記する(§3.4)

## 検証

- [x] 変更した Dart ファイルのみ `dart format --output=none --set-exit-if-changed` が通る
- [x] `flutter analyze --fatal-infos` が通る(ホスト側で実行。No issues found)
- [x] `flutter test` が通る(**ホスト側で実行**。109 件すべて成功。委託先の sandbox では走らなかった — 下記申し送り)
- [x] 受け入れ条件の自己点検: 「項目名のみで登録が完了する」「エラー時に画面が閉じず入力が残る」「51 文字以上を入力できない」「登録直後は未実施」「保存失敗で一覧が変わらない」がテストで押さえられていることを確認する

## 振り返り(申し送り)

### 1. Codex の sandbox で今度は Flutter SDK が読み取り専用だった(#5 とは別の壁)

#5 は `flutter test` が localhost ソケットを作れずに止まったが、今回止まったのは**その手前**で、
`flutter analyze` すら起動できなかった(SDK キャッシュが読み取り専用で、Dart が
`.dart_tool` 等へ書き戻せない)。委託は `status=failed` / `exit 2` で返っている。
**原因は成果物ではなく実行環境**で、ホスト側で `dart format`(差分なし)・
`flutter analyze --fatal-infos`(No issues found)・`flutter test`(109 件成功)を回して検収した。

**このプロジェクトで impl を委託する限り、当面は毎回 `status=failed` で返る。**
#7 以降も「委託先の失敗 = 成果物の失敗」と読まないこと。恒久対応(`.codex/` の sandbox 設定で
ループバック許可 + SDK キャッシュの書き込み許可)は別チケットの判断。

### 2. 保存中のシステム戻る操作は塞いでいない(#8 で再検討)

判断7 は「保存ボタンとキャンセルアイコンの無効化」までを指定しており、Android の戻る
ジェスチャーまでは塞いでいない。保存中に離脱しても `mounted` ガードでクラッシュせず、
書き込み自体は完走して項目は登録されるため実害は小さいと判断して**今回は対応しない**。
#8(編集・削除)で同じ画面構造を作るとき、`PopScope(canPop: !_isSaving)` を入れるかを
まとめて判断する。

### 3. FAB の非表示条件のうち「読み込み中・読み込み失敗」はテスト未カバー

判断5 は 4 状態すべてを規定しているが、design.md §3.4 のテスト表が「2 件 → 出る」
「0 件 → 出ない」の 2 本しか要求していなかった。**設計時点のカバレッジの薄さ**であって
実装の不備ではない。#7 で一覧画面のテストを触るときに 2 本足す。

### 4. `docs/functional-design.md` からの逸脱(`/sync-docs` 対象)

`writeErrorProvider` を作らなかった(判断2)。機能設計書「コンポーネント設計」「エラーハンドリング」は
DB 書き込み失敗を一律 `writeErrorProvider` 経由の `SnackBar` と書いているが、#6 は
**失敗の発生源(登録画面)が前面にいる**ため、失敗を出す場所も登録画面になる。
#7(「やった」= 一覧に留まったまま書き込む)で初めて別チャネルが要る。
**#7 で `writeErrorProvider` を新設するときに、Riverpod 3 で legacy 扱いの `StateProvider` ではなく
`Notifier` ベースで作る**(#5 申し送り 3 の積み残し)。そのうえで `/sync-docs` に載せる。
