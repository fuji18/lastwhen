# 設計書: 追加画面のよくある項目を減らし、保存ボタンを常に見せる(#93)

<!-- status: ready -->

## アーキテクチャ概要

UI 層の 1 画面(`lib/ui/screens/item_add_screen.dart`)だけの変更。domain / data / state は触らない。
`ItemTemplateChips` ウィジェット・空状態(`empty_state.dart`)・編集画面も触らない。

## 設計判断(確定事項。実装者は変えない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | 追加画面に出すよくある項目は **3 件まで** | 360dp 幅で 2 行に収まり、項目名・アイコン・カテゴリの入力欄を押し出さない |
| 2 | 出す 3 件は **登録済みと同名のものを除いた後の先頭から**(`availableItemTemplates(...)` の結果を `take(3)`) | 先に 3 件へ絞ってから除くと、登録が進むほどチップが減って 0 件になる。除いてから絞れば残りがある限り 3 件出る |
| 3 | 「もっと見る」は **付けない**(単に減らす) | 開閉の状態と操作が 1 つ増える。残りは登録が進むと自然に繰り上がって出る。空状態には 6 件そのまま残る |
| 4 | 「保存」は **画面下に固定**する。本文(入力欄・チップ・アイコン・カテゴリ)だけをスクロールさせ、`FilledButton` はスクロールの外に置く | `Scaffold` の `resizeToAvoidBottomInset`(既定 true)で本文の高さがキーボードの分だけ縮むので、ボタンはキーボードの直上に来る。親指の届く位置に残り、編集画面と同じ `FilledButton` の見た目を保てる |
| 5 | AppBar の `actions` には保存を **置かない**(両方にもしない) | 文字サイズ 200% で AppBar に「項目を追加」とボタンが並ぶと 360dp 幅に収まらない。保存が 2 つあると読み上げ・テストの両方で紛らわしい |
| 6 | 数の上限は `item_add_screen.dart` のトップレベル定数 `maxAddScreenTemplates = 3` に置く | 画面の見せ方の値なので domain には置かない。テストから参照するため公開にする |

既存の判断は変えない: 保存中は二度押しを塞ぐ(`_isSaving`)・保存完了を待ってから戻る・チップのタップは入力欄に入れるだけで保存しない。

## 実装内容

### §1 `lib/ui/screens/item_add_screen.dart`

1. import の下、クラス宣言の前にトップレベル定数を足す:

   ```dart
   /// 登録画面に出すよくある項目の上限(#93)。多く並べると「保存」が画面外へ押し出される。
   /// 空状態(`EmptyState`)は画面に余裕があるので上限を設けない。
   const int maxAddScreenTemplates = 3;
   ```

2. クラスの doc コメント末尾の文「よくある項目(F17)を選ぶと項目名とアイコンが入る。登録済みと同名のものは出さない。」を次に置き換える:

   ```dart
   /// よくある項目(F17)を選ぶと項目名とアイコンが入る。登録済みと同名のものを除いた先頭
   /// [maxAddScreenTemplates] 件だけ出す。「保存」は画面下に固定し、キーボード表示中も見せる(#93)。
   ```

3. `build` の `templates` の算出を次にする(除いてから絞る = 判断2):

   ```dart
   final templates = items == null
       ? const <ItemTemplate>[]
       : availableItemTemplates(
           items.map((item) => item.name),
         ).take(maxAddScreenTemplates).toList();
   ```

4. `body` の構造を次にする(判断4)。`SafeArea` の直下を `Column` にし、既存の `SingleChildScrollView` を `Expanded` で包む。
   スクロール内の `Column` の children からは **末尾の `const SizedBox(height: 24)` と `FilledButton` を取り除き**、
   `ItemCategoryPicker` で終える。取り除いた `FilledButton` はスクロールの外、`Padding` の中に置く:

   ```dart
   body: SafeArea(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
         Expanded(
           child: SingleChildScrollView(
             padding: const EdgeInsets.all(16),
             child: Column(
               // (既存どおり。children は TextField 〜 ItemCategoryPicker)
             ),
           ),
         ),
         // スクロールの外に置き、キーボード表示中も直上に見せる(#93)。
         Padding(
           padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
           child: FilledButton(
             onPressed: _isSaving ? null : _save,
             child: const Text('保存'),
           ),
         ),
       ],
     ),
   ),
   ```

   - スクロール内 `Column` の既存コメント(`// スクロールビューの中では高さが無限になるので min を明示する。`)と `mainAxisSize: MainAxisSize.min` はそのまま残す
   - `Scaffold` に `resizeToAvoidBottomInset` を書かない(既定の true に頼る)
   - 余白は 4 の倍数(8 / 16)。生の色・文字スタイルは足さない

それ以外(`_save` / `_applyTemplate` / `_handleChanged` / AppBar)は変えない。

### §2 テスト: `test/ui/item_add_screen_test.dart`

既存テストの修正:

- **「よくある項目のタップで項目名とアイコンが入り保存で登録される」**: `'布団干し'` は 4 件目以降になり出なくなるので、
  3 件目の `'エアコン掃除'` に替える。アイコンの期待値は `ItemIcon.bed` → `ItemIcon.airConditioner`。
  `items.single.name` / `items.single.icon` の期待値も同様に替える
- **「登録済みと同名のよくある項目は出ない」**: `findsNWidgets(5)` → `findsNWidgets(maxAddScreenTemplates)`。
  `'美容院'` が出ないことの検査は残し、繰り上がった `'歯医者'` が出ることを足す:
  `expect(find.widgetWithText(ActionChip, '歯医者'), findsOneWidget);`

追加するテスト(ファイル末尾の `main` 内。`openAddScreen` を使う):

- **テスト A「登録画面のよくある項目は先頭から上限の件数だけ出る」**: 項目 0 件で `openAddScreen`。
  `ItemTemplateChips` 配下の `ActionChip` が `findsNWidgets(maxAddScreenTemplates)`。
  `itemTemplates.take(maxAddScreenTemplates)` の各 `name` について `find.widgetWithText(ActionChip, name)` が `findsOneWidget`。
  `itemTemplates.skip(maxAddScreenTemplates)` の各 `name` について `ItemTemplateChips` 配下に無い
  (`find.descendant(of: find.byType(ItemTemplateChips), matching: find.text(name))` が `findsNothing`)
- **テスト B「小さい画面でキーボード表示中も保存が見える」**: 画面を 360×640dp にする
  (`tester.view.physicalSize = const Size(360 * 3, 640 * 3); tester.view.devicePixelRatio = 3; addTearDown(tester.view.reset);`)。
  `openAddScreen` の後で `tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);` としてキーボードを模し、`await tester.pumpAndSettle();`。
  **`ensureVisible` もスクロールもせずに**:
  - `final save = find.widgetWithText(FilledButton, '保存');`
  - `expect(save.hitTestable(), findsOneWidget);`
  - `expect(tester.getRect(save).bottom, lessThanOrEqualTo(640 - 280));`
  - `expect(tester.takeException(), isNull);`
  - 続けて `TextField` に `'洗車'` を `enterText` し、`save` をタップ → `pumpAndSettle` → `repository.watchAll().first` の `single.name` が `'洗車'`(固定した保存がそのまま動く)

### §3 テスト: `test/ui/accessibility_test.dart`

既存のループ「文字サイズ 200% で編集/登録画面が破綻しない」は変えない。その直後(ループの外)に 1 件足す:

- **テスト C「文字サイズ 200% でキーボード表示中も登録画面の保存が押せる」**: `_setScreenSize(tester);`(360×640)の後、
  `tester.view.viewInsets = const FakeViewPadding(bottom: 280 * 3);`。
  既存ループの登録画面側と同じ `MediaQuery(textScaler: TextScaler.linear(2))` + `ProviderScope` + `MaterialApp(theme: AppTheme.light(), home: const ItemAddScreen())` を
  `pumpWidget` して `pumpAndSettle`(リポジトリへの事前登録は不要)。**`ensureVisible` せずに**:
  - `final save = find.widgetWithText(FilledButton, '保存');`
  - `expect(save.hitTestable(), findsOneWidget);`
  - `expect(tester.getRect(save).bottom, lessThanOrEqualTo(640 - 280));`
  - `expect(_ellipsizedTexts(tester), isEmpty);`
  - `expect(tester.takeException(), isNull);`

  注意: `viewInsets` は `_setScreenSize` の `addTearDown(tester.view.reset)` で一緒に戻る(`reset` は `viewInsets` も戻す)。追加の tearDown は不要。

### §4 docs

- `docs/product-requirements.md` の F17 行(`| F17 | よくある項目のワンタップ追加 |`)の
  「登録画面ではタップで項目名とアイコンを入力欄に入れる。」を
  「登録画面では登録済みを除いた先頭 3 件を出し、タップで項目名とアイコンを入力欄に入れる。」に置き換える
- 同ファイルの「> **追記(#67)**: F17 を P2 から P1 に前倒しした。…」の引用ブロックの直後(空行 1 つを挟む)に次の引用ブロックを足す:

  ```markdown
  > **追記(#93)**: 登録画面のよくある項目は 3 件までにした。6 件並べると「保存」が画面外へ押し出され、スクロールしないと
  > 保存できなかった(#90 の実機確認)。「保存」も画面下に固定し、キーボード表示中も見えるようにした。空状態は画面に余裕があり
  > ワンタップ追加の主な入口なので 6 件のまま残す。
  ```

- `docs/functional-design.md`「### よくある項目(F17)」節の「- **登録画面**: …」の箇条を次に置き換える(2 行の折り返しを含めて全体を差し替える):

  ```markdown
  - **登録画面**: 項目名の下に「よくある項目から選ぶ」とチップを並べる。**出すのは登録済みを除いた先頭 3 件まで**
    (`maxAddScreenTemplates`。空状態は 6 件のまま。#93)。**タップで項目名とアイコンを入力欄に入れるだけ**で、
    保存は「保存」ボタン。カテゴリの選択は変えない。「保存」はスクロールの外で画面下に固定し、キーボード表示中もその直上に見せる
  ```

- 同ファイル「### ウィジェットテスト」表の「| よくある項目 |」行の検証内容を次にする:

  ```markdown
  | よくある項目 | 空状態のチップ 1 タップで確認なしに未実施の項目が一覧に出る。登録画面では同名のものが出ず先頭 3 件まで、タップで入力欄が埋まる。360×640dp でキーボード表示中(文字サイズ 200% を含む)もスクロールせずに「保存」が押せる |
  ```

### §5 追補(Codex 委託の検収で判明。判断7)

**判断7**: テスト C の `MediaQuery(data: const MediaQueryData(textScaler: TextScaler.linear(2)), …)` は、ビューの
`viewInsets` / `size` を空の値で上書きしてしまい、キーボードが無い扱いになる(実測: 保存の下端が 624dp)。
テスト C だけ、MediaQuery の値をビューから作って文字サイズだけ上書きする形に直す:

```dart
MediaQuery(
  data: MediaQueryData.fromView(
    tester.view,
  ).copyWith(textScaler: const TextScaler.linear(2)),
  child: ProviderScope(/* 既存どおり */),
),
```

- `const` が外れる以外、テスト C の他の行は変えない。`viewInsets` の設定は `pumpWidget` より前のまま
- 既存ループ「文字サイズ 200% で編集/登録画面が破綻しない」は変えない(`ensureVisible` で到達を見るテストなので影響しない)
- 実装(`item_add_screen.dart`)は変えない

## 触らないもの

- `lib/domain/item_template.dart`(6 件の中身と `availableItemTemplates`)
- `lib/ui/widgets/empty_state.dart` / `lib/ui/widgets/item_template_chips.dart`
- `lib/ui/screens/item_edit_screen.dart`
- `test/ui/item_list_screen_test.dart` の空状態のテスト(6 件のまま通ることが「空状態は変わらない」の確認になる)
