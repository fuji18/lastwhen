# 設計: 記録の履歴を日付ごとに削除できるようにする(Issue #63)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - パッケージ・アセットを追加しない。`pubspec.yaml` を変更しない
> - **`lib/data/database/` と `lib/data/migrations/` を触らない**(スキーマ・マイグレーションは変えない。`done_logs` の既存列だけで足りる)
> - 色・余白・タイポは `Theme.of(context)` から取る。UI 文言は本書の表記どおり
> - 既存テストの期待値を緩めない。`DoneHistoryEntry` のコンストラクタ変更に伴う引数の追加だけは行う(§6-3)

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 消える単位は**履歴の 1 行 = ローカルの 1 暦日**。その暦日の `done_logs` をすべて消す | ユーザー選択。画面の 1 行と消える範囲を一致させる |
| B | 暦日の範囲は**状態管理層**がローカルの `DateTime(y, m, d)` 〜 `DateTime(y, m, d + 1)` で作り、リポジトリには「日時の範囲」として渡す。リポジトリは暦日もタイムゾーンも知らない | データ層は `Clock` もタイムゾーンの解釈も持たない(`docs/architecture.md`)。`DateTime` のローカル生成は夏時間の切替日も 23/25 時間の 1 日として正しく引け、`d + 1` は月末・年末で正規化される |
| C | `DoneHistoryEntry` に**不透明なキー** `HistoryDayKey` を持たせる。UI はキーの中身を読まず、`ItemListNotifier.deleteHistoryDay` に返すだけ | `MarkDoneUndo` と同じ約束(日時の解釈を状態管理層に閉じる) |
| D | 取り消しは**消した行を元の ID・元の日時で戻す**。リポジトリは消した行を返し、状態管理層がそれを取り消しハンドルに入れる | 「元の日時で戻す」(Issue のスコープ)。ID も戻せば、戻した後の状態が削除前と区別できない |
| E | 削除は**確認ダイアログを出す**。削除後に取り消し導線を **4 秒**出す(`SnackBar` の既定の長さ、`persist: false`) | ユーザー選択。「削除には確認を入れる」(CLAUDE.md)を守りつつ、確認を押し間違えても救う |
| F | 楽観的更新をしない。削除・取り消しの完了後、`watchAll()` の再送出で画面が変わる | CLAUDE.md「譲らない設計判断」 |
| G | 範囲に該当する行が無かった(同時操作で既に消えていた等)ときは `Ignored` を返し、UI は何も出さない | 既存の `Ignored` と同じ扱い(`docs/functional-design.md`「エラーの分類」) |
| H | 日付の文言は短い形 `M月d日`(`9月12日`)をダイアログと `SnackBar` に、長い形 `y年M月d日` を読み上げラベルに使う | 画面上の文言は「日付を指定して記録」の `SnackBar`(`M月d日で記録しました`)に揃える。読み上げは行の表示(長い形)と同じ日付を含める |
| I | 削除ボタンは**履歴の各行の右端の `IconButton`**(`Icons.delete_outline`、tooltip = 読み上げラベル)。行の読み上げ(日付・間隔)とボタンの読み上げを分ける | ユーザー選択。`IconButton` は M3 の既定で 48dp のタップ領域を持つ |

## §1 ドメイン

### `lib/domain/item.dart`

`DoneLogId` の直後に追加する:

```dart
/// 実施履歴 1 行(#63)。暦日単位の削除を取り消すとき、消した行を元の ID・日時で戻すために使う。
final class DoneLog {
  const DoneLog({required this.id, required this.doneAt});

  final DoneLogId id;

  /// 実施日時(UTC)。
  final DateTime doneAt;

  @override
  bool operator ==(Object other) =>
      other is DoneLog && other.id == id && other.doneAt == doneAt;

  @override
  int get hashCode => Object.hash(id, doneAt);
}
```

### `lib/domain/item_repository.dart`

`removeDoneLog` の後に 2 つ追加する:

```dart
/// [from] 以上 [to] 未満の履歴をすべて消し、最終実施日時を残りの履歴の最大値(無ければ null)に
/// 揃える(#63)。`updatedAt` は [now]。**同一トランザクションで書く。**
///
/// [from] / [to] はどのタイムゾーンの `DateTime` でもよい(実装が UTC に直して比べる)。
/// 消した行を**新しい順**で返す。対象の項目や該当する行が無ければ何も書かずに空を返す(例外にしない)。
Future<List<DoneLog>> removeDoneLogsBetween(
  ItemId id, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
});

/// [removeDoneLogsBetween] の取り消し。[logs] を元の ID・日時で戻し、最終実施日時を履歴の最大値に
/// 揃える。`updatedAt` は [now]。**同一トランザクションで書く。**
///
/// 対象の項目が無い、または [logs] が空なら何も書かない(例外にしない)。同じ ID の行が既にあれば
/// その行は飛ばす(二重に戻さない)。
Future<void> restoreDoneLogs(
  ItemId id,
  List<DoneLog> logs, {
  required DateTime now,
});
```

## §2 データ: `lib/data/item_repository_impl.dart`

`removeDoneLog` の直後に実装する。**`_syncLastDoneAt` を再利用する。**

```dart
@override
Future<List<DoneLog>> removeDoneLogsBetween(
  ItemId id, {
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final fromMillis = _toEpochMillis(from);
  final toMillis = _toEpochMillis(to);
  return _db.transaction(() async {
    // 消す前に行を控える(取り消しで元の ID・日時に戻すため)。
    final rows = await (_db.select(_db.doneLogs)
          ..where(
            (t) =>
                t.itemId.equals(id.value) &
                t.doneAt.isBiggerOrEqualValue(fromMillis) &
                t.doneAt.isSmallerThanValue(toMillis),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.doneAt)]))
        .get();
    // 該当なし(項目が無い場合を含む)なら何も書かない。updated_at も進めない。
    if (rows.isEmpty) {
      return const <DoneLog>[];
    }
    await (_db.delete(_db.doneLogs)..where(
          (t) => t.id.isIn([for (final row in rows) row.id]),
        ))
        .go();
    await _syncLastDoneAt(id, now: now);
    return [
      for (final row in rows)
        DoneLog(id: DoneLogId(row.id), doneAt: _toUtc(row.doneAt)),
    ];
  });
}

@override
Future<void> restoreDoneLogs(
  ItemId id,
  List<DoneLog> logs, {
  required DateTime now,
}) async {
  if (logs.isEmpty) {
    return;
  }
  await _db.transaction(() async {
    final exists = await (_db.select(
      _db.items,
    )..where((t) => t.id.equals(id.value))).getSingleOrNull();
    // 対象が無い(= 削除と同時操作)なら書かない。存在しない item_id への INSERT は
    // 外部キー制約違反になる。
    if (exists == null) {
      return;
    }
    for (final log in logs) {
      // 同じ ID が既にあれば飛ばす(取り消しが二重に走っても行が増えない)。
      await _db
          .into(_db.doneLogs)
          .insert(
            DoneLogRow(
              id: log.id.value,
              itemId: id.value,
              doneAt: _toEpochMillis(log.doneAt),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await _syncLastDoneAt(id, now: now);
  });
}
```

(書式は `dart format` に従ってよい。Drift の生成コード上の列名・行クラス名は既存コードと同じ `doneLogs` / `DoneLogRow` / `t.doneAt` / `t.itemId` / `t.id`)

## §3 フェイク: `test/support/fake_item_repository.dart`

**実装と同じ振る舞いにする**(共有シナリオ §6-1 が両方に当たる)。

1. `_insertLog(ItemId id, DateTime doneAt)` に任意の名前付き引数 `{DoneLogId? logId}` を足し、null なら従来どおり採番、非 null ならその ID を使う
2. `removeDoneLogsBetween`:
   - `_failIfConfigured()`
   - 項目が無い、または履歴が無ければ `const <DoneLog>[]` を返す(emit しない)
   - `final fromUtc = _normalize(from); final toUtc = _normalize(to);` で `!e.doneAt.isBefore(fromUtc) && e.doneAt.isBefore(toUtc)` の行を集める(リストは既に新しい順なので、その順のまま)
   - 該当なしなら `const <DoneLog>[]` を返す(emit しない)
   - 該当行を消し、`_update` で `lastDoneAt`(残りの先頭 or null)と `updatedAt: _normalize(now)` を書く(`removeDoneLog` と同じ形)
   - `[for (final e in removed) DoneLog(id: e.id, doneAt: e.doneAt)]` を返す
3. `restoreDoneLogs`:
   - `_failIfConfigured()`
   - `logs` が空、または項目が無ければ何もしない
   - 各 log について、同じ ID が `_doneLogs[id]` に無ければ `_insertLog(id, _normalize(log.doneAt), logId: log.id)`
   - `_update` で `lastDoneAt: _doneLogs[id]!.first.doneAt`、`updatedAt: _normalize(now)`

## §4 状態

### `lib/state/item_view.dart`

1. `_lastDoneFormat` の直後に追加: `final DateFormat _shortDateFormat = DateFormat('M月d日');`(コメント: 削除の確認・結果の文言用。ロケールを渡さない理由は `_lastDoneFormat` と同じ)
2. `DoneHistoryEntry` の前に追加:

   ```dart
   /// 履歴 1 行が指す暦日(#63)。**UI はこの中身を読まない。**
   ///
   /// 受け取って `ItemListNotifier.deleteHistoryDay` に返すだけ(`MarkDoneUndo` と同じ約束)。
   final class HistoryDayKey {
     const HistoryDayKey(this.date);

     /// ローカルの暦日を `calendarDateOf` で UTC の点にしたもの。年・月・日だけが意味を持つ。
     final DateTime date;

     @override
     bool operator ==(Object other) => other is HistoryDayKey && other.date == date;

     @override
     int get hashCode => date.hashCode;
   }
   ```

3. `DoneHistoryEntry` に**必須**の名前付き引数を 2 つ足す(コンストラクタは `{required this.dateText, required this.shortDateText, required this.dayKey, this.intervalDays}`):
   - `final String shortDateText;` — 記録した日の短い形(`9月12日`)。`_shortDateFormat` で整形する。削除の確認と結果の文言に使う
   - `final HistoryDayKey dayKey;` — 削除の対象を状態管理層へ返すためのキー
   - `==` / `hashCode` に両方を含める
4. `ItemView.from` の `history` 組み立てで `shortDateText: _shortDateFormat.format(dates[i])`、`dayKey: HistoryDayKey(dates[i])` を渡す

### `lib/state/delete_history_day_result.dart`(新規)

`record_past_date_result.dart` と同じ書き方で:

```dart
import '../domain/item.dart';

/// 記録の履歴から 1 日分を削除した結果(#63)。**例外を投げない。**
sealed class DeleteHistoryDayResult {
  const DeleteHistoryDayResult();
}

/// 削除まで成功した。[undo] を取り消し導線へ渡す。
final class DeleteHistoryDaySucceeded extends DeleteHistoryDayResult {
  const DeleteHistoryDaySucceeded(this.undo);

  final DeleteHistoryDayUndo undo;
}

/// 対象の項目、またはその日の記録が無かった(同時操作)。**何も書いていない。** UI は何も表示しない。
final class DeleteHistoryDayIgnored extends DeleteHistoryDayResult {
  const DeleteHistoryDayIgnored();
}

/// 書き込みに失敗した。履歴は直前の値のまま。
final class DeleteHistoryDayFailed extends DeleteHistoryDayResult {
  const DeleteHistoryDayFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。**UI はこの中身を読まない。**
final class DeleteHistoryDayUndo {
  const DeleteHistoryDayUndo({required this.id, required this.logs});

  /// 削除した項目。
  final ItemId id;

  /// 消した履歴の行(元の ID・日時)。
  final List<DoneLog> logs;
}
```

取り消しの結果は既存の `UndoResult`(`mark_done_result.dart`)を使う。

### `lib/state/item_list_notifier.dart`

`undoRecordPastDate` の直後に追加する(import に `delete_history_day_result.dart` を足す):

```dart
/// 記録の履歴から 1 日分(ローカルの暦日)の記録をすべて削除する(#63)。
///
/// 確認を取るのは UI の責務。誤りは [undoDeleteHistoryDay] で救う。並びは組み替えない(F30)。
Future<DeleteHistoryDayResult> deleteHistoryDay(
  ItemId id,
  HistoryDayKey day,
) async {
  if (!_latestItems.any((item) => item.id == id)) {
    return const DeleteHistoryDayIgnored();
  }
  final date = day.date;
  // ローカルの 0:00〜翌 0:00。ローカル時刻の DateTime は夏時間の切替日も正しい長さの 1 日になり、
  // day + 1 は月末・年末で正規化される。
  final from = DateTime(date.year, date.month, date.day);
  final to = DateTime(date.year, date.month, date.day + 1);
  try {
    final removed = await ref
        .read(itemRepositoryProvider)
        .removeDoneLogsBetween(
          id,
          from: from,
          to: to,
          now: ref.read(clockProvider).now(),
        );
    if (removed.isEmpty) {
      return const DeleteHistoryDayIgnored();
    }
    return DeleteHistoryDaySucceeded(
      DeleteHistoryDayUndo(id: id, logs: removed),
    );
  } catch (error, stackTrace) {
    developer.log(
      '記録の削除に失敗しました',
      name: 'lastwhen.state',
      error: error,
      stackTrace: stackTrace,
    );
    return const DeleteHistoryDayFailed();
  }
}

/// [deleteHistoryDay] を取り消す。消した行を元の日時で戻す。
Future<UndoResult> undoDeleteHistoryDay(DeleteHistoryDayUndo undo) async {
  try {
    await ref
        .read(itemRepositoryProvider)
        .restoreDoneLogs(
          undo.id,
          undo.logs,
          now: ref.read(clockProvider).now(),
        );
    return const UndoSucceeded();
  } catch (error, stackTrace) {
    developer.log(
      '記録の削除の取り消しに失敗しました',
      name: 'lastwhen.state',
      error: error,
      stackTrace: stackTrace,
    );
    return const UndoFailed();
  }
}
```

## §5 UI

### `lib/ui/item_navigation.dart`

`_undoRecordPastDate` の直後に追加する(import に `../state/delete_history_day_result.dart` を足す。`DoneHistoryEntry` は既に import 済みの `item_view.dart` にある):

```dart
/// 記録の履歴から 1 日分の記録を削除し、取り消し導線を出す(#63)。
///
/// **確認ダイアログを出す**(削除には確認を入れる)。確認後の誤りは取り消しで救う。
Future<void> deleteHistoryDayWithUndo(
  BuildContext context,
  ItemId id,
  DoneHistoryEntry entry,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${entry.shortDateText}の記録を削除しますか?'),
      content: const Text('この日の記録をすべて削除します。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  // バリアタップ・戻る操作は null。true 以外はすべて「削除しない」。
  if (confirmed != true) {
    return;
  }
  final result = await notifier.deleteHistoryDay(id, entry.dayKey);
  switch (result) {
    case DeleteHistoryDaySucceeded(:final undo):
      // キューに積ませない。「直近 1 件のみ」を保つ(「やった」と同じ)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${entry.shortDateText}の記録を削除しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoDeleteHistoryDay(messenger, notifier, undo),
          ),
        ),
      );
    // 同時操作。何も出さない。
    case DeleteHistoryDayIgnored():
      break;
    case DeleteHistoryDayFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('削除できませんでした。もう一度お試しください')),
      );
  }
}

/// 記録の削除を取り消す。失敗したら知らせる。
void _undoDeleteHistoryDay(
  ScaffoldMessengerState messenger,
  ItemListNotifier notifier,
  DeleteHistoryDayUndo undo,
) {
  unawaited(() async {
    final result = await notifier.undoDeleteHistoryDay(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}
```

### `lib/ui/screens/item_detail_screen.dart`

1. `historyEntrySemanticsLabel` の直後に公開関数を追加:

   ```dart
   /// 履歴 1 行の削除ボタンの読み上げ文(tooltip)。日付を含める。
   String historyDeleteButtonLabel(DoneHistoryEntry entry) =>
       '${entry.dateText}の記録を削除';
   ```

2. 画面クラスの doc コメントの「削除の入口はここに置かない(編集画面の中だけ。F7)」を
   「項目の削除の入口はここに置かない(編集画面の中だけ。F7)。記録の履歴の各行からは、その日の記録を削除できる(#63)」に改める
3. 履歴の組み立て `for (final entry in item.history) _HistoryRow(entry: entry)` を `_HistoryRow(itemId: item.id, entry: entry)` にする
4. `_HistoryRow` を次の形に改める(`itemId` を必須で受け取る):

   ```dart
   Row(
     children: [
       Expanded(
         child: Semantics(
           label: historyEntrySemanticsLabel(entry),
           excludeSemantics: true,
           child: Padding(
             padding: const EdgeInsets.symmetric(vertical: 8),
             child: Row(
               children: [ /* 現行の 丸・日付(Expanded)・間隔 をそのまま */ ],
             ),
           ),
         ),
       ),
       const SizedBox(width: 4),
       IconButton(
         onPressed: () =>
             unawaited(deleteHistoryDayWithUndo(context, itemId, entry)),
         tooltip: historyDeleteButtonLabel(entry),
         icon: const Icon(Icons.delete_outline),
       ),
     ],
   )
   ```

   - 行全体を 1 つの `Semantics(excludeSemantics: true)` で包まない(ボタンが読み上げから消えるため)。日付と間隔の読み上げは現行と同じ文
   - `IconButton` の色・サイズは既定のまま(M3 の既定で 48dp のタップ領域、色は `onSurfaceVariant`)。生の値を書かない
   - 削除中のボタン無効化は行わない(確認ダイアログが開いている間は他の行を押せず、削除後は行ごと消える)

## §6 テスト

既存の書き方(`FakeItemRepository` / `FakeClock` / `ProviderScope` の overrides / 既存の時刻定数)に倣う。時刻が足りなければ同じファイル内の既存定数と同じ書き方で足す。

1. `test/data/item_repository_impl_test.dart` の `_runSharedScenarios`(実装とフェイクの両方)に追加:
   - 同じ範囲の 2 行が消え、範囲外の行は残る。戻り値は消した 2 行(新しい順・ID と日時が一致)。`lastDoneAt` は残りの最大値、`updatedAt` は `now`
   - 最新の行を含む範囲を消すと `lastDoneAt` が 1 つ前の行の日時に戻る
   - 全件を含む範囲を消すと `lastDoneAt == null`、`recentDoneAts` が空
   - 境界: `from` ちょうどの行は消え、`to` ちょうどの行は残る
   - 該当なしの範囲: 空リストを返し、`lastDoneAt` / `updatedAt` が変わらない
   - 存在しない項目: 空リストを返し、他項目に影響しない
   - `removeDoneLogsBetween` → `restoreDoneLogs`: `recentDoneAts` と `lastDoneAt` が削除前と同じになり、`updatedAt` は restore の `now`
   - `restoreDoneLogs` を同じ logs で 2 回呼んでも `recentDoneAts` の件数が増えない
   - 存在しない項目への `restoreDoneLogs` は例外にならず、他項目に影響しない
2. `test/state/item_list_notifier_test.dart` に `deleteHistoryDay` / `undoDeleteHistoryDay` の group を追加:
   - 3 暦日の記録がある項目で真ん中の日の `dayKey` を渡すと `DeleteHistoryDaySucceeded`、次の emit の `history` からその日が消える
   - 同じ暦日に 2 件ある日を消すと 2 件とも消える(`undo.logs.length == 2` を見てよい)
   - 最新の日を消すと `lastDoneText` が 1 つ前の日になる。全件消すと `elapsed` が `NeverDone`
   - `undoDeleteHistoryDay` で `UndoSucceeded`、`history` と `lastDoneText` が削除前に戻る
   - 一覧に無い ID は `DeleteHistoryDayIgnored`(リポジトリを呼ばない)
   - 既に消えた日(同じキーで 2 回目)は `DeleteHistoryDayIgnored`
   - `writeError` を仕込むと `DeleteHistoryDayFailed`、`history` は変わらない。取り消しで `writeError` を仕込むと `UndoFailed`
3. `test/state/item_view_test.dart`: 既存の `DoneHistoryEntry(...)` の期待値に `shortDateText` と `dayKey`(`HistoryDayKey(DateTime.utc(2026, 9, 12))` の形)を足す。
   1 ケース追加: 各行の `shortDateText` が `9月12日` 形式、`dayKey.date` がローカルの暦日(`calendarDateOf`)と一致する。
   `test/ui/screens/item_detail_screen_test.dart` の既存の `DoneHistoryEntry(...)` も同様に引数を足す(期待値は変えない)
4. `test/ui/screens/item_detail_screen_test.dart` に group「記録の削除」を追加:
   - 履歴の各行に削除ボタンがある(`find.byTooltip('2026年9月12日の記録を削除')` 形式で行数ぶん見つかる)
   - 押すと `AlertDialog` に `9月12日の記録を削除しますか?` が出る。`キャンセル` で閉じ、履歴が変わらず `SnackBar` も出ない
   - `削除` で行が消え、`9月12日の記録を削除しました` が出る。`取り消す` で行と「最後にやった日」が元に戻る
   - 同じ暦日に 2 件ある行を消すと、その日の記録がすべて消える(記録がそれだけなら `まだ記録がありません` が 2 箇所・平均が `学習中`)
   - 最新の日を消すと「最後にやった日」が 1 つ前の日になる
   - 削除の直前に `writeError` を仕込むと `削除できませんでした。もう一度お試しください` が出て、履歴が変わらない
   - `historyDeleteButtonLabel` の単体テスト
   - 既存の「メニューに `削除` が無い」テスト(`find.text('削除')` が findsNothing)は変更せずに通ること。削除ボタンは tooltip だけで `Text('削除')` を描かないため影響しない
5. `test/ui/accessibility_test.dart` の「文字サイズ 200% で記録の詳細が破綻しない」に追加:
   履歴の削除ボタンを `ensureVisible` した後 `hitTestable` で見つかる。
   `tester.getSemantics(find.byTooltip(<ラベル>))` が `containsSemantics(tooltip: <ラベル>, isButton: true, hasTapAction: true)` に一致する

## §7 docs の更新

### `docs/product-requirements.md`

- F29 の行末 `削除の入口は置かない(F7)` を
  `項目の削除の入口は置かない(F7)。記録の履歴の各行から、その暦日の記録を削除できる(確認あり・削除後 4 秒の取り消しあり。#63)` に改める
- `> **追記(#58)**` の段落の後に足す:
  ```
  >
  > **追記(#63)**: 記録の履歴から暦日単位で記録を削除できるようにした。「やった」の取り消し(4 秒)を
  > 逃した誤記録は、基準間隔・経年ステージ・並び順・通知のすべてに効き続けるため。F7 と同じく
  > **削除には確認を入れ**、確認を押し間違えても救えるよう削除後 4 秒の取り消しも出す。画面の 1 行と
  > 消える範囲を一致させるため、同じ暦日の記録はまとめて消す。履歴の日付の編集は扱わない。
  ```

### `docs/functional-design.md`

- 「### 記録の詳細(F29)」の表の「記録の履歴」行の内容の末尾に `。各行の右端に削除ボタンを置く(下記)` を足す
- 同節の箇条書き「**削除の入口を置かない**。削除は編集画面の中だけ(F7)。…」を「**項目の削除の入口を置かない**。項目の削除は編集画面の中だけ(F7)。…」に改める(後半はそのまま)
- 同節の箇条書きの末尾に足す:
  ```
  - **記録の履歴の各行から、その暦日の記録をすべて削除できる**(#63)。行の右端の削除ボタン
    (読み上げは `2026年9月12日の記録を削除`)を押すと確認ダイアログ(`9月12日の記録を削除しますか?` /
    キャンセル・削除)を出し、削除すると `9月12日の記録を削除しました` と取り消し導線を **4 秒間**出す。
    取り消すと消した記録を元の日時で戻す。最終実施日は残りの履歴の最大値に揃い、全件消すと未実施に戻る。
    暦日の範囲はローカルの 0:00〜翌 0:00 を状態管理層で作り、リポジトリには日時の範囲として渡す
  ```
- 「### 統合テスト」の表に 2 行足す(「過去日の記録 → 取り消し」の直後):
  `| 範囲の履歴の削除 | 範囲内(from 以上 to 未満)の行だけが消え、`lastDoneAt` が残りの最大値(無ければ null)になる |`
  `| 範囲の履歴の削除 → 取り消し | 消した行が元の ID・日時で戻り、二重に戻しても増えない |`
- 「### ウィジェットテスト」の表の「記録の詳細」行の直後に足す:
  `| 記録の削除 | 履歴の行から確認を挟んで暦日単位で消え、4 秒間取り消せる。失敗時は履歴が変わらない |`

### `docs/glossary.md`

- 「### 履歴(Done Log)【P1】」の箇条書きの末尾に足す:
  `- **記録の詳細の履歴から暦日単位で削除できる**(#63)。削除は確認あり・取り消しあり`
- 「### 記録の詳細(ItemDetailScreen)【P1】」の本文「削除の入口は置かない。」を
  「項目の削除の入口は置かない。記録の履歴からは、その日の記録を削除できる(#63)。」に改める

## §8 完了条件

- `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` がすべて通る
  (委託先の sandbox ではテストを回せない。format と analyze まで通し、テストは検収側が回す)
- `git diff --stat -- lib/data/database lib/data/migrations pubspec.yaml` が空

## §9 CI 修正(PR #64 の `quality` 失敗への対応)

CI の `flutter analyze --fatal-infos` が 12 件で落ちた。原因と修正は次の 2 つだけ。**これ以外のコードを変えない。**

1. `lib/state/item_list_notifier.dart` に `import 'delete_history_day_result.dart';` を足す(既存の相対 import の並びに、アルファベット順で入れる)。
   `DeleteHistoryDay*` が未解決の error 7 件と、`lib/ui/item_navigation.dart` 145〜148 行の dead_code warning 4 件はこれで消える見込み。消えなければ止めて報告する
2. `test/ui/accessibility_test.dart` の `containsSemantics(...)` を `isSemantics(...)` に置き換える(引数はそのまま)。Flutter 3.40 以降で `containsSemantics` が非推奨になったため(§6-5 の指示の誤り)。`isSemantics` がその引数を受け付けない場合は止めて報告する

完了条件: `flutter analyze --fatal-infos` が 0 件。`flutter test` で、変更に関係するテスト(`test/state/item_list_notifier_test.dart`・`test/ui/screens/item_detail_screen_test.dart`・`test/ui/accessibility_test.dart`・`test/data/item_repository_impl_test.dart`・`test/state/item_view_test.dart`)が通る。
