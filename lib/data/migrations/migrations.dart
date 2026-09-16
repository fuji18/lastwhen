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
