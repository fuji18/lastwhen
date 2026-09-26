# 設計: 過去の日付で記録する(F16 / Issue #49)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れない。** スキーマは変わらない(`done_logs` は v2 で追加済み)
> - **依存の追加は司令塔が済ませた**(`pubspec.yaml` に `flutter_localizations`、`pubspec.lock` 更新済み)。実装者は `pubspec.*` を触らない
> - **`docs/` は司令塔が更新済み**(`functional-design.md` の ItemRepository / 詳細シート / 図鑑 / UC1b / テスト表、`glossary.md`、`architecture.md`)。実装者は `docs/` を触らない
> - UI 文言は下の表記どおりに書く(用語集: 「記録」を「修正」「変更」と言い換えない)

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 「修正」は**過去日のログを追加**する。最新ログを置き換えない | 置き換えると直近の実施が消え、基準間隔の学習から 1 回分欠ける。PRD の「記録忘れの後追い入力」は追加 |
| B | `lastDoneAt` は常に `MAX(done_at)`。古い日を入れても動かない | `lastDoneAt` は最新ログのキャッシュ(`functional-design.md` Item 制約) |
| C | 同じ暦日のログがあっても追加する。特別扱いしない | `intervalDaysOf` が暦日単位でまとめるので 0 日間隔は学習に入らない(既存実装のまま) |
| D | 取り消し導線(SnackBar 4 秒)を出す。確認ダイアログは出さない | 取り消せる操作には確認を入れない(CLAUDE.md の判断表)。取り消しは**追加した 1 行を ID で**消す |
| E | 記録日時: **今日なら現在時刻**、過去日なら**その日のローカル 12:00** を UTC にする | 0:00 だとタイムゾーンを西へまたいだとき前日に読める |
| F | 入口は詳細シートの「日付を指定して記録」。一覧・図鑑どちらのシートにも出す | ユーザー判断。図鑑の「記録の入口を置かない」はカード上の 1 タップを指す |
| G | アプリのロケールを `ja` に固定 | ユーザー判断。`showDatePicker` を日本語で出す |

---

## 1. ドメイン層

### 1-1. `lib/domain/item.dart` に `DoneLogId` を足す

`ItemId` の直下に追加する。

```dart
/// 実施履歴 1 行の ID。取り消しで「追加した 1 行」を指すために使う(#49)。
extension type const DoneLogId(String value) {}
```

### 1-2. `lib/domain/item_repository.dart` にメソッドを 2 つ足す

`restoreLastDoneAt` の後ろに追加する。

```dart
  /// 過去の日付で記録する(F16)。`done_logs` に 1 行追加し、最終実施日時を
  /// **履歴の最大値**に揃える([doneAt] が最新でなければ最終実施日は動かない)。
  /// `updatedAt` は [now]。**同一トランザクションで書く。**
  ///
  /// 追加した履歴の ID を返す。対象の項目が無ければ何も書かずに null を返す(例外にしない)。
  Future<DoneLogId?> addDoneLog(
    ItemId id,
    DateTime doneAt, {
    required DateTime now,
  });

  /// [addDoneLog] の取り消し。[logId] の 1 行だけを消し、最終実施日時を残りの履歴の
  /// 最大値(無ければ null)に揃える。`updatedAt` は [now]。**同一トランザクションで書く。**
  ///
  /// 対象の項目や行が無くても例外にしない。
  Future<void> removeDoneLog(
    ItemId id,
    DoneLogId logId, {
    required DateTime now,
  });
```

### 1-3. 新規 `lib/domain/past_date_record.dart`

```dart
import 'elapsed_days.dart';

/// 日付の選択で選ばれた暦日([pickedDate]、ローカル)が、[now] から見て未来か。
bool isFuturePickedDate(DateTime pickedDate, {required DateTime now}) =>
    calendarDateOf(pickedDate).isAfter(calendarDateOf(now.toLocal()));

/// 選ばれた暦日を記録日時(UTC)に直す(F16)。
///
/// - **今日なら [now] そのもの**(「やった」と同じ時刻の意味にする)
/// - 過去日なら**その日のローカル 12:00**。0:00 にするとタイムゾーンを西へまたいだとき
///   前日の暦日に読めてしまう。正午なら ±12 時間まで同じ暦日に収まる
///
/// 未来日かどうかは見ない(呼び出し側が [isFuturePickedDate] で弾く)。
DateTime doneAtOfPickedDate(DateTime pickedDate, {required DateTime now}) {
  if (calendarDateOf(pickedDate) == calendarDateOf(now.toLocal())) {
    return now.toUtc();
  }
  return DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 12).toUtc();
}
```

---

## 2. データ層 `lib/data/item_repository_impl.dart`(`database/` ではない)

`restoreLastDoneAt` の後ろに 2 メソッドと private ヘルパーを足す。**既存メソッドは変えない。**

```dart
  @override
  Future<DoneLogId?> addDoneLog(
    ItemId id,
    DateTime doneAt, {
    required DateTime now,
  }) {
    // 項目の存在確認・done_logs への追加・last_done_at の同期を同じトランザクションに入れる。
    return _db.transaction(() async {
      final exists = await (_db.select(
        _db.items,
      )..where((t) => t.id.equals(id.value))).getSingleOrNull();
      // 対象が無い(= 削除と同時操作)なら書かない。存在しない item_id への INSERT は
      // 外部キー制約違反になる。
      if (exists == null) {
        return null;
      }
      final logId = _uuid.v4();
      await _db
          .into(_db.doneLogs)
          .insert(
            DoneLogRow(
              id: logId,
              itemId: id.value,
              doneAt: _toEpochMillis(doneAt),
            ),
          );
      await _syncLastDoneAt(id, now: now);
      return DoneLogId(logId);
    });
  }

  @override
  Future<void> removeDoneLog(
    ItemId id,
    DoneLogId logId, {
    required DateTime now,
  }) async {
    await _db.transaction(() async {
      await (_db.delete(_db.doneLogs)..where(
            (t) => t.id.equals(logId.value) & t.itemId.equals(id.value),
          ))
          .go();
      await _syncLastDoneAt(id, now: now);
    });
  }

  /// last_done_at を done_logs の最大値(無ければ NULL)に揃え、updated_at を [now] にする。
  ///
  /// `updates: {_db.items}` を渡して watchAll の購読に変更を通知させる。
  Future<void> _syncLastDoneAt(ItemId id, {required DateTime now}) async {
    await _db.customUpdate(
      'UPDATE items SET '
      'last_done_at = (SELECT MAX(done_at) FROM done_logs WHERE item_id = ?), '
      'updated_at = ? '
      'WHERE id = ?',
      variables: [
        Variable.withString(id.value),
        Variable.withInt(_toEpochMillis(now)),
        Variable.withString(id.value),
      ],
      updates: {_db.items},
    );
  }
```

- `watchAll` の既存コメント「done_logs は常に items と同じトランザクションで書かれる」は新メソッドでも成り立つ(変更不要)
- `DoneLogId` の import は既存の `import '../domain/item.dart';` で足りる
- Drift の `&` 演算子(`Expression<bool>` 同士)は既存コードで未使用だが Drift 標準。analyze が通らなければ `.where((t) => t.id.equals(logId.value))` の後に `..where((t) => t.itemId.equals(id.value))` を重ねる(Drift は複数の `where` を AND で結ぶ)

---

## 3. テスト用フェイク `test/support/fake_item_repository.dart`

**実装と同じ並び規則にする**: 実装の履歴は `ORDER BY done_at DESC, rowid DESC`(同時刻なら後から入れた行が先)。
過去日が入るため「常に先頭へ insert」では実装とずれる。

1. private クラスを足す:

   ```dart
   /// フェイクの履歴 1 行。実装の `done_logs` の行に相当する。
   final class _FakeDoneLog {
     const _FakeDoneLog(this.id, this.doneAt);

     final DoneLogId id;
     final DateTime doneAt;
   }
   ```

2. `_doneLogs` の型を `Map<ItemId, List<_FakeDoneLog>>` に変える(並びは新しい順のまま)。`int _logSequence = 0;` を足す
3. 挿入ヘルパーを足し、`markDone` もこれを使う:

   ```dart
   /// 実装の `ORDER BY done_at DESC, rowid DESC` と同じ位置に入れる(同時刻なら先頭側)。
   void _insertLog(ItemId id, DateTime doneAt) {
     final logs = _doneLogs[id] ??= <_FakeDoneLog>[];
     final log = _FakeDoneLog(DoneLogId('fake-log-${_logSequence++}'), doneAt);
     final index = logs.indexWhere((e) => !e.doneAt.isAfter(doneAt));
     logs.insert(index < 0 ? logs.length : index, log);
   }
   ```

   `_insertLog` は挿入した `_FakeDoneLog` の `id` を返す形(`DoneLogId _insertLog(...)`)にしてよい。`addDoneLog` で使う

4. `markDone`: `(_doneLogs[id] ??= ...).insert(0, timestamp)` を `_insertLog(id, timestamp)` に置き換える。他は変えない
5. `restoreLastDoneAt`: `logs.removeAt(0)` のまま(先頭 = 実装の「直近 1 行」)。型だけ追従
6. `_snapshot`: `recentDoneAts` を `logs.map((e) => e.doneAt)` から作る(件数の切り詰めは現状どおり)
7. `addDoneLog`:
   - `_failIfConfigured()` → 項目が無ければ `null` を返す(履歴も作らない)
   - `_insertLog(id, _normalize(doneAt))` で追加し、その ID を返す
   - `_update` で `lastDoneAt: _doneLogs[id]!.first.doneAt`、`updatedAt: _normalize(now)`
8. `removeDoneLog`:
   - `_failIfConfigured()` → `_doneLogs[id]?.removeWhere((e) => e.id == logId)`
   - `_update` で `lastDoneAt`: 残りが空なら null、あれば `first.doneAt`。`updatedAt: _normalize(now)`
   - 項目が無ければ `_update` が何もしない(既存の挙動)

---

## 4. 状態管理層

### 4-1. 新規 `lib/state/record_past_date_result.dart`

```dart
import '../domain/item.dart';

/// 過去の日付での記録結果(F16)。**例外を投げない。**
sealed class RecordPastDateResult {
  const RecordPastDateResult();
}

/// 保存まで成功した。[undo] を取り消し導線へ、[dateText](`9月14日`)を SnackBar の文言へ渡す。
final class RecordPastDateSucceeded extends RecordPastDateResult {
  const RecordPastDateSucceeded(this.undo, {required this.dateText});

  final RecordPastDateUndo undo;
  final String dateText;
}

/// 対象が一覧に無かった(削除と同時操作)。UI は何も表示しない。
final class RecordPastDateIgnored extends RecordPastDateResult {
  const RecordPastDateIgnored();
}

/// 未来日だった。**書き込みを試みていない。** 日付の選択が未来日を選ばせないため通常は届かない。
/// UI は何も表示しない。
final class RecordPastDateRejected extends RecordPastDateResult {
  const RecordPastDateRejected();
}

/// 書き込みに失敗した。一覧は直前の値のまま。
final class RecordPastDateFailed extends RecordPastDateResult {
  const RecordPastDateFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。**UI はこの中身を読まない。**
final class RecordPastDateUndo {
  const RecordPastDateUndo({required this.id, required this.logId});

  /// 記録した項目。
  final ItemId id;

  /// 追加した履歴の行。
  final DoneLogId logId;
}
```

取り消しの結果は既存の `UndoResult`(`lib/state/mark_done_result.dart`)を**再利用する**。

### 4-2. `lib/state/item_list_notifier.dart` に 3 メソッドを足す

`undoMarkDone` の後ろに置く。import に `package:intl/intl.dart`、`../domain/past_date_record.dart`、`record_past_date_result.dart` を足す。

```dart
/// 過去の日付で記録したときの SnackBar 用の日付(`9月14日`)。ロケールは渡さない(`item_view.dart` と同じ理由)。
final DateFormat _pickedDateFormat = DateFormat('M月d日');
```

(ファイル先頭の provider 定義の後、クラスの前に置く)

```dart
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
```

- `Clock.now()` は `recordPastDate` 1 回につき 1 回だけ呼ぶ(上のコードどおり `now` を使い回す)
- `lib/state/` は `package:flutter/` を import できない(レイヤー検査)。上のコードは `intl` と domain だけで足りる

---

## 5. UI 層

### 5-1. `lib/app.dart`: 日本語ロケールに固定する

```dart
import 'package:flutter_localizations/flutter_localizations.dart';
...
    return MaterialApp(
      title: 'LastWhen',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Material 標準部品(日付の選択など)を日本語で出す。MVP は日本語のみ(#49)。
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
```

クラスの doc コメントに「ロケールは `ja` に固定する(#49)」を 1 行足す。

### 5-2. `lib/ui/widgets/item_detail_sheet.dart`: ボタンを足す

- コンストラクタに `required this.onRecordPastDatePressed` を足す(`VoidCallback`、doc コメント「「日付を指定して記録」のタップ時の処理。」)
- 末尾の `Align(... FilledButton.tonalIcon 編集 ...)` を次に置き換える。**文字サイズ 200% で横に溢れないよう `Row` ではなく `Wrap`**:

```dart
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onRecordPastDatePressed,
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: const Text('日付を指定して記録'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onEditPressed,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('編集'),
                ),
              ],
            ),
```

- 未実施の項目でも出す(条件分岐しない)

### 5-3. `lib/ui/item_navigation.dart`: シートの結果で分岐する

`openItemDetailSheet` のシグネチャは**変えない**(呼び出し元の一覧・図鑑を触らない)。notifier は
`ProviderScope.containerOf(context, listen: false)` で取る。

```dart
/// 詳細シートで押されたボタン。シートを閉じてから処理する。
enum _DetailSheetAction { edit, recordPastDate }

/// 詳細シートを開く。編集画面と「日付を指定して記録」への入口はシートの中にある。
Future<void> openItemDetailSheet(BuildContext context, ItemView item) async {
  // 画面遷移と同じく、取り消し導線を閉じる。
  ScaffoldMessenger.of(context).clearSnackBars();
  final action = await showModalBottomSheet<_DetailSheetAction>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ItemDetailSheet(
      item: item,
      onEditPressed: () =>
          Navigator.of(sheetContext).pop(_DetailSheetAction.edit),
      onRecordPastDatePressed: () =>
          Navigator.of(sheetContext).pop(_DetailSheetAction.recordPastDate),
    ),
  );
  if (!context.mounted) {
    return;
  }
  switch (action) {
    case _DetailSheetAction.edit:
      openItemEditScreen(context, item);
    case _DetailSheetAction.recordPastDate:
      await _recordPastDate(context, item);
    case null:
      break;
  }
}

/// 日付を選ばせて記録し、取り消し導線を出す(F16)。**確認ダイアログは出さない。**
Future<void> _recordPastDate(BuildContext context, ItemView item) async {
  final messenger = ScaffoldMessenger.of(context);
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final today = notifier.todayLocalDate();
  final picked = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: DateTime(2000),
    // 未来日は選ばせない。
    lastDate: today,
    helpText: '記録する日を選ぶ',
    confirmText: '記録する',
  );
  if (picked == null) {
    return;
  }
  final result = await notifier.recordPastDate(item.id, picked);
  switch (result) {
    case RecordPastDateSucceeded(:final undo, :final dateText):
      // キューに積ませない。「直近 1 件のみ」を保つ(「やった」と同じ)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('$dateTextで記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoRecordPastDate(messenger, notifier, undo),
          ),
        ),
      );
    // 削除と同時操作・未来日。何も出さない。
    case RecordPastDateIgnored():
    case RecordPastDateRejected():
      break;
    case RecordPastDateFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
  }
}

/// 過去の日付での記録を取り消す。失敗したら知らせる。
void _undoRecordPastDate(
  ScaffoldMessengerState messenger,
  ItemListNotifier notifier,
  RecordPastDateUndo undo,
) {
  unawaited(() async {
    final result = await notifier.undoRecordPastDate(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}
```

- import を足す: `dart:async`(`unawaited`)、`package:flutter_riverpod/flutter_riverpod.dart`、`../state/item_list_notifier.dart`、`../state/mark_done_result.dart`(`UndoFailed`)、`../state/record_past_date_result.dart`
- `'$dateTextで記録しました'` は波括弧なしで書く(Dart の識別子は ASCII のみなので `で` で補間が切れる。波括弧を付けると `unnecessary_brace_in_string_interps` になる)
- `ui/` から `state/` の import はレイヤー規則上許可(既存の `item_list_screen.dart` と同じ)
- `ProviderScope.containerOf` が analyze で問題になる場合は、実装を止めて司令塔に戻す(引数に `WidgetRef` を足す案に切り替えるかは司令塔が判断する)

---

## 6. テスト

既存テストの書き方・ヘルパーに合わせる。**時刻の定数は各テストファイルの既存のもの**(`t0`〜`t2`、`now = DateTime.utc(2026, 9, 16, 3)` など)を使い、足りなければ同じ書式で足す。

### 6-1. `test/domain/past_date_record_test.dart`(新規)

`now = DateTime.utc(2026, 9, 16, 3)` を基準に(テスト環境のタイムゾーンに依存しないよう、ローカルの暦日は `now.toLocal()` から組み立てる):

- 今日の暦日を渡すと `now` そのもの(UTC)が返る
- 昨日の暦日を渡すと、その日のローカル 12:00 を UTC にした値が返る(`DateTime(y, m, d, 12).toUtc()` と一致)
- 返り値は `isUtc == true`
- `isFuturePickedDate`: 明日は true / 今日は false / 昨日は false

### 6-2. `test/data/item_repository_impl_test.dart`

**共有シナリオ(`_runSharedScenarios`。実装とフェイクの両方に流れる)** に足す:

| テスト名 | 手順 | 検証 |
| --- | --- | --- |
| 未実施の項目に過去日で記録すると最終実施日になる | add(now: t0) → addDoneLog(id, t0, now: t2) | 戻り値が非 null / `lastDoneAt == t0` / `updatedAt == t2` / `recentDoneAts == [t0]` |
| 最新より古い日で記録しても最終実施日は動かない | markDone(t1) → addDoneLog(id, t0, now: t2) | `lastDoneAt == t1` / `updatedAt == t2` / `recentDoneAts == [t1, t0]` |
| 最新より新しい日で記録すると最終実施日が進む | markDone(t0) → addDoneLog(id, t1, now: t2) | `lastDoneAt == t1` / `recentDoneAts == [t1, t0]` |
| 過去日の記録を取り消すと追加した 1 行だけ消える | markDone(t1) → id2 = addDoneLog(t0, now: t2) → removeDoneLog(id, id2, now: t2) | `lastDoneAt == t1` / `recentDoneAts == [t1]` / `updatedAt == t2` |
| 最新だった過去日の記録を取り消すと直前の最大値に戻る | markDone(t0) → addDoneLog(t1) → removeDoneLog | `lastDoneAt == t0` / `recentDoneAts == [t0]` |
| 唯一の記録を取り消すと未実施に戻る | addDoneLog(t0) → removeDoneLog | `lastDoneAt == null` / `recentDoneAts` が空 |
| 過去日の記録のあとの「やった」の取り消しは「やった」の行を消す | markDone(t0) → addDoneLog(古い日: t0 の 1 日前) → markDone(t2) → restoreLastDoneAt(id, t0, now: t2) | `lastDoneAt == t0` / `recentDoneAts == [t0, t0の1日前]` |
| 存在しない項目への addDoneLog / removeDoneLog は例外にならない | `ItemId('missing')` で両方呼ぶ | addDoneLog が null / 例外なし / 他項目に影響なし |

**実装だけのグループ(`ItemRepositoryImpl(永続化の詳細)`)** に足す:

- addDoneLog は done_logs に 1 行追加し、戻り値の ID の行が存在する(`SELECT id, done_at FROM done_logs`)
- removeDoneLog は指定した ID の行だけ消す(他の行は残る)

### 6-3. `test/state/item_list_notifier_test.dart`

新しい `group('過去の日付で記録', ...)` を足す。既存 `group('記録と取り消し')` の setUp・ヘルパーの形に合わせる。

- 未実施の項目に 4 日前(ローカル暦日)で記録すると `DaysAgo(4)` になり、`dateText` が `M月d日` 形式
- 今日を選ぶと `Today` になる
- 記録済み(2 日前)の項目に 5 日前で記録すると、経過日数は `DaysAgo(2)` のまま、`previousIntervalDays == 3`
- 未来日(明日)は `RecordPastDateRejected` で、リポジトリに書かれない(一覧が変わらない)
- 一覧に無い ID は `RecordPastDateIgnored`
- `writeError` を仕込むと `RecordPastDateFailed` で、一覧は `AsyncData` のまま元の値
- 取り消すと元に戻る(未実施だった項目は `NeverDone`)
- 取り消し失敗は `UndoFailed`
- `todayLocalDate()` は Clock のローカル暦日の 0:00

### 6-4. `test/ui/widgets/item_detail_sheet_test.dart`

- `_app` に `onRecordPastDatePressed` を渡す(既定は `() {}`)
- 「日付を指定して記録」ボタンが出て、押すとコールバックが呼ばれる
- 未実施の項目でもボタンが出る

### 6-5. `test/ui/item_list_screen_test.dart`

`pumpItems` の状態(美容院 = 9/12 記録 / 歯ブラシ交換 = 未実施、now = 9/16)を使う。日付の選択の中の要素は
`find.descendant(of: find.byType(DatePickerDialog), matching: ...)` で探す。

- 詳細シートから日付を指定して記録できる: 歯ブラシ交換をタップ → 「日付を指定して記録」 → 日付 `14` → 「記録する」 → カードが `2日前`、SnackBar `9月14日で記録しました` が出る。**`AlertDialog` は出ていない**
- 日付の選択の最終日は今日: `tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate` が 2026-09-16(年月日で比較)
- 取り消すと元に戻る: 上の操作のあと「取り消す」 → 歯ブラシ交換が `未実施` に戻る
- キャンセルすると何も記録されない: 日付の選択で「キャンセル」 → 歯ブラシ交換は `未実施` のまま、SnackBar なし
- 最新より古い日を入れても経過日数は変わらない: 美容院で日付 `10` を記録 → 美容院は `4日前` のまま

### 6-6. `test/ui/screens/collection_screen_test.dart`

- 図鑑から開いた詳細シートにも「日付を指定して記録」が出る

### 6-7. 既存テストの追従

- ロケールが `ja` になるため、既存テストが英語の Material 文言に依存していれば落ちる(司令塔の事前確認では該当なし)。落ちたら**そのテストの期待値を日本語の Material 文言に直す**。実装側を英語に戻さない

---

## 変更ファイル一覧

| 種別 | パス |
| --- | --- |
| 変更 | `lib/domain/item.dart` / `lib/domain/item_repository.dart` |
| 新規 | `lib/domain/past_date_record.dart` |
| 変更 | `lib/data/item_repository_impl.dart` |
| 新規 | `lib/state/record_past_date_result.dart` |
| 変更 | `lib/state/item_list_notifier.dart` |
| 変更 | `lib/app.dart` / `lib/ui/widgets/item_detail_sheet.dart` / `lib/ui/item_navigation.dart` |
| 変更 | `test/support/fake_item_repository.dart` |
| 新規 | `test/domain/past_date_record_test.dart` |
| 変更 | `test/data/item_repository_impl_test.dart` / `test/state/item_list_notifier_test.dart` / `test/ui/widgets/item_detail_sheet_test.dart` / `test/ui/item_list_screen_test.dart` / `test/ui/screens/collection_screen_test.dart` |

**触らない**: `lib/data/database/` / `lib/data/migrations/` / `pubspec.*` / `docs/` / `lib/ui/screens/*`(呼び出し元は `openItemDetailSheet` のシグネチャ据え置きで変更不要)
