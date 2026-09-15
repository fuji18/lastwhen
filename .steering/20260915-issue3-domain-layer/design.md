# 設計: ドメイン層(Issue #3)

<!-- status: ready -->

実装者が設計判断を一切せずに実装できる粒度で書く。**ここに書かれたコードをそのまま写してよい**
(型名・引数名・doc コメントを含む)。疑問が出たら実装を止めて司令塔に戻すこと。

## 0. 全体方針

- `lib/domain/` は**純 Dart**。`dart:core` 以外の import は `dart:*` も含めて書かない
  (各ファイルは他の domain ファイルを相対 import するのみ)
- 例外を投げない。検証は結果型、経過日数は非負の丸めで閉じる
- 用語は `docs/glossary.md` に従う(項目 / 記録する / 最終実施日 / 経過日数 / 未実施)
- doc コメントは `///` で日本語。**なぜそうするか**を書く(何をするかはコードが語る)

## 1. 設計判断(実装者はこれを蒸し返さない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | `elapsedDays` は `calendarDateOf`(暦日を `DateTime.utc` の点として取り直す公開ヘルパ)を経由する | 夏時間の regression をテストで固定できるようにするため(判断5)。`docs/functional-design.md`「ステップ2」の内容を関数として切り出しただけで、アルゴリズムは変えない |
| 2 | `null` 判定は `elapsedDays` の外の `elapsedLabel` 関数が行う | `docs/functional-design.md`「負数の丸めは `elapsedDays` の責務」の注記どおり、`elapsedDays` は non-null 2 引数だけを知る。一方 Issue #3 の受け入れ条件は「`lastDoneAt` が null のとき `NeverDone`」をこのチケットで検証することを求めるため、**純関数 `elapsedLabel` をドメインに置き、#5 の `ItemListNotifier` はこれを呼ぶだけにする**。判定ロジックを Notifier に手書きしない |
| 3 | 項目名の文字数は `runes.length`(コードポイント数)で数える | 絵文字・サロゲートペアを 2 文字と数えないため。`package:characters` は pubspec に直接依存が無く `depend_on_referenced_packages` に触れるので使わない |
| 4 | `SystemClock.now()` は **UTC** を返す(`DateTime.now().toUtc()`) | 保存は UTC(`docs/architecture.md`)。アプリ内を流れる時刻を UTC に統一し、ローカル変換を `elapsedDays` と UI の 1 箇所に閉じる |
| 5 | 夏時間の受け入れ条件は「`calendarDateOf` が UTC の点を返すこと」のテストで担保する | 実行環境(devcontainer / CI = UTC、開発者の端末 = JST)はいずれも夏時間を持たないため、DST をまたぐ入力を与えても**バグのある実装も同じ値を返し、テストが嘘になる**。`calendarDateOf` の戻り値が `isUtc == true` であることを検証すれば、ローカルの `DateTime` に戻す改変を**どの環境でも**落とせる。加えて DST 切替日の日付を使った暦日ケースも表に載せ、意図を残す |
| 6 | テスト内で `DateTime.now()` を呼んでよいのは `SystemClock` 自体のテストだけ | `SystemClock` は `DateTime.now()` の薄いラッパーで、それ以外に検証手段が無い。他のテストは必ず `FakeClock` か固定の `DateTime` リテラルを使う |
| 7 | `Item` に `==` / `hashCode` を実装する。`copyWith` は作らない | #4 / #5 のテストで値比較が要る。`copyWith` は使う場所が決まってから足す(YAGNI) |
| 8 | `ItemRepository` はインターフェースのみ。実装は #4 | 依存性逆転(`docs/architecture.md`「依存の向き」) |

## 2. 実装するファイル

### 2.1 `lib/domain/item.dart`

```dart
/// 項目 ID。素の String と取り違えないための型。
///
/// `rename(name, id)` のような引数の取り違えがコンパイルエラーになる。
extension type const ItemId(String value) {}

/// 管理する生活行動 1 件。
final class Item {
  const Item({
    required this.id,
    required this.name,
    required this.lastDoneAt,
    required this.createdAt,
    required this.updatedAt,
    required this.sortOrder,
  });

  final ItemId id;

  /// 前後の空白を除いた 1〜50 文字。検証は `validateItemName` が行う。
  final String name;

  /// 最終実施日時(UTC)。**null は一度も記録がないこと(未実施)を表す。**
  final DateTime? lastDoneAt;

  /// 登録日時(UTC)。
  final DateTime createdAt;

  /// 最後に書き込みが起きた日時(UTC)。記録の取り消しでも前進させる。
  final DateTime updatedAt;

  /// 表示順。MVP では常に登録順と一致する。
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.id == id &&
      other.name == name &&
      other.lastDoneAt == lastDoneAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, name, lastDoneAt, createdAt, updatedAt, sortOrder);
}
```

### 2.2 `lib/domain/item_name.dart`

```dart
/// 項目名の最大文字数(前後の空白を除いたコードポイント数)。
const int maxItemNameLength = 50;

/// 項目名の検証結果。
///
/// **例外を投げない。** 呼び出し元が理由を見て入力欄に表示する
/// (`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class ItemNameResult {
  const ItemNameResult();
}

/// 検証を通った項目名。[value] は前後の空白を除いた文字列。
final class ValidItemName extends ItemNameResult {
  const ValidItemName(this.value);

  final String value;
}

/// 検証を通らなかった項目名。
final class InvalidItemName extends ItemNameResult {
  const InvalidItemName(this.reason);

  final ItemNameReason reason;
}

/// 検証に落ちた理由。UI 文言の組み立ては UI 層の責務。
enum ItemNameReason {
  /// 空文字、または空白のみ。
  empty,

  /// 前後の空白を除いて [maxItemNameLength] を超えた。
  tooLong,
}

/// 項目名を検証する。
///
/// 絵文字などのサロゲートペアを 2 文字と数えないため、長さはコードポイント数で測る。
ItemNameResult validateItemName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const InvalidItemName(ItemNameReason.empty);
  }
  if (trimmed.runes.length > maxItemNameLength) {
    return const InvalidItemName(ItemNameReason.tooLong);
  }
  return ValidItemName(trimmed);
}
```

### 2.3 `lib/domain/clock.dart`

```dart
/// 現在時刻を返す唯一の口。
///
/// 経過日数はこのプロダクトの中心機能で、境界(日またぎ・月末・うるう年・夏時間)の
/// 検証が要る。`DateTime.now()` を直に呼ぶとテストが書けない。
abstract interface class Clock {
  /// 現在時刻(UTC)。
  DateTime now();
}

/// 端末の時計を使う [Clock]。
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
```

### 2.4 `lib/domain/elapsed_days.dart`

```dart
/// ローカル時刻の暦日を、UTC 上の点として取り直す。
///
/// ローカルの DateTime 同士で `difference()` を取ると実時間差になる。夏時間のある地域では
/// 1 日が 23/25 時間になるため、**深夜 0 時に正規化しても `inDays` が 1 日ずれる**。
/// UTC の点として持ち直せば 1 日が常に 24 時間になり、差分が暦日数と一致する。
DateTime calendarDateOf(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// 最終実施日から [now] までの**暦日の差**を返す。
///
/// 24 時間単位の経過時間ではない。端末時計が巻き戻った場合に備え、負数は 0 に丸める。
int elapsedDays({required DateTime lastDoneAt, required DateTime now}) {
  final lastDate = calendarDateOf(lastDoneAt.toLocal());
  final todayDate = calendarDateOf(now.toLocal());
  final difference = todayDate.difference(lastDate).inDays;
  return difference < 0 ? 0 : difference;
}

/// 経過日数の表示ラベル。文字列の組み立ては UI 層の責務。
sealed class ElapsedLabel {
  const ElapsedLabel();
}

/// 未実施(一度も記録がない)。**「0日前」と表示しない。**
final class NeverDone extends ElapsedLabel {
  const NeverDone();
}

/// 今日。
final class Today extends ElapsedLabel {
  const Today();
}

/// 昨日。
final class Yesterday extends ElapsedLabel {
  const Yesterday();
}

/// 2 日以上前。
final class DaysAgo extends ElapsedLabel {
  const DaysAgo(this.days);

  /// 2 以上の暦日数。
  final int days;
}

/// 最終実施日を表示ラベルへ分類する。
///
/// [lastDoneAt] が null(= 一度も記録がない)なら [NeverDone]。
ElapsedLabel elapsedLabel({
  required DateTime? lastDoneAt,
  required DateTime now,
}) {
  if (lastDoneAt == null) {
    return const NeverDone();
  }
  final days = elapsedDays(lastDoneAt: lastDoneAt, now: now);
  return switch (days) {
    0 => const Today(),
    1 => const Yesterday(),
    _ => DaysAgo(days),
  };
}
```

### 2.5 `lib/domain/item_repository.dart`

`docs/functional-design.md`「ItemRepository」のインターフェースをそのまま置く。**実装は書かない。**

```dart
import 'item.dart';

/// 項目の永続化。実装はデータレイヤー(#4)に置く。
///
/// **すべての書き込みが `now` を引数で受け取る。** データレイヤーは [Clock] に依存できない
/// ため(`docs/architecture.md`「データレイヤー」)、時刻の出どころを呼び出し元に一本化する。
abstract interface class ItemRepository {
  /// 表示順に並んだ全項目を流す。DB の変更で自動的に再送出される。
  Stream<List<Item>> watchAll();

  /// 項目を追加する。id は UUID v4 で実装側が採番する。
  Future<Item> add(String name, {required DateTime now});

  /// 項目名を変更する。
  Future<void> rename(ItemId id, String name, {required DateTime now});

  /// 項目を削除する。
  Future<void> delete(ItemId id);

  /// 最終実施日時を記録する。`updatedAt` も [doneAt] と同じ値になる。
  Future<void> markDone(ItemId id, DateTime doneAt);

  /// [markDone] の取り消し。最終実施日時を直前の値([previous])に戻す。
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  });
}
```

> `Clock` を doc コメントで参照するだけのために import しない(未使用 import になる)。
> `[Clock]` のリンクが解決しない旨を analyzer が指摘した場合は、`` `Clock` `` に書き換える。

### 2.6 `test/support/fake_clock.dart`

```dart
import 'package:lastwhen/domain/clock.dart';

/// 任意の時刻を返す [Clock]。
///
/// テスト内で `DateTime.now()` を呼ぶと、実行した瞬間によって結果が変わるテストになる。
final class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// 返す時刻を差し替える。
  void advanceTo(DateTime value) => _now = value;
}
```

## 3. テスト

グループ名は「何の話か」、テスト名は「条件 → 期待」を日本語の 1 文で
(`docs/development-guidelines.md`「テスト命名規則」)。

### 3.1 `test/domain/elapsed_days_test.dart`

`group('経過日数の算出', ...)`。すべて UTC リテラル(`DateTime.utc(...)`)で与える。
**実行環境のタイムゾーンによらず成立させるため、`lastDoneAt` と `now` は同じ日の同じ時刻帯で
差だけを与える**(例: どちらも `DateTime.utc(2026, 1, 10, 3, 0)` 基準)。

| テスト名 | 入力(UTC) | 期待 |
| --- | --- | --- |
| 同じ日に記録して同じ日に表示すると 0 日 | last = now = 2026-01-10 03:00 | `0` |
| 日付をまたぐと 24 時間未満でも 1 日 | last = 2026-01-10 23:00 / now = 2026-01-11 02:00 | `1` |
| 同じ日の 23:59 は 0 日 | last = now = 2026-01-10 23:59 | `0` |
| 月をまたぐと暦日で数える | last = 2026-01-31 06:00 / now = 2026-02-01 06:00 | `1` |
| うるう年の 2月28日から 3月1日は 2 日 | last = 2024-02-28 06:00 / now = 2024-03-01 06:00 | `2` |
| 年をまたぐと暦日で数える | last = 2025-12-31 06:00 / now = 2026-01-01 06:00 | `1` |
| 夏時間の切替日をまたいでも暦日どおり | last = 2026-03-08 06:00 / now = 2026-03-09 06:00 | `1` |
| 端末時計が巻き戻っても負数を返さない | last = 2026-01-10 06:00 / now = 2026-01-05 06:00 | `0` |
| 離れた日付は日数をそのまま返す | last = 2026-01-01 06:00 / now = 2026-02-12 06:00 | `42` |

> **`DateTime.utc(..., 3, 0)` などの時刻を選ぶ理由**: 実行環境が UTC でも JST(+9)でも
> ローカル変換後の暦日が同じ日になる時刻帯を使い、テストを環境非依存にする。
> **00:00 前後や 15:00 以降の時刻を使わないこと**(JST で日付が動く)。

`group('暦日の取り直し', ...)`(判断5 の回帰テスト):

| テスト名 | 期待 |
| --- | --- |
| 暦日は UTC の点として返る | `calendarDateOf(DateTime(2026, 3, 8, 23, 30)).isUtc` が `true` |
| 時刻成分は落ちる | `calendarDateOf(DateTime(2026, 3, 8, 23, 30))` が `DateTime.utc(2026, 3, 8)` と等しい |

`group('経過日数のラベル分類', ...)`:

| テスト名 | 期待 |
| --- | --- |
| 最終実施日が null なら未実施 | `isA<NeverDone>()` |
| 0 日なら今日 | `isA<Today>()` |
| 1 日なら昨日 | `isA<Yesterday>()` |
| 2 日なら 2日前 | `isA<DaysAgo>()` かつ `days == 2` |
| 42 日なら 42日前 | `days == 42` |
| 端末時計が巻き戻っていても今日になる | `isA<Today>()` |

### 3.2 `test/domain/item_name_test.dart`

`group('項目名の検証', ...)`:

| テスト名 | 入力 | 期待 |
| --- | --- | --- |
| 空文字は通らない | `''` | `InvalidItemName` / `ItemNameReason.empty` |
| 空白のみは通らない | `'   '`(全角空白 `'　'` も別テストで) | `empty` |
| 前後の空白は除去される | `'  歯ブラシ交換  '` | `ValidItemName('歯ブラシ交換')` |
| 1 文字は通る | `'A'` | `ValidItemName('A')` |
| 50 文字は通る | `'あ' * 50` | `ValidItemName` |
| 51 文字は通らない | `'あ' * 51` | `tooLong` |
| 空白を除いて 50 文字なら通る | `' ' + 'あ' * 50 + ' '` | `ValidItemName`(`value.runes.length == 50`) |
| 絵文字は 1 文字として数える | `'🙂' * 50` | `ValidItemName` |

> `'あ' * 50` は Dart では `'あ' * 50` と書ける(String の `*` 演算子)。

### 3.3 `test/domain/clock_test.dart`

| テスト名 | 期待 |
| --- | --- |
| SystemClock は UTC の現在時刻を返す | `isUtc` が `true`、かつ呼び出し前後の `DateTime.now().toUtc()` の間にある(判断6 の唯一の例外) |
| FakeClock は与えた時刻を返し続ける | 2 回呼んでも同じ値 |
| FakeClock は時刻を差し替えられる | `advanceTo` 後に新しい値を返す |

### 3.4 `test/domain/item_test.dart`

| テスト名 | 期待 |
| --- | --- |
| 同じ値の項目は等しい | `==` が `true`、`hashCode` が一致 |
| 最終実施日が違えば等しくない | `==` が `false` |
| 名前が違えば等しくない | `==` が `false` |
| 未実施の項目は最終実施日が null | `item.lastDoneAt` が `null` |
| ItemId は同じ文字列なら等しい | `ItemId('a') == ItemId('a')` |

> `==` の各分岐(id / name / lastDoneAt / createdAt / updatedAt / sortOrder)を
> **1 つずつ変えたケースで潰す**。カバレッジ 100% の要件は分岐まで見る。

### 3.5 `test/architecture/layer_dependency_test.dart`

`docs/development-guidelines.md`「レイヤー依存の検査」のコードをそのまま置く
(**追加依存は使わない**。`dart:io` の `Directory` / `File` を使う)。
`lib/ui/` → `lib/data/` の検査は対象コードがまだ無いので**このチケットでは書かない**。

```dart
test('domain は Flutter / Drift / Riverpod に依存しない', () { ... });
```

## 4. 検証手順(実装者が自分で回す)

```bash
dart format .
flutter analyze --fatal-infos
flutter test
```

カバレッジ 100% の確認:

```bash
flutter test --coverage
awk -F'[:,]' '/^SF:/{file=$2} /^DA:/ && $3=="0" && file ~ /^lib\/domain\// {print file" line "$2}' coverage/lcov.info
```

**1 行でも出力されたら未達**。出力が空であることを確認する(`coverage/` は成果物に含めない。
`.gitignore` に無ければ追記する)。

## 5. 完了の定義

- 上記 3 コマンドがすべて通る
- カバレッジ確認コマンドの出力が空
- `lib/domain/.gitkeep` を削除した(実ファイルが入ったため)
- requirements.md の受け入れ条件がすべて埋まっている
