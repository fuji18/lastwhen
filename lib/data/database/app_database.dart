import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../migrations/migrations.dart';

part 'app_database.g.dart';

/// `categories` テーブル。定義は `docs/glossary.md`「categories テーブル」が正。v4 で追加。
@DataClassName('CategoryRow')
class Categories extends Table {
  /// UUID v4。採番は `CategoryRepositoryImpl`(初期カテゴリはマイグレーション)が行う。
  TextColumn get id => text().named('id')();

  /// カテゴリ名。長さ・重複の検証はドメイン層が持つので、ここは NOT NULL だけを課す
  /// (UNIQUE も付けない。一度出荷した制約は修正できない)。
  TextColumn get name => text().named('name')();

  /// 表示順。`MAX(sort_order) + 1` で採番する。
  IntColumn get sortOrder => integer().named('sort_order')();

  @override
  String get tableName => 'categories';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

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

  /// アイコンの保存キー(`ItemIcon.key`)。**NULL = 未選択。** v3 で追加。
  ///
  /// CHECK 制約を付けない。候補は今後増えるうえ、一度出荷した制約は修正できない。
  /// 未知の値はドメインへの変換で未選択として扱う。
  TextColumn get icon => text().named('icon').nullable()();

  /// カテゴリ。**NULL = 未分類。** v4 で追加。カテゴリの削除で NULL に戻る(ON DELETE SET NULL)。
  TextColumn get categoryId => text()
      .named('category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();

  @override
  String get tableName => 'items';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

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

/// アプリのローカル DB。テーブルは `categories`(v4)・`items`・`done_logs`(v2 で追加)。
@DriftDatabase(tables: [Categories, Items, DoneLogs])
class AppDatabase extends _$AppDatabase {
  /// 端末のドキュメント領域のファイルを開く。
  AppDatabase() : super(_openConnection());

  /// テスト用。`NativeDatabase.memory()` を渡して実ファイルを触らずに使う。
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => buildMigrationStrategy(this);
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
