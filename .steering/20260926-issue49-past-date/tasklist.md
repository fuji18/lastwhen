# タスクリスト: 過去の日付で記録する(F16 / Issue #49)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: 計画時に司令塔が実施済み

- [x] `docs/functional-design.md` / `docs/glossary.md` / `docs/architecture.md` に F16 の振る舞いを追記
- [x] `pubspec.yaml` に `flutter_localizations`(SDK 同梱)を追加し、`flutter pub get` で `pubspec.lock` を更新

## フェーズ1: ドメイン層

- [ ] `lib/domain/item.dart` に `DoneLogId` を追加(design.md §1-1)
- [ ] `lib/domain/item_repository.dart` に `addDoneLog` / `removeDoneLog` を追加(§1-2)
- [ ] `lib/domain/past_date_record.dart` を新規作成(§1-3)と `test/domain/past_date_record_test.dart`(§6-1)

## フェーズ2: データ層とフェイク

- [ ] `lib/data/item_repository_impl.dart` に `addDoneLog` / `removeDoneLog` / `_syncLastDoneAt` を追加(§2)
- [ ] `test/support/fake_item_repository.dart` を履歴 ID つき・実装と同じ並び規則に変更し、2 メソッドを追加(§3)
- [ ] `test/data/item_repository_impl_test.dart` に共有シナリオ 8 件と実装だけのテスト 2 件を追加(§6-2)

## フェーズ3: 状態管理層

- [ ] `lib/state/record_past_date_result.dart` を新規作成(§4-1)
- [ ] `lib/state/item_list_notifier.dart` に `todayLocalDate` / `recordPastDate` / `undoRecordPastDate` を追加(§4-2)
- [ ] `test/state/item_list_notifier_test.dart` に「過去の日付で記録」グループを追加(§6-3)

## フェーズ4: UI 層

- [ ] `lib/app.dart` を日本語ロケールに固定(§5-1)
- [ ] `lib/ui/widgets/item_detail_sheet.dart` に「日付を指定して記録」を追加(§5-2)と `test/ui/widgets/item_detail_sheet_test.dart` の追従(§6-4)
- [ ] `lib/ui/item_navigation.dart` にシートの結果の分岐・日付の選択・取り消し導線を追加(§5-3)
- [ ] `test/ui/item_list_screen_test.dart` にウィジェットテスト 5 件を追加(§6-5)
- [ ] `test/ui/screens/collection_screen_test.dart` にテスト 1 件を追加(§6-6)

## フェーズ5: 検証

- [ ] `dart format --output=none --set-exit-if-changed .` を通す
- [ ] `flutter analyze --fatal-infos` を通す
- [ ] `flutter test` を通す(委託先が sandbox で実行できない場合は理由を付けて打ち消し、検収側に委ねる)。既存テストがロケール変更で落ちたら §6-7 に従う

---

## 実装後の振り返り

(司令塔が記入する)
