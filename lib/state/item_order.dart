import '../domain/elapsed_days.dart';
import '../domain/item.dart';
import 'item_view.dart';

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

/// 相対経過度の降順に並べ替えた新しいリストを返す(F30)。
///
/// null は下部にまとめ、同値・null 同士は入力順を保つ。
/// 入力は登録順(sortOrder 昇順)であることが前提。
List<ItemView> sortByRelativeElapsed(List<ItemView> views) => _stableSort(
  views,
  (a, b) => _compareDescendingNullsLast(a.relativeElapsed, b.relativeElapsed),
);

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

/// 確定済みの順序を保ち、削除済み ID を除き、新規項目を入力順で末尾に足す。
List<ItemView> applyFixedOrder(List<ItemView> views, List<ItemId> order) {
  final byId = {for (final view in views) view.id: view};
  final known = order.toSet();
  return [
    for (final id in order) ?byId[id],
    for (final view in views)
      if (!known.contains(view.id)) view,
  ];
}
