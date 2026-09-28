# 設計: 詳細シートを「記録の詳細」画面に作り替える(Issue #58)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - パッケージ・アセットを追加しない。`pubspec.yaml` を変更しない
> - **`lib/data/` を触らない**(リポジトリ・DB・マイグレーションは変更不要。履歴は既存の `Item.recentDoneAts` を使う)
> - 基準間隔・前回間隔・経年ステージの**定義を変えない**
> - 色・余白・タイポは `Theme.of(context)` から取る(ウィジェット内に色の生値を書かない)。UI 文言は本書の表記どおり
> - 既存テストは**仕様が変わった箇所(シート → 画面)だけ**書き換える。それ以外の期待値を緩めない

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 詳細シート(`ItemDetailSheet`)を**廃止し**、push 遷移の全画面 `ItemDetailScreen` に置き換える | ユーザー選択。履歴を載せても文字サイズ 200% でスクロールで崩れない |
| B | 履歴は **`Item.recentDoneAts`(直近最大 10 件)** から作る。リポジトリにクエリを足さない | ユーザー選択。11 件目以降は見えない代わりに、そのことを画面に一文で示す(§4 の h) |
| C | 履歴は **暦日単位でまとめる**(同じ暦日の記録は 1 行) | `intervalDaysOf` と同じ規則。0 日間隔の行を作らず、行の間隔と平均の計算が一致する |
| D | 平均の間隔は**基準間隔そのもの**(直近最大 5 間隔の中央値、四捨五入して表示)。ラベルは「平均の間隔」で、「過去N回の」を付けない | ユーザー選択。定義を変えると並び順・通知・経年表示すべての挙動が変わる。付記を付けると定義と食い違う |
| E | 「前回からの間隔」は**経過日数を日数で**示す(`今日` → `0日`)。記録済みのときだけ出す | 画面イメージどおり。前回間隔(直近 2 回の差)とは別物 |
| F | 「いつもより長め」は経年ステージ **`aged` 以上**(相対経過度 1.5 以上)で出す | 通知(F11)と一言「いつもより間が空いているかも。」と同じ段階に揃える。`dueSoon` で出すと催促が強い |
| G | 右上の「…」メニューは **「日付を指定して記録」「編集」の 2 つ**。削除は置かない | 削除の入口は編集画面の中だけ(F7)。F16 の入口を保つ |
| H | 「記録する」は画面下部に固定し、**確認ダイアログを出さない**。結果の出し方(`記録しました` + 取り消す 4 秒)は一覧の「やった」と**同じ関数**を使う | 既存方針(F3)。二重実装にしない |
| I | 画面は `itemListProvider` を **watch して項目 ID で引く**。記録すると画面の内容がその場で更新される | 楽観的更新はしない(`watchAll()` の再送出を待つ)。既存の一覧と同じ経路 |
| J | 表示中の項目が一覧から消えたら(編集画面で削除)、**この画面のルートを `removeRoute` で取り除く** | 編集画面の上から `pop` すると別のルートを閉じてしまう。自分のルートを名指しで外せば、編集画面の `pop` 後にホームへ戻る |
| K | この画面から戻るときも**取り消し導線を閉じる** | 「画面遷移時に取り消し導線を閉じる」(functional-design)を保つ |
| L | 図鑑から開いた画面にも「記録する」を出す | F31 の「記録の入口を置かない」は**カード上**の 1 タップの記録を指す(日付を指定して記録と同じ扱い) |

## §1 ドメイン: `lib/domain/baseline_interval.dart`

1. 公開関数を追加する:

   ```dart
   /// 実施日時(UTC)を**ローカルの暦日**に直し、重複を除いて**新しい順**に返す。
   ///
   /// [intervalDaysOf] と同じ規則(`calendarDateOf(x.toLocal())`・同日は 1 つ・降順に並べ直す)。
   List<DateTime> distinctCalendarDatesOf(List<DateTime> doneAtsNewestFirst)
   ```

2. `intervalDaysOf` の先頭の暦日リスト作成を `distinctCalendarDatesOf` の呼び出しに置き換える(挙動は変えない。既存テストがそのまま通ること)

## §2 状態: `lib/state/item_view.dart`

1. 履歴 1 行の表示モデルを追加する:

   ```dart
   /// 記録の履歴 1 行(暦日単位)。**`DateTime` を持たない**(ItemView と同じ理由)。
   final class DoneHistoryEntry {
     const DoneHistoryEntry({required this.dateText, this.intervalDays});

     /// 記録した日(`2026年9月12日`)。`_lastDoneFormat` で整形する。
     final String dateText;

     /// 1 つ前(古い側)の記録からの暦日の差。表示範囲で最も古い行は null。
     final int? intervalDays;
     // == と hashCode を実装する(dateText / intervalDays)
   }
   ```

2. `ItemView` にフィールドを 2 つ足す(コンストラクタは名前付き・既定値つき):
   - `final List<DoneHistoryEntry> history;` 既定 `const <DoneHistoryEntry>[]`。新しい順
   - `final bool historyTruncated;` 既定 `false`。`item.recentDoneAts.length >= baseline.recentDoneAtsLimit` のとき true(11 件目以降が存在しうる)
3. `ItemView.from` で組み立てる:
   - `dates = baseline.distinctCalendarDatesOf(item.recentDoneAts)`、`intervals = baseline.intervalDaysOf(item.recentDoneAts)`
   - `i` 行目 = `DoneHistoryEntry(dateText: _lastDoneFormat.format(dates[i]), intervalDays: i < intervals.length ? intervals[i] : null)`
   - `dates` は既にローカルの暦日なので `toLocal()` を重ねない
4. `==` / `hashCode` に `history`(要素ごとの比較・`Object.hashAll`)と `historyTruncated` を含める。
   `lib/state` は `package:flutter/` を import できないので、要素比較は手書きする(`lib/domain/item.dart` の `_listEquals` と同じ書き方)

## §3 UI の共通関数: `lib/ui/item_navigation.dart`

ファイル冒頭のコメントを「記録の詳細・編集画面を開く関数と、記録の結果を出す関数。一覧・図鑑・記録の詳細から使う」に改める。

1. **削除**: `_DetailSheetAction`、`openItemDetailSheet`
2. **追加** `void openItemDetailScreen(BuildContext context, ItemId id)`:
   `ScaffoldMessenger.of(context).clearSnackBars()` の後、`Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: id)))`
3. **公開化**: `_recordPastDate(context, item)` を `Future<void> recordPastDateWithUndo(BuildContext context, ItemId id)` に改名し、引数を `ItemId` にする(中身は同じ。`item.id` → `id`)
4. **移設**: `item_list_screen.dart` の `_handleDone` / `_handleUndo` をここへ移し、`Future<void> markDoneWithUndo(BuildContext context, ItemId id)` にする。
   - `WidgetRef` を受け取らない。`recordPastDateWithUndo` と同じく、**await の前に** `ScaffoldMessenger.of(context)` と
     `ProviderScope.containerOf(context, listen: false).read(itemListProvider.notifier)` を控え、以後はそれだけを使う
     (記録の詳細が閉じた後に取り消しが押されても、破棄済みの `ref` を触らない)
   - 文言・`persist: false`・`clearSnackBars` の順序・失敗時の文言は現行と**完全に同じ**にする
   - `item_list_screen.dart` の `_ItemList` は `markDoneWithUndo(context, item.id)` を呼ぶ(`unawaited` で包む)。`onTap` は `openItemDetailScreen(context, item.id)`
5. `openItemEditScreen` は変更しない

`collection_screen.dart` の `onTap` も `openItemDetailScreen(context, item.id)` にする。
`item_card.dart` / `collection_card.dart` / `collection_screen.dart` のコメント中の「詳細シート」は「記録の詳細」に直す。

## §4 画面: `lib/ui/screens/item_detail_screen.dart`(新規)

`lib/ui/widgets/item_detail_sheet.dart` は**削除**する。`agingStageHintText` はこのファイルへ移す(中身は同じ)。
`detailLastDoneLine` / `detailPreviousIntervalLine` は削除する。

### 表示用の関数(トップレベル・公開。テストから呼ぶ)

| 関数 | 返す値 |
| --- | --- |
| `String detailLastDoneText(ItemView item)` | 未実施 → `まだ記録がありません`。それ以外 → `'${item.lastDoneText}（${elapsedText(item.elapsed)}）'`(**全角括弧**。例 `2026年9月12日（4日前）` / `…（今日）` / `…（昨日）`)。`elapsedText` は `item_card.dart` のものを使う |
| `String detailAverageIntervalText(double? baselineIntervalDays)` | null → `学習中`。それ以外 → `'${baselineIntervalDays.round()}日'` |
| `String? detailSinceLastText(ElapsedLabel elapsed)` | `NeverDone` → null。`Today` → `0日`、`Yesterday` → `1日`、`DaysAgo(:days)` → `'$days日'` |
| `bool isLongerThanUsual(AgingStage stage)` | `aged` / `heavilyAged` のとき true |
| `String? agingStageHintText(AgingStage stage)` | 既存のまま移設 |
| `String historyEntrySemanticsLabel(DoneHistoryEntry entry)` | 間隔あり → `'${entry.dateText}、前回から${entry.intervalDays}日'`、なし → `entry.dateText` |

### ウィジェット構成

`ItemDetailScreen extends ConsumerStatefulWidget`(`const ItemDetailScreen({required this.itemId, super.key})`、`final ItemId itemId`)。
State は `bool _isRecording = false` と `bool _removed = false` を持つ。

```
PaperBackground
└ PopScope(canPop: true, onPopInvokedWithResult: (didPop, _) { if (didPop) messenger.clearSnackBars(); })   // 判断K。messenger は build 内で ScaffoldMessenger.of(context) を控える
  └ Scaffold
    ├ appBar: AppBar(title: Text('記録の詳細'), actions: item != null ? [_DetailMenuButton] : null)
    ├ body: SafeArea(child: <下記の本文>)
    └ bottomNavigationBar: item != null ? SafeArea(Padding(all 16, FilledButton(...))) : null
```

- `build` の冒頭: `final items = ref.watch(itemListProvider).value;` `final item = items?.where((v) => v.id == widget.itemId).firstOrNull;`
- **判断J**: `build` 内で `ref.listen(itemListProvider, (_, next) { ... })`。`next.value` が非 null で `itemId` を含まず、`_removed` が false なら
  `_removed = true` にして `final route = ModalRoute.of(context); if (route != null && route.isActive) Navigator.of(context).removeRoute(route);`
- 本文の分岐: `items == null` → `Center(CircularProgressIndicator(semanticsLabel: '読み込み中'))` / `item == null` → `SizedBox.shrink()` / それ以外 → 下の本文

#### 「…」メニュー(判断G)

`PopupMenuButton<_DetailMenuAction>`(`enum _DetailMenuAction { recordPastDate, edit }`)、`icon: Icon(Icons.more_horiz)`、`tooltip: 'その他の操作'`。
項目は上から:

1. `recordPastDate`: `ListTile(leading: Icon(Icons.edit_calendar_outlined), title: Text('日付を指定して記録'))` → `recordPastDateWithUndo(context, item.id)`
2. `edit`: `ListTile(leading: Icon(Icons.edit_outlined), title: Text('編集'))` → `openItemEditScreen(context, item)`

(`PopupMenuItem(value: …, child: ListTile(...))`。`contentPadding: EdgeInsets.zero` で可)

#### 本文(`SingleChildScrollView(padding: EdgeInsets.all(16))` > `Column(crossAxisAlignment: stretch, mainAxisSize: min)`)

a. **見出しのカード** `_HeaderCard`: `CollectionCard` と同じ紙を描く。
   `CustomPaint(painter: AgedPaperPainter(stage: item.agingStage, colors: AgingPalette.of(context).colorsOf(item.agingStage), seed: stableSeedOf(item.id.value)))` >
   `Padding(all 24)` > `Column(center)`:
   `ExcludeSemantics(Icon(itemIconData(item.icon), size: 64, color: onSurface.withValues(alpha: agingIconOpacity(item.agingStage))))`、
   `SizedBox(height: 12)`、`Semantics(header: true, child: Text(item.name, style: titleLarge + onSurface, textAlign: center))`(**maxLines を付けない**。長い名前は折り返す)。タップ不可
b. `SizedBox(height: 16)`
c. `_InfoRow(icon: Icons.calendar_month_outlined, label: '最後にやった日', value: detailLastDoneText(item))`
d. `_InfoRow(icon: Icons.bar_chart, label: '平均の間隔', value: detailAverageIntervalText(item.baselineIntervalDays))`(未実施でも出す)
e. `detailSinceLastText(item.elapsed)` が非 null のとき: `_InfoRow(icon: Icons.schedule, label: '前回からの間隔', value: そのテキスト, badge: isLongerThanUsual(item.agingStage) ? 'いつもより長め' : null)`
f. 未実施でなく `agingStageHintText(item.agingStage)` が非 null のとき: `_InfoRow(icon: Icons.chat_bubble_outline, label: その一言)`(value なし)
g. `SizedBox(16)`、`Divider()`、`SizedBox(16)`、`Semantics(header: true, child: Text('記録の履歴', style: titleMedium + onSurface))`、`SizedBox(8)`
h. 履歴:
   - `item.history` が空 → `Text('まだ記録がありません', style: bodyLarge + onSurfaceVariant)`
   - それ以外 → 各行 `_HistoryRow(entry)`:
     `Semantics(label: historyEntrySemanticsLabel(entry), excludeSemantics: true, child: Padding(vertical 8, Row([ExcludeSemantics なしでよい Icon(Icons.circle, size: 8, color: primary), SizedBox(12), Expanded(Text(entry.dateText, bodyLarge + onSurface)), if (entry.intervalDays != null) Text('${entry.intervalDays}日', bodyLarge + onSurfaceVariant)])))`
   - `item.historyTruncated` のとき末尾に `SizedBox(8)` + `Text('直近${recentDoneAtsLimit}件まで表示しています', style: bodySmall + onSurfaceVariant)`(`recentDoneAtsLimit` は `domain/baseline_interval.dart`)

`_InfoRow`(private StatelessWidget。`icon` / `label` 必須、`value` / `badge` 任意):
`MergeSemantics(Padding(vertical 8, Row(crossAxisAlignment: start, [ExcludeSemantics(Icon(icon, size: 24, color: onSurfaceVariant)), SizedBox(16), Expanded(Column(crossAxisAlignment: start, [Text(label, value == null ? bodyLarge + onSurface : bodyMedium + onSurfaceVariant), if value: SizedBox(2) + Text(value, titleMedium + onSurface), if badge: SizedBox(4) + _Badge(badge)]))])))`
**ラベルと値を縦に積む**(横並びにしない。200% で右端がはみ出さないため)。

`_Badge`: `Align(alignment: centerLeft, child: DecoratedBox(decoration: BoxDecoration(color: tertiaryContainer, borderRadius: BorderRadius.circular(8)), child: Padding(horizontal 8, vertical 4, child: Text(text, labelMedium + onTertiaryContainer))))`

#### 「記録する」ボタン(判断H)

`FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)), onPressed: _isRecording ? null : _record, child: const Text('記録する'))`

```dart
Future<void> _record() async {
  setState(() => _isRecording = true);
  await markDoneWithUndo(context, widget.itemId);
  if (mounted) setState(() => _isRecording = false);
}
```

## §5 テスト

既存の `test/` の書き方(`FakeItemRepository` / `FakeClock` / `ProviderScope` の overrides)に倣う。

1. `test/domain/baseline_interval_test.dart`: `distinctCalendarDatesOf` — 同日 2 件が 1 つになる / 順序が崩れた入力でも新しい順 / 空入力で空
2. `test/state/item_view_test.dart`: `history` — 未実施で空 / 1 件で 1 行・間隔 null / 3 暦日で新しい順・間隔つき・最古は null / 同日 2 件が 1 行 / `recentDoneAts` が 10 件で `historyTruncated == true`、9 件で false
3. `test/ui/widgets/item_detail_sheet_test.dart` を**削除**し、`test/ui/screens/item_detail_screen_test.dart` を新規作成:
   - 記録 3 件(暦日が異なる): `最後にやった日` / `2026年9月12日（4日前）` 形式 / `平均の間隔` の日数 / `前回からの間隔` / 履歴が新しい順で間隔つき
   - 記録 1 件: 平均が `学習中`、履歴 1 行で間隔の表示なし
   - 未実施: `まだ記録がありません` が 2 箇所(最後にやった日・履歴)、`前回からの間隔` が無い、平均が `学習中`
   - `aged` 相当で `いつもより長め` が出る / `dueSoon` 相当で出ない
   - 「記録する」: ダイアログが出ない(`find.byType(AlertDialog)` が無い)/ `記録しました` が出る / 履歴の先頭が今日になる / `取り消す` で元に戻る
   - メニュー(`find.byTooltip('その他の操作')`)に `日付を指定して記録` と `編集` があり、`削除` は無い
   - メニューの `日付を指定して記録` で日付の選択(`記録する日を選ぶ`)が開く
   - メニューの `編集` → 編集画面で削除 → ホーム(一覧)に戻り、`ItemDetailScreen` が残っていない
   - 記録が 10 件で `直近10件まで表示しています` が出る
   - 記録後に戻ると取り消し導線(`SnackBar`)が消えている
   - 各表示用関数の単体テスト(§4 の表の全分岐)
4. 既存テストの書き換え(**シート → 画面**の差し替えだけ。検証している性質は保つ):
   - `test/ui/item_list_screen_test.dart` 292 / 345 / 357 / 367 行付近: `ItemDetailSheet` → `ItemDetailScreen`。「編集」「日付を指定して記録」はメニュー経由で押す。「閉じる」は `tester.pageBack()` で戻る
   - `test/ui/item_edit_screen_test.dart` 97 行付近: メニュー経由で編集を開く
   - `test/ui/screens/collection_screen_test.dart` 258 / 272 行付近: 同上。図鑑から開いた画面にもメニューの `日付を指定して記録` がある
   - `test/ui/terminology_test.dart` の `'詳細'` ケース: `ItemDetailScreen` を待つ
   - `test/ui/accessibility_test.dart` の「文字サイズ 200% で詳細シートが破綻しない」→「…記録の詳細が破綻しない」: 省略テキストが無い・例外が無い・`記録する` が `hitTestable`・`find.text('記録の履歴')` を `ensureVisible` できる

## §6 docs の更新

### `docs/product-requirements.md`

- F29 の行を次に置き換える:
  `| F29 | 記録の詳細 | カードをタップすると専用画面へ遷移し、最後にやった日(日付と経過日数)・平均の間隔(基準間隔。記録 1 件以下は「学習中」)・前回からの間隔(相対経過度 1.5 以上で「いつもより長め」)・経年ステージの一言・記録の履歴(直近 10 件、暦日単位、新しい順、前回からの間隔つき)を示す。下部の「記録する」で記録できる(確認なし・取り消しあり)。右上のメニューから日付を指定して記録(F16)と編集へ進む。削除の入口は置かない(F7) |`
- P1 の表の直後の設計判断ブロック(`> **追記(#51)**` の段落)の後に、次の段落を足す:
  ```
  >
  > **追記(#58)**: F29 を「最大 3 行のシート」から「記録の詳細」画面に改めた。画面イメージが
  > 項目ごとの専用画面に履歴と平均の間隔を並べており、一覧の 1 タップの記録(F3)を保ったまま
  > 「振り返る場所」を別に持つほうが、記録を積む動機になると判断した。平均の間隔は基準間隔(F27)
  > そのもので、定義(直近最大 5 間隔の中央値)は変えない。履歴は既に読んでいる直近 10 件に留め、
  > 全件の履歴・年間実施回数などの統計は F23 に残す。
  ```
- F23 の概要を `平均実施間隔の推移・年間実施回数・全件の履歴。F12 が前提。直近 10 件の履歴と平均の間隔は F29 が出す` に改める
- F31 の「カードのタップで詳細シート(F29)を開く」を「カードのタップで記録の詳細(F29)を開く」に改める

### `docs/functional-design.md`

- 「### 詳細シート(F29)」節を「### 記録の詳細(F29)」に改め、本文を本書 §4 の仕様(表示項目の表・未実施/1 件のときの表示・メニュー・記録する・判断 E/F/J/K/L)で書き直す。旧来の 3 行の表と「3 行を超える情報を出さない」は削除する
- 画面遷移図: `一覧 --> 詳細: 項目をタップ` 等の「詳細」を「記録の詳細」に改め、`記録の詳細 --> 記録の詳細: 「記録する」(遷移しない)`、`記録の詳細 --> 一覧: 戻る`、`記録の詳細 --> 編集: メニューの「編集」`、`削除確認 --> 一覧: 削除実行` が成り立つように直す。図鑑側も `図鑑 --> 記録の詳細: カードをタップ` / `記録の詳細 --> 図鑑: 戻る`
- 図の直後の段落: 「一覧に重ねる詳細シート(F29)」→「一覧・図鑑から開く記録の詳細(F29)」。「図鑑の詳細シートから編集へ」→「図鑑から開いた記録の詳細から編集へ」。削除したときは記録の詳細も閉じてホーム/図鑑へ戻る旨を 1 文足す
- UC1b 手順 1: 「記録の詳細の右上のメニューから『日付を指定して記録』を選ぶ。日付の選択を開く」
- 通知節(355 行付近)「詳細シートの『いつもより…』」→「記録の詳細の『いつもより…』」
- 図鑑節(596 行付近)の「詳細シート」→「記録の詳細」。「記録の詳細の『記録する』と『日付を指定して記録』は一覧から開いたときと同じく出す(#49 / #58)」に改める
- 「詳細シートを開くときも同じく閉じる」→「記録の詳細を開くとき・記録の詳細から戻るときも同じく閉じる」
- ウィジェットテスト表: 「日付を指定して記録」行の「詳細シートから」→「記録の詳細のメニューから」。行を 1 つ足す: `| 記録の詳細 | 履歴が新しい順に間隔つきで並び、記録 1 件以下は平均が「学習中」、「記録する」は確認なしで取り消せる |`
- 上記以外にも `詳細シート` が残っていれば `記録の詳細` に直す(`grep -n 詳細シート docs/` で 0 件にする)

### `docs/glossary.md`

- 「### 詳細シート(ItemDetailSheet)【P1】」節を次に置き換える:
  ```
  ### 記録の詳細(ItemDetailScreen)【P1】

  カードをタップすると開く、項目ごとの画面(F29)。最後にやった日・平均の間隔・前回からの間隔・
  経年ステージの一言・記録の履歴(直近 10 件)を示し、「記録する」と、メニューから日付を指定して記録・編集へ進める。
  削除の入口は置かない。

  - **コード上の表記**: `ItemDetailScreen`
  - **UI 文言**: 画面タイトルは「記録の詳細」。行の見出しは「最後にやった日」「平均の間隔」「前回からの間隔」「記録の履歴」
  - **「前回からの間隔」は経過日数を日数で示したもの**(`今日` は `0日`)。前回間隔(直近 2 回の差)とは別物
  - **使わない言い換え**: 詳細シート(#58 で廃止)
  ```
- F16 の段落「詳細シートの『日付を指定して記録』から」→「記録の詳細のメニューの『日付を指定して記録』から」
- 図鑑の節「詳細シートは一覧から開いたときと同じで」→「記録の詳細は一覧から開いたときと同じで、『記録する』と」
- 上記以外の `詳細シート` も直す(`grep` で 0 件にする。ただし新しい節の「使わない言い換え: 詳細シート」は残す)

### `docs/repository-structure.md`

- `item_navigation.dart` のコメントを `# 記録の詳細・編集画面を開く関数、記録の結果を出す関数` に
- `item_detail_sheet.dart` の行を削除し、`screens/` の一覧に `item_detail_screen.dart      # 記録の詳細` を足す(既存の並びの書式に合わせる)

## §7 完了条件

- `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` がすべて通る
- `grep -rn "ItemDetailSheet\|openItemDetailSheet\|item_detail_sheet" lib test docs` が 0 件
- `grep -rn "詳細シート" lib test docs` が glossary の「使わない言い換え」の 1 件だけ
