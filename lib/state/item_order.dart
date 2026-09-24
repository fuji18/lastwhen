import '../domain/item.dart';
import 'item_view.dart';

/// 相対経過度の降順に並べ替えた新しいリストを返す(F30)。
///
/// null は下部にまとめ、同値・null 同士は入力順を保つ。
/// 入力は登録順(sortOrder 昇順)であることが前提。ItemView は sortOrder を
/// 持たず、List.sort は安定ソートを保証しないため、入力位置で比較する。
List<ItemView> sortByRelativeElapsed(List<ItemView> views) {
  final indexed = [
    for (var i = 0; i < views.length; i++) (index: i, view: views[i]),
  ];
  indexed.sort((a, b) {
    final ra = a.view.relativeElapsed;
    final rb = b.view.relativeElapsed;
    if (ra != null && rb != null) {
      final byRelative = rb.compareTo(ra);
      if (byRelative != 0) {
        return byRelative;
      }
    } else if (ra == null && rb != null) {
      return 1;
    } else if (ra != null && rb == null) {
      return -1;
    }
    return a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.view];
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
