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

- [x] `lib/domain/item.dart` に `DoneLogId` を追加(design.md §1-1)
- [x] `lib/domain/item_repository.dart` に `addDoneLog` / `removeDoneLog` を追加(§1-2)
- [x] `lib/domain/past_date_record.dart` を新規作成(§1-3)と `test/domain/past_date_record_test.dart`(§6-1)

## フェーズ2: データ層とフェイク

- [x] `lib/data/item_repository_impl.dart` に `addDoneLog` / `removeDoneLog` / `_syncLastDoneAt` を追加(§2)
- [x] `test/support/fake_item_repository.dart` を履歴 ID つき・実装と同じ並び規則に変更し、2 メソッドを追加(§3)
- [x] `test/data/item_repository_impl_test.dart` に共有シナリオ 8 件と実装だけのテスト 2 件を追加(§6-2)

## フェーズ3: 状態管理層

- [x] `lib/state/record_past_date_result.dart` を新規作成(§4-1)
- [x] `lib/state/item_list_notifier.dart` に `todayLocalDate` / `recordPastDate` / `undoRecordPastDate` を追加(§4-2)
- [x] `test/state/item_list_notifier_test.dart` に「過去の日付で記録」グループを追加(§6-3)

## フェーズ4: UI 層

- [x] `lib/app.dart` を日本語ロケールに固定(§5-1)
- [x] `lib/ui/widgets/item_detail_sheet.dart` に「日付を指定して記録」を追加(§5-2)と `test/ui/widgets/item_detail_sheet_test.dart` の追従(§6-4)
- [x] `lib/ui/item_navigation.dart` にシートの結果の分岐・日付の選択・取り消し導線を追加(§5-3)
- [x] `test/ui/item_list_screen_test.dart` にウィジェットテスト 5 件を追加(§6-5)
- [x] `test/ui/screens/collection_screen_test.dart` にテスト 1 件を追加(§6-6)

## フェーズ5: 検証

- [x] `dart format --output=none --set-exit-if-changed <変更した Dart ファイル>` を通す(AGENTS.md に従い対象を限定)
- [x] キャッシュ内 Dart SDK の `dart analyze --fatal-infos <変更したファイル>` を通す(変更した Dart 16 ファイルで pass)
- [x] ~~`flutter test` を通す~~(理由: AGENTS.md の規定により sandbox では実行しない。関連テストはホスト側の司令塔 / CI に委ねる。既存テストがロケール変更で落ちたら §6-7 に従う)→ 検収で司令塔が `/check` を実施し 549 件 pass

---

## 実装後の振り返り

- 実装完了日: 2026-09-26
- 経路: `delegate-codex.sh impl` で tasklist 全体を 1 回で委託(ラベルなし。design.md にコードまで書き切ったため分割しなかった)。初回は denylist 検査(`.claude/settings.local.json`)で停止し、ユーザーが内容を確認のうえ承認して再実行
- 計画との差分: なし。§6-7(ロケール変更による既存テストの破損)は発生しなかった
- 検収: `/check` 549 件 pass / code-reviewer 0 critical・0 major・1 minor(モード B の作法に関する運用注記のみ。ユーザー判断で検収を実施したため対応不要)
- 申し送り: 依存追加(SDK 同梱でも)は委託先が行えないため、計画段階で司令塔が `pubspec` を更新しておくと委託が 1 回で通る。取り消しを「追加した行の ID」で持つ形は、今後の履歴系操作(F12 の拡張など)でも再利用できる
