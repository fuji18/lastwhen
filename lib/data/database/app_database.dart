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
