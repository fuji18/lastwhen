# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**

---

## フェーズ1: 実装

- [x] `lib/ui/screens/item_add_screen.dart` に `maxAddScreenTemplates` を足し、doc コメントとよくある項目の算出を直す(design §1 の 1〜3)
- [x] 同ファイルの `body` を「スクロール + 画面下に固定した保存」にする(design §1 の 4)

## フェーズ2: テスト

- [x] `test/ui/item_add_screen_test.dart` の既存 2 テストを直す(design §2)
- [x] `test/ui/item_add_screen_test.dart` にテスト A・B を足す(design §2)
- [x] `test/ui/accessibility_test.dart` にテスト C を足す(design §3)

## フェーズ3: docs

- [x] `docs/product-requirements.md` の F17 行と追記(#93)(design §4)
- [x] `docs/functional-design.md` の F17 節の登録画面の箇条とウィジェットテスト表(design §4)

## フェーズ3.5: 追補(Codex 委託の検収で判明)

- [x] `test/ui/accessibility_test.dart` のテスト C の MediaQuery をビューから作る形に直す(design §5 判断7)

## フェーズ4: 自己検証

- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / 変更したテストファイルの `flutter test` が通る
  - Codex: AGENTS.md に従い、変更した Dart 3 ファイルのみを SDK 内の Dart で analyze --fatal-infos / format 確認し、すべて pass。関連テストは sandbox では実行できないためホストに委ねた。
  - ホストで確認: `dart format --output=none --set-exit-if-changed lib/ui/screens/item_add_screen.dart test/ui/item_add_screen_test.dart test/ui/accessibility_test.dart` pass / `flutter analyze --fatal-infos` 同 3 ファイル pass / `flutter test test/ui/item_add_screen_test.dart test/ui/accessibility_test.dart` 47 件すべて pass

---

## 実装後の振り返り

- 実装完了日: 2026-09-30
- 計画と実績の差分:
  - Codex 委託 1 回目は `.claude/settings.local.json` の機密検出で exit 2(#92 と同じ)。中身に機密が無いことを確認し、ユーザーが ACK 付きで再実行した。2 回目で 7/8 完了(sandbox でテスト不可のため判断待ち)
  - ホストで変更テストを回すとテスト C だけ失敗。原因は設計の穴で、`MediaQuery(data: const MediaQueryData(...))` がビューの `viewInsets` を空で上書きし、キーボードが無い扱いになっていた(保存の下端 624dp)。判断7 を追補し、implement-ticket の Sonnet fork 1 回で修正、47 件通過
  - モード B のため `/check` と `code-reviewer`(§6)は未実施。CI と、枠が戻ってからのレビューに委ねる
- 申し送り:
  - テストで文字サイズだけ変えたいときは `MediaQueryData.fromView(tester.view).copyWith(textScaler: ...)` を使う。`const MediaQueryData(...)` で包むと画面サイズ・`viewInsets`・`padding` がすべて 0 になり、キーボードや SafeArea を見るテストが素通りする。既存の「文字サイズ 200% で編集/登録画面が破綻しない」も同じ書き方なので、寸法を検査に足すときは要注意
  - 編集画面(`item_edit_screen.dart`)の保存は今もスクロールの中にある。自動でキーボードを出さない(判断15)ため今は問題になっていないが、実機で押し出されるなら別チケットで同じ形(画面下に固定)に揃える
