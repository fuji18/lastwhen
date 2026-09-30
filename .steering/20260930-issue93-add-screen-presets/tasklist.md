# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**

---

## フェーズ1: 実装

- [ ] `lib/ui/screens/item_add_screen.dart` に `maxAddScreenTemplates` を足し、doc コメントとよくある項目の算出を直す(design §1 の 1〜3)
- [ ] 同ファイルの `body` を「スクロール + 画面下に固定した保存」にする(design §1 の 4)

## フェーズ2: テスト

- [ ] `test/ui/item_add_screen_test.dart` の既存 2 テストを直す(design §2)
- [ ] `test/ui/item_add_screen_test.dart` にテスト A・B を足す(design §2)
- [ ] `test/ui/accessibility_test.dart` にテスト C を足す(design §3)

## フェーズ3: docs

- [ ] `docs/product-requirements.md` の F17 行と追記(#93)(design §4)
- [ ] `docs/functional-design.md` の F17 節の登録画面の箇条とウィジェットテスト表(design §4)

## フェーズ4: 自己検証

- [ ] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / 変更したテストファイルの `flutter test` が通る

---

## 実装後の振り返り

(全タスク完了後に司令塔が記入)
