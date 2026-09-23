# 設計: 実施履歴の保持と基準間隔の学習(Issue #20)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> `pubspec.yaml` に依存を足す必要が出たときも同じ(**このチケットで依存は増えない**。
> `drift_dev` は導入済み)。
> **UI(`lib/ui/`)は一切変更しない。** 表示は #21 / #22 の担当。
> **このチケットは委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れる。Codex に委託しない。**

## 0. 全体方針

```
「やった」 → ItemRepository.markDone(id, doneAt)
              └ transaction { UPDATE items.last_done_at ; INSERT done_logs }
取り消し   → ItemRepository.restoreLastDoneAt(id, previous, now)
              └ transaction { DELETE done_logs の直近 1 行 ; UPDATE items.last_done_at }
一覧       → watchAll(): items を watch → 発火ごとに done_logs を 1 本のクエリで項目ごと直近 10 件取得
              → Item.recentDoneAts に詰める
表示モデル → ItemView.from(item, now): recentDoneAts から 前回間隔 / 基準間隔 / 相対経過度 を算出
```

- **`items.last_done_at` は「最新ログのキャッシュ」**として残す(列は消さない)。書き込みは必ず `done_logs` と同一トランザクション
- 算出はドメインの純関数(`lib/domain/baseline_interval.dart`)。`Clock` を要する相対経過度の計算は状態管理層の `ItemView.from` で行う
- マイグレーションは Drift の **`make-migrations`(スキーマのスナップショット + step-by-step + 生成テスト)** で行う。手書きの `if (from < 2)` 分岐にしない

## 判断1: マイグレーションの手順(`make-migrations`)

**順序を守ること。v1 のスナップショットは、スキーマを変える前のコードから取る必要がある。**

1. リポジトリ直下に `build.yaml` を新規作成する:

   ```yaml
   targets:
     $default:
       builders:
         drift_dev:
           options:
             databases:
               app_database: lib/data/database/app_database.dart
             schema_dir: drift_schemas/
             test_dir: test/data/drift/
   ```

2. **スキーマを変える前に** `dart run drift_dev make-migrations` を実行する。`drift_schemas/app_database/drift_schema_v1.json` ができることを確認する(できなければ停止して報告)
3. 判断2 のとおりスキーマを変更し、`schemaVersion` を 2 にする
4. `dart run build_runner build --delete-conflicting-outputs` → `dart run drift_dev make-migrations` を実行する。
   `drift_schema_v2.json`、`lib/data/database/app_database.steps.dart`、`test/data/drift/app_database/` 配下の生成物ができる
5. 生成物はすべてコミット対象(`drift_schemas/` を含む)。**生成された JSON・`*.steps.dart`・`test/data/drift/app_database/generated/` を手で編集しない**
6. 生成物が `flutter analyze --fatal-infos` や `dart format --set-exit-if-changed` に引っかかる場合は、`analysis_options.yaml` の `analyzer.exclude` に `"**/*.steps.dart"` と `"test/data/drift/app_database/generated/**"` を足し、format は生成物に `dart format` をかけて整える(生成物の中身の意味は変えない)

## 判断2: `done_logs` テーブル(`lib/data/database/app_database.dart`)

```dart
/// `done_logs` テーブル。「やった」1 回につき 1 行。定義は `docs/glossary.md`「done_logs テーブル」が正。
@DataClassName('DoneLogRow')
@TableIndex(name: 'done_logs_item_id_done_at', columns: {#itemId, #doneAt})
class DoneLogs extends Table {
  /// UUID v4。採番は `ItemRepositoryImpl`(移送分はマイグレーション)が行う。
  TextColumn get id => text().named('id')();

  /// 対象の項目。項目の削除で行ごと消える(ON DELETE CASCADE)。
  TextColumn get itemId => text()
      .named('item_id')
      .references(Items, #id, onDelete: KeyAction.cascade)();

  /// 実施日時。UTC のエポックミリ秒(items.last_done_at と同じ形式)。
  IntColumn get doneAt => integer().named('done_at')();

  @override
  String get tableName => 'done_logs';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

- `@DriftDatabase(tables: [Items, DoneLogs])`、`schemaVersion => 2`
- クラスのドキュメントコメント「MVP のテーブルは `items` 1 枚だけ」を「`items` と `done_logs`(v2 で追加)」に直す
- **外部キーを有効にする。** `MigrationStrategy` に `beforeOpen: (details) async { await db.customStatement('PRAGMA foreign_keys = ON'); }` を足す(判断3 参照)。SQLite は既定で外部キーを無視するため、これが無いと CASCADE が効かない

## 判断3: マイグレーション定義(`lib/data/migrations/migrations.dart`)

`buildMigrationStrategy()` のシグネチャを `MigrationStrategy buildMigrationStrategy(GeneratedDatabase db)` に変え、`AppDatabase.migration` から `buildMigrationStrategy(this)` で呼ぶ。

```dart
MigrationStrategy buildMigrationStrategy(GeneratedDatabase db) {
  return MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.doneLogs);
        await m.createIndex(schema.doneLogsItemIdDoneAt); // 生成された名前に合わせる
        await _moveLastDoneAtToDoneLogs(m.database);
      },
    ),
    beforeOpen: (details) async {
      await db.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
```

- `stepByStep` は `app_database.steps.dart` が生成する関数。import する
- 生成された `schema.doneLogs` / インデックスのゲッター名が上と違えば、**生成物の名前に合わせる**(これは設計判断ではない)
- **既存データの移送 `_moveLastDoneAtToDoneLogs`** はこのファイル内の private 関数。**v1 時点の列名を生の SQL で固定して書く**(将来 `Items` の Dart 定義が変わっても、この移行の意味が変わらないようにするため)。

  ```dart
  /// v1 → v2: 記録済みの項目ごとに、最終実施日を 1 行の履歴として移す。
  ///
  /// id は UUID v4 を Dart 側で採番する(SQLite に UUID 関数が無い)。
  Future<void> _moveLastDoneAtToDoneLogs(DatabaseConnectionUser database) async {
    final rows = await database.customSelect(
      'SELECT id, last_done_at FROM items WHERE last_done_at IS NOT NULL',
    ).get();
    const uuid = Uuid();
    for (final row in rows) {
      await database.customStatement(
        'INSERT INTO done_logs (id, item_id, done_at) VALUES (?, ?, ?)',
        [uuid.v4(), row.read<String>('id'), row.read<int>('last_done_at')],
      );
    }
  }
  ```

- ファイル先頭のコメント「現在は v1 の初期作成のみ」を更新し、「**一度出荷したステップ(`from1To2`)は修正しない。v3 は `from2To3` を足す**」を明記する
- **`m.createAll()` を onUpgrade に書かない**(既存コメントの原則を維持)
- 失敗時の扱いは既存方針どおり(例外を握りつぶさない = 起動を中断)。Drift の onUpgrade はトランザクション内で走るので、途中失敗は v1 のまま残る

## 判断4: ドメインモデル(`lib/domain/item.dart`)

`Item` に 1 フィールド足す:

```dart
/// 直近の実施日時(UTC)。**新しい順**、最大 [recentDoneAtsLimit] 件。
/// 未実施なら空。先頭は [lastDoneAt] と一致する。
final List<DateTime> recentDoneAts;
```

- コンストラクタでは `this.recentDoneAts = const <DateTime>[]` の**省略可能な名前付き引数**にする(既存テスト・Fake の `Item(...)` 呼び出しを壊さない)
- `==` / `hashCode` に含める。リスト比較は `lib/domain/` 内で自前の要素比較を書く(`package:collection` / `package:flutter/foundation.dart` を import しない。レイヤー依存テストがある)。`hashCode` は `Object.hashAll(recentDoneAts)` を `Object.hash` に混ぜる
- 件数の上限は `lib/domain/baseline_interval.dart` の定数 `const int recentDoneAtsLimit = 10;` を正とし、データ層もこれを参照する

**なぜ 10 件か**: 基準間隔は直近 5 間隔 = 最大 6 つの**異なる暦日**を要する。同じ日に複数回記録した行は 1 日にまとめる(判断5)ため、行数には余裕を持たせる。10 件で 6 暦日に届かない場合(同日の多重記録が多い)は、取れた範囲の間隔で算出してよい。

## 判断5: 算出(`lib/domain/baseline_interval.dart`、新規・純関数)

```dart
import 'elapsed_days.dart';

/// 一覧で項目ごとに読み出す直近履歴の件数。
const int recentDoneAtsLimit = 10;

/// 基準間隔の算出に使う間隔の最大数。
const int baselineIntervalSampleSize = 5;

/// 実施日時(新しい順・UTC)から、**暦日の間隔**を新しい順に返す。
///
/// - 各日時はローカルの暦日に直してから比べる(`calendarDateOf(x.toLocal())`)。
///   `elapsedDays` と同じ規則で、夏時間の切替をまたいでも 1 日ずれない
/// - **同じ暦日の記録は 1 つにまとめる**(同日に 2 回押しても間隔 0 日を作らない)
/// - 暦日は降順に並べ直してから差を取る(端末時計の巻き戻りで順序が崩れても負の間隔を作らない)
/// - 結果の各要素は 1 以上。暦日が 1 つ以下なら空リスト
List<int> intervalDaysOf(List<DateTime> doneAtsNewestFirst);

/// 前回間隔: 直近 2 つの暦日の差。取れなければ null。
int? previousIntervalDays(List<DateTime> doneAtsNewestFirst);

/// 基準間隔: 直近最大 [baselineIntervalSampleSize] 個の間隔の**中央値**。取れなければ null。
///
/// 個数が偶数なら中央 2 つの平均(例: 6 と 7 → 6.5)。**丸めない**。
double? baselineIntervalDays(List<DateTime> doneAtsNewestFirst);

/// 相対経過度: 経過日数 ÷ 基準間隔。どちらかが null なら null。**丸めない。**
double? relativeElapsed({required int? elapsedDays, required double? baselineIntervalDays});
```

- 基準間隔は `double?`(中央値が .5 になりうるため)。前回間隔は `int?`
- 間隔はすべて 1 以上なので基準間隔は 0 にならず、ゼロ除算は起きない
- **null を絶対日数で代用しない**(記録 1 件以下・未実施は基準間隔も相対経過度も null)
- 中央値を採る理由をドキュメントコメントに 1 行書く(「1 回だけ極端に空いた間隔に基準が引っ張られない」)

## 判断6: リポジトリ(`lib/domain/item_repository.dart` / `lib/data/item_repository_impl.dart`)

**インターフェースのメソッドは増やさない。** 振る舞いとドキュメントコメントを変える:

| メソッド | 変更 |
| --- | --- |
| `watchAll()` | 各 `Item` の `recentDoneAts` を埋めて流す |
| `markDone(id, doneAt)` | `_db.transaction` の中で `items` を更新し、`done_logs` に 1 行 INSERT(id = UUID v4、done_at = doneAt と同じミリ秒) |
| `restoreLastDoneAt(id, previous, now)` | `_db.transaction` の中で、その項目の `done_logs` の直近 1 行(`ORDER BY done_at DESC, rowid DESC LIMIT 1` で id を取り、その id で DELETE)を消し、`items` を従来どおり更新。**履歴が 0 件なら DELETE は何もしない**(例外にしない) |
| `delete(id)` | 変更なし(外部キーの CASCADE で `done_logs` も消える) |
| `add` / `rename` | 変更なし |

`watchAll()` の実装:

```dart
@override
Stream<List<Item>> watchAll() {
  final query = /* 既存の items の select + orderBy */;
  // done_logs は常に items と同じトランザクションで書かれる(markDone / restoreLastDoneAt)。
  // そのため items の変更通知だけを契機にすれば履歴の変化も取りこぼさない。
  return query.watch().asyncMap((rows) async {
    final logs = await _recentDoneAtsByItem();
    return rows.map((row) => _toDomain(row, logs[row.id] ?? const [])).toList(growable: false);
  });
}
```

`_recentDoneAtsByItem()` は **1 本の SQL** で全項目の直近 `recentDoneAtsLimit` 件を取る(N+1 にしない):

```sql
SELECT item_id, done_at FROM (
  SELECT item_id, done_at,
         ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY done_at DESC, rowid DESC) AS rn
  FROM done_logs
) WHERE rn <= ?
ORDER BY item_id, done_at DESC, rn
```

- `customSelect(sql, variables: [Variable.withInt(recentDoneAtsLimit)], readsFrom: {_db.doneLogs})` で実行し、`Map<String, List<DateTime>>`(値は新しい順・UTC)に詰める
- `_toDomain(ItemRow row, List<DateTime> recentDoneAts)` に引数を足す。`add` の戻り値は `_toDomain(row, const [])`

## 判断7: 表示モデル(`lib/state/item_view.dart`)

`ItemView` にフィールドを 3 つ足す(UI はまだ使わない):

```dart
/// 前回間隔(日)。記録 1 件以下なら null。
final int? previousIntervalDays;

/// 基準間隔(日)。記録 1 件以下なら null。画面上の呼び名は「平均」。
final double? baselineIntervalDays;

/// 相対経過度(経過日数 ÷ 基準間隔)。基準間隔が null・未実施なら null。
final double? relativeElapsed;
```

- コンストラクタでは**省略可能な名前付き引数(既定 null)**にする(既存テストの `ItemView(...)` を壊さない)
- `ItemView.from(item, now:)` で、`item.recentDoneAts` から判断5 の関数で算出する。経過日数は `lastDoneAt == null ? null : elapsedDays(lastDoneAt: lastDoneAt, now: now)`
- `==` / `hashCode` に含める
- `toItemViews` は変更なし(`now` は 1 回の変換につき 1 つ、の約束のまま)

## 判断8: `FakeItemRepository`(`test/support/fake_item_repository.dart`)

実装と同じ振る舞いにする(ファイル先頭の約束):

- 項目ごとの履歴 `Map<ItemId, List<DateTime>>`(新しい順)を持つ
- `markDone`: 先頭に追加 / `restoreLastDoneAt`: 先頭を 1 つ除く(空なら何もしない) / `delete`: 履歴も消す
- スナップショットでは各 `Item` に `recentDoneAts`(先頭から最大 `recentDoneAtsLimit` 件)を詰める
- `writeError` 設定時は従来どおり書き込み前に投げる(履歴も変えない)

## 判断9: テスト

| ファイル | 内容 |
| --- | --- |
| `test/data/drift/app_database/migration_test.dart`(`make-migrations` が生成する雛形を編集) | (a) v1→v2 の `migrateAndValidate` でスキーマが一致する。(b) **データ検証**: v1 に「記録済み 2 件 + 未実施 1 件」を入れて v2 へ上げ、items の全列が不変・`done_logs` が 2 行(item_id と done_at が元の last_done_at と一致)・未実施の項目の履歴は 0 行 |
| `test/domain/baseline_interval_test.dart`(新規) | 記録 0 / 1 / 2 / 6 件以上、同日の多重記録、間隔に外れ値を 1 つ混ぜる(例: 7,7,60,7,7 → 7)、偶数個の中央値(6,7 → 6.5)、時計の巻き戻りで順序が崩れた入力、夏時間の切替をまたぐ入力(`elapsed_days_test.dart` の既存の夏時間テストと同じ作り方に合わせる)、`relativeElapsed` の null 伝播 |
| `test/data/item_repository_impl_test.dart`(追記) | markDone で done_logs が 1 行増え done_at が last_done_at と一致 / 取り消しで直近 1 行だけ消える / 未実施に戻す取り消しで履歴 0 行 / delete で履歴も消える(外部キー有効の確認)/ watchAll の `recentDoneAts` が新しい順で最大 10 件 / **トランザクション**: done_logs への INSERT を失敗させたとき items も更新されていない(手段: テスト内で `DROP TABLE done_logs` してから `markDone` を呼び、例外になること・`last_done_at` が元のままであることを確かめる)/ 既存の Fake との同一シナリオテストに履歴の観点を足す |
| `test/state/item_view_test.dart`(追記) | 履歴 0 / 1 / 3 件の Item から 3 フィールドが期待どおり |
| `test/state/item_list_notifier_test.dart` | 既存テストが通ることの確認のみ(追加は不要) |

**N+1 の確認**はコードレビューで行う(`watchAll` の発火 1 回につき SQL が 2 本であること)。テストで SQL 本数は数えない。

## 判断10: ドキュメント追記

- `docs/product-requirements.md` P1 表に `| F27 | 基準間隔の学習 | 実施履歴(F12)から項目ごとの基準間隔(直近最大 5 間隔の中央値)を学習する。ユーザーに設定を求めない。F9(目安期間の手動設定)の代替経路で、F10 の状態表示は基準間隔を使う形(#21)で実現する |` を F16 の下に足す
- `docs/functional-design.md`: ER 図の `ITEMS ||..o{ DONE_LOGS : "P1 で追加"` を `ITEMS ||--o{ DONE_LOGS : "v2 で追加"` に。`ItemRepository` のインターフェース節の `markDone` / `restoreLastDoneAt` のコメントに「done_logs と同一トランザクション」を追記
- `docs/glossary.md`:
  - 「履歴(Done Log)【P1】」を実装済みの記述に更新(【P1】は外さなくてよい)
  - ドメイン用語に 3 つ追加: **前回間隔**(`previousIntervalDays`)/ **基準間隔**(`baselineIntervalDays`。「**画面上の呼び名は『平均』。計算は中央値**」「null のとき画面上は『学習中』」を明記)/ **相対経過度**(`relativeElapsed`)
  - データモデル用語に「done_logs テーブル」(列: id / item_id / done_at、CASCADE、インデックス)を「items テーブル」の後に追加

## 検証コマンド

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```
