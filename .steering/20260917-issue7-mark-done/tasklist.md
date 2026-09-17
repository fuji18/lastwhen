# タスクリスト: 「やった」の記録と取り消し(Issue #7)

<!-- status: ready -->

> 進捗は実装中に随時更新する(`- [ ]` → `- [x]`)。技術的理由で不要になった項目は
> `- [x] ~~項目~~ (理由: ...)` の形で残す。**理由なくスキップしない。**
> 設計判断が要るものが出たら、推測せず停止して司令塔に戻す(`design.md` に無い判断は書かない)。

## バッチ1: 状態管理層

- [ ] `lib/state/mark_done_result.dart` を新規作成する(`design.md` §3 の通り。`add_item_result.dart` と同じ粒度のコメントを付ける)
- [ ] `ItemListNotifier.build()` に最新 `List<Item>` のキャッシュ(`_latestItems`)を足す(§4)
- [ ] `ItemListNotifier.markDone` / `undoMarkDone` を足す(§4)。**`state` を書かない**
- [ ] `test/state/item_list_notifier_test.dart` に §6-1 の 9 ケースを足す(既存ヘルパーを使う。`FakeItemRepository` は変更しない)

## バッチ2: UI 層

- [ ] `_ItemList` を `ConsumerWidget` にし、`onDonePressed` を `_handleDone` に結線する(§5-1)
- [ ] `_handleDone` / `_handleUndo` を `item_list_screen.dart` のトップレベル private 関数として足す(§5-2)
- [ ] `_openAddScreen` の先頭で `clearSnackBars()` を呼ぶ(§5-3)、`#7 で繋ぐ` などの古いコメントを始末する(§5-4)
- [ ] `test/ui/item_list_screen_test.dart` に §6-2 の 10 ケースを足す(`DoneButton` は行を特定して押す)

## バッチ3: 仕上げ

- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る(**委託先では実行できない。検収側 / CI が回す**)
- [ ] `requirements.md` の受け入れ条件を上から照合し、満たしていない行が無いことを確認する

## 変更しないもの(触ったら設計違反)

- `lib/domain/` / `lib/data/`(データ層の `markDone` / `restoreLastDoneAt` は #4 で完成済み)
- `lib/ui/widgets/`(`DoneButton` / `ItemRow` は #5 のまま)
- `lib/app.dart` / `pubspec.yaml` / `docs/` / `test/support/`
