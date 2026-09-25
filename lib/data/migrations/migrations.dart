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
/// **一度出荷したステップ(`from1To2` など)は修正しない。** v5 を足すときは
/// `from4To5` を新しく足す。**`m.createAll()` を `onUpgrade` に書かない**
/// (ユーザーの記録が全損する)。
MigrationStrategy buildMigrationStrategy(GeneratedDatabase db) {
  return MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedDefaultCategories(m.database);
    },
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.doneLogs);
        await m.createIndex(schema.doneLogsItemIdDoneAt);
        await _moveLastDoneAtToDoneLogs(m.database);
      },
      from2To3: (m, schema) async {
        // 列の追加だけ。既存行は NULL(= 未選択)になる。データの移送は無い。
        await m.addColumn(schema.items, schema.items.icon);
      },
      from3To4: (m, schema) async {
        // 参照先を先に作る。既存行の category_id は NULL(= 未分類)になる。
        await m.createTable(schema.categories);
        await m.addColumn(schema.items, schema.items.categoryId);
        await _seedDefaultCategories(m.database);
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

/// 初期カテゴリ。**表示順 = 並び順。** 画面イメージの区分(`requirements.md`)。
const List<String> _defaultCategoryNames = ['生活', '健康', '趣味', 'その他'];

/// 初期カテゴリを入れる(v4 の新規作成と v3 → v4 の移行で共用)。
///
/// **v4 時点の列名を生の SQL で固定して書く**(`_moveLastDoneAtToDoneLogs` と同じ理由)。
/// 以降のバージョンで `categories` に列を足すときは NULL 許容か既定値つきにすること。
Future<void> _seedDefaultCategories(DatabaseConnectionUser database) async {
  const uuid = Uuid();
  for (var i = 0; i < _defaultCategoryNames.length; i++) {
    await database.customStatement(
      'INSERT INTO categories (id, name, sort_order) VALUES (?, ?, ?)',
      [uuid.v4(), _defaultCategoryNames[i], i],
    );
  }
}
