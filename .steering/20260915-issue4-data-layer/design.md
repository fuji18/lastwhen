# 設計: データ層(Issue #4)

<!-- status: ready -->

実装者が設計判断を一切せずに実装できる粒度で書く。**ここに書かれたコードをそのまま写してよい**
(型名・引数名・doc コメントを含む)。疑問が出たら実装を止めて司令塔に戻すこと。

## 0. 全体方針

- `lib/data/` は Drift・SQLite へのアクセスと「Drift 行 ↔ ドメインモデル」の変換だけを持つ。
  **`Clock`・経過日数の計算・表示用の文字列整形を書かない**(`docs/architecture.md`「データレイヤー」)
- 保存形式は **UTC のエポックミリ秒(整数)**。変換はこの層の 2 つのヘルパ関数に閉じる
- 例外を握りつぶさない。ただし「**対象なし**」(既に削除された項目への操作)はエラーにせず 0 行更新で通す
  (`docs/glossary.md`「対象なし」)
- **`pubspec.yaml` を触らない。** 追加依存が要ると判断したら実装を止めて司令塔に戻す
- doc コメントは `///` で日本語。**なぜそうするか**を書く(何をするかはコードが語る)

## 1. 設計判断(実装者はこれを蒸し返さない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | 日時の列は `IntColumn`(エポックミリ秒)。Drift の `DateTimeColumn` を**使わない** | Drift の `dateTime()` は既定でエポック**秒**として保存し、ミリ秒が落ちる。`store_date_time_values_as_text` に切り替えると今度は文字列保存になり、受け入れ条件「文字列で保存しない」に反する。整数列 + 明示変換なら、ビルド設定の変更でスキーマが静かに変わることもない |
| 2 | 列名を `.named('...')` で全列に明示する | Drift の既定は Dart 名の snake_case 変換だが、`build.yaml` の設定 1 行でこの規則は変えられる。**出荷後に修正できないスキーマ**を暗黙の変換規則に預けない |
| 3 | テーブルクラスは `Items`、データクラス名は `@DataClassName('ItemRow')` | 既定だとデータクラスが `Item` になり、ドメインの `Item` と衝突する。行は永続化の表現で、ドメインモデルとは別物であることを型名で示す |
| 4 | `name` に `withLength` の CHECK 制約を**付けない**。NOT NULL だけを課す | 長さの検証はドメイン層(`validateItemName`。**コードポイント数**)が持つ。SQLite の `length()` と数え方が一致する保証が無く、**一度出荷した CHECK は修正できない**。受け入れ条件が求めているのは NOT NULL の二重化まで |
| 5 | `sort_order` は `MAX(sort_order) + 1` を**同一トランザクション内**で採番する(空なら 0) | `docs/functional-design.md`「データモデル定義」の既定どおり。採番と INSERT が分かれると同時追加で衝突する |
| 6 | `watchAll` の並びは `sort_order` 昇順 → `id` 昇順 | 判断5 の採番は削除後に番号を再利用しうる(A=0,B=1 で B を削除 → 次も 1)。第 2 キーを固定しておけば、並びが実行ごとに揺れない |
| 7 | 接続を開く処理(`path_provider` / `LazyDatabase`)は `app_database.dart` に置く。ファイルを増やさない | チケットのスコープが `lib/data/database/` に挙げているのはこのファイルだけ。`connection.dart` を別に切るほどの分量が無い |
| 8 | `MigrationStrategy` は `onCreate` のみ。`onUpgrade` も `beforeOpen` も書かない | v1 に上位バージョンからの移行は存在しない。外部キーが無い(MVP は単一テーブル)ので `pragma foreign_keys` も要らない。**P1 で `done_logs` を足すときに両方をここへ追加する** |
| 9 | `AppDatabase` に `forTesting` 名前付きコンストラクタを置く | 統合テストが `NativeDatabase.memory()` を渡すため。本番用の既定コンストラクタは引数を取らない |
| 10 | Riverpod の Provider を**作らない** | `AppDatabase` の生存期間とアプリ起動時の初期化は #5(状態管理層)の担当。ここで先に置くと #5 が捨てる |
| 11 | フェイク(`FakeItemRepository`)に**同じシナリオテストを当てる** | フェイクの振る舞いがずれると、#5 以降の上位層テストが「通るのに本番で壊れる」形で嘘をつく。同じ `group` を実装とフェイクの両方に流して差を出さない |
| 12 | フェイクも**ミリ秒精度に丸めて UTC で保持する** | 実装は epoch ms を往復するのでマイクロ秒が落ちる。丸めないとフェイクだけが元の `DateTime` を返し、判断11 のシナリオ共有が成立しない |

## 2. 実装するファイル

### 2.1 `lib/data/database/app_database.dart`

```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../migrations/migrations.dart';

part 'app_database.g.dart';

/// `items` テーブル。列の定義は `docs/glossary.md`「items テーブル」が正。
///
/// 日時を整数で持つのは、保存形式が **UTC のエポックミリ秒**だから
/// (`docs/architecture.md`「データ永続化戦略」)。`DateTimeColumn` は既定でエポック秒に
/// 落ちるため使わない。
@DataClassName('ItemRow')
class Items extends Table {
  /// UUID v4。採番は `ItemRepositoryImpl` が行う。
  TextColumn get id => text().named('id')();

  /// 項目名。**長さの検証はドメイン層が持つ**ので、ここは NOT NULL だけを課す。
  /// コードポイント数と SQLite の `length()` は数え方が一致せず、
  /// 一度出荷した CHECK 制約は修正できない。
  TextColumn get name => text().named('name')();

  /// 最終実施日時。UTC のエポックミリ秒。**NULL = 未実施。**
  IntColumn get lastDoneAt => integer().named('last_done_at').nullable()();

  /// 登録日時。UTC のエポックミリ秒。
  IntColumn get createdAt => integer().named('created_at')();

  /// 最終更新日時。UTC のエポックミリ秒。取り消しでも前進させる。
  IntColumn get updatedAt => integer().named('updated_at')();

  /// 表示順。`MAX(sort_order) + 1` で採番する。MVP では常に登録順と一致する。
  IntColumn get sortOrder => integer().named('sort_order')();

  @override
  String get tableName => 'items';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// アプリのローカル DB。MVP のテーブルは `items` 1 枚だけ。
@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  /// 端末のドキュメント領域のファイルを開く。
  AppDatabase() : super(_openConnection());

  /// テスト用。`NativeDatabase.memory()` を渡して実ファイルを触らずに使う。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => buildMigrationStrategy();
}

/// `<アプリのドキュメント領域>/lastwhen.sqlite` を開く。
///
/// **OS の自動バックアップ(iCloud / Auto Backup)から除外しない。** MVP に
/// エクスポート機能が無い以上、これが唯一の機種変更時の移行手段になる
/// (`docs/architecture.md`「バックアップ戦略」)。
QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}lastwhen.sqlite',
    );

    // Android では sqlite3 が既定で使う一時ディレクトリに書けない。
    // 明示しないと大きめのクエリで失敗する。
    final temporary = await getTemporaryDirectory();
    sqlite3.tempDirectory = temporary.path;

    return NativeDatabase.createInBackground(file);
  });
}
```

`package:path` は直接依存に無いので **`p.join` を使わない**(`depend_on_referenced_packages`)。
対応 OS は iOS / Android だけなので `Platform.pathSeparator` の連結で足りる。

### 2.2 `lib/data/migrations/migrations.dart`

```dart
import 'package:drift/drift.dart';

/// スキーマ移行の定義。現在は v1 の初期作成のみ。
///
/// 原則(`docs/architecture.md`「マイグレーション戦略」):
///
/// - **前進のみ。** ダウングレードは実装しない
/// - **破壊的変更を避ける。** 列の削除・リネームではなく、追加と非使用化で進める
/// - **失敗時にテーブルを作り直さない。** 起動を中断してエラーを出す
///
/// v2 を足すときは `onUpgrade` をここに追加する。**`m.createAll()` による
/// 作り直しを書かない**(ユーザーの記録が全損する)。
MigrationStrategy buildMigrationStrategy() {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
  );
}
```

### 2.3 `lib/data/item_repository_impl.dart`

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/item.dart';
import '../domain/item_repository.dart';
import 'database/app_database.dart';

/// [ItemRepository] の Drift 実装。
///
/// **この層は `Clock` を持たない**(`docs/architecture.md`「データレイヤー」)。
/// 書き込み時刻はすべて呼び出し元から引数で受け取る。
final class ItemRepositoryImpl implements ItemRepository {
  /// [db] の `items` テーブルを読み書きする。
  ItemRepositoryImpl(this._db);

  final AppDatabase _db;

  static const Uuid _uuid = Uuid();

  @override
  Stream<List<Item>> watchAll() {
    final query = _db.select(_db.items)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        // sort_order は削除後に番号を再利用しうる。第 2 キーを固定して
        // 並びが実行ごとに揺れないようにする。
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toDomain).toList(growable: false),
    );
  }

  @override
  Future<Item> add(String name, {required DateTime now}) {
    final timestamp = _toEpochMillis(now);
    // 採番と INSERT を同じトランザクションに入れる。分けると同時追加で
    // sort_order が衝突する。
    return _db.transaction(() async {
      final maximum = _db.items.sortOrder.max();
      final aggregate = await (_db.selectOnly(_db.items)
            ..addColumns([maximum]))
          .getSingle();
      final currentMax = aggregate.read(maximum);

      final row = ItemRow(
        id: _uuid.v4(),
        name: name,
        lastDoneAt: null,
        createdAt: timestamp,
        updatedAt: timestamp,
        sortOrder: currentMax == null ? 0 : currentMax + 1,
      );
      await _db.into(_db.items).insert(row);
      return _toDomain(row);
    });
  }

  @override
  Future<void> rename(ItemId id, String name, {required DateTime now}) async {
    // last_done_at を companion に載せない = 変更しない。
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(
        name: Value(name),
        updatedAt: Value(_toEpochMillis(now)),
      ),
    );
  }

  @override
  Future<void> delete(ItemId id) async {
    await (_db.delete(_db.items)..where((t) => t.id.equals(id.value))).go();
  }

  @override
  Future<void> markDone(ItemId id, DateTime doneAt) async {
    final timestamp = _toEpochMillis(doneAt);
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(
        lastDoneAt: Value(timestamp),
        updatedAt: Value(timestamp),
      ),
    );
  }

  @override
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  }) async {
    await (_db.update(_db.items)..where((t) => t.id.equals(id.value))).write(
      ItemsCompanion(
        // previous が null なら未実施へ戻す。Value(null) が NULL を書く。
        lastDoneAt: Value(previous == null ? null : _toEpochMillis(previous)),
        // 取り消しも書き込みなので updated_at は前進させる(巻き戻さない)。
        updatedAt: Value(_toEpochMillis(now)),
      ),
    );
  }
}

/// ドメインの日時を保存形式(UTC のエポックミリ秒)へ変換する。
int _toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

/// 保存形式をドメインの日時(UTC)へ戻す。
DateTime _toUtc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

/// Drift の行をドメインモデルへ変換する。
Item _toDomain(ItemRow row) {
  final lastDoneAt = row.lastDoneAt;
  return Item(
    id: ItemId(row.id),
    name: row.name,
    lastDoneAt: lastDoneAt == null ? null : _toUtc(lastDoneAt),
    createdAt: _toUtc(row.createdAt),
    updatedAt: _toUtc(row.updatedAt),
    sortOrder: row.sortOrder,
  );
}
```

**「対象なし」の扱い**: `rename` / `delete` / `markDone` / `restoreLastDoneAt` は
対象が無ければ 0 行更新で静かに終わる。例外にしない(`docs/glossary.md`「対象なし」)。

### 2.4 `test/support/fake_item_repository.dart`

```dart
import 'dart:async';

import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_repository.dart';

/// メモリ上の [ItemRepository]。#5 以降の上位層テストで Drift を起動しないために置く。
///
/// **`ItemRepositoryImpl` と同じ振る舞いを保つこと。** ずれると上位層のテストが
/// 「通るのに本番で壊れる」形で嘘をつく。同じシナリオを両方に当てるテストが
/// `test/data/item_repository_impl_test.dart` にある。
final class FakeItemRepository implements ItemRepository {
  final List<Item> _items = <Item>[];
  final StreamController<List<Item>> _controller =
      StreamController<List<Item>>.broadcast();

  int _idSequence = 0;

  @override
  Stream<List<Item>> watchAll() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  @override
  Future<Item> add(String name, {required DateTime now}) async {
    final timestamp = _normalize(now);
    // 実装と同じ MAX + 1 採番にする(空なら 0)。
    final sortOrder =
        _items.fold<int>(-1, (max, e) => e.sortOrder > max ? e.sortOrder : max) +
            1;
    final item = Item(
      id: ItemId('fake-item-${_idSequence++}'),
      name: name,
      lastDoneAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      sortOrder: sortOrder,
    );
    _items.add(item);
    _emit();
    return item;
  }

  @override
  Future<void> rename(ItemId id, String name, {required DateTime now}) async {
    _update(id, (item) => _copy(item, name: name, updatedAt: _normalize(now)));
  }

  @override
  Future<void> delete(ItemId id) async {
    _items.removeWhere((item) => item.id == id);
    _emit();
  }

  @override
  Future<void> markDone(ItemId id, DateTime doneAt) async {
    final timestamp = _normalize(doneAt);
    _update(
      id,
      (item) => _copy(item, lastDoneAt: timestamp, updatedAt: timestamp),
    );
  }

  @override
  Future<void> restoreLastDoneAt(
    ItemId id,
    DateTime? previous, {
    required DateTime now,
  }) async {
    _update(
      id,
      (item) => _copy(
        item,
        lastDoneAt: previous == null ? null : _normalize(previous),
        updatedAt: _normalize(now),
      ),
    );
  }

  /// 購読を終了する。テストの `addTearDown` で呼ぶ。
  Future<void> dispose() => _controller.close();

  /// 対象が無ければ何もしない(実装の「対象なし」と揃える)。
  void _update(ItemId id, Item Function(Item) transform) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    _items[index] = transform(_items[index]);
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot());
    }
  }

  List<Item> _snapshot() {
    final sorted = [..._items]..sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.id.value.compareTo(b.id.value);
    });
    return List<Item>.unmodifiable(sorted);
  }

  /// 実装は epoch ミリ秒を往復するのでマイクロ秒が落ちる。同じ精度に丸める。
  DateTime _normalize(DateTime value) => DateTime.fromMillisecondsSinceEpoch(
    value.toUtc().millisecondsSinceEpoch,
    isUtc: true,
  );

  /// `Item` に `copyWith` を作らない方針(#3 判断7)なので、ここで組み直す。
  /// `lastDoneAt` は null 自体が意味を持つため、名前付き引数で置き換えない。
  Item _copy(
    Item source, {
    String? name,
    Object? lastDoneAt = _unset,
    DateTime? updatedAt,
  }) {
    return Item(
      id: source.id,
      name: name ?? source.name,
      lastDoneAt: identical(lastDoneAt, _unset)
          ? source.lastDoneAt
          : lastDoneAt as DateTime?,
      createdAt: source.createdAt,
      updatedAt: updatedAt ?? source.updatedAt,
      sortOrder: source.sortOrder,
    );
  }
}

/// 「引数が渡されなかった」を `null` と区別するための番兵。
const Object _unset = Object();
```

### 2.5 `test/data/item_repository_impl_test.dart`

`group` の構成は次のとおり。**共有シナリオは実装とフェイクの両方に流す**(判断11)。

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/data/database/app_database.dart';
import 'package:lastwhen/data/item_repository_impl.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_repository.dart';

import '../support/fake_item_repository.dart';

/// テストで使う固定時刻。データ層は `Clock` を持たないので呼び出し側が時刻を決める。
final DateTime t0 = DateTime.utc(2026, 9, 15, 1, 0);
final DateTime t1 = DateTime.utc(2026, 9, 15, 2, 0);
final DateTime t2 = DateTime.utc(2026, 9, 16, 3, 0);

void main() {
  _runSharedScenarios('ItemRepositoryImpl', _createRealRepository);
  _runSharedScenarios('FakeItemRepository', _createFakeRepository);

  group('ItemRepositoryImpl(永続化の詳細)', () {
    // ここは AppDatabase を直接持つ(生の SQL で保存形式を確認するため)
  });
}

AppDatabase _createDatabase() {
  final db = AppDatabase.forTesting(
    DatabaseConnection(
      NativeDatabase.memory(),
      // ウィジェットテストでのエラーを避けるための推奨設定。
      closeStreamsSynchronously: true,
    ),
  );
  addTearDown(db.close);
  return db;
}

ItemRepository _createRealRepository() => ItemRepositoryImpl(_createDatabase());

ItemRepository _createFakeRepository() {
  final repository = FakeItemRepository();
  addTearDown(repository.dispose);
  return repository;
}
```

#### 共有シナリオ(`_runSharedScenarios(String label, ItemRepository Function() create)`)

`group(label, ...)` の中で `late ItemRepository repository;` を `setUp(() => repository = create());` で作る。
一覧の取得は `await repository.watchAll().first`。

| # | テスト名 | 確認内容 |
| --- | --- | --- |
| 1 | `追加すると未実施の項目が登録順に並ぶ` | 3 件追加 → `name` が投入順 / 全件 `lastDoneAt == null` / `sortOrder` が `0,1,2` / `createdAt == updatedAt == t0` |
| 2 | `記録すると最終実施日が更新される` | 追加(t0) → `markDone(id, t1)` → `lastDoneAt == t1` かつ `updatedAt == t1` |
| 3 | `未実施の項目を記録して取り消すと未実施に戻る` | 追加 → `markDone(id, t1)` → `restoreLastDoneAt(id, null, now: t2)` → `lastDoneAt == null` かつ `updatedAt == t2`(**前進する。巻き戻さない**) |
| 4 | `記録済みの項目を取り消すと直前の値に戻る` | `markDone(t1)` → `markDone(t2)` → `restoreLastDoneAt(id, t1, now: t2)` → `lastDoneAt == t1` |
| 5 | `名称変更では名前だけが変わる` | 追加(t0) → `markDone(t1)` → `rename(id, '新しい名前', now: t2)` → `name` が変わり、**`lastDoneAt == t1` / `createdAt == t0` / `sortOrder` が不変**、`updatedAt == t2` |
| 6 | `削除しても他の項目に影響しない` | 3 件追加 → 真ん中を削除 → 残り 2 件の `id` / `name` / `sortOrder` が不変 |
| 7 | `100 件を投入して一覧を取得できる` | 100 件追加 → `length == 100` / `sortOrder` が `0..99` の昇順 / 先頭と末尾の `name` が一致 |
| 8 | `存在しない項目への操作は例外にならない` | 未登録の `ItemId('missing')` に `rename` / `markDone` / `restoreLastDoneAt` / `delete` を実行しても投げず、一覧が空のまま(`docs/glossary.md`「対象なし」) |

#### 実装だけの group(`ItemRepositoryImpl(永続化の詳細)`)

| # | テスト名 | 確認内容 |
| --- | --- | --- |
| 9 | `日時は整数で保存される` | 追加 → `markDone` → `db.customSelect("SELECT typeof(last_done_at) AS l, typeof(created_at) AS c, typeof(updated_at) AS u FROM items").getSingle()` の 3 列がすべて `'integer'`。**`'text'` なら失敗**(受け入れ条件「文字列で保存しない」の機械的検証) |
| 10 | `未実施は NULL で保存される` | 追加直後に `SELECT typeof(last_done_at) ...` が `'null'` |
| 11 | `保存値は UTC のエポックミリ秒そのもの` | `markDone(id, t1)` 後に `SELECT last_done_at` の生値が `t1.millisecondsSinceEpoch` と一致 |
| 12 | `name に NOT NULL 制約がある` | `db.customStatement("INSERT INTO items (id, name, created_at, updated_at, sort_order) VALUES ('x', NULL, 0, 0, 0)")` が `throwsA(isA<Exception>())` |
| 13 | `watchAll は書き込みのたびに再送出される` | `expectLater(repository.watchAll(), emitsInOrder([isEmpty, hasLength(1), hasLength(2)]))` を**先に**仕掛けてから `add` を 2 回実行する |
| 14 | `schemaVersion は 1` | `db.schemaVersion == 1`(スキーマを変えたら必ずここが落ちる = マイグレーションを書き忘れない) |

この group では `_createDatabase()` で `AppDatabase` を作り、`ItemRepositoryImpl(db)` を自分で組む
(生の SQL を撃つために `db` への参照が要る)。

## 3. 生成コード

```bash
dart run build_runner build --delete-conflicting-outputs
```

- 出力は `lib/data/database/app_database.g.dart`。**コミットする**(`docs/architecture.md`「生成コードの扱い」)
- `analysis_options.yaml` が `**/*.g.dart` を除外済みなので lint の対象外
- 生成物を手で編集しない。直したいときは元の `Items` / `AppDatabase` を直して再生成する

## 4. 検証コマンド

```bash
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze --fatal-infos
flutter test
```

`dart format` の出力が正。§2 のコード片と空白・改行位置が違っても、フォーマッタの結果を採る。

## 5. 触らないもの

`pubspec.yaml` / `lib/main.dart` / `lib/app.dart` / `lib/ui/` / `lib/state/` /
`docs/` / `.github/` / `android/` / `ios/` / `analysis_options.yaml`。

`lib/data/.gitkeep` だけは削除する(実ファイルが入るため)。
