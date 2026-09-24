# 設計: カードをタップして開く詳細シート(Issue #22 / F29)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> **このチケットで依存は増えない**(`pubspec.yaml` を変更しない)。
> **`lib/state/` と `lib/data/` は変更しない。** 必要な値(`elapsed` / `previousIntervalDays` /
> `agingStage`)は `ItemView` にすでにある。委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)には触れない。
>
> **スコープ判断(司令塔 / 2026-09-23)**: 本チケットは P1。P0 は全件 closed(MVP 完了)で前倒しには当たらない。
> #20 / #21 と同じ扱いで**実装は承認済み**(この判断で停止しないこと)。
> **タップの行き先はユーザー判断で確定済み**: タップ → 詳細シート、編集はシート内の導線(requirements.md)。

## 0. 全体方針

```
ItemListScreen
  └ ItemCard(onTap: () => _openDetailSheet(context, item))      ← 行き先を編集画面から変える
        _openDetailSheet:
          1. ScaffoldMessenger.clearSnackBars()                    ← 取り消し導線を閉じる
          2. showModalBottomSheet<bool>(builder: ItemDetailSheet(item, onEditPressed: pop(true)))
          3. 戻り値が true かつ context.mounted なら _openEditScreen(context, item)
ItemDetailSheet(item: ItemView, onEditPressed: VoidCallback)   ← StatelessWidget。状態を持たない
  ├ 見出し: 項目名
  ├ 1 行目: 最後：14日前   / 未実施なら「まだ記録がありません」だけ
  ├ 2 行目: 前回：7日間隔   (previousIntervalDays が null なら行ごと出さない)
  ├ 3 行目: そろそろかも。  (agingStageHintText(stage) が null なら出さない)
  └ 「編集」ボタン
```

## 判断1: 文言を作る純関数(`lib/ui/widgets/item_detail_sheet.dart` のトップレベル関数)

**置き場所は UI 層**。Issue の技術メモは「`lib/domain/aging_stage.dart` 側に置く」としているが、
既存の同種の写像 `agingStageSemanticsText`(ステージ → 読み上げ文)が `item_card.dart`(UI 層)にあり、
**画面に出す日本語文言は UI 層に置く**という既存パターンに揃える(司令塔判断)。`lib/domain/` は変更しない。

```dart
/// 1 行目。未実施なら「まだ記録がありません」。
///
/// 経過日数の表記は一覧と揃える(`elapsedText` を再利用する。`今日` / `昨日` / `14日前`)。
String detailLastDoneLine(ElapsedLabel elapsed) => switch (elapsed) {
  NeverDone() => 'まだ記録がありません',
  _ => '最後：${elapsedText(elapsed)}',
};

/// 2 行目。前回間隔が無い(記録が 1 件以下)なら null = 行ごと出さない。
/// 「—」などの代替表記も出さない。
String? detailPreviousIntervalLine(int? previousIntervalDays) =>
    previousIntervalDays == null ? null : '前回：$previousIntervalDays日間隔';

/// 3 行目。経年ステージから決まる。**断定・催促をしない**(「〜かも。」で止める)。
///
/// 「そろそろ」未満(相対経過度 < 1.0)と、相対経過度が null(= fresh)では null。
String? agingStageHintText(AgingStage stage) => switch (stage) {
  AgingStage.fresh => null,
  AgingStage.slightlyAged => null,
  AgingStage.dueSoon => 'そろそろかも。',
  AgingStage.aged => 'いつもより間が空いているかも。',
  AgingStage.heavilyAged => 'だいぶ間が空いているかも。',
};
```

- 区切りは**全角コロン `：`**(U+FF1A)。半角 `:` にしない
- `elapsedText` は `item_card.dart` から import する(複製しない)
- 未実施のとき 2・3 行目は出さない。`ItemView` の構造上、未実施なら `previousIntervalDays` は null・`agingStage` は fresh になるので
  関数を素直に呼べば自然に出ないが、**ウィジェット側でも `NeverDone` なら 2・3 行目を組み立てない**(判断2 のコード)
- 3 行目の文言のうち `aged` / `heavilyAged` の 2 つは司令塔が決めた(Issue は `dueSoon` の例文のみ)。
  用語集の禁止一覧(「周期」「サイクル」「インターバル」など)に当たらない表現を選んである。変更しない

## 判断2: `ItemDetailSheet`(`lib/ui/widgets/item_detail_sheet.dart` 新規)

```dart
/// 詳細シート。**3 行まで**しか出さない(`docs/functional-design.md`「詳細シート」)。
///
/// 読み取り専用 + 編集への導線だけ。状態を持たず、開いた時点の [ItemView] をそのまま描く。
/// 削除の入口は置かない(削除は編集画面の中だけ。F7)。
class ItemDetailSheet extends StatelessWidget {
  const ItemDetailSheet({required this.item, required this.onEditPressed, super.key});

  final ItemView item;

  /// 「編集」ボタンのタップ時の処理。
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) { ... }
}
```

レイアウト(上から順):

```dart
final theme = Theme.of(context);
final lines = <String>[
  detailLastDoneLine(item.elapsed),
  if (item.elapsed is! NeverDone) ...[
    ?detailPreviousIntervalLine(item.previousIntervalDays),
    ?agingStageHintText(item.agingStage),
  ],
];
return SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(item.name, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onSurface)),
        ),
        const SizedBox(height: 16),
        for (final (index, line) in lines.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          Text(line, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface)),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onEditPressed,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('編集'),
          ),
        ),
      ],
    ),
  ),
);
```

- **null-aware 要素(`?expr`)を使う**(`pubspec.yaml` の SDK 制約は `^3.13.3` で使える)
- **`maxLines` / `overflow` を指定しない。** 項目名も各行も折り返して全文を出す(200% で省略しない)
- 各行は**別々の `Text`**。`Semantics` でまとめない(スクリーンリーダーが 1 行ずつ順に読む)。
  `ExcludeSemantics` / `MergeSemantics` も使わない
- 色・タイポは `Theme.of(context)` だけから取る。生の色値を書かない。余白の数値リテラル(24 / 16 / 8)は
  既存ウィジェット(`item_card.dart`)と同じ扱いで直書きしてよい
- 「編集」ボタンは `FilledButton.tonalIcon`(既定で高さ 40dp + タップ領域 48dp。`MaterialTapTargetSize.padded`)。
  アイコンは `Icons.edit_outlined`
- **「やった」ボタン・削除ボタンを置かない**
- 経年ステージの紙(`AgedPaperPainter`)をシートに**掛けない**。シートは Material 3 の既定の面のまま

## 判断3: 一覧からシートを開く(`lib/ui/screens/item_list_screen.dart`)

`_ItemList` の `onTap` を `_openEditScreen` から `_openDetailSheet` に替え、次の関数を足す。
`_openEditScreen` は残す(シートの「編集」から呼ぶ)。

```dart
/// 詳細シートを開く。**編集画面への入口はシートの中にある**(`docs/functional-design.md`「画面遷移図」)。
Future<void> _openDetailSheet(BuildContext context, ItemView item) async {
  // 遷移時と同じく取り消し導線を閉じる(判断13 と同じ理由)。
  ScaffoldMessenger.of(context).clearSnackBars();
  final openEdit = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ItemDetailSheet(
      item: item,
      onEditPressed: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  if (openEdit == true && context.mounted) {
    _openEditScreen(context, item);
  }
}
```

- `onTap: () => unawaited(_openDetailSheet(context, item))`(`dart:async` は import 済み)
- **SnackBar を閉じるのは `clearSnackBars()`**。Issue は `hideCurrentSnackBar` と書いているが、
  この画面の既存コード(`_openAddScreen` / `_openEditScreen` / `_handleDone`)がすべて `clearSnackBars()` なので揃える
  (キューに積まれたものも含めて消える。挙動の差は無い)
- `isScrollControlled: true` は 200% の文字サイズで内容が画面の半分を超えても切れないようにするため
- シートを閉じる操作(下スワイプ / 外側タップ / 戻る)は `showModalBottomSheet` の既定のまま。戻り値は null になり、何もしない
- `ItemCard` の `onTap` の doc コメントを「カードそのもののタップ時の処理(詳細シートを開く)。」に直す。
  「削除の入口は編集画面だけ。一覧にスワイプ削除を置かない。」の 1 文は残す
- `_openAddScreen` の doc コメントの「画面は一覧・登録・編集の 3 つだけ」は直さない(ルート表を持たない理由として今も正しい)

## 判断4: テスト

### 4-1. `test/ui/widgets/item_detail_sheet_test.dart`(新規)

純関数のテスト(`group('文言')`):

| 関数 | 入力 | 期待 |
| --- | --- | --- |
| `detailLastDoneLine` | `NeverDone()` | `まだ記録がありません` |
| 〃 | `Today()` / `Yesterday()` / `DaysAgo(14)` | `最後：今日` / `最後：昨日` / `最後：14日前` |
| `detailPreviousIntervalLine` | `null` / `7` | `null` / `前回：7日間隔` |
| `agingStageHintText` | 5 ステージすべて | fresh・slightlyAged は null、残りは判断1 の文言 |

ウィジェットのテスト(`MaterialApp(theme: AppTheme.light(), home: Scaffold(body: ItemDetailSheet(...)))` で直接 pump する):

| ケース | `ItemView` | 期待 |
| --- | --- | --- |
| 通常の 3 行 | `elapsed: DaysAgo(14)`, `lastDoneText: '2026年9月9日'`, `previousIntervalDays: 7`, `baselineIntervalDays: 7`, `relativeElapsed: 2.0`, `agingStage: AgingStage.heavilyAged` | `最後：14日前` / `前回：7日間隔` / `だいぶ間が空いているかも。` が出る |
| そろそろ | 上と同じで `relativeElapsed: 1.2`, `agingStage: AgingStage.dueSoon` | 3 行目が `そろそろかも。` |
| 未実施 | `elapsed: NeverDone()`, `lastDoneText: null`, 他は既定 | `まだ記録がありません` だけ。`find.textContaining('最後：')` / `('前回：')` / `('かも。')` がすべて findsNothing |
| 記録 1 件のみ | `elapsed: DaysAgo(3)`, `lastDoneText` あり, `previousIntervalDays: null`, `relativeElapsed: null`, `agingStage: fresh` | `最後：3日前` だけ。`前回：` / `かも。` が findsNothing |
| 相対経過度 1.0 未満 | `elapsed: DaysAgo(5)`, `previousIntervalDays: 7`, `baselineIntervalDays: 7`, `relativeElapsed: 5 / 7`, `agingStage: slightlyAged` | 1・2 行目が出て、`かも。` が findsNothing |
| 3 行まで | 「通常の 3 行」の `ItemView` | シート内の `Text` の数 = 見出し 1 + 3 行 + ボタンの `編集` 1 = 5(`find.descendant(of: find.byType(ItemDetailSheet), matching: find.byType(Text))`)。基準間隔の値 `7.0` や `平均` の文字が出ない |
| 削除の入口が無い | 同上 | `find.text('削除')` / `find.byIcon(Icons.delete_outline)` / `find.byIcon(Icons.delete)` が findsNothing。「やった」ボタン(`DoneButton`)も findsNothing |
| 編集ボタン | 同上 | `find.text('編集')` をタップすると `onEditPressed` が 1 回呼ばれる |
| 読み上げ順 | 同上 | `tester.ensureSemantics()` を使い、`find.bySemanticsLabel('最後：14日前')` / `('前回：7日間隔')` / `('だいぶ間が空いているかも。')` がそれぞれ見つかる(1 行ずつ独立したノード)。見出しは `SemanticsFlag.isHeader` を持つ(`tester.getSemantics(find.text(name))` で確認) |

### 4-2. `test/ui/item_list_screen_test.dart`(既存の追従と追加)

- 既存「カードタップで編集画面へ遷移すると取り消し導線が閉じる」を**「カードタップで詳細シートが開き、取り消し導線が閉じる」**に書き換える:
  記録 → `SnackBar` あり → `美容院` をタップ → `find.byType(ItemDetailSheet)` findsOneWidget・`find.byType(ItemEditScreen)` findsNothing・`SnackBar` findsNothing
- 追加「詳細シートの編集から編集画面へ遷移する」: `美容院` をタップ → `find.text('編集')` をタップ → `ItemEditScreen` findsOneWidget、`ItemDetailSheet` findsNothing
- 追加「詳細シートを閉じると一覧に戻る」: シートを開いて `tester.tapAt(const Offset(10, 10))`(シート外)→ `pumpAndSettle` → `ItemDetailSheet` findsNothing、`ItemEditScreen` findsNothing
- シート表示中は項目名がカードとシートの 2 箇所に出るため、`find.text('美容院')` のアサーションは開く前だけに使う

### 4-3. その他の既存テストの追従(タップ → 編集画面を前提にしている箇所)

- `test/ui/item_edit_screen_test.dart` の `openEditScreen`: `tap(find.text(name))` → `pumpAndSettle` の後に
  `tap(find.text('編集'))` → `pumpAndSettle` を足す。**それ以外のテストは直さない**
  (テスト名「カードタップで現在の項目名が入った編集画面が開く」は「詳細シートの編集から現在の項目名が入った編集画面が開く」に直す)
- `test/ui/terminology_test.dart`: `'編集'` / `'削除確認'` のケースで `美容院` タップの後に `編集` をタップする手順を足す。
  さらに画面リストに **`'詳細'`** を足し、`美容院` をタップして `find.byType(ItemDetailSheet)` findsOneWidget を確かめる case を追加する
  (既存と同じく `_expectAllowed(_renderedTexts(tester))` で禁止語を検査する)
- `test/ui/accessibility_test.dart`: 既存の `for (final scale in [1.0, 1.5, 2.0])` の一覧テストの近くに
  **「文字サイズ 200% で詳細シートが破綻しない」**を足す: `_setScreenSize(tester, height: 320)` → `seedItems()` →
  `_app(repository, FakeClock(now), textScale: 2)` → `美容院` のカードをタップ → `pumpAndSettle` →
  `expect(_ellipsizedTexts(tester), isEmpty)` / `expect(tester.takeException(), isNull)` →
  `await tester.ensureVisible(find.text('編集'))` → `pumpAndSettle` → `find.text('編集').hitTestable()` findsOneWidget
- 上記以外で `find.byType(ItemEditScreen)` をカードタップ直後に期待しているテストが見つかったら、同じく「編集」タップを挟んで追従する
  (追従は手順の追加だけ。期待値は変えない)。**期待値を変えないと通らないテストが出たら停止して報告する**

## 判断5: ドキュメント追記

- `docs/product-requirements.md`「P1 機能」表の F28 の次に 1 行足す:
  `| F29 | 詳細シート | カードをタップすると「最後：14日前」「前回：7日間隔」「そろそろかも。」を最大 3 行で示す。履歴一覧・統計・基準間隔は出さない(F23 とは別物)。編集画面への入口を兼ねる。削除の入口は置かない(F7) |`
- `docs/functional-design.md`「画面遷移図」:
  - `一覧 --> 編集: 項目をタップ` を削除し、`一覧 --> 詳細: 項目をタップ` / `詳細 --> 一覧: 閉じる` / `詳細 --> 編集: 編集ボタン` を足す
  - 図の下の段落を「**通常操作の画面は 3 つだけ**(一覧・登録・編集)と、一覧に重ねる詳細シート(F29)。記録は遷移を伴わない —— これが「1 タップ」の実体。」に直す(起動失敗の段落はそのまま)
- `docs/functional-design.md`「UI設計」: 「状態ごとの表示」節の**前**に `### 詳細シート(F29)` を足す。内容は
  requirements.md の 3 行の表(行 / 内容 / 出さない条件)と、3 行目の文言表(判断1 の 3 ステージ)、
  「3 行を超える情報を出さない」「削除の入口を置かない」「開くときに取り消し導線を閉じる」の 3 点
- `docs/functional-design.md`「画面遷移時に取り消し導線を閉じる」の注記に「詳細シートを開くときも同じく閉じる」を 1 文足す
- `docs/glossary.md`「アーキテクチャ用語」の `### カード(ItemCard)` の次に:
  ```
  ### 詳細シート(ItemDetailSheet)【P1】

  カードをタップすると開くボトムシート。最終実施からの経過日数・前回間隔・経年ステージの一言を**最大 3 行**で示し、
  編集画面への入口を兼ねる。統計・履歴一覧・基準間隔は出さない。

  - **コード上の表記**: `ItemDetailSheet`
  ```

## 判断6: 検証

- `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` が通ること
- `flutter test` は sandbox で実行できない場合、`AGENTS.md` §2 に従いホスト(検収)に委ねてよい。その旨を tasklist に書く

## ディレクトリ構造(変更点)

```
lib/ui/widgets/item_detail_sheet.dart        新規
lib/ui/widgets/item_card.dart                doc コメントのみ
lib/ui/screens/item_list_screen.dart         _openDetailSheet 追加・onTap 差し替え
test/ui/widgets/item_detail_sheet_test.dart  新規
test/ui/item_list_screen_test.dart           追従 + 追加
test/ui/item_edit_screen_test.dart           ヘルパーの追従
test/ui/terminology_test.dart                追従 + '詳細' 追加
test/ui/accessibility_test.dart              200% の詳細シートを追加
docs/product-requirements.md / docs/functional-design.md / docs/glossary.md
```
