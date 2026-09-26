# 設計: 下部ナビと図鑑画面(Issue #34 / F31)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **スコープ判断(司令塔)**: F31 は P2。P0・P1 のチケットはすべてクローズ済みで、残る唯一のチケットとして着手する(前倒しではない)
> - **未決事項はユーザーが決定済み**(`requirements.md`「Issue の未決事項に対するユーザーの決定」)
> - **委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れない。** DB スキーマは変わらない
> - **依存は増えない。** `pubspec.yaml` を変更しない。追加の UI パッケージを入れない
> - **`docs/` は司令塔が更新済み**(PRD F31 / 機能設計「画面遷移図」「図鑑(F31)」「パフォーマンス最適化」/ 用語集「図鑑」)。実装者は `docs/` を触らない
> - 用語: 「図鑑」「ホーム」「項目」「平均」「学習中」。**「コレクション」を UI 文言に出さない**(コード上の名前は `Collection*`)
> - 色・余白・タイポは `Theme.of(context)` から取る。既存ウィジェットと同じく、余白の数値リテラル(8 / 12 / 16 等)は可

## 0. 全体像

```
state : lib/state/collection.dart(新規)
          collectionCategoryFilterProvider(図鑑専用の絞り込み。CategoryFilterNotifier を再利用)
          collectionOf(純関数: 未実施を除く → カテゴリ → 検索)
ui    : lib/ui/screens/home_shell.dart(新規) … 下部ナビ + IndexedStack[ItemListScreen, CollectionScreen]
        lib/ui/screens/collection_screen.dart(新規) … 図鑑
        lib/ui/widgets/collection_card.dart(新規) … 図鑑のカード
        lib/ui/item_navigation.dart(新規) … 詳細シート・編集画面を開く関数(一覧と図鑑で共有)
        lib/ui/widgets/load_error.dart(新規) … 一覧の _LoadError を公開ウィジェットへ移す
        lib/ui/screens/item_list_screen.dart(変更) … 上の 2 つへ移した分を削り、呼び出しを差し替える
        lib/app.dart(変更) … home を HomeShell に
```

- **図鑑は `itemListProvider` から作る。** Drift の購読を増やさない(`docs/functional-design.md`「パフォーマンス最適化」)
- **並びは一覧と同じ**(`itemListProvider` が流す F30 の確定順)。図鑑専用の並び替えを書かない
- `ItemView` / `ItemListNotifier` / `domain/` / `data/` は変更しない

## 判断1: 図鑑の絞り込み(`lib/state/collection.dart` 新規)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category.dart';
import '../domain/elapsed_days.dart';
import 'category_filter.dart';
import 'item_view.dart';

/// 図鑑の絞り込み。**null は「すべて」。一覧の [categoryFilterProvider] とは独立**で、保存しない。
final collectionCategoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, CategoryId?>(
      CategoryFilterNotifier.new,
    );

/// 図鑑に載せる項目を、**入力順を保って**返す(F31)。
///
/// 1. 未実施(`NeverDone`)を除く。図鑑に載るのは 1 回以上記録した項目だけ
/// 2. [category] で絞る(null は「すべて」。[filterByCategory] に任せる)
/// 3. [query] を前後の空白を除いて、項目名の部分一致で絞る。英字の大文字小文字を区別しない。
///    空文字(空白だけを含む)なら絞らない
List<ItemView> collectionOf(
  List<ItemView> views, {
  CategoryId? category,
  String query = '',
}) {
  final recorded = views
      .where((view) => view.elapsed is! NeverDone)
      .toList(growable: false);
  final byCategory = filterByCategory(recorded, category);
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return byCategory;
  }
  return byCategory
      .where((view) => view.name.toLowerCase().contains(needle))
      .toList(growable: false);
}
```

- `CategoryFilterNotifier` クラスは `lib/state/category_filter.dart` のものをそのまま使う(クラスを複製しない)
- 検索語は**状態管理層に置かない**。図鑑画面の `State` が持つ(判断5)。保存しない要件なので provider にする理由がない

## 判断2: 画面を開く関数の共有(`lib/ui/item_navigation.dart` 新規)

`item_list_screen.dart` の `_openDetailSheet` と `_openEditScreen` を**このファイルへ移し、公開関数にする**。
本体(コメント含む)は現行のまま移し、名前だけ変える。

| 旧(private) | 新(public) |
| --- | --- |
| `_openDetailSheet(BuildContext context, ItemView item)` | `Future<void> openItemDetailSheet(BuildContext context, ItemView item)` |
| `_openEditScreen(BuildContext context, ItemView item)` | `void openItemEditScreen(BuildContext context, ItemView item)` |

- `openItemDetailSheet` の中の `_openEditScreen(...)` 呼び出しは `openItemEditScreen(...)` に変える
- import は `package:flutter/material.dart` / `../state/item_view.dart` / `screens/item_edit_screen.dart` / `widgets/item_detail_sheet.dart`
- `item_list_screen.dart` 側は `_ItemList` の `onTap` を `unawaited(openItemDetailSheet(context, item))` に変え、不要になった import(`item_detail_sheet.dart` / `item_edit_screen.dart`)を消す
- ファイル冒頭のライブラリ doc に「一覧と図鑑の両方から開くため、画面から切り出した(#34)」と 1 行書く

## 判断3: 読み込み失敗の表示(`lib/ui/widgets/load_error.dart` 新規)

`item_list_screen.dart` の `_LoadError` を**公開クラス `LoadError` としてこのファイルへ移す**。中身(文言・アイコン・
`CenteredScrollable`・「再試行」ボタン)とコメントは現行のまま。コンストラクタは `const LoadError({required this.onRetry, super.key})`。
一覧側の `_LoadError(...)` 呼び出しを `LoadError(...)` に差し替える。

## 判断4: 下部ナビ(`lib/ui/screens/home_shell.dart` 新規)

```dart
/// 下部ナビで一覧(ホーム)と図鑑を切り替える外枠(F31)。起動直後は必ずホーム。
///
/// **`Scaffold` にしない。** 外枠を `Scaffold` にすると内側の各画面の `Scaffold` が
/// 「入れ子」扱いになり、`SnackBar` が外枠にだけ出て一覧の FAB と重なる。
/// 各画面の `Scaffold` をルートのまま保ち、ナビは `Column` の下段に置く。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // キーボード表示中(図鑑の検索)はナビを隠す。残すと入力欄とキーボードの間にナビ分の隙間が空く。
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Expanded(
          // 下端の安全領域はナビ(または非表示時は各画面)が引き受ける。
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: !keyboardVisible,
            child: IndexedStack(
              index: _index,
              children: const [ItemListScreen(), CollectionScreen()],
            ),
          ),
        ),
        if (!keyboardVisible)
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: '図鑑',
              ),
            ],
          ),
      ],
    );
  }

  void _select(int index) {
    if (index == _index) {
      return;
    }
    // 画面遷移と同じく取り消し導線を閉じる(`docs/functional-design.md`「状態ごとの表示」)。
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _index = index);
  }
}
```

- **`IndexedStack` で両画面を生かしたままにする。** 一覧のスクロール位置・絞り込み、図鑑の検索語をタブ切替で失わない。一覧の `AppLifecycleListener`(F30 の復帰時の並び確定)も図鑑表示中に生き続ける
- `lib/app.dart` の `home:` を `const HomeShell()` に変える。`App` の doc コメントの「通常操作の画面は一覧・登録・編集の 3 つだけで、起動直後は必ず一覧に出る」を「起動直後は必ず一覧(ホーム)に出る。一覧と図鑑は下部ナビで切り替える(#34)」に直す
- `item_list_screen.dart` のクラス doc「**起動直後に出る唯一の画面**」を「**起動直後に出る画面**(ホーム)。図鑑とは下部ナビで切り替える」に直す
- 一覧の FAB・`ListView` の下余白(88)は変えない(ナビは各画面の `Scaffold` の外にあるため、FAB の位置計算に影響しない)

## 判断5: 図鑑画面(`lib/ui/screens/collection_screen.dart` 新規)

`ConsumerStatefulWidget`。`State` が次の 2 つを持つ:

- `bool _searching = false`(検索欄を表示中か)
- `final TextEditingController _queryController`(`dispose` で破棄する)。`addListener` で `setState` を呼び、入力のたびに再描画する

### AppBar

| 状態 | `leading` | `title` | `actions` |
| --- | --- | --- | --- |
| 通常 | なし(既定) | `Text('図鑑')` | `IconButton(icon: Icon(Icons.search), tooltip: '検索', onPressed: 検索を開く)` |
| 検索中 | `IconButton(icon: Icon(Icons.arrow_back), tooltip: '検索を閉じる', onPressed: 検索を閉じる)` | `TextField`(下記) | なし |

- 検索中の `TextField`: `controller: _queryController`, `autofocus: true`, `textInputAction: TextInputAction.search`, `decoration: const InputDecoration(hintText: '項目名で検索', border: InputBorder.none)`
- 検索を開く = `setState(() => _searching = true)`。検索を閉じる = `_queryController.clear()` のうえ `setState(() => _searching = false)`(**閉じると条件を消す**)
- 通常時にタイトルを「図鑑」、一覧側は現行の「LastWhen」のまま(一覧の AppBar は変えない)

### 本体

```dart
final items = ref.watch(itemListProvider);
final categories = ref.watch(categoryListProvider).value ?? const [];
final filter = resolveCategoryId(ref.watch(collectionCategoryFilterProvider), categories);
```

`body: SafeArea(child: switch (items) { ... })`:

| `items` | 表示 |
| --- | --- |
| `AsyncData(:final value)` | `_buildCollection(value, categories, filter)`(下記) |
| `AsyncError()` | `LoadError(onRetry: () => ref.invalidate(itemListProvider))` |
| それ以外 | `const Center(child: CircularProgressIndicator(semanticsLabel: '読み込み中'))` |

`_buildCollection`:

1. `final recorded = collectionOf(value)`(条件なし = 記録済みの全件)
2. `recorded.isEmpty` なら `_CollectionEmpty` を返す(**チップ列も出さない**)
3. そうでなければ `final visible = collectionOf(value, category: filter, query: _queryController.text)` とし、
   `Column([ if (categories.isNotEmpty) CategoryFilterBar(categories:, selected: filter, onSelected: (id) => ref.read(collectionCategoryFilterProvider.notifier).select(id)), Expanded(child: visible.isEmpty ? const _CollectionFilteredEmpty() : _CollectionGrid(items: visible)) ])`

- **FAB を置かない。** 図鑑には項目の追加導線を置かない
- 取り消し導線を出す操作(記録)が図鑑に無いので、`_handleDone` 相当は書かない

### 空の表示(どちらも `CenteredScrollable` の中に置く。一覧の `_FilteredEmpty` と同じ組み方)

| ウィジェット | 中身 |
| --- | --- |
| `_CollectionEmpty` | `Column(mainAxisSize: min)`: `ExcludeSemantics(Icon(Icons.menu_book_outlined, size: 56, color: onSurfaceVariant))` / `SizedBox(16)` / `Text('まだ図鑑にカードがありません', style: titleMedium, textAlign: center)` / `SizedBox(8)` / `Text('「やった」を記録した項目がここに並びます', style: bodyMedium(onSurfaceVariant), textAlign: center)` |
| `_CollectionFilteredEmpty` | `Text('条件に合う項目はありません', style: bodyLarge, textAlign: center)` |

### グリッド(`_CollectionGrid`)

```dart
final theme = Theme.of(context);
final textScaler = MediaQuery.textScalerOf(context);
return GridView.builder(
  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: collectionColumnCount(textScaler),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    mainAxisExtent: collectionCardExtent(theme.textTheme, textScaler),
  ),
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return CollectionCard(
      item: item,
      onTap: () => unawaited(openItemDetailSheet(context, item)),
    );
  },
);
```

- `collectionColumnCount` / `collectionCardExtent` は `collection_card.dart` に置く(判断6)
- **`GridView.builder` で遅延生成する**(100 件で全カードを同時に構築しない)

## 判断6: 図鑑のカード(`lib/ui/widgets/collection_card.dart` 新規)

### 公開する定数・関数

```dart
/// 図鑑のカードで描くアイコンの一辺(dp)。
const double collectionCardIconSize = 40;

/// 図鑑のカードの内側の余白(dp)。
const double collectionCardPadding = 12;

/// 基準間隔の表示(`平均7日` / `学習中`)。**四捨五入**する(`double.round()`)。
/// 画面上の呼び名は「平均」、null は「学習中」(`docs/glossary.md`「基準間隔」)。
String collectionIntervalText(double? baselineIntervalDays) =>
    baselineIntervalDays == null ? '学習中' : '平均${baselineIntervalDays.round()}日';

/// 列数。文字倍率が [itemCardStackThreshold] 以上なら 2 列、未満なら 3 列。
/// 判定は一覧のカードと同じ方法(基準 16dp を拡大して比べる)で行う。
int collectionColumnCount(TextScaler textScaler) =>
    textScaler.scale(16) >= 16 * itemCardStackThreshold ? 2 : 3;

/// カード 1 枚の高さ(dp)。文字倍率に合わせて伸ばし、200% でもはみ出さないようにする。
///
/// 余白 × 2 + アイコン + 8 + 項目名 2 行 + 4 + 平均 1 行 + 余裕 8。
double collectionCardExtent(TextTheme textTheme, TextScaler textScaler) {
  double lineHeight(TextStyle? style) {
    final fontSize = style?.fontSize ?? 14;
    // height が未指定のテーマでも日本語の行が収まるよう、既定を大きめに取る。
    return textScaler.scale(fontSize) * (style?.height ?? 1.5);
  }

  return collectionCardPadding * 2 +
      collectionCardIconSize +
      8 +
      lineHeight(textTheme.titleSmall) * 2 +
      4 +
      lineHeight(textTheme.bodySmall) +
      8;
}

/// 読み上げ文。`項目名、平均7日` / `項目名、学習中`。経年ステージが fresh 以外なら
/// `、状態は{agingStageSemanticsText}` を足す(一覧のカードと同じ語)。
String collectionCardSemanticsLabel(ItemView item) { ... }
```

- `itemCardStackThreshold` と `agingStageSemanticsText` は `item_card.dart` から import する(複製しない)

### `CollectionCard`(`StatelessWidget`)

コンストラクタ: `const CollectionCard({required this.item, required this.onTap, super.key})`。フィールド `ItemView item` / `VoidCallback onTap`。

構造は一覧の `ItemCard` の外側と同じ組み方にする(**外側の `Padding` は付けない**。間隔はグリッドの spacing が持つ):

```
CustomPaint(
  painter: AgedPaperPainter(stage: item.agingStage, colors: AgingPalette.of(context).colorsOf(item.agingStage), seed: stableSeedOf(item.id.value)),
  child: Material(type: transparency,
    child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(agedPaperCornerRadius),
      child: Padding(padding: EdgeInsets.all(collectionCardPadding),
        child: Semantics(label: collectionCardSemanticsLabel(item), excludeSemantics: true,
          child: Column(mainAxisAlignment: center, crossAxisAlignment: center, children: [
            Icon(itemIconData(item.icon), size: collectionCardIconSize,
                 color: onSurface.withValues(alpha: agingIconOpacity(item.agingStage))),
            SizedBox(height: 8),
            Text(item.name, style: titleSmall(color: onSurface), textAlign: center, maxLines: 2, overflow: ellipsis),
            SizedBox(height: 4),
            Text(collectionIntervalText(item.baselineIntervalDays), style: bodySmall(color: onSurfaceVariant),
                 textAlign: center, maxLines: 1, overflow: ellipsis),
          ])))))))
```

- **経過日数・最終実施日・「やった」ボタンを出さない**(図鑑は眺める場所。記録の入口は置かない)
- 古びは紙の面とアイコンの掠れだけ。テキストの色は変えない(一覧のカードと同じ方針)
- `Semantics` には `button: true` を付けない(`InkWell` がタップ操作を読み上げに出す)

## 判断7: テスト

既存テストのヘルパ(`FakeItemRepository` / `FakeCategoryRepository` / `FakeClock`、`App` を `ProviderScope` で包む `_app`)を
`test/ui/item_list_screen_test.dart` と同じ形で使う。記録済みにするには `repository.markDone(id, 日時)` を呼ぶ。
基準間隔を持たせるには同じ項目に 3 回以上 `markDone` する(記録 1 件以下なら基準間隔は null)。

### `test/state/collection_test.dart`(新規)

`ItemView` を直接組み立てて `collectionOf` を検証する:
- 未実施(`elapsed: NeverDone()`)を除き、記録済みを入力順で返す
- `category` 指定で一致するものだけ。null なら全件
- `query` の部分一致・英字の大文字小文字を無視(`'ABC'` で `'abcd'` が当たる)・前後空白を無視・空白だけなら絞らない
- 未実施の項目は名前が一致しても返らない

### `test/ui/widgets/collection_card_test.dart`(新規)

- `collectionIntervalText`: `7.0` → `平均7日` / `6.5` → `平均7日` / `6.4` → `平均6日` / null → `学習中`
- `collectionColumnCount`: `TextScaler.noScaling` → 3 / `TextScaler.linear(2)` → 2
- カードに項目名と `平均N日` が出て、経過日数(`N日前`)と「やった」が出ない
- タップで `onTap` が呼ばれる
- 読み上げ文が `項目名、平均7日` の形になる(`collectionCardSemanticsLabel` を直接検証)

### `test/ui/screens/collection_screen_test.dart`(新規。`App` 全体を起動する)

- 起動直後はホーム(`ItemListScreen` が見え、`NavigationBar` に「ホーム」「図鑑」)
- 「図鑑」をタップすると、記録済みの項目だけがカード(`CollectionCard`)で並び、未実施の項目は出ない
- 記録済み 0 件なら「まだ図鑑にカードがありません」
- カテゴリのチップで絞り込める。**ホームのチップの選択が図鑑に移らない**(ホームで選んだあと図鑑を開くと「すべて」)
- 検索ボタン → 入力で部分一致に絞れる / 一致なしで「条件に合う項目はありません」/「検索を閉じる」で全件に戻る
- カードをタップすると `ItemDetailSheet` が開く
- ホームで「やった」→ 取り消し導線(`SnackBar`)が出た状態で「図鑑」をタップすると `SnackBar` が消える
- 「ホーム」に戻ると一覧が表示される
- 文字サイズ 200%(`MediaQuery` の `textScaler: TextScaler.linear(2)`。`test/ui/accessibility_test.dart` の組み方に倣う)で図鑑を開いても例外(オーバーフロー)が出ない(`tester.takeException()` が null)

### 既存テストの更新

- `test/ui/terminology_test.dart`: 既存の走査と同じ形で、**図鑑タブを開いた状態**(記録済みの項目あり)の描画文字列に禁止語が無いことを検証するケースを 1 つ足す
- 既存テストは `App` の起動画面が `HomeShell` に変わっても通る想定(図鑑は `IndexedStack` の非表示側で offstage のため、`find` の既定では拾われない)。**落ちたテストがあれば、原因が「ナビ追加による見た目の変化(ナビの高さぶん画面が縮む等)」の範囲なら期待値をその変化に合わせて直してよい。** それ以外の理由で落ちたら止めて報告する

## 判断8: レイヤー

- `lib/state/collection.dart` は `domain/` と `state/` だけに依存する(`flutter/material.dart` を import しない)
- `ui/` の新規ファイルは `state/` / `domain/` / `ui/` に依存してよい。`data/` を import しない(`test/architecture/layer_dependency_test.dart` が検査する)

## 判断9: 実装中に見つかった副作用への対処(司令塔が追記。fork の「判断待ち」への回答)

`flutter test` で 2 件落ちた。**原因は別々**なので対処も分ける。

### 9-1. `SnackBar` の複製と Hero タグの衝突 → **図鑑だけを専用の `ScaffoldMessenger` で包む**

`IndexedStack` の両画面の `Scaffold` がともにルートとしてアプリの `ScaffoldMessenger` に登録され、
取り消し導線が図鑑側(オフステージ)にも複製される。同じ内容の `SnackBar` が 2 つ載ると Hero タグが衝突し、
記録直後の画面遷移で例外になる(実機でも起きる)。

`home_shell.dart` の `IndexedStack` の children を次に変える:

```dart
children: const [
  ItemListScreen(),
  // 図鑑の Scaffold をアプリの ScaffoldMessenger に登録させない。登録されると一覧の取り消し導線が
  // オフステージの図鑑にも複製され、同じ Hero タグの SnackBar が 2 つ載って遷移時に衝突する(#34 判断9)。
  ScaffoldMessenger(child: CollectionScreen()),
],
```

- **一覧側は包まない。** 取り消し導線はアプリの `ScaffoldMessenger` に出たままにする。`HomeShell._select` の
  `ScaffoldMessenger.of(context).clearSnackBars()`(`HomeShell` の context はアプリの messenger を指す)が
  そのまま一覧の導線を閉じられるように、包むのは図鑑だけにする
- 図鑑は `SnackBar` を出さない(記録の入口が無い)。図鑑から開く詳細シート・編集画面は `Navigator` に積まれるので、
  編集画面の `SnackBar` はこれまでどおりアプリの messenger に出る
- `HomeShell` の doc コメントの「`Scaffold` にしない」段落の後に、上のコメントと同じ趣旨を 1 文足す
- **回帰テストを 1 つ足す**(`test/ui/screens/collection_screen_test.dart`): ホームで「やった」→ 取り消し導線が出た状態で
  FAB から登録画面へ遷移しても `tester.takeException()` が null、かつ `find.byType(SnackBar)` が `findsNothing`

### 9-2. 長い項目名の省略テストがオフステージの図鑑を数える → **テストの走査からオフステージを除く**

`test/ui/accessibility_test.dart` の `_ellipsizedTexts` はレンダーツリー全体を走査するため、`IndexedStack` の
非表示側(図鑑の `CollectionCard`)の省略テキストまで拾う。利用者に見えないものを数えているのはテスト側の誤りなので、
**製品コードではなく走査を直す**:

```dart
void visit(RenderObject object) {
  // IndexedStack の非表示側(図鑑タブ)は利用者に見えない。数えない(#34)。
  if (object is RenderOffstage && object.offstage) {
    return;
  }
  if (object is RenderParagraph && object.didExceedMaxLines) {
    found.add(object.text.toPlainText());
  }
  object.visitChildren(visit);
}
```

- 期待値(`[name]`)は変えない
- `test/ui/terminology_test.dart` の `_renderedTexts` は**変えない**(禁止語は見えない側にも無い方が良く、オフステージを含めて走査するのは害がない)

## ディレクトリ構造

```
lib/
  app.dart                               (変更)
  state/collection.dart                  (新規)
  ui/item_navigation.dart                (新規)
  ui/screens/home_shell.dart             (新規)
  ui/screens/collection_screen.dart      (新規)
  ui/screens/item_list_screen.dart       (変更)
  ui/widgets/collection_card.dart        (新規)
  ui/widgets/load_error.dart             (新規)
test/
  state/collection_test.dart             (新規)
  ui/widgets/collection_card_test.dart   (新規)
  ui/screens/collection_screen_test.dart (新規)
  ui/terminology_test.dart               (変更)
```

## パフォーマンス考慮事項

- 図鑑は `itemListProvider` の値を絞るだけで、購読・クエリを増やさない
- `collectionOf` はビルドのたびに走るが、最大 100 件の線形走査で十分軽い。メモ化しない
- `GridView.builder` で遅延生成する
