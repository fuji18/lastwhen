# 設計書: 一覧の並びを相対経過度の降順にする(Issue #23 / F30)

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

並び替えは **状態管理層(`lib/state/`)のメモリ上**で行う。SQL ではやらない
(相対経過度は `Clock.now()` に依存し、データ層は `Clock` に依存できない — `docs/architecture.md`「データレイヤー」)。

```
watchAll() ──emit──▶ ItemListNotifier.build の map
                      ├─ toItemViews(items, now)           … 既存
                      ├─ 初回        → sortByRelativeElapsed(views)   … 並びを確定
                      └─ 2 回目以降  → applyFixedOrder(views, _fixedOrder) … 並びを維持
AppLifecycleListener.onResume ─▶ ItemListNotifier.refreshOrder() … 並びを確定し直す
```

`ListView.builder` は受け取った `List<ItemView>` を順に描くだけ(ビルド中に並び替えない)。

## 判断一覧

### 判断1: 純関数を `lib/state/item_order.dart` に新設する

`ItemView` に依存するので `lib/domain/` には置かない(`domain` は何にも依存しない)。
ファイル先頭に `import 'item_view.dart';` と `import '../domain/item.dart';`(`ItemId` 用)。

```dart
/// 相対経過度の降順に並べ替えた新しいリストを返す(F30)。
///
/// - 相対経過度が大きいほど上
/// - 相対経過度が null の項目は下部にまとめる
/// - 同値・null 同士は**入力の順序**を保つ
///
/// **入力は登録順(`sortOrder` 昇順)であることが前提。** `ItemRepository.watchAll()` が
/// その順で返す。`ItemView` は `sortOrder` を持たないため、入力の位置をタイブレークに使う。
/// `List.sort` は安定ソートを保証しないので、位置を明示的に比較する。
List<ItemView> sortByRelativeElapsed(List<ItemView> views)
```

実装(この通りに書く):

```dart
List<ItemView> sortByRelativeElapsed(List<ItemView> views) {
  final indexed = [for (var i = 0; i < views.length; i++) (index: i, view: views[i])];
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
```

(`List<ItemView>` の返り値は `toList(growable: false)` 相当である必要はない。上の書き方でよい)

もう 1 つの純関数:

```dart
/// [order] の順序を保ったまま [views] を並べる。記録・改名・取り消しで並びを組み替えないため。
///
/// - [order] にあって [views] に無い ID(削除された項目)は飛ばす
/// - [views] にあって [order] に無い項目(新しく登録された項目)は、**入力の順序のまま末尾に足す**。
///   新規項目は未実施 = 相対経過度 null なので、規則上も下部・登録順の位置になる
List<ItemView> applyFixedOrder(List<ItemView> views, List<ItemId> order)
```

実装:

```dart
List<ItemView> applyFixedOrder(List<ItemView> views, List<ItemId> order) {
  final byId = {for (final view in views) view.id: view};
  final known = order.toSet();
  return [
    for (final id in order)
      if (byId[id] case final view?) view,
    for (final view in views)
      if (!known.contains(view.id)) view,
  ];
}
```

### 判断2: 並びを確定させるタイミング

**確定させる(= `sortByRelativeElapsed` を通す)のは次の 2 つだけ:**

1. `build()` 後の**最初の emit**(アプリ起動・`ref.invalidate(itemListProvider)` による再試行 = 「一覧を開き直す」)
2. **アプリが前面に復帰したとき**(`AppLifecycleListener.onResume` → `refreshOrder()`)

**それ以外の emit(記録・取り消し・改名・登録・削除)は `applyFixedOrder` で並びを維持する。**
登録画面・編集画面・詳細シートから戻ったときも組み替えない(画面は一覧の上に積まれるだけで、
一覧は開き直されていない)。

### 判断3: `ItemListNotifier` の変更(`lib/state/item_list_notifier.dart`)

フィールドを 1 つ足す:

```dart
  /// 確定済みの並び順(ID の列)。null = まだ確定していない(次の emit で確定させる)。判断2。
  List<ItemId>? _fixedOrder;
```

`build()` を次の形にする(既存コメントは残す):

```dart
  @override
  Stream<List<ItemView>> build() {
    final repository = ref.watch(itemRepositoryProvider);
    final clock = ref.watch(clockProvider);
    // build し直し = 一覧を開き直した扱い。次の emit で並びを確定させる(判断2)。
    _fixedOrder = null;
    // now は 1 回の emit につき 1 つ。行ごとに Clock を呼ばない(判断2)。
    return repository.watchAll().map((items) {
      _latestItems = items;
      return _ordered(toItemViews(items, now: clock.now()));
    });
  }

  /// 並びが未確定なら相対経過度で確定させ、確定済みならその並びを保つ。
  List<ItemView> _ordered(List<ItemView> views) {
    final fixed = _fixedOrder;
    final ordered = fixed == null
        ? sortByRelativeElapsed(views)
        : applyFixedOrder(views, fixed);
    _fixedOrder = [for (final view in ordered) view.id];
    return ordered;
  }
```

公開メソッドを 1 つ足す(`markDone` の前に置く):

```dart
  /// 並びを確定し直す。アプリが前面に復帰したときに UI から呼ぶ(判断2)。
  ///
  /// 経過日数も今の時刻で数え直す(バックグラウンド中に日付をまたいでいることがある)。
  /// 一覧をまだ受け取っていない・読み込みに失敗しているときは何もしない
  /// (最初の emit で確定するので不要)。
  void refreshOrder() {
    if (state is! AsyncData<List<ItemView>>) {
      return;
    }
    _fixedOrder = null;
    state = AsyncData(
      _ordered(toItemViews(_latestItems, now: ref.read(clockProvider).now())),
    );
  }
```

- `state` への代入はここだけ。書き込み系メソッド(`addItem` 等)が `state` を触らない方針は変えない
  (これは読み取った一覧の並べ直しであって、書き込みの結果を先取りするものではない = 楽観的更新ではない)
- クラス doc コメントの末尾に 1 行足す: `/// 並び順は相対経過度の降順(F30)。記録では組み替えず、開き直し・復帰で確定し直す。`
- `import 'item_order.dart';` を足す

### 判断4: UI の変更(`lib/ui/screens/item_list_screen.dart`)

`ItemListScreen` を `ConsumerStatefulWidget` に変え、復帰を購読する。**`build` の中身は変えない**
(`ref` は `ConsumerState.ref` をそのまま使う)。

```dart
class ItemListScreen extends ConsumerStatefulWidget {
  /// 一覧画面を作る。
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  /// 復帰で並びを確定し直す(F30)。記録では組み替えない。
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(itemListProvider.notifier).refreshOrder(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 既存の build 本体をそのまま移す
  }
}
```

- 復帰時に `SnackBar`(取り消し導線)は閉じない。4 秒の導線中にバックグラウンドへ行って戻るのは稀で、
  閉じる操作を足す理由にならない
- `_ItemList` は変更しない

### 判断5: テスト

#### 5-1. `test/state/item_order_test.dart`(新規・ユニット)

`ItemView` は const コンストラクタで直接作る(`elapsed` は `const NeverDone()` などで埋める。
`elapsed_days.dart` の型を確認して合わせる)。ヘルパー `ItemView _view(String id, double? relative)` を作る。

`group('sortByRelativeElapsed')`:
- 空リスト → 空
- 降順になる: `[a:1.0, b:2.0, c:0.5]` → `b, a, c`
- null は下部・登録順: `[n1:null, a:1.0, n2:null, b:2.0]` → `b, a, n1, n2`
- 同値は入力順: `[a:1.5, b:1.5, c:1.5]` → `a, b, c`。**同じ入力で 2 回呼んでも同じ結果**
- 入力リストを変更しない(呼び出し後も元の順)

`group('applyFixedOrder')`:
- order の順に並ぶ(views の順序と無関係に)
- order にあって views に無い ID は飛ばす
- views にあって order に無い項目は入力順で末尾に付く

`group('パフォーマンス')`:
- `Item` を 100 件、各 `recentDoneAts` 10 件(間隔を項目ごとに変える)で直接作り、
  `Stopwatch` で `sortByRelativeElapsed(toItemViews(items, now: now))` を計測し
  `elapsedMilliseconds < 300` を確認する(PRD の 300ms 要件の変換部分)。`now` は固定の `DateTime.utc`

#### 5-2. `test/state/item_list_notifier_test.dart`(追加)

履歴の仕込みは `repository.markDone(id, 日時)` を古い順に複数回呼ぶ。基準日は既存の `now`
(`DateTime.utc(2026, 9, 16, 3)`)。`d(n) = now.subtract(Duration(days: n))`。

- 風呂掃除: `d(28), d(21), d(14)` に記録 → 基準 7・経過 14・相対 2.0
- 車の点検: `d(540), d(360), d(180)` に記録 → 基準 180・経過 180・相対 1.0
- 美容院: 記録なし → null

テスト(`group('並び順(F30)')`):
1. **登録順が 車の点検 → 美容院 → 風呂掃除** のとき、一覧は `風呂掃除, 車の点検, 美容院`
2. 風呂掃除に notifier の `markDone(id)`(時刻は FakeClock の `now`)をした後も、順序が
   `風呂掃除, 車の点検, 美容院` のまま(風呂掃除は `Today` になっている)。
   待ち方は既存 `group('記録と取り消し')` の `ready()` / `current()` に合わせる:
   初回値を `await container.read(itemListProvider.future)` で取った後に
   `await Future<void>.delayed(Duration.zero)` を挟んでから書き込み、書き込み後も
   `await Future<void>.delayed(Duration.zero)` を挟んでから `container.read(itemListProvider).requireValue` を読む
3. 2 の後に `container.read(itemListProvider.notifier).refreshOrder()` → 順序が
   `車の点検, 風呂掃除, 美容院` になる(風呂掃除は履歴 d28/d21/d14/今日 → 基準 7・経過 0・相対 0.0 で
   車の点検の 1.0 より下。美容院は null なので最下部)。`refreshOrder()` は同期で `state` を差し替えるので
   待たずに読んでよい
4. 並び確定後に `addItem('新しい項目')` → 新しい項目が末尾に付く
5. 並び確定後に削除 → その項目が消え、他の順序は変わらない
6. `refreshOrder()` は一覧未取得(読み込み中)のとき例外を投げず何もしない

#### 5-3. `test/ui/item_list_screen_test.dart`(追加)

5-2 と同じ仕込み(登録順 車の点検 → 美容院 → 風呂掃除)で `pumpWidget` → `pumpAndSettle`。
カードの並びは `tester.getTopLeft(find.text('風呂掃除')).dy` などの y 座標比較で確かめる。

1. **風呂掃除(14日前)が車の点検(180日前)より上**、美容院が最下部
2. 風呂掃除のカードの「やった」を押す(`find.descendant(of: find.widgetWithText(ItemCard, '風呂掃除'), matching: find.byType(DoneButton))`)
   → `pumpAndSettle` 後も風呂掃除の y 座標が押す前と同じ、`今日` 表示、`取り消す` が見えている
3. 2 の後に復帰を模擬する → 風呂掃除が車の点検より下に移る。模擬は次の順で
   `tester.binding.handleAppLifecycleStateChanged(...)` を呼ぶ(`AppLifecycleListener` は不正な遷移で assert する):
   `inactive → hidden → paused → hidden → inactive → resumed`。その後 `pumpAndSettle`

#### 5-4. 既存テストの追従

履歴が 2 件以上ある項目を複数並べて**登録順を前提にしている**既存テストがあれば、F30 の順序に合わせて
期待値を直す(テストの意図は変えない)。**直した場合は tasklist の申し送りにファイル名とテスト名を書く。**
意図まで変えないと通らないテストが出たら、その場で止めて報告する。

### 判断6: ドキュメント

**`docs/product-requirements.md`** P1 表の F29 行の直後に追加:

```
| F30 | 既定の並び(相対経過度順) | 一覧の既定の並びを相対経過度の降順にする。相対経過度が無い項目は下部に登録順でまとめる。**記録操作では並びを組み替えない**(開き直し・復帰で反映)。F15 の選択 UI は持たず、既定の並びだけを変える |
```

同じ表の F15 行の概要の末尾に ` / 既定の並びは F30` を足す。

**`docs/functional-design.md`**:
- 「UI設計」の `### 詳細シート(F29)` 節の直後(`### 状態ごとの表示` の前)に次の節を足す:

```markdown
### 一覧の並び順(F30)

1. 相対経過度の**降順**(大きいほど上)
2. 相対経過度が null(記録 1 件以下・未実施)の項目は**下部にまとめ、登録順**
3. 同値は登録順(`sortOrder`)

- **記録操作では並びを組み替えない。** 並びは一覧を表示した時点(起動・再試行)と、アプリが前面に
  復帰したときにだけ確定させる。記録・取り消し・改名・登録・削除では確定済みの並びを保ち、
  新しく登録した項目は末尾に付く。押したカードが画面外へ飛ぶと、取り消し導線がどのカードを
  指しているか分からなくなり、隣のカードを続けて押す動線も壊れるため
- 並び替えは SQL ではなく `ItemListNotifier` のメモリ上で行う(相対経過度が `Clock` に依存するため)
- null を上に置かない。基準間隔が分からない項目を上げるのは、アプリが勝手に期限を決めることに近い
```

- 「データモデル定義」の `sortOrder` の表の説明(`MVP では常に登録順と一致する` を含む行)の末尾に
  ` F30 では相対経過度の同値時と、相対経過度が null の項目群の順序に使う。` を足す
- 同じ節のコードブロック内コメント `// 表示順。MVP は登録順で固定、P1 の並び替えで使う` を
  `// 登録順。F30 の並びのタイブレークに使う` に変える
- `### 状態ごとの表示` 表の `記録直後` 行の表示の末尾に `。**カードの位置は動かない**(F30)` を足す

用語集は変更しない。

### 判断7: 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test`。
委託先(Codex sandbox)ではテストを回せないため format と analyze まで(`AGENTS.md` §2)。テストは検収側が回す。

## 変更ファイル一覧

| ファイル | 変更 |
| --- | --- |
| `lib/state/item_order.dart` | 新規(判断1) |
| `lib/state/item_list_notifier.dart` | 判断3 |
| `lib/ui/screens/item_list_screen.dart` | 判断4 |
| `test/state/item_order_test.dart` | 新規(判断5-1) |
| `test/state/item_list_notifier_test.dart` | 判断5-2 |
| `test/ui/item_list_screen_test.dart` | 判断5-3 |
| `docs/product-requirements.md` / `docs/functional-design.md` | 判断6 |

`lib/data/` には触れない(委託禁止領域 `lib/data/database/` `lib/data/migrations/` を含め変更なし)。
