# タスクリスト: 一覧の並びを相対経過度の降順にする(Issue #23 / F30)

> 設計は `design.md`。判断番号はそちらを参照。

## フェーズ1: 並び替えの純関数

- [ ] 1. `lib/state/item_order.dart` に `sortByRelativeElapsed` / `applyFixedOrder` を書く(判断1)
- [ ] 2. `test/state/item_order_test.dart` を書く(判断5-1。パフォーマンスの計測を含む)

## フェーズ2: 並びの確定タイミング

- [ ] 3. `ItemListNotifier` に `_fixedOrder` / `_ordered` / `refreshOrder` を足し、`build()` を差し替える(判断3)
- [ ] 4. `test/state/item_list_notifier_test.dart` に `group('並び順(F30)')` を足す(判断5-2)
- [ ] 5. `ItemListScreen` を `ConsumerStatefulWidget` にし、`AppLifecycleListener` で `refreshOrder` を呼ぶ(判断4)
- [ ] 6. `test/ui/item_list_screen_test.dart` に並び順・記録後に動かない・復帰で反映のテストを足す(判断5-3)
- [ ] 7. 登録順を前提にした既存テストがあれば追従する(判断5-4)

## フェーズ3: ドキュメントと検証

- [ ] 8. PRD / 機能設計を追記する(判断6)
- [ ] 9. `dart format` / `flutter analyze --fatal-infos` / `flutter test` を通す(判断7)

## 申し送り(振り返りで記入)
