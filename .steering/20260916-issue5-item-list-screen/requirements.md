# 要求: 一覧画面 — 項目の表示と空状態(Issue #5)

対象 Issue: #5(P0 / フェーズ2)
根拠: `docs/functional-design.md`「コンポーネント設計」「画面遷移図」「UI設計」「パフォーマンス最適化」「エラーハンドリング」/ `docs/architecture.md`「レイヤードアーキテクチャ」/ `docs/repository-structure.md`「lib/」「test/」/ `docs/ui-design-guidelines.md` §5〜§7 / `docs/glossary.md`「項目の表示状態」「表記ゆれの禁止一覧」

## 背景

F1(一覧表示)・F4(最終実施日の表示)・F5(経過日数の表示)を満たす。

#3 でドメイン(`Item` / `elapsedDays` / `ElapsedLabel` / `Clock`)を、#4 でデータ層
(`ItemRepositoryImpl` と `FakeItemRepository`)を置いた。**このチケットで初めて 4 層が
上から下まで繋がり、「アプリを開けば経過日数が並ぶ」という製品価値が形になる。**

`lib/state/` はこのチケットで新設される。**以降の #6(登録)・#7(記録)・#8(編集・削除)は
すべてこの層に操作メソッドを足す形で進む**ため、ここで置くパターンが後続 3 チケットの型になる。

## スコープ(やること)

| 成果物 | 内容 |
| --- | --- |
| `lib/state/item_view.dart` | UI 向け表示モデル `ItemView` |
| `lib/state/providers.dart` | `AppDatabase` / `ItemRepository` / `Clock` の Provider |
| `lib/state/item_list_notifier.dart` | 一覧の状態(**読み取りのみ**)と `itemListProvider` |
| `lib/ui/screens/item_list_screen.dart` | 一覧画面(loading / error / empty / data の 4 状態) |
| `lib/ui/widgets/item_row.dart` | 一覧の 1 行 |
| `lib/ui/widgets/done_button.dart` | 「やった」ボタン(**配置のみ。動作は #7**) |
| `lib/ui/widgets/empty_state.dart` | 項目 0 件のときの表示 |
| `lib/app.dart` | 仮画面を `ItemListScreen` に差し替える |
| `lib/domain/elapsed_days.dart` | `DaysAgo` に値等価を足す(design.md 判断8) |
| `test/state/item_list_notifier_test.dart` | 変換ロジックのテスト(Drift を起動しない) |
| `test/ui/item_list_screen_test.dart` | ウィジェットテスト(空状態・項目あり) |
| `test/widget_test.dart` | Provider override を入れて更新する |
| `test/architecture/layer_dependency_test.dart` | UI→data / state→Flutter の禁止を追加する |
| `test/domain/elapsed_days_test.dart` | `DaysAgo` の等価性を追加する |

## スコープ外(やらないこと)

- **「やった」ボタンの動作**(#7)。配置と 56dp の確保だけを行う
- **空状態の導線から登録画面への遷移**(#6)。ボタンの配置とコールバックの口だけを作る
- **`FloatingActionButton`(追加ボタン)**(#6 のスコープに明記されている)
- 項目の追加(#6)・編集と削除(#8)
- `ItemListNotifier` の書き込みメソッド(`addItem` / `markDone` / `undoMarkDone` / `deleteItem`)
- `writeErrorProvider`(書き込み失敗の伝達。最初の書き込みが入る #6 で置く)
- 並び替え・カテゴリ・アイコン・目安期間による色分け(P1)
- 文字サイズ 200% の作り込みと 100 件のパフォーマンス実測(#9)
- `pubspec.yaml` への依存追加(既存の `intl` / `flutter_riverpod` だけで足りる)

## 受け入れ条件(Issue #5 より)

- [ ] アプリ起動後、他の画面を経由せず一覧画面が表示される
- [ ] 各行に「項目名」「経過日数」「最終実施日」「やったボタン」が表示される
- [ ] **経過日数が行内で最も大きく、最も太い**
- [ ] 最終実施日は経過日数より小さく、補助情報として表示される
- [ ] 最終実施日が `2026年9月12日` 形式で表示される(`intl` の `DateFormat` を使う)
- [ ] 経過日数が `今日` / `昨日` / `42日前` / `未実施` で表示される
- [ ] **未実施の項目には日付を出さない**
- [ ] 項目が 0 件のとき、空状態と新規登録への導線が画面中央に表示される
- [ ] やったボタンが行の**右側**(親指の可動域)に配置され、**56dp 以上**ある
- [ ] `ListView.builder` で遅延生成され、100 件でもスクロールが引っかからない
- [ ] `Clock.now()` の呼び出しが一覧の再構築ごとに 1 回にまとまっている(行ごとに呼ばない)
- [ ] 色・余白・タイポがすべて `Theme.of(context)` 経由で取得されている
- [ ] UI 層が `lib/data/` と Drift の型を import していない
- [ ] `lib/state/` が `BuildContext` / `Widget` に依存していない
- [ ] ウィジェットテストで空状態と項目ありの両方が検証されている
- [ ] `flutter analyze --fatal-infos` と `flutter test` が通る

## 制約

- **追加の UI パッケージを入れない**(`CLAUDE.md`)。Material 3 の組み合わせで作る
- **色・余白・タイポは `Theme.of(context)` 経由**。ウィジェットに生の値を書かない
- **UI 層で `DateTime.now()` を呼ばない**(`docs/architecture.md`「UI レイヤー」の禁止事項)
- **UI 層で経過日数を計算しない。** 計算済みの `ItemView` を描画するだけにする
- 用語は `docs/glossary.md`「表記ゆれの禁止一覧」に従う。**「未実施」を「0日前」と書かない**
- 楽観的 UI 更新を採らない(このチケットは読み取りのみなので該当箇所は無いが、
  #7 で `markDone` を足すときにこの Notifier の形が前提になる)
