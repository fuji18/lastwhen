import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'item_view.dart';
import 'providers.dart';

/// 一覧の状態。UI はこれを `AsyncValue<List<ItemView>>` として受ける。
final itemListProvider =
    StreamNotifierProvider<ItemListNotifier, List<ItemView>>(
      ItemListNotifier.new,
    );

/// 項目一覧を表示モデルへ変換して流す。
///
/// **`StreamNotifier` を継承する**(design.md 判断1)。供給源の `watchAll()` が Stream なので、
/// 購読・初回値・破棄を Riverpod 側に持たせる。
/// #6 以降の書き込みメソッド(`addItem` / `markDone` など)はこのクラスに足していく。
class ItemListNotifier extends StreamNotifier<List<ItemView>> {
  @override
  Stream<List<ItemView>> build() {
    final repository = ref.watch(itemRepositoryProvider);
    final clock = ref.watch(clockProvider);
    // now は 1 回の emit につき 1 つ。行ごとに Clock を呼ばない(判断2)。
    return repository.watchAll().map(
      (items) => toItemViews(items, now: clock.now()),
    );
  }
}
