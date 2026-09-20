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

- [ ] `lib/ui/widgets/done_button.dart` に必須引数 `semanticsLabel` を足し、
      `child` を `Text('やった', semanticsLabel: semanticsLabel)` に変える(§3 のコードをそのまま使う)
- [ ] `lib/ui/widgets/item_row.dart` を §4 のコードで全面的に置き換える
  - [ ] `itemRowStackThreshold` / `_referenceFontSize` の定数を置く
  - [ ] `_InlineLayout` / `_StackedLayout` / `_NameAndLastDone` / `_Elapsed` を追加する
  - [ ] `itemRowSemanticsLabel` / `doneButtonSemanticsLabel` を追加する
  - [ ] `elapsedText` は現行のまま変えない

## フェーズ2: 縦スクロールと装飾アイコン(design.md §5〜§8)

- [ ] `lib/ui/widgets/centered_scrollable.dart` を新規作成する(§5 のコードをそのまま使う)
- [ ] `lib/ui/widgets/empty_state.dart` を `CenteredScrollable` に載せ替え、
      `Icons.inbox_outlined` を `ExcludeSemantics` で包む(`Column` は 1 つのまま)
- [ ] `lib/ui/screens/item_list_screen.dart` の 3 箇所を直す
  - [ ] `CircularProgressIndicator` に `semanticsLabel: '読み込み中'` を付ける
  - [ ] `_LoadError` を `CenteredScrollable` に載せ替える
  - [ ] `_LoadError` の `Icons.error_outline` を `ExcludeSemantics` で包む
- [ ] `lib/ui/screens/item_add_screen.dart` の `body` を `SingleChildScrollView` 版に置き換える(§8)
- [ ] `lib/ui/screens/item_edit_screen.dart` の `body` を同じ形に置き換える(§8)

## フェーズ3: アクセシビリティの回帰テスト(design.md §9.1)

- [ ] `test/ui/accessibility_test.dart` を新規作成し、ヘルパー(`_app` / `_ellipsizedTexts` /
      `_NeverEmittingRepository` / `_FailingRepository`)を用意する
- [ ] コントラスト比のテストを書く(§1 の 9 ペア × light / dark、しきい値 4.5)
- [ ] 文字サイズ 100% / 150% / 200% で一覧の文字が省略されないテストを書く
- [ ] 長い項目名だけが 2 行で省略されるテストを書く
- [ ] 文字サイズ 200% で登録画面・編集画面が破綻しないテストを書く
- [ ] タッチターゲット(「やった」56dp 以上 / 行 48dp 以上)のテストを書く
- [ ] 片手操作(「やった」と FAB が画面の右半分)のテストを書く
- [ ] dark テーマで一覧が破綻しないテストを書く
- [ ] 読み上げラベル(行 / 「やった」ボタン / 読み込み中)のテストを書く
- [ ] 装飾アイコンが読み上げ対象外であるテストを書く(空状態 / 読み込みエラー)

## フェーズ4: パフォーマンスと用語のテスト(design.md §9.2・§9.3)

- [ ] `test/ui/performance_test.dart` を新規作成する
  - [ ] 100 件で構築される `ItemRow` が可視範囲に収まるテスト
  - [ ] 100 件をスクロールしても行数が増え続けないテスト
  - [ ] `_StatementCounter`(`QueryInterceptor`)で `from items` の SELECT が 1 本だけのテスト
  - [ ] 参考値として初回描画時間を `debugPrint` するテスト(assert は 5 秒の安全網のみ)
- [ ] `test/ui/terminology_test.dart` を新規作成する
  - [ ] 一覧(項目あり / 空)・登録・編集・削除確認ダイアログの描画文字列を検査する
  - [ ] 読み上げラベルの文字列を検査する

## フェーズ5: ドキュメント(design.md §10)

- [ ] `docs/development-guidelines.md` に `## パフォーマンス計測手順(実機)` を追記する
      (「テスト戦略」節の末尾 / `## コードレビュー基準` の直前)

## フェーズ6: 品質チェックと修正

- [ ] `dart format .` を通す
- [ ] `flutter analyze --fatal-infos` を通す
- [ ] `flutter test` の全件が通ることを確認する(**委託先はテストを回せないので、ここは検収側が回す**)
- [ ] 既存テストが落ちた場合、`design.md` §9.4 に従って原因を突き合わせてから期待値を直す
      (テストの削除・`skip` は禁止)
- [ ] `test/ui/performance_test.dart` が `debugPrint` した参考値を控える(PR ボディに転記する)

---

## 実装後の振り返り

### 実装完了日
{YYYY-MM-DD}

### 計画と実績の差分

**計画と異なった点**:
- {計画時には想定していなかった技術的な変更点}

**新たに必要になったタスク**:
- {実装中に追加したタスク}

**技術的理由でスキップしたタスク**(該当する場合のみ):
- {タスク名 / スキップ理由 / 代替実装}

### 学んだこと

**技術的な学び**:
- {実装を通じて学んだ技術的な知見}

**プロセス上の改善点**:
- {タスク管理で良かった点}

### 次回への改善提案
- {次回の機能追加で気をつけること}
