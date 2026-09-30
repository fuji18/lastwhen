# タスクリスト

## 🚨 タスク完全完了の原則

**このファイルの全タスクが完了するまで作業を継続すること**

- **全てのタスクを`[x]`にすること**。理由なくスキップしない
- スキップが許されるのは技術的理由のみ。`- [x] ~~タスク名~~(理由)` の形で残す
- **`design.md` に書かれていない設計判断が要ったら、その場で停止して報告する**
- `lib/data/database/` はコメント 1 箇所(design.md 判断 13)以外を変えない。変更が要りそうなら停止して報告する

---

## フェーズ1: 依存の追加

- [x] `flutter pub add share_plus:^13.3.0 file_picker:^13.1.0` を実行し、`pubspec.yaml` の 2 行にコメントを 1 行ずつ添える(design.md「依存ライブラリ」)。`pubspec.lock` の更新を含める

## フェーズ2: ドメイン

- [x] `lib/domain/backup.dart`(モデル・`encodeBackup` / `decodeBackup` / `backupFileNameOf`・`BackupFormatError` / `BackupFormatException`・定数)
- [x] `lib/domain/backup_repository.dart` / `lib/domain/backup_file_transfer.dart`(interface)
- [x] `test/domain/backup_test.dart`(design.md「ユニットテスト」の全ケース)

## フェーズ3: データ

- [x] `lib/data/backup_repository_impl.dart`(readAll / replaceAll。型付き API のみ・1 トランザクション)
- [x] `lib/data/platform_backup_file_transfer.dart`(share / pick)
- [x] `lib/data/database/app_database.dart` のコメント 1 箇所(判断 13。ほかは変えない)
- [x] `test/data/backup_repository_impl_test.dart`(往復・lastDoneAt・全置換・ロールバック・watchAll の再送出・空 DB)

## フェーズ4: 状態管理

- [x] `lib/state/providers.dart` に `backupRepositoryProvider` / `backupFileTransferProvider`
- [x] `lib/state/backup_service.dart`(`RestorePreparation` 系・`BackupService`・`backupServiceProvider`)
- [x] `test/support/fake_backup_repository.dart` / `test/support/fake_backup_file_transfer.dart`
- [x] `test/state/backup_service_test.dart`

## フェーズ5: UI

- [x] `lib/ui/screens/settings_screen.dart`(「バックアップ」区切り・`_BackupSection`・確認/エラーダイアログ・注意事項 2 行目の文言)
- [x] `test/ui/screens/settings_screen_test.dart`(既存 `_app` にフェイクの上書きを足す + design.md「ウィジェットテスト」の全ケース。既存テストが文言変更で落ちたら追従する)

## フェーズ6: 権限の確認

- [x] `flutter build apk --release` を通し、`grep -n "uses-permission" build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml` の結果を「実装後の振り返り」に貼る。`INTERNET` / `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_*` / `MANAGE_EXTERNAL_STORAGE` が出たら**停止して報告する**

## フェーズ7: 品質チェックと修正

- [x] 変更したファイルの `dart format` / `flutter analyze --fatal-infos` と関連テストを通す(フルスイートは検収側が回す)
- [x] `/check` を通す(司令塔の検収。ユーザーの指示でモード B 中に実施: format・analyze・test 888 件すべてパス)

## フェーズ8: ドキュメント更新

- [x] `docs/product-requirements.md`(F26 を P1 へ・追記(#68)・プライバシー注記・スコープ外)
- [x] `docs/architecture.md`(ライブラリ表・バックアップ戦略・データ保護・セキュリティ制約・依存関係管理)
- [x] `docs/functional-design.md`(設定・ファイル構造・セキュリティ考慮事項・エラーハンドリング)
- [x] `docs/glossary.md`(用語の追加・設定の UI 文言・表記ゆれの禁止一覧)
- [x] 実装後の振り返り(このファイルの下部に記録)

---

## 実装後の振り返り

### 実装完了日
2026-09-30

### 計画と実績の差分

**計画と異なった点**:
- 統合テスト「空の DB の readAll は 3 つとも空」は、マイグレーションが初期カテゴリ 4 件を
  入れるため、テスト内で `db.delete(db.categories).go()` してから確かめる形にした
  (design.md には明記が無かったが、テスト実装の詳細でありやり方の選択に設計判断は要らないと判断した)
- それ以外は design.md の記述どおりに実装できた

**新たに必要になったタスク**:
- 無し

### 権限の確認結果(フェーズ6)

```
$ grep -n "uses-permission" build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml
11:    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
12:    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
33:    <uses-permission android:name="android.permission.VIBRATE" />
39:    <uses-permission android:name="com.github.fuji18.lastwhen.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" />
```

`INTERNET` / `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_*` / `MANAGE_EXTERNAL_STORAGE` はいずれも出ていない。既存の通知権限(#51)のみで、share_plus / file_picker の追加による権限増加は無い。

### 学んだこと

- share_plus 13.x / file_picker 13.x の API(`SharePlus.instance.share(ShareParams(...))` /
  `FilePicker.pickFile` / `PlatformFile.length()`)は design.md の記述とそのまま一致しており、
  pub-cache のソースで事前確認したことで迷いなく実装できた
- 検証エラー(`decodeBackup`)を型ヘルパ関数(`_requireString` 等)に切り出すことで、
  20 種類近い不正入力のケースを見通しよく書けた

### 次回への改善提案

- 「空の DB」のように、マイグレーションの初期データがテストの前提と衝突するケースは、
  design.md のテスト戦略に一言(「初期カテゴリを削除してから」等)添えておくと実装時の
  自己判断が減る
