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

- [ ] `lib/state/collection.dart` を新規作成(`collectionCategoryFilterProvider` / `collectionOf`)(design.md 判断1)
- [ ] `test/state/collection_test.dart` を新規作成(design.md 判断7)

## フェーズ2: 共有部品の切り出し(振る舞いを変えないリファクタ)

- [ ] `lib/ui/item_navigation.dart` を新規作成し、`_openDetailSheet` / `_openEditScreen` を公開関数として移す(判断2)
- [ ] `lib/ui/widgets/load_error.dart` を新規作成し、`_LoadError` を `LoadError` として移す(判断3)
- [ ] `lib/ui/screens/item_list_screen.dart` の呼び出しを差し替え、不要な import と移した定義を消す(判断2・3)

## フェーズ3: 図鑑

- [ ] `lib/ui/widgets/collection_card.dart` を新規作成(定数・関数・`CollectionCard`)(判断6)
- [ ] `test/ui/widgets/collection_card_test.dart` を新規作成(判断7)
- [ ] `lib/ui/screens/collection_screen.dart` を新規作成(AppBar の検索切替・本体・空表示・グリッド)(判断5)

## フェーズ4: 下部ナビ

- [ ] `lib/ui/screens/home_shell.dart` を新規作成(判断4)
- [ ] `lib/app.dart` の `home` を `HomeShell` に変え、doc コメントを直す(判断4)
- [ ] `item_list_screen.dart` のクラス doc を直す(判断4)
- [ ] `test/ui/screens/collection_screen_test.dart` を新規作成(判断7)
- [ ] `test/ui/terminology_test.dart` に図鑑タブの走査ケースを追加(判断7)

## フェーズ5: 品質チェックと修正

- [ ] `dart format --output=none --set-exit-if-changed .` が通る
- [ ] `flutter analyze --fatal-infos` が通る
- [ ] `flutter test` が通る(委託先で回せない場合は検収側 = CI に委ねる。`AGENTS.md` §2)

## フェーズ6: 振り返り

- [ ] 実装後の振り返り(このファイルの下部に記録。司令塔が担当)

---

## 実装後の振り返り

### 実装完了日
{YYYY-MM-DD}

### 計画と実績の差分

### 学んだこと

### 次回への改善提案
