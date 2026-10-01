# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**

---

## フェーズ1: domain / state

- [x] `lib/domain/done_link.dart` を作る(design §1)
- [x] `lib/state/link_mark_done_result.dart` を作る(design §2)
- [x] `ItemListNotifier.markDoneFromLink` を足す(design §3)

## フェーズ2: UI・起動

- [x] `lib/ui/done_link_receiver.dart` を作る(design §4)
- [x] `lib/main.dart` / `lib/app.dart` / `lib/ui/screens/home_shell.dart` をつなぐ(design §5〜§7)
- [x] `lib/ui/item_navigation.dart` に `recordFromDoneLink` を足す(design §8)
- [x] 記録の詳細に「NFC タグに登録」メニューとダイアログを足す(design §9)
- [x] `item_list_screen.dart` のコメントを直す(design §10)
- [x] `AndroidManifest.xml` に intent-filter を足す(design §11)

## フェーズ3: テスト

- [x] `test/domain/done_link_test.dart`(design §T1)
- [x] `test/state/item_list_notifier_test.dart` に `markDoneFromLink` のテスト(design §T2)
- [x] `test/ui/done_link_receiver_test.dart`(design §T3)
- [x] `test/ui/done_link_flow_test.dart`(design §T4)
- [x] `test/ui/screens/item_detail_screen_test.dart` にダイアログのテスト(design §T5)
- [x] `test/ui/terminology_test.dart` の許可語(design §T6)

## フェーズ4: docs

- [x] `docs/product-requirements.md` に F32(design §D1)
- [x] `docs/functional-design.md` に UC1c・記録の詳細・セキュリティ(design §D2)
- [x] `docs/glossary.md` に NFC タグ(design §D3)

## フェーズ5: 自己検証

- [x] `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` が通る

---

## 申し送り

(振り返りで記入)
