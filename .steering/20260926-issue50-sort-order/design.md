# 設計: 一覧の並び替え(F15 / Issue #50)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れない。** データ層は一切変えない
> - **依存を追加しない**(`pubspec.*` を触らない)
> - **`docs/` は司令塔が更新済み**(`functional-design.md`「一覧の並び替え(F15)」節・F13 / F31 の追従・テスト表、
>   `architecture.md`、`glossary.md`「並び順」)。実装者は `docs/` を触らない
> - UI 文言は下の表記どおりに書く(用語集: 「ソート」と言わない)

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 選択は保存しない。`Notifier` の既定値 `aging` のみ | ユーザー判断。F13 と同じ。ユーザー設定の保存先を持たない |
| B | UI は AppBar の `PopupMenuButton` + `CheckedPopupMenuItem` | ユーザー判断。Material 3 の組み込みだけで済む |
| C | 名前順は正規化キー(全角→半角・小文字化・カタカナ→ひらがな)の文字コード順 | ユーザー判断。読み仮名のデータが無い |
| D | 図鑑は常に経年順。**`itemListProvider` の state は「選んだ並び」、図鑑は新設の `collectionItemsProvider` から「確定済みの経年順」を受ける** | ユーザー判断。一覧側の既存テスト(既定 = 経年順)がそのまま通る形 |
| E | 並び順の変更は `ItemListNotifier.build` 内の `ref.listen` で受ける。**`ref.watch` しない** | watch すると build し直しで `watchAll()` を購読し直し、読み込み中表示が一瞬出る |
| F | 並びの確定タイミングは F30 と同じ + **並び順を選び直したとき**。選び直しは「選んだ並び」だけを確定し直し、図鑑用の経年順は保つ | 記録操作では組み替えない規則を全並び順で保つ |
| G | 同じ並び順を選び直しても何も起きない | `Notifier` は同一値の代入で通知しない(enum は identical)。特別な処理を書かない |

---

## 1. `lib/state/item_order.dart`(並べ方の純関数)

### 1-1. import を足す

```dart
import '../domain/elapsed_days.dart';
```

### 1-2. 並び順の enum を足す(ファイル先頭の import の後)

```dart
/// 一覧の並び順(F15)。既定は [aging](F30)。
enum ItemSortOrder {
  /// 経年順。相対経過度の降順(F30)。null は下部。
  aging,

  /// 経過日数順。経過日数の降順(長く空いている項目が上)。未実施は下部。
  elapsedDays,

  /// 名前順。[nameSortKey] の昇順。未実施を区別しない。
  name,

  /// 登録順。`sortOrder` の昇順 = 入力順そのまま。
  registered,
}
```

### 1-3. 安定ソートの共通化

既存 `sortByRelativeElapsed` の中身を、次の private ヘルパーへ移して使い回す。
**`sortByRelativeElapsed` の公開シグネチャ・doc コメント・挙動は変えない**(既存テストがそのまま通ること)。

```dart
/// [compare] で並べ、0(同値)なら入力位置で比べる安定ソート。
///
/// ItemView は sortOrder を持たず、List.sort は安定ソートを保証しないため、入力位置で比較する。
List<ItemView> _stableSort(
  List<ItemView> views,
  int Function(ItemView a, ItemView b) compare,
) {
  final indexed = [
    for (var i = 0; i < views.length; i++) (index: i, view: views[i]),
  ];
  indexed.sort((a, b) {
    final byKey = compare(a.view, b.view);
    return byKey != 0 ? byKey : a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.view];
}

/// 降順で比べ、null は後ろ(下部)に置く。null 同士は 0。
int _compareDescendingNullsLast<T extends Comparable<Object>>(T? a, T? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}
```

> `T extends Comparable<Object>` で `double` / `int` が通らない場合は、`num` 専用の
> `int _compareDescendingNullsLast(num? a, num? b)` にしてよい(挙動は同じ)。これは設計判断ではない。

`sortByRelativeElapsed` は次の 1 式に置き換える(doc コメントは元のまま残す。ただし 2 段落目の
「ItemView は sortOrder を持たず…」の文は `_stableSort` へ移したので削ってよい)。

```dart
List<ItemView> sortByRelativeElapsed(List<ItemView> views) => _stableSort(
  views,
  (a, b) => _compareDescendingNullsLast(a.relativeElapsed, b.relativeElapsed),
);
```

### 1-4. 並び順ごとの並べ替え

```dart
/// [order] で並べ替えた新しいリストを返す(F15)。
///
/// 入力は登録順(sortOrder 昇順)であることが前提。同値は入力順(= 登録順)を保つ。
List<ItemView> sortItemViews(List<ItemView> views, ItemSortOrder order) =>
    switch (order) {
      ItemSortOrder.aging => sortByRelativeElapsed(views),
      ItemSortOrder.elapsedDays => _stableSort(
        views,
        (a, b) => _compareDescendingNullsLast(
          _elapsedDaysOf(a.elapsed),
          _elapsedDaysOf(b.elapsed),
        ),
      ),
      ItemSortOrder.name => _sortByName(views),
      ItemSortOrder.registered => List.of(views, growable: false),
    };

/// 経過日数ラベルを日数へ戻す。未実施は null(下部にまとめる)。
int? _elapsedDaysOf(ElapsedLabel label) => switch (label) {
  NeverDone() => null,
  Today() => 0,
  Yesterday() => 1,
  DaysAgo(:final days) => days,
};

/// 名前順。キーは 1 項目につき 1 回だけ作る(比較のたびに正規化しない)。
List<ItemView> _sortByName(List<ItemView> views) {
  final keys = {for (final view in views) view.id: nameSortKey(view.name)};
  return _stableSort(views, (a, b) => keys[a.id]!.compareTo(keys[b.id]!));
}
```

### 1-5. 名前順のキー

```dart
/// 名前順の比較キー(F15)。読み仮名を持たないため、表記の揺れだけを畳む。
///
/// 1. 全角英数字・記号(U+FF01〜U+FF5E)を半角へ、全角スペース(U+3000)を半角スペースへ
/// 2. カタカナ(U+30A1〜U+30F6)をひらがなへ
/// 3. 小文字へ
///
/// 漢字は読みではなく文字コード順になり、かなより後ろに来る(`docs/functional-design.md` F15)。
/// 半角カタカナと長音符「ー」はそのまま。
String nameSortKey(String name) {
  final buffer = StringBuffer();
  for (final rune in name.runes) {
    buffer.writeCharCode(_foldRune(rune));
  }
  return buffer.toString().toLowerCase();
}

int _foldRune(int rune) {
  if (rune >= 0xFF01 && rune <= 0xFF5E) {
    return rune - 0xFEE0;
  }
  if (rune == 0x3000) {
    return 0x20;
  }
  if (rune >= 0x30A1 && rune <= 0x30F6) {
    return rune - 0x60;
  }
  return rune;
}
```

`applyFixedOrder` は変えない。

---

## 2. `lib/state/item_sort_order.dart`(新規・選択中の並び順)

`lib/state/category_filter.dart` の `categoryFilterProvider` と同じ形。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item_order.dart';

/// 一覧の並び順(F15)。**保存しない**(再起動で経年順に戻る)。図鑑には効かない。
final itemSortOrderProvider =
    NotifierProvider<ItemSortOrderNotifier, ItemSortOrder>(
      ItemSortOrderNotifier.new,
    );

class ItemSortOrderNotifier extends Notifier<ItemSortOrder> {
  @override
  ItemSortOrder build() => ItemSortOrder.aging;

  void select(ItemSortOrder order) => state = order;
}
```

---

## 3. `lib/state/item_list_notifier.dart`

### 3-1. import を足す

```dart
import 'item_sort_order.dart';
```

### 3-2. クラス doc コメントの最終行を差し替える

変更前: `/// 並び順は相対経過度の降順(F30)。記録では組み替えず、開き直し・復帰で確定し直す。`

変更後:

```dart
/// 並び順は選択中の [ItemSortOrder](既定は F30 の相対経過度の降順)。記録では組み替えず、
/// 開き直し・復帰・並び順の選び直しで確定し直す。図鑑用に経年順の確定済みの並びも別に持つ。
```

### 3-3. フィールドを足す

`_fixedOrder` の直後:

```dart
  /// 確定済みの経年順(F30)。図鑑は選んだ並び順に追従しないので別に持つ。null は次の emit で確定。
  List<ItemId>? _fixedAgingOrder;

  /// 確定済みの経年順の ID 列。`collectionItemsProvider` が読む。未確定なら空。
  ///
  /// state の更新と同時に書き換わるので、state を watch している側が読めば食い違わない。
  List<ItemId> get agingOrder => _fixedAgingOrder ?? const <ItemId>[];
```

`_fixedOrder` の doc コメントは `/// 確定済みの並び順(選択中の並び順で確定)。null のときは次の emit で確定する。` に変える。

### 3-4. `build()`

`_fixedOrder = null;` の直後に次を足す。

```dart
    _fixedAgingOrder = null;
    // watch しない。build し直すと watchAll() を購読し直し、読み込み中の表示が一瞬出る(判断E)。
    ref.listen(itemSortOrderProvider, (_, _) => _reconfirm(includeAging: false));
```

### 3-5. `_ordered()` を差し替える

```dart
  /// 未確定なら確定させ、確定済みならその並びを保つ。選んだ並びと経年順の両方を扱う。
  List<ItemView> _ordered(List<ItemView> views) {
    final agingFixed = _fixedAgingOrder;
    final aging = agingFixed == null
        ? sortByRelativeElapsed(views)
        : applyFixedOrder(views, agingFixed);
    _fixedAgingOrder = [for (final view in aging) view.id];

    final fixed = _fixedOrder;
    final ordered = fixed == null
        ? sortItemViews(views, ref.read(itemSortOrderProvider))
        : applyFixedOrder(views, fixed);
    _fixedOrder = [for (final view in ordered) view.id];
    return ordered;
  }
```

### 3-6. `refreshOrder()` と選び直しを共通化する

`refreshOrder()` の本体を private の `_reconfirm` へ移し、`refreshOrder` はそれを呼ぶだけにする。
doc コメントは `refreshOrder` に残す。

```dart
  void refreshOrder() => _reconfirm(includeAging: true);

  /// 現在時刻で経過日数を数え直し、選んだ並びを確定し直す。[includeAging] なら図鑑用の経年順も。
  ///
  /// 一覧が未取得・読み込み失敗なら何もしない。初回 emit で確定する。
  void _reconfirm({required bool includeAging}) {
    if (state is! AsyncData<List<ItemView>>) {
      return;
    }
    _fixedOrder = null;
    if (includeAging) {
      _fixedAgingOrder = null;
    }
    state = AsyncData(
      _ordered(toItemViews(_latestItems, now: ref.read(clockProvider).now())),
    );
  }
```

`refreshOrder` の既存 doc コメント(「アプリ復帰時に…」「一覧が未取得・読み込み失敗なら何もしない…」)は
そのまま `refreshOrder` の上に残す。

それ以外のメソッドは変えない。

---

## 4. `lib/state/collection.dart`(図鑑の供給源)

import を足す: `item_list_notifier.dart` / `item_order.dart`。

`collectionCategoryFilterProvider` の直後に足す。

```dart
/// 図鑑の供給源。一覧で選んだ並び順(F15)に追従せず、**常に F30 の確定済みの並び**で流す。
///
/// `agingOrder` は state の更新と同時に書き換わるため、state を watch していれば読み遅れない。
final collectionItemsProvider = Provider<AsyncValue<List<ItemView>>>((ref) {
  final items = ref.watch(itemListProvider);
  final order = ref.read(itemListProvider.notifier).agingOrder;
  return items.whenData((views) => applyFixedOrder(views, order));
});
```

`collectionOf` は変えない(入力順を保つので、上の並びがそのまま図鑑の並びになる)。

---

## 5. UI 層

### 5-1. `lib/ui/widgets/item_sort_menu_button.dart`(新規)

`CategoryFilterBar` と同じく **provider を読まない**(値とコールバックだけを受ける)。

```dart
import 'package:flutter/material.dart';

import '../../state/item_order.dart';

/// 並び順の UI 文言。
String itemSortOrderLabel(ItemSortOrder order) => switch (order) {
  ItemSortOrder.aging => '経年順',
  ItemSortOrder.elapsedDays => '経過日数順',
  ItemSortOrder.name => '名前順',
  ItemSortOrder.registered => '登録順',
};

/// 一覧の AppBar に置く並び順のメニュー(F15)。選択中の候補にチェックを付ける。
///
/// provider を読まない(値とコールバックだけを受ける)。
class ItemSortMenuButton extends StatelessWidget {
  /// 並び順のメニューを作る。
  const ItemSortMenuButton({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 選択中の並び順。
  final ItemSortOrder selected;

  /// 並び順が選ばれたときの処理。
  final ValueChanged<ItemSortOrder> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ItemSortOrder>(
      icon: const Icon(Icons.sort),
      tooltip: '並び順',
      initialValue: selected,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final order in ItemSortOrder.values)
          CheckedPopupMenuItem<ItemSortOrder>(
            value: order,
            checked: order == selected,
            child: Text(itemSortOrderLabel(order)),
          ),
      ],
    );
  }
}
```

### 5-2. `lib/ui/screens/item_list_screen.dart`

- import を足す: `../../state/item_sort_order.dart` / `../widgets/item_sort_menu_button.dart`
- `build` の AppBar `actions` の**先頭**(カテゴリ管理ボタンの前)に、`hasItems` のときだけ置く:

```dart
          // 追加の FAB と同じ条件で出す。空状態・読み込み中・失敗では並べるものが無い。
          if (hasItems)
            ItemSortMenuButton(
              selected: ref.watch(itemSortOrderProvider),
              onSelected: (order) =>
                  ref.read(itemSortOrderProvider.notifier).select(order),
            ),
```

それ以外(`_buildList` の `filterByCategory` など)は変えない。state が選んだ並びで来るので、
絞り込みは既存どおりその部分列になる。

### 5-3. `lib/ui/screens/collection_screen.dart`

- `build` の `final items = ref.watch(itemListProvider);` を `final items = ref.watch(collectionItemsProvider);` に変える
- 再試行の `ref.invalidate(itemListProvider)` は**変えない**(供給源の購読をやり直す)
- `itemListProvider` の import が不要になったら消す(`invalidate` で使っているなら残る)

---

## 6. テスト

既存テストは**1 件も期待値を変えずに**通ること(既定が経年順のため)。

### 6-1. `test/state/item_order_test.dart` に追加

既存の `_view(id, relative)` ヘルパーは残し、経過日数と名前を指定できるヘルパーを足す。

```dart
ItemView _named(String id, {String? name, ElapsedLabel elapsed = const NeverDone()}) =>
    ItemView(id: ItemId(id), name: name ?? id, elapsed: elapsed, lastDoneText: null);
```

`group('sortItemViews', ...)`:

| テスト名 | 入力(登録順) | 期待(名前 or id の順) |
| --- | --- | --- |
| 経年順は sortByRelativeElapsed と同じになる | 既存 `_view` で `[n1:null, a:1, b:2]` | `sortByRelativeElapsed` の結果と等しい |
| 経過日数順は日数の降順で未実施は下部に登録順でまとまる | `n1:NeverDone, b:DaysAgo(3), c:Today, d:DaysAgo(10), n2:NeverDone, e:Yesterday` | `d, b, e, c, n1, n2` |
| 経過日数順で同じ日数は登録順を保つ | `a:DaysAgo(5), b:DaysAgo(5), c:DaysAgo(5)` | `a, b, c` |
| 名前順はかなの表記を畳んで五十音に並ぶ | 名前 `ゴミ出し, 洗濯, ごはん, ｂａｎａｎａ, あさ, Apple` | `Apple, ｂａｎａｎａ, あさ, ごはん, ゴミ出し, 洗濯` |
| 名前順で同じ名前は登録順を保つ | id `a`,`b` とも名前 `掃除`、id `c` 名前 `あ` | `c, a, b`(id で確認) |
| 名前順は未実施を区別しない | `a` 名前 `い`(DaysAgo(3))、`b` 名前 `あ`(NeverDone) | `b, a` |
| 登録順は入力順のまま | 任意の 3 件(経過日数・名前をばらばらに) | 入力と同じ順 |
| 空リストは全ての並び順で空になる | `[]` を `ItemSortOrder.values` 全部で | 空 |

`group('nameSortKey', ...)`:

| 入力 | 期待 |
| --- | --- |
| `'ＡＢＣ　ｘ１'` | `'abc x1'` |
| `'カタカナ'` | `'かたかな'` |
| `'ヴ'`(U+30F4) | `'ゔ'`(U+3094) |
| `'コーヒー'` | `'こーひー'`(長音符はそのまま) |
| `'ｶﾀ'`(半角カタカナ) | `'ｶﾀ'`(そのまま) |
| `'洗濯'` | `'洗濯'` |

### 6-2. `test/state/item_list_notifier_test.dart` に `group('並び順の選択(F15)', ...)` を追加

既存 `group('並び順(F30)')` の `ready()` と同じデータ(車の点検: 相対経過度大・180日前 / 美容院: 未実施 /
風呂掃除: 14日前)を使う。group 内に同じ形の `ready()` / `current()` を置く(既存 group の中の関数は
参照できないため複製してよい)。`itemSortOrderProvider` は `container.read(itemSortOrderProvider.notifier).select(...)` で切り替える。

| テスト名 | 手順 | 期待 |
| --- | --- | --- |
| 既定は経年順 | `ready()` | `container.read(itemSortOrderProvider)` が `ItemSortOrder.aging` |
| 名前順を選ぶとすぐに名前順で確定する | `ready()` の後に `repository.add('あさ散歩', now: now)` → `current()` で末尾に付いたことを確認 → `select(name)` → `current()` | 先頭が `あさ散歩`(かなは漢字より前)。登録直後(選ぶ前)は末尾だったこと |
| 経過日数順では未実施が下部で日数の降順 | `select(elapsedDays)` → `current()` | `['車の点検', '風呂掃除', '美容院']` |
| 登録順を選ぶと登録した順になる | `select(registered)` → `current()` | `['車の点検', '美容院', '風呂掃除']` |
| 経過日数順で記録しても組み替えない | `select(elapsedDays)` → 先頭(車の点検)を `markDone` → `current()` | 順は `['車の点検', '風呂掃除', '美容院']` のまま、先頭が `Today` |
| 記録後に refreshOrder を呼ぶと選んだ並び順で確定し直す | 上の続きで `refreshOrder()` → `current()` | `['風呂掃除', '車の点検', '美容院']`(車の点検は今日 = 0 日) |
| 読み込み中に並び順を選んでも例外を投げない | 一覧の読み込み前に `select(name)` → その後 `itemListProvider.future` を待つ | 例外なし。最初の値が名前順で確定している |
| 図鑑の供給源は選んだ並び順に追従しない | `select(registered)` → `current()` → `container.read(collectionItemsProvider).requireValue` | 経年順 `['風呂掃除', '車の点検', '美容院']` |

### 6-3. `test/state/collection_test.dart`

変更不要(`collectionOf` は変えていない)。`collectionItemsProvider` のテストは 6-2 の最終行で担保する。

### 6-4. `test/ui/item_list_screen_test.dart` に `group('並び順の選択(F15)', ...)` を追加

既存 `group('並び順(F30)')` の `pumpOrderedItems` と同じデータを使う(group 内に複製してよい)。
`top(tester, name)` も同様に複製する。メニューは `find.byTooltip('並び順')` をタップして開き、
`find.text('名前順')` 等をタップして選ぶ(タップ後 `pumpAndSettle`)。

| テスト名 | 期待 |
| --- | --- |
| 項目があると並び順ボタンが出て空のときは出ない | 項目 0 件で `find.byTooltip('並び順')` が `findsNothing`、`pumpOrderedItems` 後は `findsOneWidget` |
| メニューに 4 つの並び順が出て経年順にチェックが付いている | 4 文言が出る。`tester.widget<CheckedPopupMenuItem<ItemSortOrder>>(...)` で `aging` の `checked` が true、他は false |
| 登録順を選ぶと登録した順に並ぶ | `車の点検` < `美容院` < `風呂掃除`(top の比較) |
| 経過日数順で記録してもカードの位置が変わらない | 経過日数順を選ぶ → `風呂掃除` の DoneButton をタップ → `風呂掃除` の top が変わらない |
| 絞り込みと併用しても選んだ並びを保つ | 既存 `group('カテゴリの絞り込み(F13)')` の `pumpWithCategories` と同じ準備で、同じカテゴリに 2 件以上入れ、登録順と経年順が異なるデータにする。登録順を選んでからカテゴリを選ぶと、表示が登録順の部分列になる |
| 選び直した並び順にチェックが移る | 名前順を選ぶ → メニューを開き直す → `name` が checked、`aging` が unchecked |

> 絞り込み併用のテストで準備データの作り方(カテゴリへの割り当て方法)が既存 group から読み取れない場合は、
> 推測せず止めて報告する。

### 6-5. 検証コマンド

変更したファイルに対して `dart format` / `flutter analyze --fatal-infos` / 関連テストを通す。
フルスイートは検収側(`/check`)が回す。
