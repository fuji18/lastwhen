# タスクリスト: 一覧の並びを相対経過度の降順にする(Issue #23 / F30)

> 設計は `design.md`。判断番号はそちらを参照。

## フェーズ1: 並び替えの純関数

- [x] 1. `lib/state/item_order.dart` に `sortByRelativeElapsed` / `applyFixedOrder` を書く(判断1)
- [x] 2. `test/state/item_order_test.dart` を書く(判断5-1。パフォーマンスの計測を含む)

## フェーズ2: 並びの確定タイミング

- [x] 3. `ItemListNotifier` に `_fixedOrder` / `_ordered` / `refreshOrder` を足し、`build()` を差し替える(判断3)
- [x] 4. `test/state/item_list_notifier_test.dart` に `group('並び順(F30)')` を足す(判断5-2)
- [x] 5. `ItemListScreen` を `ConsumerStatefulWidget` にし、`AppLifecycleListener` で `refreshOrder` を呼ぶ(判断4)
- [x] 6. `test/ui/item_list_screen_test.dart` に並び順・記録後に動かない・復帰で反映のテストを足す(判断5-3)
- [x] 7. 登録順を前提にした既存テストがあれば追従する(判断5-4)

## フェーズ3: ドキュメントと検証

- [x] 8. PRD / 機能設計を追記する(判断6)
- [x] 9. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断7) — 変更した Dart 6 ファイルの format・analyze --fatal-infos は pass。テストは sandbox では実行できないためホストに委ねた。

## 申し送り(振り返りで記入)

- 実装: タスク 1〜8 完了。変更は本ファイルを含め 9 ファイル。コミットなし(econ)。
- 既存テスト: 複数項目の履歴に基づく登録順依存はなく、期待値の追従変更なし。
- 静的解析の指摘に従い、applyFixedOrder の null 除外を同じ意味の null-aware element に変更。
- ホスト検収: test/state/item_order_test.dart・test/state/item_list_notifier_test.dart・test/ui/item_list_screen_test.dart の実行後、タスク 9 を完了する。
- ホスト検収結果(2026-09-24): `dart format` 変更なし / `flutter analyze --fatal-infos` 問題なし / `flutter test` 全 332 件 pass(test-runner・code-reviewer の双方で確認)。code-reviewer 指摘は 0 critical / 0 major / 2 minor(うち 1 件は本タスク 9 の記録漏れで対応済み、1 件は確認結果のみ)。
