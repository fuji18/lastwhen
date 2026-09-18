# 設計: 「やった」の記録と取り消し(Issue #7)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> `pubspec.yaml` に依存を足す必要が出たときも同じ。
> **データ層(`lib/data/`)は一切変更しない。** 必要な API(`markDone` / `restoreLastDoneAt`)は
> #4 で実装・テスト済み。

## 0. 全体方針

UC1(`docs/functional-design.md`)のシーケンスをそのまま写す。#6 で確立した
「**状態管理層が sealed な結果型を返し、UI がその分岐を画面の振る舞いに写す**」パターンの横展開。

```
ItemRow の「やった」タップ
  → ItemListNotifier.markDone(id)
      → 一覧の直前値から previousLastDoneAt を取り出す(見つからなければ Ignored)
      → Clock.now() → ItemRepository.markDone(id, now)   … 例外なら MarkDoneFailed
      → MarkDoneSucceeded(MarkDoneUndo(id, previousLastDoneAt))
  → watchAll() の再送出で行が「今日」になる
  → UI: clearSnackBars() → SnackBar「記録しました」+ SnackBarAction「取り消す」(既定 4 秒)

「取り消す」タップ
  → ItemListNotifier.undoMarkDone(undo)
      → ItemRepository.restoreLastDoneAt(id, previous, now: Clock.now())
  → watchAll() の再送出で行が元に戻る(未実施だったなら「未実施」)
```

**`markDone` / `undoMarkDone` は `state` を書かない。** 一覧は `watchAll()` の購読結果だけを
反映する。これは #6 の `addItem` と同じ約束で、「保存に失敗しても行は元の値のまま」という
受け入れ条件がこの約束から自動的に満たされる。

## 1. 設計判断(実装者はこれを蒸し返さない)

**判断1: 確認ダイアログを出さない。**
`CLAUDE.md`「譲らない設計判断」/ `docs/product-requirements.md` F3 の注記で確定済み。
1 タップという中心的価値と正面から衝突する。誤操作は**取り消し**で救う。
`showDialog` を書かない。

**判断2: `writeErrorProvider` を導入しない。結果型で返し、呼び出し元の画面で `SnackBar` を出す。**
`docs/functional-design.md`「エラーの分類」はグローバルな `StateProvider<String?>` を想定しているが、
あれが解こうとしている問題は「**一覧の `state` をエラーにしない**」という 1 点で、結果型でも同じだけ
満たせる。一方グローバル 1 本にすると「一度きりのメッセージ」をリセットする責務が UI 側に生まれ、
`ref.listen` + 消し込みの往復が増える。#7 の書き込みは**一覧画面に留まったまま**起きるので、
発生源の画面がそのまま `context` を持っており、経由させる理由がない。#6 の `AddItemResult` と
同じ形に揃える方が、コードベース全体の一貫性も高い。
**`docs/` の追従は `/sync-docs` の担当。このチケットで `docs/` を書き換えない。**

**判断3: 取り消しに必要な直前値は「ハンドル」に載せて UI へ渡し、Notifier に可変フィールドを持たせない。**
`docs/functional-design.md` は「Notifier が直前の `lastDoneAt` を直近 1 件だけ保持する」と書くが、
**保持期間は取り消し導線の寿命(4 秒 / 次の記録まで)そのもの**であり、それを管理しているのは
`ScaffoldMessenger` の方である。Notifier 側にも同じ寿命の状態を置くと二重管理になり、
「別の項目を記録すると前の対象を破棄する」を両方で実装することになる。
`markDone` が返す `MarkDoneUndo` を `SnackBarAction` のクロージャが捕まえる形にすれば、
**「直近 1 件のみ」は `SnackBar` が 1 つしか出ないことから構造的に導かれる**(判断5)。
`MarkDoneUndo` は UI にとって**中身を読まない不透明なハンドル**として扱う
(UI から `previousLastDoneAt` を参照するコードを書かない。`ItemView` が `DateTime` を
持たないという #5 の約束をここでも崩さない)。

**判断4: 直前値は Notifier がキャッシュした最新の `List<Item>` から引く。**
`ItemView` は `DateTime` を持たない(#5 判断)ので、`state` からは直前値を取れない。
リポジトリを引き直す(`watchAll().first`)と購読をもう 1 本張ることになるため、
`build()` の `map` の中で最後に流れてきた `List<Item>` を private フィールドへ控える。
一覧に無い ID(削除と同時操作)は `MarkDoneIgnored` を返し、**書き込みを試みない**
(`docs/functional-design.md`「対象項目が存在しない」= 無視・表示しない)。

**判断5: `SnackBar` を出す前に必ず `clearSnackBars()` を呼ぶ。**
`ScaffoldMessenger` は `showSnackBar` を**キューに積む**。何もしないと 2 件続けて記録したとき
1 件目の導線が先に 4 秒出てから 2 件目が出る形になり、受け入れ条件「取り消せるのは直近の 1 件のみ。
別の項目を記録すると前の導線は消える」を満たせない。`hideCurrentSnackBar()` では現在の 1 件しか
落ちないため、**`clearSnackBars()` を使う**。記録・取り消し失敗・書き込み失敗のすべての表示経路で
先に呼ぶ。

**判断6: `duration` は明示しない。ただし取り消し導線には `persist: false` を明示する。**
`docs/functional-design.md`「状態ごとの表示」が「4 秒間(`SnackBar` の既定)」と書いているので、
`duration` は既定(`_snackBarDisplayDuration` = 4 秒)に任せる。明示すると二重管理になる。

**一方 `persist` は明示する。** Flutter 3.47 の `SnackBar` は
`persist = persist ?? action != null`(`packages/flutter/lib/src/material/snack_bar.dart`)で、
**アクションを付けると既定で自動消去されない** —— `ScaffoldMessengerState.build` のタイマーは
`duration` 経過後に `snackBar.persist` を見て、true なら `hideCurrentSnackBar` を呼ばずに戻る
(`packages/flutter/lib/src/material/scaffold.dart`)。受け入れ条件と
`docs/product-requirements.md` F3 が要求しているのは「直後に **4 秒間**だけ出る」なので、
取り消し導線には `persist: false` を明示する。
失敗表示の `SnackBar` はアクションが無く既定で `false` になるため、そちらには書かない
(書くと「なぜここにあるのか」が読めなくなる)。

> **この判断は委託先の停止報告(1 回目の委託の `exit 1`)を受けて司令塔が下した。**
> 当初の「既定に任せれば 4 秒で消える」は SDK の挙動を取り違えていた。委託先が推測で
> `persist: false` を足さずに止めたのは正しい振る舞い。

テスト側は `const Duration(seconds: 4)` を `pump` して消えることを確認する。

**判断7: 画面遷移の前に `clearSnackBars()` を呼ぶ。**
`ScaffoldMessenger` は `Navigator` の上にあるので、**何もしないと導線が遷移後も残る**
(`docs/functional-design.md`「画面遷移時に取り消し導線を閉じる」)。登録画面へ push する
`_openAddScreen` の先頭で呼ぶ。これで「取り消しは一覧に留まっている間だけ有効」が構造的に成立する。

**判断8: 「やった」の二度押しを塞がない(`_isSaving` 相当のフラグを置かない)。**
#6 の登録は二度押しで**項目が 2 件できる**ので塞いだが、記録は同じ行への UPDATE で、
2 回押しても結果は「今日」のまま変わらない。取り消しハンドルも後勝ちで整合する。
ボタンを一時的に無効化すると、中心操作の体感が落ちるほうの害が大きい。

**判断9: 視覚的フィードバックは Material 3 の既定(`FilledButton.tonal` の ripple)+ 行の更新 + `SnackBar` で満たす。**
独自のアニメーションやハプティクスを足さない(`CLAUDE.md`「追加の UI パッケージを入れない」/
`docs/ui-design-guidelines.md` §7)。`DoneButton` は**変更しない**。

**判断10: 失敗のログは `dart:developer` の `log` で出す(#6 判断9 と同じ)。**
`lib/state/` は `package:flutter/` を import できない(`test/architecture/layer_dependency_test.dart`)。
`name` は `'lastwhen.state'` で揃える。

## 2. 実装するファイル

| ファイル | 変更 |
| --- | --- |
| `lib/state/mark_done_result.dart` | **新規**。`MarkDoneResult` / `MarkDoneUndo` / `UndoResult` |
| `lib/state/item_list_notifier.dart` | `markDone` / `undoMarkDone` と最新 `List<Item>` のキャッシュを追加 |
| `lib/ui/screens/item_list_screen.dart` | `onDonePressed` の結線、`SnackBar` 表示、遷移前の `clearSnackBars()` |
| `test/state/item_list_notifier_test.dart` | 記録・取り消しのユニットテストを追加 |
| `test/ui/item_list_screen_test.dart` | 記録・取り消しのウィジェットテストを追加 |

**触らないファイル**: `lib/domain/`(全部)、`lib/data/`(全部)、`lib/ui/widgets/`(全部)、
`lib/app.dart`、`pubspec.yaml`、`docs/`。

## 3. `lib/state/mark_done_result.dart`(新規)

`lib/state/add_item_result.dart` と同じ置き方・同じ粒度のドキュメントコメントを付ける。

```dart
import '../domain/item.dart';

/// 「やった」の記録結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class MarkDoneResult {
  const MarkDoneResult();
}

/// 保存まで成功した。[undo] を取り消し導線へ渡す。
final class MarkDoneSucceeded extends MarkDoneResult {
  const MarkDoneSucceeded(this.undo);

  final MarkDoneUndo undo;
}

/// 対象が一覧に無かった(削除と同時操作)。**書き込みを試みていない。**
///
/// `docs/functional-design.md`「エラーの分類」に従い、UI は何も表示しない。
final class MarkDoneIgnored extends MarkDoneResult {
  const MarkDoneIgnored();
}

/// 書き込みに失敗した。一覧は直前の値のまま。
final class MarkDoneFailed extends MarkDoneResult {
  const MarkDoneFailed();
}

/// 取り消しに必要な情報を運ぶ不透明なハンドル。
///
/// **UI はこの中身を読まない。** 受け取って [ItemListNotifier.undoMarkDone] に返すだけ
/// (design.md 判断3)。日時の解釈を状態管理層に閉じる約束を、取り消し経路でも崩さないため。
final class MarkDoneUndo {
  const MarkDoneUndo({required this.id, required this.previousLastDoneAt});

  /// 記録した項目。
  final ItemId id;

  /// 記録する直前の最終実施日時(UTC)。**未実施だったなら null。**
  final DateTime? previousLastDoneAt;
}

/// 取り消しの結果。
sealed class UndoResult {
  const UndoResult();
}

/// 直前の値に戻した。
final class UndoSucceeded extends UndoResult {
  const UndoSucceeded();
}

/// 書き込みに失敗した。一覧は「今日」のまま。
final class UndoFailed extends UndoResult {
  const UndoFailed();
}
```

## 4. `lib/state/item_list_notifier.dart`

`build()` を次の形に差し替える(`_latestItems` の記録を足すだけ。`now` の扱いは変えない)。

```dart
  /// 最後に流れてきたドメインの一覧。取り消し用の直前値を引くために控える(判断4)。
  List<Item> _latestItems = const <Item>[];

  @override
  Stream<List<ItemView>> build() {
    final repository = ref.watch(itemRepositoryProvider);
    final clock = ref.watch(clockProvider);
    // now は 1 回の emit につき 1 つ。行ごとに Clock を呼ばない(判断2)。
    return repository.watchAll().map((items) {
      _latestItems = items;
      return toItemViews(items, now: clock.now());
    });
  }
```

`addItem` の下に 2 メソッドを足す。**`state` を書かないこと**(`addItem` と同じ約束)。

```dart
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
```

import に `../domain/item.dart` と `mark_done_result.dart` を足す。
クラスのドキュメントコメントにある「#6 以降の書き込みメソッド(`addItem` / `markDone` など)は
このクラスに足していく」の一文は、実態に合わせて整える。

## 5. `lib/ui/screens/item_list_screen.dart`

### 5-1. `_ItemList` を `ConsumerWidget` にする

`onDonePressed` から `ref` が要るため。`_ItemList` の `build` を
`Widget build(BuildContext context, WidgetRef ref)` に変え、行のコールバックを結ぶ。

```dart
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemRow(
          item: item,
          onDonePressed: () => _handleDone(context, ref, item.id),
        );
      },
```

### 5-2. 記録と取り消しのハンドラ(ファイル末尾の private 関数として置く)

`_openAddScreen` と同じ並びに、トップレベルの private 関数として置く。

```dart
/// 「やった」を記録し、直後に取り消し導線を出す。
///
/// **確認ダイアログを挟まない**(`docs/product-requirements.md` F3)。
Future<void> _handleDone(BuildContext context, WidgetRef ref, ItemId id) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(itemListProvider.notifier).markDone(id);
  switch (result) {
    case MarkDoneSucceeded(:final undo):
      // キューに積ませない。積むと前の導線が先に出て「直近 1 件のみ」が崩れる(判断5)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない(判断6)。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _handleUndo(messenger, ref, undo),
          ),
        ),
      );
    // 削除と同時操作。何も出さない(`docs/functional-design.md`「エラーの分類」)。
    case MarkDoneIgnored():
      break;
    case MarkDoneFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
  }
}

/// 直前の「やった」を取り消す。
///
/// `BuildContext` ではなく [ScaffoldMessengerState] を受け取る。取り消しは `SnackBar` の
/// アクションから走るため、押された時点で元の行のコンテキストが生きている保証がない。
void _handleUndo(
  ScaffoldMessengerState messenger,
  WidgetRef ref,
  MarkDoneUndo undo,
) {
  unawaited(() async {
    final result = await ref.read(itemListProvider.notifier).undoMarkDone(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}
```

`unawaited` は `dart:async` の import が要る。
`SnackBarAction.onPressed` は同期の `VoidCallback` なので、`async` 関数を直に渡さない。

### 5-3. 遷移前に導線を閉じる

`_openAddScreen` の先頭で `ScaffoldMessenger.of(context).clearSnackBars();` を呼ぶ(判断7)。
理由をコメントで 1 行残す(`ScaffoldMessenger` は `Navigator` の上にあるため遷移後も残る)。

### 5-4. 既存コメントの始末

`_ItemList` の `// #7(「やった」の記録)で ... に繋ぐ(判断12)。` を消す。
`_LoadError` の `// 書き込みの失敗はここに来ない(#6 以降で SnackBar に出す)。` は
「書き込みの失敗はここに来ない(`SnackBar` に出す)」へ直す。

import に `../../domain/item.dart`(`ItemId`)・`../../state/mark_done_result.dart`・`dart:async` を足す。

## 6. テスト

### 6-1. `test/state/item_list_notifier_test.dart` に足す

既存の `_container` ヘルパーをそのまま使う。**追加するケース**:

| ケース | 検証 |
| --- | --- |
| 記録すると最終実施日が `Clock` の現在時刻になる | 記録後の `ItemView.elapsed` が `Today`、`lastDoneText` が当日 |
| 未実施の項目を記録すると取り消しハンドルの直前値が null | `MarkDoneSucceeded.undo.previousLastDoneAt` が `null` |
| 記録済みの項目を記録すると直前値が元の日時 | 同上が元の `lastDoneAt` と一致 |
| 未実施へ戻す取り消し | 取り消し後に `elapsed` が `NeverDone` で `lastDoneText` が `null` |
| 直前の日付へ戻す取り消し | 取り消し後に元の日付へ戻る |
| 一覧に無い ID | `MarkDoneIgnored` が返り、**リポジトリの内容が変わらない** |
| 書き込み失敗 | `repository.writeError` を仕込み `MarkDoneFailed`。**一覧は `AsyncData` のまま**で行の値も変わらない |
| 取り消しの失敗 | `UndoFailed` が返り、行は「今日」のまま |
| 時刻は `Clock` 経由 | `_CountingClock` の `calls` が記録の前後で増える |

`repository.writeError` は書き込みだけに効き、`watchAll()` には影響しない
(`test/support/fake_item_repository.dart`)。**`FakeItemRepository` は変更しない。**

### 6-2. `test/ui/item_list_screen_test.dart` に足す

既存の `_app` / `pumpItems` ヘルパーをそのまま使う(`pumpItems` は「美容院」= 2026年9月12日記録済み、
「歯ブラシ交換」= 未実施 の 2 件を積む。`FakeClock` は 2026-09-16)。**追加するケース**:

| ケース | 検証 |
| --- | --- |
| 確認ダイアログが出ない | 「やった」タップ後に `find.byType(AlertDialog)` と `find.byType(Dialog)` が `findsNothing` |
| 行が「今日」になる | 未実施の行の「やった」を押すと `未実施` が消えて `今日` が出る |
| 取り消し導線が出る | `SnackBar` と「取り消す」が 1 つ出る |
| 未実施へ戻る往復 | 「取り消す」を押すと行が `未実施` に戻り、日付も消える |
| 記録済みの行の往復 | 「美容院」を記録 → 取り消しで `4日前` と `2026年9月12日` に戻る |
| 直近 1 件のみ | 2 行続けて記録すると `SnackBar` は 1 つだけ。「取り消す」は**後に押した行**に効き、先の行は `今日` のまま |
| 4 秒で消える | 記録後 `await tester.pump(const Duration(seconds: 4))` + `pumpAndSettle` で `SnackBar` が消える |
| 書き込み失敗 | `repository.writeError` を仕込むと行が変わらず「保存できませんでした。もう一度お試しください」が出る。**一覧は消えない**(`ItemRow` が 2 件のまま) |
| 遷移で閉じる | 記録 → FAB で登録画面へ → `SnackBar` が消えている |
| 画面遷移を伴わない | 記録・取り消しの後も `ItemListScreen` が 1 つのまま(`ItemAddScreen` が出ない) |

**タップは `tester.tap(find.descendant(of: <対象行>, matching: find.byType(DoneButton)))` で行を特定する。**
「やった」というテキストは全行にあるので `find.text('やった')` で押さない。
タップ後は `await tester.pumpAndSettle()` で書き込み完了と `SnackBar` の登場を待つ。

## 7. 完了の定義

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test`(委託先はネットワーク無効の sandbox で実行できない。**検収側 / CI が回す**)
- 上記の受け入れ条件(`requirements.md`)がすべて満たされている
