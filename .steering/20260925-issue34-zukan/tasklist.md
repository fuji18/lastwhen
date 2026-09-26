# タスクリスト: 下部ナビと図鑑画面(Issue #34 / F31)

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。未完了タスク(`[ ]`)を残したまま作業を終了しない
- スキップは技術的理由がある場合のみ。`- [x] ~~タスク名~~(理由: ...)` の形で残す
- `design.md` に無い設計判断が必要になったら、推測せず止めて報告する

---

## フェーズ0: ドキュメント(司令塔が計画時に実施済み)

- [x] PRD に F31 を追記(`docs/product-requirements.md` P2 表)
- [x] 機能設計の画面遷移図・「図鑑(F31)」節・パフォーマンス最適化を更新(`docs/functional-design.md`)
- [x] 用語集に「図鑑」を追記(`docs/glossary.md`)

## フェーズ1: 状態管理層

- [x] `lib/state/collection.dart` を新規作成(`collectionCategoryFilterProvider` / `collectionOf`)(design.md 判断1)
- [x] `test/state/collection_test.dart` を新規作成(design.md 判断7)

## フェーズ2: 共有部品の切り出し(振る舞いを変えないリファクタ)

- [x] `lib/ui/item_navigation.dart` を新規作成し、`_openDetailSheet` / `_openEditScreen` を公開関数として移す(判断2)
- [x] `lib/ui/widgets/load_error.dart` を新規作成し、`_LoadError` を `LoadError` として移す(判断3)
- [x] `lib/ui/screens/item_list_screen.dart` の呼び出しを差し替え、不要な import と移した定義を消す(判断2・3)

## フェーズ3: 図鑑

- [x] `lib/ui/widgets/collection_card.dart` を新規作成(定数・関数・`CollectionCard`)(判断6)
- [x] `test/ui/widgets/collection_card_test.dart` を新規作成(判断7)
- [x] `lib/ui/screens/collection_screen.dart` を新規作成(AppBar の検索切替・本体・空表示・グリッド)(判断5)

## フェーズ4: 下部ナビ

- [x] `lib/ui/screens/home_shell.dart` を新規作成(判断4)
- [x] `lib/app.dart` の `home` を `HomeShell` に変え、doc コメントを直す(判断4)
- [x] `item_list_screen.dart` のクラス doc を直す(判断4)
- [x] `test/ui/screens/collection_screen_test.dart` を新規作成(判断7)
- [x] `test/ui/terminology_test.dart` に図鑑タブの走査ケースを追加(判断7)

## フェーズ4.5: 副作用への対処(design.md 判断9)

- [x] `home_shell.dart` で図鑑だけを `ScaffoldMessenger` で包み、doc コメントを足す(判断9-1)
- [x] `collection_screen_test.dart` に「記録直後に登録画面へ遷移しても例外が出ない」回帰テストを足す(判断9-1)
- [x] `accessibility_test.dart` の `_ellipsizedTexts` でオフステージを走査から除く(判断9-2)

## フェーズ5: 品質チェックと修正

- [x] `dart format --output=none --set-exit-if-changed .` が通る
- [x] `flutter analyze --fatal-infos` が通る
- [x] `flutter test` が通る(508 件全て通過)
  - **判断9-2 の実装は design.md の提示コードから技術的に差し替えた。** design.md は
    `RenderOffstage` で非表示側を除く実装を提示していたが、実際の `IndexedStack` は
    `RenderOffstage` を経由せず `RenderIndexedStack` が直接 paint/hit-test/semantics を
    選択中の子だけに絞る実装だったため(`RenderOffstage` は 1 つもツリーに現れない)、
    素直に適用すると効果が無かった。設計の意図(「利用者に見えない側を数えない」)は
    明確なので、`test/ui/accessibility_test.dart` の `_ellipsizedTexts` を
    `RenderIndexedStack.visitChildrenForSemantics` と同じ考え方(`index` と
    `firstChild`/`childAfter` で選択中の子だけを訪問する)に書き換えて対応した。
    設計判断(何を作るか)ではなく提示コードの技術的な誤りの訂正と判断し、
    停止せずに進めた。

## フェーズ6: 振り返り

- [x] 実装後の振り返り(このファイルの下部に記録。司令塔が担当)

---

## 実装後の振り返り

### 実装完了日
2026-09-26

### 計画と実績の差分

- **Codex 委託から implement-ticket の fork(Sonnet)に切り替えた。** `delegate-codex.sh` の denylist 検査が
  `.claude/settings.local.json`(中身は MCP 設定と許可 1 件だけ)で止まり、承認つき再実行は Claude Code の自動モードに
  データ流出扱いで拒否された。ユーザーの指示で fork に変更
- **判断待ち 1 回(判断9 を追記)。** `IndexedStack` の両画面の `Scaffold` がともにルートとしてアプリの
  `ScaffoldMessenger` に登録され、取り消し導線がオフステージの図鑑にも複製されて Hero タグが衝突した。
  図鑑だけを専用の `ScaffoldMessenger` で包んで解消。計画時は「外枠を `Scaffold` にすると入れ子になる」ことだけを
  見ていて、「ルートの Scaffold が 2 つあると両方に配られる」ことを見落としていた
- **判断9-2 の提示コードは技術的に誤っていた。** `IndexedStack` は `RenderOffstage` を使わず `RenderIndexedStack` が
  直接選択中の子だけを描画するため、`RenderOffstage` 判定は効かない。fork が `RenderIndexedStack` の選択中の子だけを
  訪問する形に差し替えた(意図どおり)

### 学んだこと

- `ScaffoldMessenger` は登録済みの**ルートの** `Scaffold` 全部に `SnackBar` を配る。`IndexedStack` で画面を生かしたまま
  並べるときは、`SnackBar` を出さない側を専用の `ScaffoldMessenger` で包んで登録を切り離す
- `find` の既定(`skipOffstage`)は `IndexedStack` の非表示側を除くが、レンダーツリーを直接たどる自前の走査は除かない

### 次回への改善提案

- レンダーツリーの内部実装に依存するコードを design.md に書くときは、計画時に Flutter のソースで確かめるか、
  「意図だけを書き、実装手段は実装者に任せる」と明記する
- denylist 検査に `.claude/settings.local.json` が掛かる件は、自動モードでは承認つき再実行が通らない。
  委託の前にユーザーへ `!` 付きでの実行を案内する
