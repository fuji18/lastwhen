# タスクリスト: 記録の詳細画面(Issue #58)

> 仕様は `design.md`。**全タスクを `[x]` にするまで終了しない。** 不要になったタスクは理由つきで打ち消す。
> 書かれていない設計判断が要るときは止めて司令塔に戻す。

## フェーズ1: ドメインと状態

- [x] `distinctCalendarDatesOf` を追加し、`intervalDaysOf` をそれで書き直す(design §1)
- [x] `baseline_interval_test.dart` に `distinctCalendarDatesOf` のテストを足す(§5-1)
- [x] `DoneHistoryEntry` と `ItemView.history` / `historyTruncated` を追加し、`==` / `hashCode` に含める(§2)
- [x] `item_view_test.dart` に履歴のテストを足す(§5-2)

## フェーズ2: UI

- [x] `item_navigation.dart`: `openItemDetailScreen` / `recordPastDateWithUndo` / `markDoneWithUndo` に改める(§3)
- [x] `item_list_screen.dart` / `collection_screen.dart` を新しい関数に切り替え、コメントの「詳細シート」を直す(§3)
- [x] `item_detail_screen.dart` を作る(本文・メニュー・記録するボタン・削除時の removeRoute・戻るときの clearSnackBars)(§4)
- [x] `item_detail_sheet.dart` を削除する(§4)

## フェーズ3: テスト

- [x] `item_detail_sheet_test.dart` を削除し、`item_detail_screen_test.dart` を作る(§5-3)
- [x] 既存テスト(一覧・編集・図鑑・用語・アクセシビリティ)をシート → 画面に書き換える(§5-4)

## フェーズ4: docs

- [x] `docs/product-requirements.md`(F29 / 追記 #58 / F23 / F31)(§6)
- [x] `docs/functional-design.md`(記録の詳細節・画面遷移図・UC1b・通知・図鑑・テスト表)(§6)
- [x] `docs/glossary.md`(§6)
- [x] `docs/repository-structure.md`(§6)

## フェーズ5: 検証

- [x] `dart format --output=none --set-exit-if-changed .` が通る
- [x] `flutter analyze --fatal-infos` が通る
- [x] `flutter test` が通る
- [x] §7 の grep 条件を満たす

## 実装後の振り返り

- 実装完了日: 2026-09-28
- 計画と実績の差分: 設計どおり。implement-ticket の Sonnet fork 1 回で完走(判断待ち 0)。全画面 push に変わったことで一覧が offstage になり、既存テストの一部は「戻る」を挟んでから一覧を検証する形に直した。PopupMenu の中身は Overlay に載るため、図鑑テストの descendant 検索をグローバル検索に変えた
- 検収: モード B(econ)のため `/check` と `code-reviewer` は回さず CI に委ねる(fork 内で format / analyze / test 786 件 pass)
- 申し送り: 履歴は直近 10 件まで(ユーザー判断)。全件表示が要るならリポジトリに 1 項目分の全件クエリを足し、F23 と合わせて検討する。見た目(紙のカード・バッジ色 tertiaryContainer)は実機で要確認
