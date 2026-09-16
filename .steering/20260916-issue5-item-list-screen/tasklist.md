# タスクリスト: 一覧画面(Issue #5)

design.md の §2〜§4 に従う。**設計判断が必要になったら実装を止めて司令塔に戻す。**
`pubspec.yaml` に依存を足す必要が出たときも同じく止める。
§5「触らないもの」に手を入れない(特に `test/support/fake_item_repository.dart`)。

## 実装: 状態管理層

- [x] `lib/state/item_view.dart` を作成する(`ItemView` / `ItemView.from` / `toItemViews`。design.md §2.1)
- [x] `lib/state/providers.dart` を作成する(Provider 3 本。§2.2)
- [x] `lib/state/item_list_notifier.dart` を作成する(`ItemListNotifier` / `itemListProvider`。§2.3)

## 実装: ドメイン層(追記のみ)

- [x] `lib/domain/elapsed_days.dart` の `DaysAgo` に `==` / `hashCode` を足す(§2.9。**他は触らない**)

## 実装: UI 層

- [x] `lib/ui/widgets/done_button.dart` を作成する(56dp の確保。§2.6)
- [x] `lib/ui/widgets/empty_state.dart` を作成する(§2.5)
- [x] `lib/ui/widgets/item_row.dart` を作成する(`ItemRow` / `elapsedText`。§2.7)
- [x] `lib/ui/screens/item_list_screen.dart` を作成する(4 状態の出し分け。§2.4)
- [x] `lib/app.dart` の `_PlaceholderHome` を削除し `home` を `ItemListScreen` にする(§2.8)

## テスト

- [x] `test/state/item_view_test.dart` を作成する(§3.2 のシナリオ 1〜4)
- [x] `test/state/item_list_notifier_test.dart` を作成する(§3.1 のシナリオ 1〜8)
- [x] `test/ui/item_list_screen_test.dart` を作成する(§3.3 のシナリオ 1〜8)
- [x] `test/widget_test.dart` に Provider override を入れて更新する(§3.4)
- [x] `test/architecture/layer_dependency_test.dart` に UI→data と state→Flutter の検査を足す(§3.5)
- [x] `test/domain/elapsed_days_test.dart` に `DaysAgo` の等価性を 1 本足す(§3.6)

## 検証

- [x] 変更した Dart ファイルのみ `dart format` を実行し、フォーマット確認で差分なし(ユーザー指示に従い全体フォーマットは実行しない)
- [x] `flutter analyze --no-pub --fatal-infos` が通る(変更した Dart 15 ファイルのみ。読み取り専用 SDK を `/tmp/lastwhen-flutter` にコピーして実行)
- [x] `flutter test` が通る(**ホスト側で実行**。86 件すべて成功。委託先の sandbox では走らなかった — 下記申し送り)
  - 関連6ファイルを `flutter test --no-pub` で実行したが、sandbox が `127.0.0.1` のサーバーソケット作成を拒否(`Operation not permitted`)し、全ファイルがテスト開始前に停止。司令塔の実行環境で再検証が必要。
- [x] 受け入れ条件の自己点検: 「未実施の行に日付が出ていない」「経過日数が行内で最大・最も太い」「`DoneButton` が 56dp 以上」がテストで押さえられていることを確認する

## 振り返り(申し送り)

### 1. Codex の sandbox では `flutter test` が走らない(#6 以降にも効く)

委託は `status=failed` / `exit 2` で終わったが、**原因は成果物ではなく実行環境**。
`flutter test` はテストランナーとの通信に localhost ソケットを作るため、
ネットワーク無効の sandbox では起動そのものができない。lint・型・format は sandbox 内で通っており、
ホスト側で `flutter analyze --fatal-infos`(No issues found)と `flutter test`(86 件成功)を
回して検収した。run record は `status=failed` のまま `accepted=true` にしてある
(**実際に起きたことを書き換えないため**。検収したのは司令塔だという事実を分けて残す)。

**このプロジェクトで impl を委託する限り、毎回 `status=failed` で返る。**
#6 以降は「委託先のテスト失敗 = 成果物の失敗」と読まないこと。
恒久対応(`.codex/` の sandbox 設定でループバックを許可する等)は別チケットの判断。

### 2. AGENTS.md がテンプレート既定(Node)のままで、委託が一度も成立しなかった

verify-probe が `node_modules/.bin/eslint` を、§2 の検証コマンド表が `npm run lint` 等を指していた。
`/kickoff` の Flutter 化で取り残されたもの。#5 の委託で初めて踏み、同じブランチで修復した
(`47442d7`)。`AGENTS.md` は Codex 委託禁止領域なので司令塔か人間しか直せない。

修復のため tasklist に `<!-- main-edit-ok -->` を追加して PreToolUse hook を解除している。
**#5 のマージ後は不要**なので、次にこのステアリングを触る機会があれば削除してよい。

### 3. `docs/functional-design.md` からの逸脱(`/sync-docs` 対象)

`ItemListNotifier` を `AsyncNotifier` ではなく **`StreamNotifier`** で実装した(design.md 判断1)。
機能設計書「コンポーネント設計」の記載が `AsyncNotifier` のままなので、次の `/sync-docs` で
実装に合わせて更新する。`writeErrorProvider` も同節に `StateProvider` と書かれているが、
**Riverpod 3 で `StateProvider` は legacy 扱い**(`flutter_riverpod/legacy.dart` からの import が要る)。
#6 で書き込みを入れるときに `Notifier` ベースへ置き換える判断が要る。

## ハーネス修復(メインセッションが直接行う)

<!-- main-edit-ok -->

**このマーカーは AGENTS.md の修復のためだけに付けた。** `AGENTS.md` は Codex への委託禁止領域
なので、司令塔か人間しか直せない。#5 の実装コード(`lib/` / `test/`)は従来どおり委託先が書く。

- [x] `AGENTS.md` の verify-probe を Flutter 用に直す(`node_modules/.bin/eslint` は
      この構成では永久に存在せず、委託が入口で必ず止まっていた)
- [x] `AGENTS.md` §2 の検証コマンド表を npm から Flutter のコマンドへ差し替える
- [x] `docs/template-dev/CHANGELOG.md` に記録する(CI の `record-hygiene` が要求する)
