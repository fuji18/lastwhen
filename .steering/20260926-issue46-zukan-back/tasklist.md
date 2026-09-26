# タスクリスト: 図鑑の検索中にシステムの戻るで検索を閉じる(Issue #46)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: ドキュメント(司令塔が計画時に実施済み)

- [x] `docs/functional-design.md`「図鑑(F31)」の検索の項に、システムの戻るの挙動を追記

## フェーズ1: 実装

- [x] `lib/ui/screens/collection_screen.dart` の `Scaffold` を `PopScope` で包む(design.md 判断1)
- [x] `test/ui/screens/collection_screen_test.dart` にヘルパー `recordSystemPops` とテスト 3 件を追加(design.md 判断2)

## フェーズ2: 検証

- [x] `dart format` と `flutter analyze --fatal-infos` を通す(変更した 2 ファイル。AGENTS.md に従いキャッシュ内の Dart SDK で format / analyze --fatal-infos を実行し、問題なし)
- [x] ~~`flutter test test/ui/screens/collection_screen_test.dart` を通す~~(理由: AGENTS.md の規約に従い、テストは sandbox では実行できないためホスト(`/check` / CI)に委ねた。テスト実行・合否確認は未実施)
