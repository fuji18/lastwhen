import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/category.dart';
import '../domain/item.dart';
import '../domain/item_icon.dart';
import '../domain/item_name.dart';
import '../domain/past_date_record.dart';
import 'add_item_result.dart';
import 'edit_item_result.dart';
import 'item_order.dart';
import 'item_sort_order.dart';
import 'item_view.dart';
import 'mark_done_result.dart';
import 'providers.dart';
import 'record_past_date_result.dart';

/// 一覧の状態。UI はこれを `AsyncValue<List<ItemView>>` として受ける。
final itemListProvider =
    StreamNotifierProvider<ItemListNotifier, List<ItemView>>(
      ItemListNotifier.new,
    );

/// 過去の日付で記録したときの SnackBar 用の日付(`9月14日`)。ロケールは渡さない(`item_view.dart` と同じ理由)。
final DateFormat _pickedDateFormat = DateFormat('M月d日');

/// 項目一覧を表示モデルへ変換して流す。
///
/// **`StreamNotifier` を継承する**(design.md 判断1)。供給源の `watchAll()` が Stream なので、
/// 購読・初回値・破棄を Riverpod 側に持たせる。
/// 登録・記録・取り消しは結果型を返し、一覧の更新は購読に任せる。
/// 並び順は選択中の [ItemSortOrder](既定は F30 の相対経過度の降順)。記録では組み替えず、
/// 開き直し・復帰・並び順の選び直しで確定し直す。図鑑用に経年順の確定済みの並びも別に持つ。
class ItemListNotifier extends StreamNotifier<List<ItemView>> {
  /// 最後に流れてきたドメインの一覧。取り消し用の直前値を引くために控える(判断4)。
  List<Item> _latestItems = const <Item>[];

  /// 確定済みの並び順(選択中の並び順で確定)。null のときは次の emit で確定する。
  List<ItemId>? _fixedOrder;

  /// 確定済みの経年順(F30)。図鑑は選んだ並び順に追従しないので別に持つ。null は次の emit で確定。
  List<ItemId>? _fixedAgingOrder;

  /// 確定済みの経年順の ID 列。`collectionItemsProvider` が読む。未確定なら空。
  ///
  /// state の更新と同時に書き換わるので、state を watch している側が読めば食い違わない。
  List<ItemId> get agingOrder => _fixedAgingOrder ?? const <ItemId>[];

  @override
  Stream<List<ItemView>> build() {
    final repository = ref.watch(itemRepositoryProvider);
    final clock = ref.watch(clockProvider);
    // build し直し = 一覧を開き直した扱い。次の emit で並びを確定させる。
    _fixedOrder = null;
    _fixedAgingOrder = null;
    // watch しない。build し直すと watchAll() を購読し直し、読み込み中の表示が一瞬出る(判断E)。
    ref.listen(
      itemSortOrderProvider,
      (_, _) => _reconfirm(includeAging: false),
    );
    // now は 1 回の emit につき 1 つ。行ごとに Clock を呼ばない(判断2)。
    return repository.watchAll().map((items) {
      _latestItems = items;
      return _ordered(toItemViews(items, now: clock.now()));
    });
  }

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

  /// 項目を登録する。検証を通ったときだけ保存し、結果を返す。
  ///
  /// **`state` を触らない。** 一覧は `watchAll()` の購読結果だけを反映させる
  /// (`docs/functional-design.md`「エラーハンドリング」)。保存に失敗しても一覧は
  /// 直前の値のまま残り、UI が一覧ごとエラー画面に切り替わることがない。
  ///
  /// **楽観的 UI 更新を採らない**(`CLAUDE.md`)。保存の完了を待ってから返る。
  Future<AddItemResult> addItem(
    String rawName, {
    ItemIcon? icon,
    CategoryId? categoryId,
  }) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return AddItemRejected(reason);
      case ValidItemName(:final value):
        try {
          await ref
              .read(itemRepositoryProvider)
              .add(
                value,
                icon: icon,
                categoryId: categoryId,
                now: ref.read(clockProvider).now(),
              );
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

  /// 日付の選択で選べる最後の日(= 今日のローカル暦日の 0:00、ローカル時刻)。
  ///
  /// UI が `DateTime.now()` を呼ばないよう、`Clock` から作って渡す。
  DateTime todayLocalDate() {
    final now = ref.read(clockProvider).now().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  /// 過去の日付で記録する(F16)。[pickedDate] は日付の選択が返したローカルの暦日。
  ///
  /// 履歴に 1 行**追加**する。最新より古い日なら最終実施日は動かない。
  /// **確認は挟まない。** 誤りは [undoRecordPastDate] で救う。並びは組み替えない(F30)。
  Future<RecordPastDateResult> recordPastDate(
    ItemId id,
    DateTime pickedDate,
  ) async {
    if (!_latestItems.any((item) => item.id == id)) {
      return const RecordPastDateIgnored();
    }
    final now = ref.read(clockProvider).now();
    if (isFuturePickedDate(pickedDate, now: now)) {
      return const RecordPastDateRejected();
    }
    try {
      final logId = await ref
          .read(itemRepositoryProvider)
          .addDoneLog(id, doneAtOfPickedDate(pickedDate, now: now), now: now);
      if (logId == null) {
        return const RecordPastDateIgnored();
      }
      return RecordPastDateSucceeded(
        RecordPastDateUndo(id: id, logId: logId),
        dateText: _pickedDateFormat.format(pickedDate),
      );
    } catch (error, stackTrace) {
      developer.log(
        '過去の日付での記録に失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const RecordPastDateFailed();
    }
  }

  /// [recordPastDate] を取り消す。追加した 1 行だけを消す。
  Future<UndoResult> undoRecordPastDate(RecordPastDateUndo undo) async {
    try {
      await ref
          .read(itemRepositoryProvider)
          .removeDoneLog(
            undo.id,
            undo.logId,
            now: ref.read(clockProvider).now(),
          );
      return const UndoSucceeded();
    } catch (error, stackTrace) {
      developer.log(
        '過去の日付での記録の取り消しに失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const UndoFailed();
    }
  }

  /// 項目名・アイコン・カテゴリを変更する。**最終実施日は変わらない**(判断6)。
  ///
  /// 検証は登録と同じ `validateItemName`(`docs/product-requirements.md` F6)。
  /// 一覧に無い ID は書き込まず [EditItemIgnored] を返す(判断7)。
  Future<EditItemResult> editItem(
    ItemId id,
    String rawName, {
    required ItemIcon? icon,
    required CategoryId? categoryId,
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
                categoryId: categoryId,
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
