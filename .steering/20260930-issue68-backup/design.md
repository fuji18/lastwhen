# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

既存の 4 レイヤーに沿って足す。**スキーマ変更なし・マイグレーションなし。**

```
ui/screens/settings_screen.dart   「バックアップ」区切り(書き出す / 復元する)・確認/エラーのダイアログ
        │ ref.read
state/backup_service.dart         BackupService(書き出しと復元の手順)+ 復元準備の結果型
state/providers.dart              backupRepositoryProvider / backupFileTransferProvider
        │
domain/backup.dart                BackupSnapshot 等のモデル・JSON 変換(encode/decode)・検証・エラー型・ファイル名
domain/backup_repository.dart     interface BackupRepository(readAll / replaceAll)
domain/backup_file_transfer.dart  interface BackupFileTransfer(share / pick)
        ▲ implements
data/backup_repository_impl.dart          Drift 実装(1 トランザクションで全置換)
data/platform_backup_file_transfer.dart   share_plus / file_picker / path_provider の実装
```

- ui は data を import しない(`test/architecture/layer_dependency_test.dart`)。ui は `backupServiceProvider` だけを触る
- domain は `dart:convert` / `dart:typed_data` 以外を import しない(Flutter・Drift・Riverpod・share_plus・file_picker を持ち込まない)
- state は `package:flutter/` を import しない

## 設計判断(確定事項。実装者は変えない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | ファイル形式は **JSON(UTF-8、インデント 2)**。拡張子 `.json`、MIME `application/json` | 依存なしで読み書きでき、人が中身を確かめられる |
| 2 | ファイル名は `lastwhen-backup-YYYYMMDD.json`(**端末のローカル日付**、ゼロ埋め) | 利用者が見分けるための名前なのでローカル日付。中身の日時は UTC |
| 3 | 日時は **UTC のエポックミリ秒(整数)**で書く。DB の保存形式と同じ | 変換で精度・タイムゾーンを失わない(CLAUDE.md「日時は UTC で保存する」) |
| 4 | `lastDoneAt` は**ファイルに書かない**。復元時に `done_logs` の `MAX(done_at)`(無ければ null)から算出する | 受け入れ条件「`lastDoneAt` が `MAX(done_at)` と一致」を構造で保証する |
| 5 | 復元は**全置換のみ**。1 トランザクションで `done_logs` → `items` → `categories` を全削除し、`categories` → `items` → `done_logs` の順に挿入する | マージは ID 衝突・カテゴリ名の重複の判断が要る。移行用途なら全置換で足りる |
| 6 | **ファイルの検証は DB に触る前に全部済ませる**(decode が成功した `BackupSnapshot` だけが replaceAll に渡る)。replaceAll の失敗はトランザクションのロールバックで既存データを守る | 「不正なファイルで既存データを一切変えない」を二重に守る |
| 7 | 確認は**ファイルを選んで検証が通った後**に出す。件数を見せる | 不正なファイルで確認を押させない。何で置き換わるかを見せる |
| 8 | 共有は **share_plus**、ファイル選択は **file_picker**(`FileType.any`)。一時ファイルは `path_provider` の一時ディレクトリに書く | 下記「依存ライブラリ」。拡張子フィルタは Android でドライブのファイルの MIME が揃わず選べなくなるため使わず、中身で判定する |
| 9 | 通知の取り直しは**追加の実装をしない**。Drift の型付き delete / insert で `items` を書き換えるので `ItemRepository.watchAll()` が再送出され、`NotificationSync` が張り直す。**テストで保証する** | 既存の購読経路を使う。個別の呼び出しを足すと二重になる |
| 10 | 復元が成功したらカテゴリの絞り込み(`categoryFilterProvider`)を「すべて」(null)に戻す | 絞り込み中のカテゴリが復元後に無い/別物になりうる |
| 11 | ファイルの上限は **10 MiB**(`maxBackupFileBytes = 10 * 1024 * 1024`)。超えたら読まずに `notBackupFile` | 誤って巨大ファイルを選んだときにメモリを使い切らない。想定規模(項目 1,000 件)は 1 MiB 未満 |
| 12 | 書き出しの成否は表示しない(共有シートを閉じた/選んだは区別しない)。**例外のときだけ** SnackBar「書き出せませんでした」 | 共有先で保存できたかはアプリから分からない。成功と言い切れないことを言わない |
| 13 | `lib/data/database/app_database.dart` は**コメントの 1 箇所だけ**直す(下記)。コード・スキーマは変えない | コメントが「エクスポートが無い以上、唯一の移行手段」と書いており事実でなくなる |

## コンポーネント設計

### 1. `lib/domain/backup.dart`(新規)

```dart
/// 形式の識別子と現在のバージョン。
const String backupFormatId = 'lastwhen-backup';
const int backupFormatVersion = 1;
const int maxBackupFileBytes = 10 * 1024 * 1024;

final class BackupCategory { const BackupCategory({required this.id, required this.name, required this.sortOrder}); final String id; final String name; final int sortOrder; }
final class BackupItem {
  const BackupItem({required this.id, required this.name, required this.icon, required this.categoryId,
    required this.createdAt, required this.updatedAt, required this.sortOrder});
  final String id; final String name;
  final String? icon;        // ItemIcon.key。未知の値もそのまま持つ(DB と同じ扱い)
  final String? categoryId;  // null = 未分類
  final DateTime createdAt;  // UTC
  final DateTime updatedAt;  // UTC
  final int sortOrder;
}
final class BackupDoneLog { const BackupDoneLog({required this.id, required this.itemId, required this.doneAt}); final String id; final String itemId; final DateTime doneAt; /* UTC */ }

final class BackupSnapshot {
  const BackupSnapshot({required this.categories, required this.items, required this.doneLogs});
  final List<BackupCategory> categories;
  final List<BackupItem> items;
  final List<BackupDoneLog> doneLogs;
}

enum BackupFormatError {
  /// JSON でない・UTF-8 でない・`format` が違う・`version` が整数でないか 1 未満・上限超え。
  notBackupFile,
  /// `version` が [backupFormatVersion] より大きい(新しいアプリで書き出された)。
  newerVersion,
  /// 形式は合っているが中身が壊れている(欠けた項目・型違い・ID の重複・参照切れ・名前の検証違反)。
  invalidContent,
}

final class BackupFormatException implements Exception {
  const BackupFormatException(this.error);
  final BackupFormatError error;
  @override String toString() => 'BackupFormatException($error)';
}

/// [snapshot] を JSON 文字列にする。[exportedAt] は書き出した時刻(UTC に直して書く)。
String encodeBackup(BackupSnapshot snapshot, {required DateTime exportedAt});

/// [bytes] を検証して読む。不正なら [BackupFormatException] を投げる(他の例外を漏らさない)。
BackupSnapshot decodeBackup(List<int> bytes);

/// 書き出すファイル名。[localNow] のローカル日付を使う(呼び出し側が toLocal() 済みで渡す)。
String backupFileNameOf(DateTime localNow); // => 'lastwhen-backup-20260930.json'
```

**JSON の形(v1)**。キーはこの綴りで固定。配列の順は下記「readAll の並び」のまま書く。

```json
{
  "format": "lastwhen-backup",
  "version": 1,
  "exportedAt": 1790000000000,
  "categories": [ { "id": "…", "name": "生活", "sortOrder": 0 } ],
  "items": [ { "id": "…", "name": "歯ブラシ交換", "icon": "brush", "categoryId": "…",
               "createdAt": 1780000000000, "updatedAt": 1790000000000, "sortOrder": 0 } ],
  "doneLogs": [ { "id": "…", "itemId": "…", "doneAt": 1785000000000 } ]
}
```

- `icon` / `categoryId` は null のとき **キーを省かず `null` を書く**
- エンコードは `const JsonEncoder.withIndent('  ')`。日時は `dateTime.toUtc().millisecondsSinceEpoch`

**decodeBackup の検証(この順に判定し、最初に当たったもので投げる)**

1. `bytes.length > maxBackupFileBytes` → `notBackupFile`
2. `utf8.decode(bytes)`(allowMalformed なし)と `jsonDecode` が失敗 → `notBackupFile`(`FormatException` を捕まえる)
3. トップが `Map<String, dynamic>` でない、または `format != backupFormatId` → `notBackupFile`
4. `version` が `int` でない、または `< 1` → `notBackupFile`。`> backupFormatVersion` → `newerVersion`
5. 以下すべて → 違反は `invalidContent`
   - `exportedAt` は `int`(値は使わない)
   - `categories` / `items` / `doneLogs` はそれぞれ `List`、要素はすべて `Map<String, dynamic>`
   - 各フィールドの型: 文字列 = `String`、整数 = `int`(**`double` は不可**。`1.0` も不可)、`icon` / `categoryId` は `String` または `null`。**キーが無いのも違反**(`null` 許容のキーも存在は必須)
   - 整数の日時(`createdAt` / `updatedAt` / `doneAt`)は `>= 0`
   - `id` は空文字でない。テーブルごとに重複しない
   - カテゴリ名は `validateCategoryName(name, existingNames: <それより前のカテゴリの名前>)` が `ValidCategoryName`
   - 項目名は `validateItemName(name)` が `ValidItemName`
   - 項目の `categoryId` は null か、ファイル内のカテゴリの `id`
   - 記録の `itemId` はファイル内の項目の `id`
   - 未知のキーは無視する(v1 の範囲での前方互換)
- 名前は**検証が通った元の文字列をそのまま**モデルに入れる(トリムし直さない。DB に入っているのはトリム済みの値)
- 型違いの取り出しで起きる `TypeError` 等を外へ漏らさない。**`decodeBackup` から出る例外は `BackupFormatException` だけ**にする(ヘルパで型を確かめてから取り出す実装にする。`catch (_)` で包むのは可)

### 2. `lib/domain/backup_repository.dart`(新規)

```dart
abstract interface class BackupRepository {
  /// 全データを 1 トランザクションで読む(読み途中の書き込みで食い違わない)。
  Future<BackupSnapshot> readAll();

  /// 全データを [snapshot] で置き換える。**1 トランザクション。** 失敗したら何も変わらない。
  /// `items.last_done_at` は [snapshot] の記録の最大値(無ければ null)で埋める。
  Future<void> replaceAll(BackupSnapshot snapshot);
}
```

### 3. `lib/domain/backup_file_transfer.dart`(新規)

```dart
abstract interface class BackupFileTransfer {
  /// [bytes] を [fileName] のファイルとして OS の共有シートに渡す。閉じられるまで待つ。
  Future<void> share({required String fileName, required List<int> bytes});

  /// OS のファイル選択を開き、選ばれたファイルの中身を返す。キャンセルは null。
  /// 大きさが [maxBackupFileBytes] を超えたら読まずに `BackupFormatException(notBackupFile)` を投げる。
  Future<List<int>?> pick();
}
```

### 4. `lib/data/backup_repository_impl.dart`(新規)

`final class BackupRepositoryImpl implements BackupRepository`、コンストラクタ `BackupRepositoryImpl(this._db)`(`AppDatabase`)。

- **readAll**: `_db.transaction` の中で 3 つを select する。並びは
  - categories: `sort_order`, `id` の昇順
  - items: `sort_order`, `id` の昇順
  - done_logs: `item_id`, `done_at`, `id` の昇順
  - 日時は `DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true)`
- **replaceAll**: `_db.transaction(() async { ... })` の中で
  1. `await _db.delete(_db.doneLogs).go();` → `items` → `categories` の順に全削除
  2. 記録から項目ごとの最大 `doneAt` を求める(`Map<String, int>`)
  3. `await _db.batch((b) { b.insertAll(_db.categories, …); b.insertAll(_db.items, …); b.insertAll(_db.doneLogs, …); });`(この順)。行は `CategoryRow` / `ItemRow` / `DoneLogRow`(既存の生成クラス)で作る。`ItemRow.lastDoneAt` は手順 2 の値
  - **Drift の型付き API だけを使う**(`customStatement` で消さない)。型付き API でないと `watchAll()` の購読に変更が通知されず、通知の取り直し(判断 9)が起きない
  - 例外は握りつぶさずそのまま投げる(トランザクションがロールバックされる)
- 行 ⇔ モデルの変換はこのファイルの private 関数に置く

### 5. `lib/data/platform_backup_file_transfer.dart`(新規)

`final class PlatformBackupFileTransfer implements BackupFileTransfer`(引数なしコンストラクタ)。

- **share**:
  1. `final dir = Directory('${(await getTemporaryDirectory()).path}${Platform.pathSeparator}backup'); await dir.create(recursive: true);`
  2. `final file = File('${dir.path}${Platform.pathSeparator}$fileName'); await file.writeAsBytes(bytes, flush: true);`(同名は上書き。**消さない** —— 共有先が戻った後に読みに来ることがある。一時ディレクトリなので OS が片付ける)
  3. `await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/json')], fileNameOverrides: [fileName]));` 戻り値の `ShareResult` は使わない(判断 12)
- **pick**:
  1. `final picked = await FilePicker.pickFile(type: FileType.any);` null なら null を返す
  2. `final length = await picked.length(); if (length != null && length > maxBackupFileBytes) throw const BackupFormatException(BackupFormatError.notBackupFile);`
  3. `final bytes = await picked.readAsBytes();` 読んだ後も `bytes.length > maxBackupFileBytes` なら同じ例外。返すのは `bytes`
- file_picker 13 は**静的メソッド**(`FilePicker.pickFile`)。`FilePicker.platform` は使わない
- このクラスはプラットフォームチャネルを叩くのでユニットテストを書かない(state 以上はフェイクで差し替える)

### 6. `lib/state/providers.dart`(変更)

末尾に追加:

```dart
/// バックアップの読み書き。テストは `FakeBackupRepository` に差し替える。
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// 共有シートとファイル選択。テストは `FakeBackupFileTransfer` に差し替える。
final backupFileTransferProvider = Provider<BackupFileTransfer>(
  (ref) => PlatformBackupFileTransfer(),
);
```

### 7. `lib/state/backup_service.dart`(新規)

```dart
/// 復元するファイルを選んだ結果。
sealed class RestorePreparation { const RestorePreparation(); }
final class RestoreCanceled extends RestorePreparation { const RestoreCanceled(); }
final class RestoreReady extends RestorePreparation { const RestoreReady(this.snapshot); final BackupSnapshot snapshot; }
final class RestoreRejected extends RestorePreparation { const RestoreRejected(this.error); final BackupFormatError error; }
/// ファイルを読めなかった(権限の取り消し・クラウド上のファイルの取得失敗など)。
final class RestoreReadFailed extends RestorePreparation { const RestoreReadFailed(); }

final class BackupService {
  BackupService({required BackupRepository repository, required BackupFileTransfer transfer, required Clock clock});
  // フィールドは _repository / _transfer / _clock。NotificationSync と同じく initializing formal を使わない書き方に揃える

  /// 全データを書き出して共有シートを開く。失敗は例外のまま投げる(UI が SnackBar を出す)。
  Future<void> export() async {
    final now = _clock.now();
    final snapshot = await _repository.readAll();
    final json = encodeBackup(snapshot, exportedAt: now);
    await _transfer.share(fileName: backupFileNameOf(now.toLocal()), bytes: utf8.encode(json));
  }

  /// ファイルを選ばせて検証する。**DB には触らない。** 例外は投げない。
  Future<RestorePreparation> prepareRestore() async {
    // pick が null → RestoreCanceled
    // pick / decode が BackupFormatException → RestoreRejected(e.error)
    // それ以外の例外(pick の I/O 失敗) → developer.log('バックアップの読み込みに失敗しました', error:, stackTrace:, name: 'BackupService') して RestoreReadFailed
    // 成功 → RestoreReady(decodeBackup(bytes))
  }

  /// [snapshot] で全データを置き換える。失敗は例外のまま投げる(既存データは変わっていない)。
  Future<void> restore(BackupSnapshot snapshot) => _repository.replaceAll(snapshot);
}

final backupServiceProvider = Provider<BackupService>((ref) => BackupService(
  repository: ref.watch(backupRepositoryProvider),
  transfer: ref.watch(backupFileTransferProvider),
  clock: ref.watch(clockProvider),
));
```

- ログに項目名・ファイルの中身を出さない(`docs/functional-design.md`「セキュリティ考慮事項」)。`error` に例外を渡すのは可

### 8. `lib/ui/screens/settings_screen.dart`(変更)

**並び**(上から):カテゴリの管理 / `Divider` / **見出し「バックアップ」** / データを書き出す / データを復元する / `Divider` / 注意事項 … (以降は既存のまま)

| 行 | leading | title | subtitle |
| --- | --- | --- | --- |
| 書き出し | `Icons.upload_file_outlined` | データを書き出す | 項目・記録・カテゴリを 1 つのファイルにまとめて、保存先や送り先を選びます |
| 復元 | `Icons.settings_backup_restore` | データを復元する | 書き出したファイルから戻します。今のデータは置き換わります |

- 注意事項の 2 行目の文言を「アプリを削除すると、項目と記録もすべて消えます。機種変更の前に「データを書き出す」で保存しておくと、復元できます。」に変える
- 2 行は `_BackupSection`(`ConsumerStatefulWidget`、このファイルの private)にまとめる。`bool _busy` を持ち、処理中は 2 行とも `enabled: false`(二重タップ防止)。`finally` で戻す。`SettingsScreen` 自体は `StatelessWidget` のままでよい
- 生の色・余白を書かない。色は `Theme.of(context).colorScheme` から取る

**書き出しのタップ**:
1. `ScaffoldMessenger.of(context).clearSnackBars();`
2. `_busy = true` → `await ref.read(backupServiceProvider).export();`
3. 例外なら(`mounted` を確かめて)SnackBar「書き出せませんでした」。成功時は何も出さない(判断 12)

**復元のタップ**:
1. `clearSnackBars()`、`_busy = true`
2. `final preparation = await ref.read(backupServiceProvider).prepareRestore();`
3. `switch`:
   - `RestoreCanceled` → 何もしない
   - `RestoreRejected(error)` → エラーダイアログ(下記)。本文は `_rejectionMessageOf(error)`
   - `RestoreReadFailed` → エラーダイアログ。本文「ファイルを読み込めませんでした。もう一度お試しください。」
   - `RestoreReady(snapshot)` → 確認ダイアログ(下記)。`true` 以外は何もしない(バリアタップ・戻るは null)
4. 確認で「復元する」→ `await service.restore(snapshot)`
   - 成功 → `ref.read(categoryFilterProvider.notifier).select(null);` → SnackBar「復元しました」
   - 例外 → エラーダイアログ。本文「復元できませんでした。データは変わっていません。」

**確認ダイアログ**(`item_edit_screen.dart` の削除確認と同じ組み立て):
- title: `データを復元しますか?`
- content: `今の項目と記録はすべて消え、選んだファイルの内容に置き換わります。元に戻せません。\n\nファイルの内容: 項目 ${items.length} 件・記録 ${doneLogs.length} 件・カテゴリ ${categories.length} 件`
- actions: `TextButton('キャンセル')` → pop(false) / `TextButton('復元する')`(`foregroundColor: colorScheme.error`)→ pop(true)

**エラーダイアログ**: title `復元できません`、content は上記の本文、actions は `TextButton('閉じる')` 1 つ。

**`_rejectionMessageOf`**:

| BackupFormatError | 本文 |
| --- | --- |
| notBackupFile | このアプリで書き出したファイルではありません。データは変わっていません。 |
| newerVersion | 新しいバージョンのアプリで書き出されたファイルです。アプリを更新してから復元してください。データは変わっていません。 |
| invalidContent | ファイルの内容が壊れているため、復元できません。データは変わっていません。 |

### 9. `lib/data/database/app_database.dart`(コメントのみ・判断 13)

`_openConnection` の doc コメントの 2〜3 行目

```
/// **OS の自動バックアップ(iCloud / Auto Backup)から除外しない。** MVP に
/// エクスポート機能が無い以上、これが唯一の機種変更時の移行手段になる
/// (`docs/architecture.md`「バックアップ戦略」)。
```

を次に置き換える。**ほかの行は 1 文字も変えない。**

```
/// **OS の自動バックアップ(iCloud / Auto Backup)から除外しない。** 書き出し・復元(F26)を
/// 使わない利用者にとっては、これが機種変更時の移行手段になる
/// (`docs/architecture.md`「バックアップ戦略」)。
```

## データフロー

### 書き出し
```
1. 設定 →「データを書き出す」
2. BackupService.export: Clock.now → BackupRepository.readAll(1 トランザクション)→ encodeBackup
3. BackupFileTransfer.share: 一時ディレクトリに lastwhen-backup-YYYYMMDD.json を書く → 共有シート
4. 例外のときだけ SnackBar「書き出せませんでした」
```

### 復元
```
1. 設定 →「データを復元する」
2. BackupService.prepareRestore: BackupFileTransfer.pick → decodeBackup(DB に触らない)
3. 不正 → エラーダイアログ(何も変えない)/ キャンセル → 何もしない
4. 正常 → 件数つきの確認ダイアログ →「復元する」
5. BackupRepository.replaceAll(1 トランザクションで全置換)
6. items の変更で watchAll が再送出 → 一覧・図鑑・NotificationSync(通知の張り直し)が追従
7. 絞り込みを「すべて」に戻し、SnackBar「復元しました」
```

## エラーハンドリング戦略

- ドメインの検証エラーは `BackupFormatException(BackupFormatError)` の 1 型に集約する
- state の `prepareRestore` は例外を投げず結果型で返す。`export` / `restore` は例外のまま投げ、UI が表示を決める
- ユーザー向け文言に例外の文言を出さない(`docs/architecture.md`「入力検証」)
- **失敗を成功に見せない**: 復元の成功表示は replaceAll の完了後だけ。楽観的更新はしない

## テスト戦略

### ユニットテスト(`test/domain/backup_test.dart`)
- encode → decode の往復で全フィールドが一致する(null の icon / categoryId、記録 0 件の項目を含む)
- encode の結果に `"format": "lastwhen-backup"` / `"version": 1` があり、日時が UTC ミリ秒の整数で入っている(ローカル時刻の `DateTime` を渡しても UTC の値になる)
- `backupFileNameOf(DateTime(2026, 1, 5, 23, 59))` → `lastwhen-backup-20260105.json`
- decode が `notBackupFile`: UTF-8 でないバイト列 / JSON でない / トップが配列 / `format` 違い / `version` が文字列・0 / 上限 + 1 バイト
- decode が `newerVersion`: `version: 2`
- decode が `invalidContent`: キー欠け(`icon` キーなしを含む)/ 日時が `1.0` / 負の日時 / 空の id / id の重複 / 存在しない `categoryId` / 存在しない `itemId` / 空の項目名 / 51 文字の項目名 / 重複したカテゴリ名 / 配列の要素が文字列
- **どの不正入力でも `BackupFormatException` 以外が出ない**

### 統合テスト(`test/data/backup_repository_impl_test.dart`、`AppDatabase.forTesting(NativeDatabase.memory())`)
- 既存の `ItemRepositoryImpl` / `CategoryRepositoryImpl` でデータを作る(カテゴリ追加・アイコンつき項目・未分類項目・未実施項目・`markDone` 複数回・過去日付の `addDoneLog`)→ `readAll` → `encodeBackup` → `decodeBackup` → **別のインメモリ DB** に `replaceAll` → 両 DB の `readAll` を `encodeBackup`(同じ `exportedAt`)した文字列が一致する
- 復元先の `ItemRepositoryImpl.watchAll().first` の各項目の `lastDoneAt` が、その項目の記録の最大値(記録なしは null)と一致する
- 既存データがある DB に `replaceAll` すると、既存の項目・記録・カテゴリが残らない
- **ロールバック**: 既存データがある DB に、参照切れ(存在しない `itemId` の記録)を含む `BackupSnapshot` を**直接組み立てて**(decode を通さず)`replaceAll` → 例外が出て、`readAll` の結果が呼ぶ前と一致する(外部キーは `migrations.dart` の beforeOpen で ON)
- **通知の取り直しの契機**: `ItemRepositoryImpl.watchAll()` を購読した状態で `replaceAll` すると、復元後の項目の一覧が送出される
- 空の DB の `readAll` → 3 つとも空

### state(`test/state/backup_service_test.dart`、フェイクで)
- `export`: フェイク transfer が受け取った `fileName` が `FakeClock` のローカル日付のファイル名、`bytes` を `decodeBackup` するとリポジトリの内容になる
- `prepareRestore`: pick が null → `RestoreCanceled` / 不正なバイト列 → `RestoreRejected(notBackupFile)` / pick が `BackupFormatException` → `RestoreRejected` / pick が `Exception` → `RestoreReadFailed` / 正常 → `RestoreReady`。**どの場合も `replaceAll` が呼ばれていない**
- `restore`: `replaceAll` に同じ snapshot が渡る

### ウィジェットテスト(`test/ui/screens/settings_screen_test.dart` に追加)
- 見出し「バックアップ」と 2 行が表示される
- 書き出し: タップで transfer.share が 1 回呼ばれる。share が例外 → SnackBar「書き出せませんでした」
- 復元: 不正なファイル → 「復元できません」ダイアログと notBackupFile の本文。`replaceAll` は呼ばれない
- 復元: 正常 → 件数つきの確認 →「キャンセル」で `replaceAll` が呼ばれない
- 復元: 正常 → 「復元する」→ `replaceAll` が呼ばれ、SnackBar「復元しました」
- 復元: `replaceAll` が例外 → 「復元できませんでした。データは変わっていません。」
- 既存テストの `_app` は `backupRepositoryProvider` / `backupFileTransferProvider` をフェイクで上書きする(実プラットフォームを叩かない)

### フェイク(`test/support/`)
- `fake_backup_repository.dart`: `BackupSnapshot snapshot`(readAll が返す)、`List<BackupSnapshot> replaced`(replaceAll の記録)、`Object? replaceError`(設定されていれば投げる)
- `fake_backup_file_transfer.dart`: `List<({String fileName, List<int> bytes})> shared`、`Object? shareError`、`List<int>? pickResult`、`Object? pickError`

## 依存ライブラリ

`flutter pub add share_plus:^13.3.0 file_picker:^13.1.0` で追加する(`pubspec.yaml` の依存の並びの最後、`timezone` の後。既存と同じくコメントを 1 行添える)。

| パッケージ | 用途 | 追加の理由 |
| --- | --- | --- |
| `share_plus` ^13.x | 書き出したファイルを OS の共有シートに渡す | 共有シートを Flutter 本体だけで開く手段が無い。Android は自前の FileProvider で渡すため**権限を足さない**(マニフェストは `<provider>` のみ) |
| `file_picker` ^13.x | 復元するファイルを選ぶ | OS のファイル選択(Android は SAF の `GET_CONTENT`)を開く手段が Flutter 本体に無い。**権限を要求しない**(マニフェストは `<queries>` のみ) |

- どちらも HTTP クライアントを持ち込まない(share_plus の `url_launcher_*` 依存は web / Windows / Linux 用で、Android のビルドに入らない)。**release のマージ済みマニフェストで `INTERNET` と `READ_/WRITE_EXTERNAL_STORAGE` / `READ_MEDIA_*` が無いことを確かめる**(tasklist フェーズ5)
- 出たら**実装を止めて報告する**(データセーフティの回答が成り立たなくなる)

## ディレクトリ構造

```
lib/domain/backup.dart                       新規
lib/domain/backup_repository.dart            新規
lib/domain/backup_file_transfer.dart         新規
lib/data/backup_repository_impl.dart         新規
lib/data/platform_backup_file_transfer.dart  新規
lib/data/database/app_database.dart          コメントのみ(判断 13)
lib/state/providers.dart                     変更
lib/state/backup_service.dart                新規
lib/ui/screens/settings_screen.dart          変更
test/domain/backup_test.dart                 新規
test/data/backup_repository_impl_test.dart   新規
test/state/backup_service_test.dart          新規
test/support/fake_backup_repository.dart     新規
test/support/fake_backup_file_transfer.dart  新規
test/ui/screens/settings_screen_test.dart    変更
pubspec.yaml / pubspec.lock                  依存の追加
docs/product-requirements.md / architecture.md / functional-design.md / glossary.md  変更
```

## docs の更新内容

### `docs/product-requirements.md`
- 「P2 機能」表から F26 の行を消し、「P1 機能」表の F17 の行の直後に追加:
  `| F26 | データのバックアップ(書き出しと復元) | 全データ(項目・記録の履歴・カテゴリ・アイコン)を JSON ファイル 1 つに書き出し、OS の共有シートで端末の外へ渡す。そのファイルから**全置換**で復元する(確認あり・元に戻せない)。入口は設定。不正なファイルでは何も変えずに理由を出す(#68) |`
- 「P1 機能」の追記群の末尾(#67 の追記の後)に追加:
  `> **追記(#68)**: F26 を P2 から P1 に前倒しした。移行手段が OS の自動バックアップだけだと、自動バックアップが無効な端末や OS をまたぐ移行で記録がすべて失われる。記録の信頼性が製品価値そのものなので、公開の前に入れる。復元はマージせず全置換にし、「削除には確認を入れる」と同じ基準(元に戻せない)で確認を入れる。`
- 「セキュリティ / プライバシー」の注記「OS 標準バックアップは例外として許容する。…」の「MVP に手動エクスポート(F26)が無い以上これが唯一の機種変更手段であり、意図的に除外指定しない」を「F26 の書き出しを使わない利用者にとっては機種変更の手段になるため、意図的に除外指定しない」に変える
- 「スコープ外」から `- データのエクスポート・バックアップ` の行を消す

### `docs/architecture.md`
- 「フレームワーク・ライブラリ」表の末尾(`timezone` の後)に 2 行: `share_plus` / `file_picker`(バージョン方針 `^13.x`、用途と選定理由は上の「依存ライブラリ」表と同じ趣旨。末尾に `(#68)`)
- 「バックアップ戦略」を書き直す: 経路は 2 つ —— (1) OS の自動バックアップ(既存の表をそのまま残す)、(2) **アプリの書き出しと復元(F26 / #68)**: JSON 1 ファイル・形式バージョンつき・日時は UTC ミリ秒・`lastDoneAt` は持たず復元時に算出・復元は 1 トランザクションの全置換。末尾の引用「MVP に手動エクスポート(F26)が無い以上、これが唯一の移行手段。」を「書き出しを使わない利用者にとっては、OS の自動バックアップが移行手段になる。**バックアップ対象から除外する設定を入れない**ことは引き続き要件」に変える
- 「データ保護」の「アクセス制御」に追記: 書き出したファイルは**アプリの一時ディレクトリ**に書いて共有シートに渡す。端末の外へ出るのは利用者が共有先を選んだときだけ。**ファイルは暗号化しない**(保存内容の機微度が低いという既存の判断と同じ)
- 「セキュリティ制約」に 1 項目: 書き出したファイルは平文の JSON で、共有先での扱いは共有先に従う(プライバシーポリシーに記載済み)
- 「依存関係管理」表に `share_plus` / `file_picker`(キャレット)を追加

### `docs/functional-design.md`
- 「設定(#81)」の表の「カテゴリの管理」行の後に「バックアップ」区切りの 2 行(書き出す / 復元する)と動きを足す。注意事項の行の要約に「書き出しで復元できる」を足す。表の後に箇条書きで: 復元はファイルの検証 → 件数つきの確認 → 全置換 / 不正なファイルは理由を出して何も変えない / 成功で絞り込みを「すべて」に戻す
- 「ファイル構造(データ保存形式)」に小節「バックアップファイル(F26 / #68)」を足し、上の JSON の形と検証規則の要約を書く。既存の引用「MVP にエクスポート機能(F26)が無い以上、これが唯一の移行手段になる。」を「書き出し(F26)を使わない利用者にとっては、これが移行手段になる。」に変える
- 「セキュリティ考慮事項」の「権限」行に追記: 書き出し・復元は OS の共有シートとファイル選択(SAF)を使い、ストレージ権限を要求しない
- 「エラーハンドリング」の表に 2 行: 「バックアップファイルの不正(形式・バージョン・中身)」→ DB に触らない / ダイアログで理由 ・「復元の書き込み失敗」→ ロールバックで既存データを保持 / 「復元できませんでした。データは変わっていません。」

### `docs/glossary.md`
- 「ドメイン用語」の末尾(「よくある項目」の後)に `### バックアップ(書き出し・復元)【P1】` を追加: 定義(全データを 1 ファイルに書き出し、そのファイルから全置換で戻す)/ コード上の表記 `BackupSnapshot` / `BackupService` / `BackupRepository` / UI 文言「バックアップ」「データを書き出す」「データを復元する」/ 使わない言い換え: エクスポート、インポート、リストア、同期
- 「設定(SettingsScreen)」の説明と UI 文言に「バックアップ」区切りと 2 行を足す
- 「表記ゆれの禁止一覧」に `| 書き出す / 復元する | エクスポート、インポート、リストア |` を追加

## 実装の順序

1. 依存の追加(`flutter pub add`)
2. domain(モデル・JSON・検証・interface)とそのテスト
3. data(リポジトリ実装・プラットフォーム実装)と統合テスト
4. state(providers・BackupService)とテスト
5. ui(設定画面)とウィジェットテスト
6. release ビルドでマニフェストの権限を確認
7. docs

## セキュリティ考慮事項

- 書き出したファイルは平文。アプリは自動で送信しない(共有先は利用者が選ぶ)
- 権限を足さない(確認は release のマージ済みマニフェストで行う)
- ログに項目名・ファイルの中身を出さない
- 読み込むファイルは信頼しない: 上限・型・参照を全部確かめてから DB に渡す

## パフォーマンス考慮事項

- 想定規模(項目 1,000 件・記録数千件)で JSON は 1 MiB 未満。メモリ上で一括処理してよい
- 挿入は `batch` の `insertAll` でまとめる(1 行ずつ await しない)

## 将来の拡張性

- 形式を変えるときは `backupFormatVersion` を上げ、decode に旧版の読み替えを足す。新しい版のファイルは古いアプリで `newerVersion` になる

## 追補: レビュー指摘の修正(/code-review)

**不具合**: `lib/domain/backup.dart` の `_decodeContent` のカテゴリのループで、重複判定用の `categoryNames` に**トリム前の** `rawName` を足している。`validateCategoryName` は比較対象をトリム後の値で比べるため、`" 家事"` → `"家事"` の順に並ぶと重複を見逃す(逆順は検出される)。

**修正(この 1 行だけ)**: `categoryNames.add(rawName);` を `categoryNames.add(validated.value);` に変える(`validated` は直前の `is! ValidCategoryName` の判定で `ValidCategoryName` に昇格済み。`value` はトリム後の名前)。コメントを「重複判定はトリム後の名前で比べる。モデルには検証が通った元の文字列をそのまま入れる(トリムし直さない)。」に変える。**`BackupCategory` に入れる名前は `rawName` のまま変えない。**

**テスト**: `test/domain/backup_test.dart` の「重複したカテゴリ名」の直後に 1 件足す:
- テスト名 `前後に空白のある名前が先に来ても重複を検出する`
- categories = `[{'id': 'cat-1', 'name': ' 生活', 'sortOrder': 0}, {'id': 'cat-2', 'name': '生活', 'sortOrder': 1}]` → `expectInvalid(top)`
