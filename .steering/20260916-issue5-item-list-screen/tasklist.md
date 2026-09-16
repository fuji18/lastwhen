# タスクリスト: 一覧画面(Issue #5)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。
§5「触らないもの」に手を入れない(特に `test/support/fake_item_repository.dart`)。

## 実装: 状態管理層

- [ ] `lib/state/item_view.dart` を作成する(`ItemView` / `ItemView.from` / `toItemViews`。design.md §2.1)
- [ ] `lib/state/providers.dart` を作成する(Provider 3 本。§2.2)
- [ ] `lib/state/item_list_notifier.dart` を作成する(`ItemListNotifier` / `itemListProvider`。§2.3)

## 実装: ドメイン層(追記のみ)

- [ ] `lib/domain/elapsed_days.dart` の `DaysAgo` に `==` / `hashCode` を足す(§2.9。**他は触らない**)

## 実装: UI 層

- [ ] `lib/ui/widgets/done_button.dart` を作成する(56dp の確保。§2.6)
- [ ] `lib/ui/widgets/empty_state.dart` を作成する(§2.5)
- [ ] `lib/ui/widgets/item_row.dart` を作成する(`ItemRow` / `elapsedText`。§2.7)
- [ ] `lib/ui/screens/item_list_screen.dart` を作成する(4 状態の出し分け。§2.4)
- [ ] `lib/app.dart` の `_PlaceholderHome` を削除し `home` を `ItemListScreen` にする(§2.8)

## テスト

- [ ] `test/state/item_view_test.dart` を作成する(§3.2 のシナリオ 1〜4)
- [ ] `test/state/item_list_notifier_test.dart` を作成する(§3.1 のシナリオ 1〜8)
- [ ] `test/ui/item_list_screen_test.dart` を作成する(§3.3 のシナリオ 1〜8)
- [ ] `test/widget_test.dart` に Provider override を入れて更新する(§3.4)
- [ ] `test/architecture/layer_dependency_test.dart` に UI→data と state→Flutter の検査を足す(§3.5)
- [ ] `test/domain/elapsed_days_test.dart` に `DaysAgo` の等価性を 1 本足す(§3.6)

## 検証

- [ ] `dart format .` を実行し、差分が出ない状態にする
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る
- [ ] 受け入れ条件の自己点検: 「未実施の行に日付が出ていない」「経過日数が行内で最大・最も太い」「`DoneButton` が 56dp 以上」がテストで押さえられていることを確認する

## 振り返り(申し送り)

<!-- 実装後に司令塔が記入する -->

## ハーネス修復(メインセッションが直接行う)

<!-- main-edit-ok -->

**このマーカーは AGENTS.md の修復のためだけに付けた。** `AGENTS.md` は Codex への委託禁止領域
なので、司令塔か人間しか直せない。#5 の実装コード(`lib/` / `test/`)は従来どおり委託先が書く。

- [x] `AGENTS.md` の verify-probe を Flutter 用に直す(`node_modules/.bin/eslint` は
      この構成では永久に存在せず、委託が入口で必ず止まっていた)
- [x] `AGENTS.md` §2 の検証コマンド表を npm から Flutter のコマンドへ差し替える
- [x] `docs/template-dev/CHANGELOG.md` に記録する(CI の `record-hygiene` が要求する)
