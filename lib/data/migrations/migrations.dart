import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.steps.dart';

/// スキーマ移行の定義。
///
/// 原則(`docs/architecture.md`「マイグレーション戦略」):
///
/// - **前進のみ。** ダウングレードは実装しない
/// - **破壊的変更を避ける。** 列の削除・リネームではなく、追加と非使用化で進める
/// - **失敗時にテーブルを作り直さない。** 起動を中断してエラーを出す
///
/// **一度出荷したステップ(`from1To2` など)は修正しない。** v3 を足すときは
/// `from2To3` を新しく足す。**`m.createAll()` を `onUpgrade` に書かない**
/// (ユーザーの記録が全損する)。
MigrationStrategy buildMigrationStrategy(GeneratedDatabase db) {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.doneLogs);
        await m.createIndex(schema.doneLogsItemIdDoneAt);
        await _moveLastDoneAtToDoneLogs(m.database);
      },
    ),
    beforeOpen: (details) async {
      // SQLite は既定で外部キー制約を無視する。done_logs の ON DELETE CASCADE を
      // 効かせるため、接続のたびに明示的に有効化する。
      await db.customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// v1 → v2: 記録済みの項目ごとに、最終実施日を 1 行の履歴として移す。
///
/// id は UUID v4 を Dart 側で採番する(SQLite に UUID 関数が無い)。
/// **v1 時点の列名を生の SQL で固定して書く**(将来 `Items` の Dart 定義が変わっても、
/// この移行の意味が変わらないようにするため)。
Future<void> _moveLastDoneAtToDoneLogs(DatabaseConnectionUser database) async {
  final rows = await database
      .customSelect(
        'SELECT id, last_done_at FROM items WHERE last_done_at IS NOT NULL',
      )
      .get();
  const uuid = Uuid();
  for (final row in rows) {
    await database.customStatement(
      'INSERT INTO done_logs (id, item_id, done_at) VALUES (?, ?, ?)',
      [uuid.v4(), row.read<String>('id'), row.read<int>('last_done_at')],
    );
  }
}
