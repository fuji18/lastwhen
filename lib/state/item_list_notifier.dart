import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/item.dart';
import '../domain/item_icon.dart';
import '../domain/item_name.dart';
import 'add_item_result.dart';
import 'edit_item_result.dart';
import 'item_order.dart';
import 'item_view.dart';
import 'mark_done_result.dart';
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
/// 登録・記録・取り消しは結果型を返し、一覧の更新は購読に任せる。
/// 並び順は相対経過度の降順(F30)。記録では組み替えず、開き直し・復帰で確定し直す。
class ItemListNotifier extends StreamNotifier<List<ItemView>> {
  /// 最後に流れてきたドメインの一覧。取り消し用の直前値を引くために控える(判断4)。
  List<Item> _latestItems = const <Item>[];

  /// 確定済みの並び順。null のときは次の emit で確定する。
  List<ItemId>? _fixedOrder;

  @override
  Stream<List<ItemView>> build() {
    final repository = ref.watch(itemRepositoryProvider);
    final clock = ref.watch(clockProvider);
    // build し直し = 一覧を開き直した扱い。次の emit で並びを確定させる。
    _fixedOrder = null;
    // now は 1 回の emit につき 1 つ。行ごとに Clock を呼ばない(判断2)。
    return repository.watchAll().map((items) {
      _latestItems = items;
      return _ordered(toItemViews(items, now: clock.now()));
    });
  }

  /// 未確定なら相対経過度で確定させ、確定済みならその並びを保つ。
  List<ItemView> _ordered(List<ItemView> views) {
    final fixed = _fixedOrder;
    final ordered = fixed == null
        ? sortByRelativeElapsed(views)
        : applyFixedOrder(views, fixed);
    _fixedOrder = [for (final view in ordered) view.id];
    return ordered;
  }

  /// 項目を登録する。検証を通ったときだけ保存し、結果を返す。
  ///
  /// **`state` を触らない。** 一覧は `watchAll()` の購読結果だけを反映させる
  /// (`docs/functional-design.md`「エラーハンドリング」)。保存に失敗しても一覧は
  /// 直前の値のまま残り、UI が一覧ごとエラー画面に切り替わることがない。
  ///
  /// **楽観的 UI 更新を採らない**(`CLAUDE.md`)。保存の完了を待ってから返る。
  Future<AddItemResult> addItem(String rawName, {ItemIcon? icon}) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return AddItemRejected(reason);
      case ValidItemName(:final value):
        try {
          await ref
              .read(itemRepositoryProvider)
              .add(value, icon: icon, now: ref.read(clockProvider).now());
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

  /// アプリ復帰時に、現在時刻で経過日数と並び順を確定し直す。
  ///
  /// 一覧が未取得・読み込み失敗なら何もしない。初回 emit で確定する。
  void refreshOrder() {
    if (state is! AsyncData<List<ItemView>>) {
      return;
    }
    _fixedOrder = null;
    state = AsyncData(
      _ordered(toItemViews(_latestItems, now: ref.read(clockProvider).now())),
    );
  }

  /// 「やった」を記録する。現在時刻を最終実施日として保存する。
  ///
  /// **確認は挟まない**(`docs/product-requirements.md` F3)。誤操作は [undoMarkDone] で救う。
  /// 戻り値の [MarkDoneSucceeded.undo] を取り消し導線へ渡す。
  Future<MarkDoneResult> markDone(ItemId id) async {
    final index = _latestItems.indexWhere((item) => item.id == id);
    // 一覧に無い = 削除と同時操作。書き込まず、UI にも出さない(判断4)。
    if (index < 0) {
      return const MarkDoneIgnored();
    }
    final previous = _latestItems[index].lastDoneAt;
    final now = ref.read(clockProvider).now();
    try {
      await ref.read(itemRepositoryProvider).markDone(id, now);
      return MarkDoneSucceeded(
        MarkDoneUndo(id: id, previousLastDoneAt: previous),
      );
    } catch (error, stackTrace) {
      developer.log(
        '「やった」の記録に失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const MarkDoneFailed();
    }
  }

  /// [markDone] を取り消し、最終実施日を直前の値へ戻す。
  ///
  /// **未実施だった項目は未実施(null)へ戻す。** 「今日」のまま残すと記録が捏造される。
  Future<UndoResult> undoMarkDone(MarkDoneUndo undo) async {
    try {
      await ref
          .read(itemRepositoryProvider)
          .restoreLastDoneAt(
            undo.id,
            undo.previousLastDoneAt,
            // 取り消しも書き込みなので updatedAt は前進させる(巻き戻さない)。
            now: ref.read(clockProvider).now(),
          );
      return const UndoSucceeded();
    } catch (error, stackTrace) {
      developer.log(
        '「やった」の取り消しに失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const UndoFailed();
    }
  }

  /// 項目名とアイコンを変更する。**最終実施日は変わらない**(判断6)。
  ///
  /// 検証は登録と同じ `validateItemName`(`docs/product-requirements.md` F6)。
  /// 一覧に無い ID は書き込まず [EditItemIgnored] を返す(判断7)。
  Future<EditItemResult> editItem(
    ItemId id,
    String rawName, {
    required ItemIcon? icon,
  }) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return EditItemRejected(reason);
      case ValidItemName(:final value):
        // 検証 → 存在確認の順(判断8)。
        if (!_latestItems.any((item) => item.id == id)) {
          return const EditItemIgnored();
        }
        try {
          await ref
              .read(itemRepositoryProvider)
              .edit(
                id,
                name: value,
                icon: icon,
                now: ref.read(clockProvider).now(),
              );
          return const EditItemSucceeded();
        } catch (error, stackTrace) {
          developer.log(
            '項目の変更に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const EditItemFailed();
        }
    }
  }

  /// 項目を削除する。**記録ごと消える。取り消せない。**
  ///
  /// 確認を取るのは UI の責務(`docs/product-requirements.md` F7 / 判断1)。
  /// ここは確認済みの前提で呼ばれる。**`Clock` を使わない**(判断11)。
  Future<DeleteItemResult> deleteItem(ItemId id) async {
    if (!_latestItems.any((item) => item.id == id)) {
      return const DeleteItemIgnored();
    }
    try {
      await ref.read(itemRepositoryProvider).delete(id);
      return const DeleteItemSucceeded();
    } catch (error, stackTrace) {
      developer.log(
        '項目の削除に失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const DeleteItemFailed();
    }
  }
}
