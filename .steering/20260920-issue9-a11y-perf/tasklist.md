# タスクリスト: アクセシビリティとパフォーマンスの仕上げ(Issue #9)

<!-- status: ready -->

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- 全てのタスクを `[x]` にする。未完了(`[ ]`)を残したまま終了しない
- スキップが許されるのは技術的理由のみ。その場合は
  `- [x] ~~タスク名~~(不要になった技術的理由)` と記録する
- 「時間の都合」「難しいから後回し」はスキップの理由にならない
- **`design.md` に書かれていない設計判断が必要になったら、推測せず停止して司令塔に報告する**

---

## フェーズ1: 読み上げラベルとボタン(design.md §3・§4)

- [x] `lib/ui/widgets/done_button.dart` に必須引数 `semanticsLabel` を足し、
      `child` を `Text('やった', semanticsLabel: semanticsLabel)` に変える(§3 のコードをそのまま使う)
- [x] `lib/ui/widgets/item_row.dart` を §4 のコードで全面的に置き換える
  - [x] `itemRowStackThreshold` / `_referenceFontSize` の定数を置く
  - [x] `_InlineLayout` / `_StackedLayout` / `_NameAndLastDone` / `_Elapsed` を追加する
  - [x] `itemRowSemanticsLabel` / `doneButtonSemanticsLabel` を追加する
  - [x] `elapsedText` は現行のまま変えない

## フェーズ2: 縦スクロールと装飾アイコン(design.md §5〜§8)

- [x] `lib/ui/widgets/centered_scrollable.dart` を新規作成する(§5 のコードをそのまま使う)
- [x] `lib/ui/widgets/empty_state.dart` を `CenteredScrollable` に載せ替え、
      `Icons.inbox_outlined` を `ExcludeSemantics` で包む(`Column` は 1 つのまま)
- [x] `lib/ui/screens/item_list_screen.dart` の 3 箇所を直す
  - [x] `CircularProgressIndicator` に `semanticsLabel: '読み込み中'` を付ける
  - [x] `_LoadError` を `CenteredScrollable` に載せ替える
  - [x] `_LoadError` の `Icons.error_outline` を `ExcludeSemantics` で包む
- [x] `lib/ui/screens/item_add_screen.dart` の `body` を `SingleChildScrollView` 版に置き換える(§8)
- [x] `lib/ui/screens/item_edit_screen.dart` の `body` を同じ形に置き換える(§8)

## フェーズ3: アクセシビリティの回帰テスト(design.md §9.1)

- [x] `test/ui/accessibility_test.dart` を新規作成し、ヘルパー(`_app` / `_ellipsizedTexts` /
      `_NeverEmittingRepository` / `_FailingRepository`)を用意する
- [x] コントラスト比のテストを書く(§1 の 9 ペア × light / dark、しきい値 4.5)
- [x] 文字サイズ 100% / 150% / 200% で一覧の文字が省略されないテストを書く
- [x] 長い項目名だけが 2 行で省略されるテストを書く
- [x] 文字サイズ 200% で登録画面・編集画面が破綻しないテストを書く
- [x] タッチターゲット(「やった」56dp 以上 / 行 48dp 以上)のテストを書く
- [x] 片手操作(「やった」と FAB が画面の右半分)のテストを書く
- [x] dark テーマで一覧が破綻しないテストを書く
- [x] 読み上げラベル(行 / 「やった」ボタン / 読み込み中)のテストを書く
- [x] 装飾アイコンが読み上げ対象外であるテストを書く(空状態 / 読み込みエラー)

## フェーズ4: パフォーマンスと用語のテスト(design.md §9.2・§9.3)

- [x] `test/ui/performance_test.dart` を新規作成する
  - [x] 100 件で構築される `ItemRow` が可視範囲に収まるテスト
  - [x] 100 件をスクロールしても行数が増え続けないテスト
  - [x] `_StatementCounter`(`QueryInterceptor`)で `from items` の SELECT が 1 本だけのテスト
  - [x] 参考値として初回描画時間を `debugPrint` するテスト(assert は 5 秒の安全網のみ)
- [x] `test/ui/terminology_test.dart` を新規作成する
  - [x] 一覧(項目あり / 空)・登録・編集・削除確認ダイアログの描画文字列を検査する
  - [x] 読み上げラベルの文字列を検査する

## フェーズ5: ドキュメント(design.md §10)

- [x] `docs/development-guidelines.md` に `## パフォーマンス計測手順(実機)` を追記する
      (「テスト戦略」節の末尾 / `## コードレビュー基準` の直前)

## フェーズ6: 品質チェックと修正

- [x] `dart format .` を通す(AGENTS.md に従い、変更した Dart 10 ファイルのみ直接 SDK で format・確認済み)
- [x] `flutter analyze --fatal-infos` を通す(AGENTS.md に従い、変更した Dart 10 ファイルを直接 SDK の `dart analyze --fatal-infos` で個別検査し、全て pass)
- [x] `flutter test` の全件が通ることを確認する(**委託先はテストを回せないので、ここは検収側が回す**)
      → 2026-09-21 に **186 件すべてパス**(format 0 変更 / analyze No issues)
- [x] ~~既存テストが落ちた場合、`design.md` §9.4 に従って原因を突き合わせてから期待値を直す~~
      (既存テストは 1 件も落ちなかったため不要。落ちた 6 件はすべて今回追加した新規テストで、
      原因は design.md §12・§13 の設計ミス)
- [x] `test/ui/performance_test.dart` が `debugPrint` した参考値を控える(PR ボディに転記する)
      → **100 件の初回描画 67ms**(デバッグ / `flutter test` / Linux x64 devcontainer)

## フェーズ7: 検収で判明したテストの修正(design.md §12)

> 2026-09-21 にホスト上で `flutter test` を回した結果、**6 件が失敗**した。
> **原因はすべて §9 に書いたテストの検出方法の誤りで、実装の欠陥ではない。**
> **`lib/ui/` は 1 行も変更しない。** 直すのは `test/ui/` の 2 ファイルだけ。

- [x] `test/ui/accessibility_test.dart` に `_semanticsLabels` ヘルパーを追加する(design.md §9.1)
  - [x] `import 'package:flutter/semantics.dart';` を足す
  - [x] 行の読み上げラベルの検証を `expect(_semanticsLabels(tester), contains('...'))` に置き換える
  - [x] 「やった」ボタンの読み上げラベルの検証を同じ形に置き換える
  - [x] 読み込み中のインジケータのラベルの検証を同じ形に置き換える
  - [x] 使われなくなった `find.bySemanticsLabel` を残さない
- [x] `test/ui/performance_test.dart` のクエリ判定を
      `RegExp(r'from\s+"?items"?', caseSensitive: false)` に置き換える(design.md §9.2)
- [x] `dart format` / `dart analyze --fatal-infos` を変更した 2 ファイルに通す

## フェーズ8: セマンティクスハンドルの後始末(design.md §13)

> 検収 2 回目。残る失敗 5 件は `A SemanticsHandle was active at the end of the test.` で、
> **アサーションはすべて通っている**。直すのは後始末の書き方 1 点だけ。
> **`lib/` も `_semanticsLabels` も変更しない。**

- [x] `test/ui/accessibility_test.dart` の `addTearDown(handle.dispose)` 3 箇所を
      テスト本体末尾の `handle.dispose();` に置き換える(274 / 289 / 303 行目付近)
- [x] `dart format` / `dart analyze --fatal-infos` を通す

---

## 実装後の振り返り

### 実装完了日
2026-09-21

### 計画と実績の差分

**計画と異なった点**:
- **実装(`lib/ui/`)は 1 回の委託で完成し、以降 1 行も直していない。** 往復 3 回のうち
  2 回目・3 回目はすべて**テストの書き方**の修正だった
- 落ちた 6 件はすべて今回追加した新規テストで、原因は司令塔が §9 に書いた検証方法の誤り。
  既存テストは 1 件も落ちなかった(レイアウトを全面的に組み替えたにもかかわらず)

**新たに必要になったタスク**:
- フェーズ7(design.md §12): drift のクエリ判定と読み上げラベルの検出方法の修正
- フェーズ8(design.md §13): `addTearDown(handle.dispose)` → テスト本体末尾の `handle.dispose()`

**技術的理由でスキップしたタスク**:
- 実機ベースのパフォーマンス計測(コールドスタート 1.5 秒 / 100 件初回描画 300ms / 60fps)
  - スキップ理由: devcontainer に Android 端末・エミュレータ・`adb` が無く、
    リリースビルドで測れない(`flutter devices` で確認。検出は Linux desktop のみ)
  - 代替実装: `test/ui/performance_test.dart`(遅延生成・クエリ本数・参考値)と
    `docs/development-guidelines.md`「パフォーマンス計測手順(実機)」。
    ユーザー承認済み。PR ボディに計測環境と未実施の理由を明記する

### 学んだこと

**技術的な学び**:
- `ColorScheme.fromSeed` は使用ペアすべてで AA を満たしていた(最小 5.02:1)。
  **「足りないはず」と決めてかからず先に測ったことで、色をいじる作業が丸ごと消えた**
- 逆に、**製品の中心要素である経過日数が文字サイズ 100% でも省略されていた**。
  個別チケットの受け入れ条件では拾えず、横断チケットで初めて見つかった
- `tester.ensureSemantics()` のハンドルは `addTearDown` で解放できない。
  Flutter の検査がテスト本体直後に走るため、本体末尾で `dispose()` する
- drift は `FROM "items"` と二重引用符付きで SQL を出す

**プロセス上の改善点**:
- **計画前に実測した数値(省略の有無・コントラスト比・ボタン実寸)を design.md に表で残したのが効いた。**
  委託先が測り直す必要が無く、判断の根拠も後から追える
- **一方、テストの検証方法は実測せずに書いたため 2 回差し戻した。** 往復 3 回のうち 2 回はこれが原因

### 次回への改善提案
- **design.md にテストの検証 API を書くときは、計画段階で 1 回動かして確かめる。**
  実装コードは実測値に基づいて書けたのに、テストコードは推測で書いたために往復が増えた。
  「使ったことのない検証 API を仕様に書くときは、捨てプローブで 1 回叩く」を計画フェーズの作法にする
- 非機能要件の横断チケットは、**修正より先に計測を置く**。今回は計測で作業量が半分になった
