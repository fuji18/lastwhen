# 設計: 一覧画面 — 項目の表示と空状態(Issue #5)

<!-- status: ready -->

実装者が設計判断を一切せずに実装できる粒度で書く。**ここに書かれたコードをそのまま写してよい**
(型名・引数名・doc コメントを含む)。疑問が出たら実装を止めて司令塔に戻すこと。

## 0. 全体方針

- 層の責務は `docs/architecture.md`「レイヤードアーキテクチャ」が正。このチケットで新設する
  `lib/state/` は **`Widget` / `BuildContext` に依存しない**。`lib/ui/` は **`lib/data/` と
  Drift の型を知らない**。どちらも `test/architecture/layer_dependency_test.dart` で機械検査する
- **UI 層で `DateTime.now()` を呼ばない・経過日数を計算しない。** UI は計算済みの `ItemView` を
  描画するだけにする
- **色・タイポは `Theme.of(context)` 経由**で取る。ウィジェットに生の色・フォントサイズを書かない
- **このチケットは読み取りのみ。** `ItemListNotifier` に書き込みメソッドを足さない(#6 以降)
- **`pubspec.yaml` を触らない。** 追加依存が要ると判断したら実装を止めて司令塔に戻す
- doc コメントは `///` で日本語。**なぜそうするか**を書く(何をするかはコードが語る)
- 用語は `docs/glossary.md`「表記ゆれの禁止一覧」。**「未実施」を「0日前」と書かない**

## 1. 設計判断(実装者はこれを蒸し返さない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | `ItemListNotifier` は `AsyncNotifier` ではなく **`StreamNotifier<List<ItemView>>`** を継承する | 供給源の `ItemRepository.watchAll()` が Stream。`AsyncNotifier` だと「初回値を待つ Future」と「以降を反映する購読」を自前で二重に持つことになり、購読の解除漏れと二重購読の温床になる。`StreamNotifier` は `build()` が返した Stream の購読・初回値・破棄を Riverpod 側が持つ。state の型は `AsyncValue<List<ItemView>>` のままなので UI の出し分けは変わらず、#6 以降に書き込みメソッドを足せる点も同じ。**`docs/functional-design.md`「ItemListNotifier」の記載(`AsyncNotifier`)からの逸脱**で、tasklist の振り返りで `/sync-docs` 対象として申し送る |
| 2 | `Clock.now()` は **Stream の `map` 内で 1 回**だけ呼ぶ | 1 回の emit = 1 つの基準時刻。行ごとに呼ぶと描画中に日付をまたいだとき行間で基準が食い違う(`docs/functional-design.md`「パフォーマンス最適化」)。受け入れ条件そのもの |
| 3 | 最終実施日の整形は**状態管理層**で行い、`ItemView.lastDoneText` に **`String?`** として持たせる | `docs/functional-design.md`「コンポーネント設計」の `ItemView` 定義どおり。UTC 保存をローカルの暦日として読む解釈を 1 箇所に閉じ、UI に `DateTime` を渡さない |
| 4 | `DateFormat` に**ロケールを渡さない**(`DateFormat('y年M月d日')`) | `年` `月` `日` は ASCII 英字ではないためパターン文字にならず、リテラルとして出力される。整形されるのは数値フィールドだけなので、ロケール依存のシンボル(曜日名・月名)を一切引かない。`'ja'` を明示すると `initializeDateFormatting('ja')` の呼び出しと `main()` の非同期化が要る割に、**出力は同じ**。出力そのものは §4.2 のテストで固定する |
| 5 | 整形前に **`.toLocal()` を必ず通す** | `lastDoneAt` は UTC。UTC のまま整形すると、経過日数(`elapsedDays` はローカルの暦日で数える)と表示日付が別の日を指す行が出る |
| 6 | 経過日数の**文字列化は UI 層**(`item_row.dart` の `elapsedText`)で行う | `ElapsedLabel` は表示ラベルの分類であって文言ではない(`docs/glossary.md`「経過日数」)。文言は UI の責務。`ItemView.elapsed` が `ElapsedLabel` のままなのは判断3 と同じく機能設計書の定義どおり |
| 7 | `lib/ui/` が `lib/domain/elapsed_days.dart` を import することを**許可する** | 判断6 の帰結。`docs/repository-structure.md`「lib/ui/」の禁止リストは `data/` と Drift 生成型であって `domain/` ではない。**禁止なのは UI が `data/` を見ることと、UI が計算すること**で、ドメインの型を読むことではない |
| 8 | `DaysAgo` に **`==` / `hashCode`** を足す(`lib/domain/elapsed_days.dart`) | `ItemView` の値等価が `elapsed` を含むため、`DaysAgo(42) != DaysAgo(42)` のままだと同じ内容の一覧が毎回「変わった」と判定され、`StreamNotifier` の更新フィルタが効かない。`NeverDone` / `Today` / `Yesterday` は `const` インスタンスなので既に等価 |
| 9 | Provider は 3 本(`appDatabaseProvider` / `itemRepositoryProvider` / `clockProvider`)。**`itemRepositoryProvider` の型はドメインの `ItemRepository`** | 上位層のテストがこの 1 本を `FakeItemRepository` に差し替えるだけで Drift を起動せずに済む(`docs/functional-design.md`「テスト戦略」) |
| 10 | 「やった」ボタンは `lib/ui/widgets/done_button.dart` に切り出し、**56dp を `minimumSize` + `tapTargetSize: shrinkWrap` で確保**する | ファイル構成は `docs/repository-structure.md`「lib/ui/」どおり。Material の既定タップ領域は 48dp で不足(`docs/ui-design-guidelines.md` §7)。`shrinkWrap` にしないと「見た目 40dp + 透明パディング 48dp」になり、**実寸を検査するテストが書けない** |
| 11 | **`FloatingActionButton` を置かない** | 追加ボタンは #6 のスコープに明記されている。#5 の受け入れ条件が求めているのは**空状態の中の導線**だけ |
| 12 | 「やった」ボタンと空状態の導線は、**何もしないコールバック**を渡して配置だけ行う | #5 は読み取りのみで、遷移先(#6)も記録処理(#7)もまだ無い。`null` を渡すと Material が**無効表示**にして「壊れた画面」に見えるため、no-op を渡して見た目を正にする。接続点はコメントで明示し、#6 / #7 が 1 箇所を書き換えれば済む形にする |
| 13 | 一覧のエラー表示は**専用画面を作らず**、`ItemListScreen` の body 内に置く | `docs/functional-design.md`「エラーハンドリング」が求めるのは「一覧を表示せずエラーへ」であって画面遷移ではない。MVP の通常フローに現れない状態のためにルーティングを足さない |
| 14 | 余白は **4 の倍数の `const` リテラル**で書く(`Theme` 経由にしない) | Material 3 の `ThemeData` に余白トークンが無い。ガイドライン §3.1 が求めるのは「4 の倍数で揃える」ことで、`Theme` 経由の取得は**色・タイポ**に対する要求(§7) |
| 15 | MVP では**状態を色で分けない**。強調はサイズとウェイトだけで作る | `docs/functional-design.md`「色の使い方」。経過日数に `colorScheme.primary` 等を付けない |

> **Riverpod 3 の既知の挙動**: 失敗した provider は既定で自動リトライされる。DB オープン失敗時に
> `AsyncError` が出たあと勝手に再試行が走ることがあるが、**これは正常**。§2.4 の再試行ボタン
> (`ref.invalidate`)は手動の再試行手段として別に置く。

## 2. 実装するファイル

### 2.1 `lib/state/item_view.dart`(新規)

```dart
import 'package:intl/intl.dart';

import '../domain/elapsed_days.dart';
import '../domain/item.dart';

/// 最終実施日の表示フォーマット(`2026年9月12日`)。
///
/// **ロケールを渡さない。** `年` `月` `日` は ASCII 英字ではないためパターン文字にならず、
/// リテラルとして出力される。整形されるのは数値フィールドだけなので、ロケール依存の
/// シンボル(曜日名・月名)を引かず、`initializeDateFormatting` も要らない。
final DateFormat _lastDoneFormat = DateFormat('y年M月d日');

/// UI が描画に必要とするものだけを持つ表示モデル。
///
/// **`DateTime` を持たない。** 「UTC で保存された日時をローカルの暦日として読む」という
/// 解釈を状態管理層に閉じ、UI に漏らさない(`docs/functional-design.md`「コンポーネント設計」)。
final class ItemView {
  /// 表示モデルを組み立てる。通常は [ItemView.from] を使う。
  const ItemView({
    required this.id,
    required this.name,
    required this.elapsed,
    required this.lastDoneText,
  });

  /// ドメインの [Item] を [now] 時点の表示モデルへ変換する。
  factory ItemView.from(Item item, {required DateTime now}) {
    final lastDoneAt = item.lastDoneAt;
    return ItemView(
      id: item.id,
      name: item.name,
      elapsed: elapsedLabel(lastDoneAt: lastDoneAt, now: now),
      // UTC のまま整形すると、ローカルの暦日で数える経過日数と別の日を指す行が出る。
      lastDoneText: lastDoneAt == null
          ? null
          : _lastDoneFormat.format(lastDoneAt.toLocal()),
    );
  }

  /// 対象の項目 ID。
  final ItemId id;

  /// 項目名。
  final String name;

  /// 経過日数の表示ラベル。**文字列への変換は UI 層が行う。**
  final ElapsedLabel elapsed;

  /// 最後にやった日(`2026年9月12日`)。**未実施なら null**。
  final String? lastDoneText;

  @override
  bool operator ==(Object other) =>
      other is ItemView &&
      other.id == id &&
      other.name == name &&
      other.elapsed == elapsed &&
      other.lastDoneText == lastDoneText;

  @override
  int get hashCode => Object.hash(id, name, elapsed, lastDoneText);
}

/// 一覧をまとめて表示モデルへ変換する。
///
/// **[now] を引数で受け取り、1 回の変換につき 1 つに固定する。** 行ごとに `Clock.now()` を
/// 呼ぶと、描画中に日付をまたいだとき行間で基準時刻が食い違う
/// (`docs/functional-design.md`「パフォーマンス最適化」)。
List<ItemView> toItemViews(List<Item> items, {required DateTime now}) =>
    items.map((item) => ItemView.from(item, now: now)).toList(growable: false);
```

### 2.2 `lib/state/providers.dart`(新規)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/item_repository_impl.dart';
import '../domain/clock.dart';
import '../domain/item_repository.dart';

/// アプリ全体で 1 つの [AppDatabase]。**DB を開く唯一の場所。**
///
/// `ref.onDispose` で閉じるのは、テストが `ProviderContainer` を捨てたときに
/// ファイルハンドルを残さないため。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// 項目の永続化。**型はドメインのインターフェース**にする。
///
/// 上位層(Notifier・ウィジェットテスト)はこの 1 本を `FakeItemRepository` に
/// 差し替えるだけで、Drift を起動せずにテストできる。
final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ItemRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// 現在時刻の供給元。テストは `FakeClock` に差し替える。
final clockProvider = Provider<Clock>((ref) => const SystemClock());
```

### 2.3 `lib/state/item_list_notifier.dart`(新規)

```dart
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
    return repository
        .watchAll()
        .map((items) => toItemViews(items, now: clock.now()));
  }
}
```

### 2.4 `lib/ui/screens/item_list_screen.dart`(新規)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_row.dart';

/// 一覧画面。**起動直後に出る唯一の画面**(`docs/functional-design.md`「画面遷移図」)。
class ItemListScreen extends ConsumerWidget {
  /// 一覧画面を作る。
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LastWhen')),
      body: SafeArea(
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: _handleAddPressed,
          ),
          AsyncData(:final value) => _ItemList(items: value),
          AsyncError() => _LoadError(
            onRetry: () => ref.invalidate(itemListProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// 新規登録への導線。
  ///
  /// **#6(項目の新規登録)で登録画面への遷移をここに入れる。** このチケットの
  /// スコープは導線の配置までで、遷移先の画面がまだ無い(判断12)。
  void _handleAddPressed() {}
}

/// 項目が 1 件以上あるときの一覧。
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<ItemView> items;

  @override
  Widget build(BuildContext context) {
    // 100 件で全行を同時に構築しない(`docs/functional-design.md`「パフォーマンス最適化」)。
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ItemRow(
        item: items[index],
        // #7(「やった」の記録)で `ItemListNotifier.markDone` に繋ぐ(判断12)。
        onDonePressed: () {},
      ),
    );
  }
}

/// 一覧そのものを読み込めなかったときの表示。
///
/// DB のオープン失敗・購読の切断がここに来る(`docs/functional-design.md`
/// 「エラーハンドリング」)。書き込みの失敗はここに来ない(#6 以降で `SnackBar` に出す)。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'データを読み込めませんでした',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}
```

### 2.5 `lib/ui/widgets/empty_state.dart`(新規)

```dart
import 'package:flutter/material.dart';

/// 項目が 0 件のときの表示。
///
/// **空状態そのものを新規登録への導線にする**(`docs/ui-design-guidelines.md` §7
/// 「状態の表現」)。何も無い画面を見せて終わらせない。
class EmptyState extends StatelessWidget {
  /// 空状態を作る。[onAddPressed] は新規登録への導線。
  const EmptyState({required this.onAddPressed, super.key});

  /// 新規登録への導線が押されたときの処理。
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'まだ項目がありません',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '「最後にやったのはいつ?」を知りたいことを登録します',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('項目を追加'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 2.6 `lib/ui/widgets/done_button.dart`(新規)

```dart
import 'package:flutter/material.dart';

/// 「やった」ボタンの最小辺(dp)。
///
/// Material の既定タップ領域は 48dp だが、このアプリは**片手・1 タップ**が中心価値なので
/// 自前で 56dp を指定する(`docs/ui-design-guidelines.md` §7「タッチターゲット」)。
const double doneButtonMinSize = 56;

/// 記録(「やった」)のボタン。
///
/// ラベルは「やった」で固定する(`docs/glossary.md`「表記ゆれの禁止一覧」)。
/// **押したときの動作は呼び出し元が決める。**
class DoneButton extends StatelessWidget {
  /// ボタンを作る。[onPressed] はタップ時の処理。
  const DoneButton({required this.onPressed, super.key});

  /// タップ時の処理。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(doneButtonMinSize, doneButtonMinSize),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 既定の `padded` だと「見た目 40dp + 透明パディング」になり、
        // ウィジェットの実寸が 56dp を表さなくなる(判断10)。
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('やった'),
    );
  }
}
```

### 2.7 `lib/ui/widgets/item_row.dart`(新規)

```dart
import 'package:flutter/material.dart';

import '../../domain/elapsed_days.dart';
import '../../state/item_view.dart';
import 'done_button.dart';

/// 一覧の 1 行。**このアプリで最も重要なコンポーネント。**
///
/// 左に「項目名 + 最後にやった日」、右寄りに「経過日数」、右端に「やった」ボタンを置く
/// (`docs/functional-design.md`「UI設計」)。**経過日数が行内で最大・最も太い。**
/// ボタンを右端に置くのは片手操作で親指が届く範囲だから。
class ItemRow extends StatelessWidget {
  /// 1 行を作る。
  const ItemRow({required this.item, required this.onDonePressed, super.key});

  /// 表示する項目。
  final ItemView item;

  /// 「やった」ボタンのタップ時の処理。
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastDoneText = item.lastDoneText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 未実施の行には日付を出さない(`docs/glossary.md`「項目の表示状態」)。
                if (lastDoneText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    lastDoneText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Flexible にして、文字サイズを上げても横にはみ出さないようにする。
          Flexible(
            flex: 2,
            child: Text(
              elapsedText(item.elapsed),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 行内で最大・最も太い。**強調はサイズとウェイトだけで作り、色を使わない**
              // (MVP は状態を色で分けない。`docs/functional-design.md`「色の使い方」)。
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DoneButton(onPressed: onDonePressed),
        ],
      ),
    );
  }
}

/// 経過日数の表示文字列。
///
/// 文言は `docs/glossary.md`「項目の表示状態」が正。**`NeverDone` を「0日前」と書かない**
/// (「今日やった」と区別がつかなくなる)。
String elapsedText(ElapsedLabel label) => switch (label) {
  NeverDone() => '未実施',
  Today() => '今日',
  Yesterday() => '昨日',
  DaysAgo(:final days) => '$days日前',
};
```

### 2.8 `lib/app.dart`(書き換え)

`_PlaceholderHome` を**クラスごと削除**し、`home` を `ItemListScreen` にする。
`import 'ui/screens/item_list_screen.dart';` を足す。doc コメントは次のとおりに直す。

```dart
import 'package:flutter/material.dart';

import 'ui/screens/item_list_screen.dart';
import 'ui/theme/app_theme.dart';

/// `MaterialApp` の組み立て。
///
/// 通常操作の画面は一覧・登録・編集の 3 つだけで、起動直後は必ず一覧に出る
/// (`docs/functional-design.md`「画面遷移図」)。`Navigator` の名前付きルートは
/// 画面が増える #6 / #8 で必要になった時点で足す。
/// `themeMode` は既定の [ThemeMode.system] に任せ、端末の設定に追従させる。
class App extends StatelessWidget {
  /// アプリのルートウィジェットを作る。
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastWhen',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const ItemListScreen(),
    );
  }
}
```

### 2.9 `lib/domain/elapsed_days.dart`(追記のみ)

`DaysAgo` クラスに値等価を足す(判断8)。**他の箇所は触らない。**

```dart
/// 2 日以上前。
final class DaysAgo extends ElapsedLabel {
  const DaysAgo(this.days);

  /// 2 以上の暦日数。
  final int days;

  // 同じ日数なら同じラベル。値等価が無いと、内容の変わっていない一覧が
  // 毎回「変わった」と判定され、更新フィルタが効かない。
  @override
  bool operator ==(Object other) => other is DaysAgo && other.days == days;

  @override
  int get hashCode => days.hashCode;
}
```

## 3. テスト

環境のタイムゾーンは **UTC**(devcontainer / GitHub Actions とも)。既存の
`test/domain/elapsed_days_test.dart` と同じく、日時は `DateTime.utc(...)` で書き、
時刻成分は `3, 0` のように昼側に寄せる。

### 3.1 `test/state/item_list_notifier_test.dart`(新規)

Drift を起動しない。`FakeItemRepository` と `FakeClock` を `ProviderContainer.test` に流し込む。

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/state/item_list_notifier.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/state/providers.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';
```

ヘルパ(ファイル内に置く):

```dart
/// `Clock.now()` が何回呼ばれたかを数える [Clock]。
final class _CountingClock implements Clock {
  _CountingClock(this._now);

  final DateTime _now;

  /// `now()` の呼び出し回数。
  int calls = 0;

  @override
  DateTime now() {
    calls++;
    return _now;
  }
}

/// フェイクと固定 Clock を差し込んだコンテナを作る。
///
/// `container.listen` で購読を保持してから `.future` を待つ。購読が無いまま読むと
/// Stream の初回値が確定する前に評価が終わりうる。
ProviderContainer _container(FakeItemRepository repository, Clock clock) {
  final container = ProviderContainer.test(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(clock),
    ],
  );
  container.listen(itemListProvider, (_, _) {});
  return container;
}
```

> **`ProviderContainer.test` は Riverpod 3 のテスト用ファクトリ**で、テスト終了時に自動で
> dispose される。もし `overrides` 引数を受け付けないバージョンだった場合に限り、
> `ProviderContainer(overrides: ...)` + `addTearDown(container.dispose)` に置き換えてよい
> (これは設計判断ではなく API 差の吸収)。

検証する項目:

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | 項目 0 件 | `await container.read(itemListProvider.future)` が空リスト |
| 2 | 未実施の項目 1 件 | `elapsed` が `NeverDone`、**`lastDoneText` が null** |
| 3 | 今日記録した項目 | `elapsed` が `Today`、`lastDoneText` が `'2026年9月16日'` |
| 4 | 昨日記録した項目 | `elapsed` が `Yesterday` |
| 5 | 4 日前に記録した項目(`2026-09-12` 記録 / now `2026-09-16`) | `elapsed` が `DaysAgo(4)`、`lastDoneText` が **`'2026年9月12日'`**(受け入れ条件の表記そのもの) |
| 6 | 3 件ある状態で 1 回読む | `_CountingClock.calls` が **1**(行ごとに呼んでいない。受け入れ条件) |
| 7 | 読み込み後に項目を追加する | 再度 emit され、一覧が 2 件になる(`watchAll` の購読が効いている) |
| 8 | `toItemViews` を直接呼ぶ | 並び順が入力どおりに保たれる |

シナリオ 6 の書き方:

```dart
test('Clock.now は 1 回の変換につき 1 回しか呼ばれない', () async {
  final repository = FakeItemRepository();
  addTearDown(repository.dispose);
  final clock = _CountingClock(DateTime.utc(2026, 9, 16, 3));
  await repository.add('美容院', now: DateTime.utc(2026, 9, 1, 3));
  await repository.add('歯ブラシ交換', now: DateTime.utc(2026, 9, 2, 3));
  await repository.add('シーツ洗濯', now: DateTime.utc(2026, 9, 3, 3));

  final container = _container(repository, clock);
  final views = await container.read(itemListProvider.future);

  expect(views, hasLength(3));
  expect(clock.calls, 1);
});
```

### 3.2 `test/state/item_view_test.dart`(新規)

`ItemView` 単体。判断4(ロケール無し `DateFormat`)と判断8 の回帰をここで固定する。

| # | 検証 |
| --- | --- |
| 1 | `ItemView.from` が `2026-09-12` の記録を `'2026年9月12日'` に整形する(**ゼロ埋めしない**) |
| 2 | 1 月 5 日の記録が `'2026年1月5日'` になる(月・日が 1 桁でも 0 が付かない) |
| 3 | `lastDoneAt` が null なら `lastDoneText` が null |
| 4 | 同じ内容の `ItemView` 2 つが `==` で等しい(`DaysAgo` を含むケース) |

### 3.3 `test/ui/item_list_screen_test.dart`(新規)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_row.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';
```

ヘルパ:

```dart
/// フェイクを差し込んだアプリ全体を組む。
///
/// `ItemListScreen` 単体ではなく `App` を包むのは、「**起動後、他の画面を経由せず
/// 一覧が出る**」という受け入れ条件をここで検査するため。
Widget _app(FakeItemRepository repository, Clock clock) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
    clockProvider.overrideWithValue(clock),
  ],
  child: const App(),
);
```

検証する項目:

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | 0 件で起動 | `EmptyState` が出て「まだ項目がありません」と「項目を追加」が見える。`ItemRow` は無い |
| 2 | 0 件で起動 | 空状態が**画面中央**にある(`Center` の子である / `tester.getCenter` の dy が画面の上下中央付近) |
| 3 | 2 件(1 件は記録済み・1 件は未実施)で起動 | 項目名・`4日前`・`2026年9月12日`・`未実施` が見え、**未実施の行に日付が出ていない** |
| 4 | 同上 | 各行に `DoneButton` がある。`tester.getSize(find.byType(DoneButton).first)` の幅・高さが **56 以上** |
| 5 | 同上 | 経過日数の `fontSize` が項目名・最終実施日より**大きく**、`fontWeight` が `FontWeight.bold` |
| 6 | 同上 | `ListView` が `ListView.builder` で作られている(`find.byType(ListView)` の `childrenDelegate` が `SliverChildBuilderDelegate`) |
| 7 | 同上 | `DoneButton` が行内で**項目名より右**にある(`tester.getCenter(...).dx` を比較) |
| 8 | 起動直後 | `MaterialApp` の `home` が `ItemListScreen`(他の画面を経由しない) |

シナリオ 5 の書き方(サイズ比較の具体):

```dart
final elapsed = tester.widget<Text>(find.text('4日前'));
final name = tester.widget<Text>(find.text('美容院'));
final lastDone = tester.widget<Text>(find.text('2026年9月12日'));
expect(elapsed.style?.fontWeight, FontWeight.bold);
expect(elapsed.style?.fontSize, greaterThan(name.style!.fontSize!));
expect(elapsed.style?.fontSize, greaterThan(lastDone.style!.fontSize!));
```

> `pumpWidget` のあと **`await tester.pumpAndSettle()`** を挟む。`watchAll` の初回値は
> マイクロタスク 1 つ分あとに届くので、`pump` 1 回だけだと loading のままになる。

### 3.4 `test/widget_test.dart`(書き換え)

既存の 1 本目は `App` を素の `ProviderScope` で包んでいるため、このチケット以降は
`appDatabaseProvider` が実 DB を開こうとして落ちる。**§3.3 の `_app` と同じ override を入れる。**
2 本目(シード色のテスト)はそのまま残す。1 本目の検査内容は「`MaterialApp` が Material 3 の
light / dark を持つ」に絞り、画面の中身の検査は §3.3 に任せる。

### 3.5 `test/architecture/layer_dependency_test.dart`(書き換え)

既存の 1 本を残したまま、受け入れ条件の 2 本を足す。共通のヘルパで `lib/` 配下の
`.dart` を集める形に整理する。

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// [directory] 配下の Dart ソースを集める。
Iterable<File> _dartFilesIn(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// [directory] 配下のどのファイルにも [banned] が現れないことを検査する。
void _expectNoImports(String directory, List<String> banned) {
  for (final file in _dartFilesIn(directory)) {
    final source = file.readAsStringSync();
    for (final fragment in banned) {
      expect(source, isNot(contains(fragment)), reason: file.path);
    }
  }
}

void main() {
  test('domain は Flutter / Drift / Riverpod に依存しない', () {
    _expectNoImports('lib/domain', const [
      "import 'package:flutter/",
      "import 'package:drift/",
      "import 'package:flutter_riverpod/",
    ]);
  });

  test('ui は data / Drift に依存しない', () {
    // UI が Drift の型や SQL を直接触ると、表示の都合でスキーマが引きずられる
    // (`docs/repository-structure.md`「lib/ui/」)。
    _expectNoImports('lib/ui', const [
      "import 'package:drift/",
      "import 'package:sqlite3/",
      "import 'package:lastwhen/data/",
      "/data/",
    ]);
  });

  test('state は Flutter のウィジェットに依存しない', () {
    // `flutter_riverpod` は許可する。禁止するのは `BuildContext` / `Widget` を
    // 持ち込む `package:flutter/` の直接 import(`docs/architecture.md`「状態管理レイヤー」)。
    _expectNoImports('lib/state', const ["import 'package:flutter/"]);
  });
}
```

> `"/data/"` を禁止文字列に入れているのは、`'../../data/item_repository_impl.dart'` のような
> **相対 import** を捕まえるため。`lib/ui/` に `data` という語を含む正当なパスは無い。

### 3.6 `test/domain/elapsed_days_test.dart`(追記のみ)

`DaysAgo` の等価性を 1 本足す。**既存のテストは触らない。**

```dart
test('DaysAgo は日数が同じなら等しい', () {
  expect(const DaysAgo(42), const DaysAgo(42));
  expect(const DaysAgo(42).hashCode, const DaysAgo(42).hashCode);
  expect(const DaysAgo(42), isNot(const DaysAgo(7)));
});
```

## 4. 検証コマンド

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

`dart format` の出力が正。§2・§3 のコード片と空白・改行位置が違っても、フォーマッタの結果を採る。

## 5. 触らないもの

`pubspec.yaml` / `lib/data/` / `lib/domain/`(§2.9 の `DaysAgo` を除く) / `lib/main.dart` /
`lib/ui/theme/app_theme.dart` / `test/data/` / `test/support/` / `docs/` / `.claude/` /
`.github/` / `android/` / `ios/` / `analysis_options.yaml`。

**`test/support/fake_item_repository.dart` を書き換えない。** 振る舞いが実装とずれると
上位層のテストが「通るのに本番で壊れる」形で嘘をつく(#4 判断11)。フェイクに不足を
見つけたら実装を止めて司令塔に戻すこと。
