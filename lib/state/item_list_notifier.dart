import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/item_name.dart';
import 'add_item_result.dart';
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

  /// 項目を登録する。検証を通ったときだけ保存し、結果を返す。
  ///
  /// **`state` を触らない。** 一覧は `watchAll()` の購読結果だけを反映させる
  /// (`docs/functional-design.md`「エラーハンドリング」)。保存に失敗しても一覧は
  /// 直前の値のまま残り、UI が一覧ごとエラー画面に切り替わることがない。
  ///
  /// **楽観的 UI 更新を採らない**(`CLAUDE.md`)。保存の完了を待ってから返る。
  Future<AddItemResult> addItem(String rawName) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return AddItemRejected(reason);
      case ValidItemName(:final value):
        try {
          await ref
              .read(itemRepositoryProvider)
              .add(value, now: ref.read(clockProvider).now());
          return const AddItemSucceeded();
        } catch (error, stackTrace) {
          // lib/state は package:flutter/ を import できないので debugPrint は使えない(判断9)。
          developer.log(
            '項目の登録に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const AddItemFailed();
        }
    }
  }
}
