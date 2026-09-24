# 設計: カテゴリと絞り込み(Issue #33 / F13)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **スコープ判断(司令塔)**: F13 は P1。P0 はすべてクローズ済みで、MVP 完了後の P1 として着手する(前倒しではない)
> - **区分・追加可否・置き場所はユーザーが決定済み**(`requirements.md`「Issue の未決事項に対するユーザーの決定」)
> - **このチケットは委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れる。Codex に委託しない**
> - **依存は増えない。** `pubspec.yaml` を変更しない。追加の UI パッケージを入れない
> - 用語は「カテゴリ」(「カテゴリー」と書かない)。カテゴリの無い状態は「**未分類**」

## 0. 全体像

```
domain : CategoryId / Category / CategoryRepository(新規) / validateCategoryName(新規)
         Item.categoryId(CategoryId?  null = 未分類)
data   : categories テーブル(v4) / items.category_id TEXT NULL FK → categories.id ON DELETE SET NULL
         CategoryRepositoryImpl(新規) / ItemRepository.add・edit に categoryId
state  : categoryRepositoryProvider / categoryListProvider(CategoryListNotifier)/ categoryFilterProvider
         resolveCategoryId / filterByCategory(純関数) / ItemView.categoryId
ui     : CategoryFilterBar(一覧上部のチップ) / ItemCategoryPicker(登録・編集) /
         CategoryNameDialog / CategoryManageScreen(新規画面)
```

- **項目のカテゴリは 0 か 1 つ。** 多対多にしない
- カテゴリには時刻の列を持たせない(表示にも並びにも使わない)。したがって `CategoryRepository` の書き込みは `now` を取らない
- 絞り込みは**表示の上での部分列**。`ItemListNotifier` の並び(F30 の確定順)は触らない

## 判断1: ドメイン

### `lib/domain/category.dart`(新規)

```dart
/// カテゴリ ID。素の String と取り違えないための型。
extension type const CategoryId(String value) {}

/// 項目を分けるためのカテゴリ。ユーザーが追加・名前変更・削除できる(F13)。
final class Category {
  const Category({required this.id, required this.name, required this.sortOrder});

  final CategoryId id;

  /// 前後の空白を除いた 1〜10 文字。検証は `validateCategoryName` が行う。
  final String name;

  /// 表示順。追加順(`MAX(sort_order) + 1`)。並び替えは提供しない。
  final int sortOrder;

  // == / hashCode は 3 フィールドすべてで比較する(Item と同じ書き方)
}
```

### `lib/domain/category_name.dart`(新規)

`item_name.dart` と同じ形にする。

```dart
/// カテゴリ名の最大文字数(前後の空白を除いたコードポイント数)。チップに収まる長さ。
const int maxCategoryNameLength = 10;

sealed class CategoryNameResult { const CategoryNameResult(); }
final class ValidCategoryName extends CategoryNameResult { const ValidCategoryName(this.value); final String value; }
final class InvalidCategoryName extends CategoryNameResult { const InvalidCategoryName(this.reason); final CategoryNameReason reason; }

enum CategoryNameReason {
  /// 空文字、または空白のみ。
  empty,
  /// 前後の空白を除いて [maxCategoryNameLength] を超えた。
  tooLong,
  /// 前後の空白を除いた名前が、既存のカテゴリ名と完全に一致した。
  duplicate,
}

/// カテゴリ名を検証する。[existingNames] は**自分以外の**既存カテゴリ名(呼び出し元が除く)。
/// 判定順: empty → tooLong → duplicate。長さはコードポイント数で測る。
CategoryNameResult validateCategoryName(String raw, {required Iterable<String> existingNames});
```

- 重複判定は**トリム後の完全一致**(大文字小文字・全角半角の正規化はしない)

### `lib/domain/category_repository.dart`(新規)

```dart
/// カテゴリの永続化。**書き込みは `now` を取らない**(カテゴリは時刻の列を持たない)。
abstract interface class CategoryRepository {
  /// 表示順(sort_order 昇順、同値は id 昇順)に並んだ全カテゴリを流す。
  Stream<List<Category>> watchAll();

  /// カテゴリを追加する。id は UUID v4、sort_order は MAX + 1(空なら 0)。
  Future<Category> add(String name);

  /// 名前を変える。対象が無ければ何もしない(例外にしない)。
  Future<void> rename(CategoryId id, String name);

  /// カテゴリを削除する。**そのカテゴリの項目は未分類になる。項目と記録は消えない。**
  Future<void> delete(CategoryId id);
}
```

### `lib/domain/item.dart`

- `final CategoryId? categoryId;` を足す。doc: `/// 項目のカテゴリ。**null は未分類。**`
- コンストラクタは `this.categoryId` の省略可能な名前付き引数(既定 null)。`==` / `hashCode` に含める

### `lib/domain/item_repository.dart`

```dart
  Future<Item> add(String name, {ItemIcon? icon, CategoryId? categoryId, required DateTime now});

  /// 項目名・アイコン・カテゴリを変更する。**最終実施日と履歴は変えない。**
  /// [icon] / [categoryId] に null を渡すと未選択 / 未分類に戻す(「変更しない」の意味ではない)。
  Future<void> edit(ItemId id, {required String name, required ItemIcon? icon,
      required CategoryId? categoryId, required DateTime now});
```

`add` の doc に「[categoryId] が null なら未分類」を足す。

## 判断2: スキーマ v4(`lib/data/database/app_database.dart`)

`Categories` テーブルを足す(`Items` の前に置く):

```dart
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
```

`Items` の `icon` の後に列を足す:

```dart
  /// カテゴリ。**NULL = 未分類。** v4 で追加。カテゴリの削除で NULL に戻る(ON DELETE SET NULL)。
  TextColumn get categoryId => text()
      .named('category_id')
      .nullable()
      .references(Categories, #id, onDelete: KeyAction.setNull)();
```

- `@DriftDatabase(tables: [Categories, Items, DoneLogs])`、`schemaVersion => 4`
- `AppDatabase` の doc を「テーブルは `categories`(v4)・`items`・`done_logs`(v2 で追加)。」にする

## 判断3: マイグレーション(`lib/data/migrations/migrations.dart`)

**手順(#32 と同じ。順序を守る)**:

1. 判断2 の変更
2. `dart run build_runner build --delete-conflicting-outputs`
3. `dart run drift_dev make-migrations` → `drift_schemas/app_database/drift_schema_v4.json`、再生成された
   `app_database.steps.dart`、`test/data/drift/app_database/generated/schema_v4.dart`(と `schema.dart`)ができる。できなければ停止して報告
4. 生成物はすべてコミット対象。**手で編集しない**(`dart format` だけはかけてよい)
5. `migration_test.dart` が再生成で上書きされていたら #32 時点の内容に戻してから追記する(`git diff` で確認)

`onCreate` と `stepByStep` を次のようにする(**`from1To2` / `from2To3` は一文字も変えない**):

```dart
    onCreate: (Migrator m) async {
      await m.createAll();
      await _seedDefaultCategories(m.database);
    },
    onUpgrade: stepByStep(
      from1To2: ...,  // 変更しない
      from2To3: ...,  // 変更しない
      from3To4: (m, schema) async {
        // 参照先を先に作る。既存行の category_id は NULL(= 未分類)になる。
        await m.createTable(schema.categories);
        await m.addColumn(schema.items, schema.items.categoryId);
        await _seedDefaultCategories(m.database);
      },
    ),
```

```dart
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
```

- ファイル先頭 doc の「v4 を足すときは `from3To4`」を「v5 を足すときは `from4To5`」に直す
- 生成されたゲッター名(`schema.categories` / `schema.items.categoryId`)が違えば生成物に合わせる(設計判断ではない)
- `PRAGMA foreign_keys = ON` は `beforeOpen` のまま(移行中は外部キーが無効なので `addColumn` の REFERENCES は問題にならない)

## 判断4: リポジトリ実装

### `lib/data/category_repository_impl.dart`(新規)

`ItemRepositoryImpl` と同じ書き方(`final class`、`static const Uuid _uuid`)。

- `watchAll`: `select(categories)` を `sortOrder` 昇順 → `id` 昇順で `watch()` し `_toDomain` で変換
- `add`: `ItemRepositoryImpl.add` と同じく **採番と INSERT を 1 トランザクション**で行う
- `rename`: `update(categories)..where(id)` に `CategoriesCompanion(name: Value(name))`
- `delete`: **1 トランザクション**で次の 2 文を順に実行する
  1. `update(items)..where((t) => t.categoryId.equals(id.value))` に `ItemsCompanion(categoryId: const Value(null))`
  2. `delete(categories)..where(id)`

  外部キーの SET NULL があっても 1 を明示的に書く。**Drift の型付き update を通すことで `items` の購読
  (`ItemRepository.watchAll`)に変更が確実に通知される**ため。`items.updated_at` は**動かさない**
  (ユーザーが項目を編集したわけではない。`now` も持たない)。コメントでこの 2 点を残す

### `lib/data/item_repository_impl.dart`

- `add`: `ItemRow(..., categoryId: categoryId?.value)`
- `edit`: `ItemsCompanion` に `categoryId: Value(categoryId?.value)` を足す
- `_toDomain`: `categoryId: row.categoryId == null ? null : CategoryId(row.categoryId!)`(ローカル変数に取って `!` を避けてよい)
- 存在しないカテゴリ ID を渡した書き込みは外部キー違反で例外になる。**捕まえない**(Notifier が保存失敗として扱う)

### テスト用フェイク

`test/support/fake_item_repository.dart`:

- `add` / `edit` に `categoryId` を足し、`Item(..., categoryId: categoryId)` / `_copy(..., categoryId: categoryId)`
- `_copy` に `Object? categoryId = _unset` を足す(`icon` と同じ番兵方式)
- **公開メソッド `void clearCategory(CategoryId id)` を足す**: 該当項目の `categoryId` を null にして emit する。
  `updatedAt` は変えない。`writeError` は見ない(呼び出し元の `FakeCategoryRepository.delete` が見る)

`test/support/fake_category_repository.dart`(新規):

- `FakeCategoryRepository({FakeItemRepository? items})`。`FakeItemRepository` と同じ構造
  (`_categories` / broadcast `StreamController` / `watchAll` は現在値を yield してから stream / `writeError` /
  `_failIfConfigured` / `dispose`)。**初期状態は空**(初期カテゴリを入れない。テストが明示的に `add` する)
- id は `'fake-category-${_idSequence++}'`、sort_order は MAX + 1(空なら 0)
- `delete` は `_failIfConfigured()` → `_items?.clearCategory(id)` → 自分から除去 → emit
- 並び: sort_order 昇順、同値は id 昇順

## 判断5: 状態管理

### `lib/state/providers.dart`

```dart
/// カテゴリの永続化。上位層のテストは `FakeCategoryRepository` に差し替える。
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepositoryImpl(ref.watch(appDatabaseProvider)),
);
```

### `lib/state/category_results.dart`(新規)

`add_item_result.dart` と同じ形・同じ doc の粒度で 3 つの sealed class を置く:

| 型 | 分岐 |
| --- | --- |
| `AddCategoryResult` | `AddCategorySucceeded(Category category)` / `AddCategoryRejected(CategoryNameReason reason)` / `AddCategoryFailed()` |
| `RenameCategoryResult` | `RenameCategorySucceeded()` / `RenameCategoryRejected(CategoryNameReason reason)` / `RenameCategoryIgnored()` / `RenameCategoryFailed()` |
| `DeleteCategoryResult` | `DeleteCategorySucceeded()` / `DeleteCategoryIgnored()` / `DeleteCategoryFailed()` |

### `lib/state/category_list_notifier.dart`(新規)

`ItemListNotifier` と同じ構造:

```dart
final categoryListProvider =
    StreamNotifierProvider<CategoryListNotifier, List<Category>>(CategoryListNotifier.new);

class CategoryListNotifier extends StreamNotifier<List<Category>> {
  List<Category> _latestCategories = const <Category>[];

  @override
  Stream<List<Category>> build() =>
      ref.watch(categoryRepositoryProvider).watchAll().map((c) => _latestCategories = c);

  Future<AddCategoryResult> addCategory(String rawName);
  Future<RenameCategoryResult> renameCategory(CategoryId id, String rawName);
  Future<DeleteCategoryResult> deleteCategory(CategoryId id);
}
```

- `addCategory`: `validateCategoryName(raw, existingNames: 全カテゴリ名)` → Rejected / 保存 → `Succeeded(保存結果)` / 例外 → Failed
- `renameCategory`: 検証(`existingNames` は **id が自分以外**の名前)→ 存在確認(無ければ Ignored)→ 保存
  (検証 → 存在確認の順は `editItem` と同じ)
- `deleteCategory`: 存在確認(無ければ Ignored)→ 保存。**確認は UI の責務**
- 例外は `developer.log(..., name: 'lastwhen.state', ...)` で残して Failed を返す。文言は
  `'カテゴリの追加に失敗しました'` / `'カテゴリの名前変更に失敗しました'` / `'カテゴリの削除に失敗しました'`
- **`state` を触らない**(一覧は購読結果だけを反映。`ItemListNotifier.addItem` と同じ方針)

### `lib/state/category_filter.dart`(新規)

```dart
/// 一覧の絞り込み。**null は「すべて」。** 保存しない(再起動で「すべて」に戻る)。
final categoryFilterProvider =
    NotifierProvider<CategoryFilterNotifier, CategoryId?>(CategoryFilterNotifier.new);

class CategoryFilterNotifier extends Notifier<CategoryId?> {
  @override
  CategoryId? build() => null;

  void select(CategoryId? id) => state = id;
}

/// [id] が [categories] に存在すればそのまま、無ければ null(削除済みのカテゴリを未分類・「すべて」として扱う)。
CategoryId? resolveCategoryId(CategoryId? id, List<Category> categories);

/// [filter] が null なら [views] をそのまま返す。そうでなければ categoryId が一致するものだけを、**入力順を保って**返す。
List<ItemView> filterByCategory(List<ItemView> views, CategoryId? filter);
```

- 選択中のカテゴリが削除されても provider の値は消さない。**読む側が必ず `resolveCategoryId` を通す**(判断7)

### `lib/state/item_view.dart`

- `final CategoryId? categoryId;`(省略可能な名前付き、既定 null)。`ItemView.from` で `categoryId: item.categoryId`。`==` / `hashCode` に含める

### `lib/state/item_list_notifier.dart`

- `addItem(String rawName, {ItemIcon? icon, CategoryId? categoryId})` → `repository.add(..., categoryId: categoryId, ...)`
- `editItem(ItemId id, String rawName, {required ItemIcon? icon, required CategoryId? categoryId})` → `repository.edit(..., categoryId: categoryId, ...)`
- doc の「項目名とアイコンを変更する」を「項目名・アイコン・カテゴリを変更する」に直す

## 判断6: UI の部品

### `lib/ui/category_name_error_text.dart`(新規)

```dart
String categoryNameErrorText(CategoryNameReason reason) => switch (reason) {
  CategoryNameReason.empty => 'カテゴリ名を入力してください',
  CategoryNameReason.tooLong => '$maxCategoryNameLength文字以内で入力してください',
  CategoryNameReason.duplicate => '同じ名前のカテゴリがあります',
};
```

保存失敗の文言は既存と同じ `'保存できませんでした。もう一度お試しください'`。

### `lib/ui/widgets/category_name_dialog.dart`(新規)

カテゴリ名を入力する `AlertDialog`。**検証エラーでは閉じずに理由を出す**必要があるため、保存処理を引数で受ける。

```dart
/// 保存を試み、成功なら null、失敗なら入力欄に出す文言を返す。
typedef CategoryNameSubmit = Future<String?> Function(String rawName);

/// ダイアログを開く。保存に成功して閉じたら true、キャンセル・バリアタップなら false。
Future<bool> showCategoryNameDialog(
  BuildContext context, {
  required String title,        // 'カテゴリを追加' / 'カテゴリ名を変更'
  required String confirmLabel, // '追加' / '保存'
  String initialName = '',
  required CategoryNameSubmit onSubmit,
});
```

- 中身は `StatefulWidget`。`TextField`(`autofocus: true`、`maxLength: maxCategoryNameLength`、
  `labelText: 'カテゴリ名'`、`errorText`、`textInputAction: done`、`onSubmitted` で確定)
- 確定: `_isBusy = true` → `await onSubmit(text)` → null なら `Navigator.pop(true)`、文字列なら `errorText` に出して `_isBusy = false`
- 保存中はキャンセル・確定ボタンを両方 `onPressed: null` にする。入力し直したら `errorText` を消す(登録画面と同じ)
- `showDialog<bool>` の戻り値が null なら false にして返す
- **呼び出し側の結果 → 文言の対応**(ヘルパー関数は作らず各呼び出し側で switch):
  Succeeded / Ignored → null、Rejected → `categoryNameErrorText(reason)`、Failed → 保存失敗の文言

### `lib/ui/widgets/category_filter_bar.dart`(新規)

```dart
/// 一覧上部の絞り込みチップ列(F13)。先頭が「すべて」(null)、以降は [categories] の順。
/// 図鑑(#34)でも使い回す想定で、**provider を読まない**(値とコールバックだけを受ける)。
class CategoryFilterBar extends StatelessWidget {
  const CategoryFilterBar({required this.categories, required this.selected, required this.onSelected, super.key});
  final List<Category> categories;
  final CategoryId? selected;           // 呼び出し側で resolveCategoryId 済みの値
  final ValueChanged<CategoryId?> onSelected;
}
```

- `SingleChildScrollView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8))`
  の中に `Row`、チップ間は `SizedBox(width: 8)`
- 各チップは `ChoiceChip(label: Text(...), selected: ..., onSelected: (_) => onSelected(id))`。
  **選択済みのチップを押しても選択を外さない**(bool 引数は無視して同じ id を渡す)
- 「すべて」の文言は定数 `allCategoriesLabel = 'すべて'` として同ファイルに置く
- 読み上げ・タップ領域は `ChoiceChip` の既定(選択状態を出す・48dp に広がる)に任せ、自前の `Semantics` を足さない

### `lib/ui/widgets/item_category_picker.dart`(新規)

登録・編集画面のカテゴリ選択欄。`ItemIconPicker` と同じ見た目の骨組み(見出し `'カテゴリ'` を `titleSmall`、8dp、`Wrap(spacing: 8, runSpacing: 8)`)。

```dart
class ItemCategoryPicker extends ConsumerWidget {
  const ItemCategoryPicker({required this.selected, required this.onChanged, this.enabled = true, super.key});
  final CategoryId? selected;
  final ValueChanged<CategoryId?> onChanged;
  final bool enabled;
}
```

- `categories = ref.watch(categoryListProvider).value ?? const <Category>[]`(Riverpod 3 では `value` が null 許容)。
  読み込み中・失敗でも「未分類」と追加チップは出す
- 表示上の選択は `resolveCategoryId(selected, categories)`
- 並び: `ChoiceChip('未分類')`(値 null。文言は定数 `uncategorizedLabel = '未分類'`)→ 各カテゴリの `ChoiceChip` →
  `ActionChip(avatar: const Icon(Icons.add), label: const Text('カテゴリを追加'))`
- `enabled == false` のときは各 `ChoiceChip.onSelected` と `ActionChip.onPressed` を null にする
- 追加チップ: `showCategoryNameDialog(title: 'カテゴリを追加', confirmLabel: '追加', onSubmit: ...)`。`onSubmit` で
  `categoryListProvider.notifier.addCategory` を呼び、`AddCategorySucceeded(:category)` を受けたらその id を
  ローカル変数に控える。ダイアログが true で閉じ、`context.mounted` なら `onChanged(控えた id)` を呼ぶ(追加したカテゴリが選ばれる)

## 判断7: 画面

### 一覧 `lib/ui/screens/item_list_screen.dart`

- `AppBar.actions` に `IconButton(icon: const Icon(Icons.label_outline), tooltip: 'カテゴリを管理', onPressed: ...)` を置く。
  **状態によらず常に出す**。押したら `clearSnackBars()` してから `CategoryManageScreen` を `MaterialPageRoute` で push
- `build` で `categories = ref.watch(categoryListProvider).value ?? const <Category>[]`、
  `filter = resolveCategoryId(ref.watch(categoryFilterProvider), categories)` を求める
- `AsyncData` かつ非空のときの body を次にする(空状態・読み込み中・失敗は今のまま):

  ```dart
  Column(children: [
    if (categories.isNotEmpty)
      CategoryFilterBar(categories: categories, selected: filter,
          onSelected: (id) => ref.read(categoryFilterProvider.notifier).select(id)),
    Expanded(child: visible.isEmpty ? const _FilteredEmpty() : _ItemList(items: visible)),
  ])
  ```

  `visible = filterByCategory(value, filter)`
- `_FilteredEmpty`: `CenteredScrollable` の中に `Text('このカテゴリの項目はありません', style: textTheme.bodyLarge, textAlign: center)`
- FAB の表示条件(`hasItems`)は**絞り込み前の件数**のまま
- `_openAddScreen(context, {CategoryId? initialCategoryId})` にし、FAB と `EmptyState` の両方から `initialCategoryId: filter` を渡す
  (`EmptyState` の `onAddPressed` のクロージャで渡す。`EmptyState` 自体は変えない)
- `_openEditScreen` は `initialCategoryId: item.categoryId` を足して渡す

### 登録 `item_add_screen.dart` / 編集 `item_edit_screen.dart`

- コンストラクタに `this.initialCategoryId`(`CategoryId?`、省略可能)を足す。doc: 登録は「開いた時点で選ばれているカテゴリ(一覧の絞り込み)」、編集は「開いた時点のカテゴリ(保存済みの値)」
- `late CategoryId? _categoryId = widget.initialCategoryId;`
- 項目名の `TextField` と `ItemIconPicker` の間に `SizedBox(height: 24)` + `ItemCategoryPicker(selected: _categoryId, onChanged: ..., enabled: !_isSaving / !_isBusy)` を置く
- 保存時は `resolveCategoryId(_categoryId, ref.read(categoryListProvider).value ?? const <Category>[])` を渡す
  (編集中にカテゴリが削除された場合に外部キー違反を起こさない)
- 登録画面の `autofocus: true` は維持する

### カテゴリ管理 `lib/ui/screens/category_manage_screen.dart`(新規)

`ConsumerWidget`。`Scaffold(appBar: AppBar(title: const Text('カテゴリを管理')))`。

- `categoryListProvider` の状態で分岐:
  - `AsyncData` 非空: `ListView.builder(padding: EdgeInsets.only(bottom: 88))`。各行
    `ListTile(title: Text(name), onTap: 名前変更, trailing: IconButton(icon: const Icon(Icons.delete_outline), tooltip: '「$name」を削除', onPressed: 削除))`
  - `AsyncData` 空: `CenteredScrollable` に `Text('カテゴリはありません')`
  - `AsyncError`: `CenteredScrollable` に `Text('データを読み込めませんでした')`
  - それ以外: `CircularProgressIndicator(semanticsLabel: '読み込み中')`
- FAB: `FloatingActionButton(tooltip: 'カテゴリを追加', child: Icon(Icons.add))` → 追加ダイアログ(判断6。選択はしない)
- 名前変更: `showCategoryNameDialog(title: 'カテゴリ名を変更', confirmLabel: '保存', initialName: name, onSubmit: renameCategory)`
- 削除: 確認ダイアログ(`item_edit_screen.dart` の削除確認と同じ組み方)
  - タイトル `'カテゴリを削除しますか?'`
  - 本文 `'「$name」を削除します。このカテゴリの項目は未分類になります。項目と記録は消えません。'`
  - 「キャンセル」/「削除」(`colorScheme.error`)。**true 以外はすべて削除しない**
  - `DeleteCategoryFailed` なら `SnackBar('削除できませんでした。もう一度お試しください')`。Succeeded / Ignored は何も出さない

## 判断8: テスト

既存テストは追従(引数追加・provider の差し替え)以外で期待値を変えない。

1. **既存のウィジェットテストの `ProviderScope` すべて**(`grep -rl itemRepositoryProvider.overrideWith test` の 8 ファイル前後)に
   `categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository())` を足す。**足さないと実 DB を開きに行って落ちる**
2. `test/domain/category_name_test.dart`: 空 / 空白のみ / 10 文字 OK / 11 文字 NG / 絵文字をコードポイントで数える / トリムして返す / 重複(トリム後一致)/ 判定順(空白のみは duplicate ではなく empty)
3. `test/domain/item_test.dart`: `categoryId` が `==` / `hashCode` に効く。`category_test.dart`(新規): `Category` の等価性
4. `migration_test.dart`: **v3 → v4 のデータ検証テスト**を v2 → v3 と同じ書き方で足す。
   items 2 行(icon あり・なし)と done_logs 1 行を入れ、移行後に items は `categoryId: null` で他の列不変、done_logs 不変、
   categories は `(name, sortOrder)` が `[('生活',0), ('健康',1), ('趣味',2), ('その他',3)]`(id は乱数なので比較しない)
5. `test/data/category_repository_impl_test.dart`(新規。`AppDatabase.forTesting(NativeDatabase.memory())`):
   新規 DB に初期 4 件がこの順 / add の sort_order が MAX + 1 / rename / delete で該当項目の categoryId が null・
   `lastDoneAt`・`updatedAt`・done_logs 件数は不変・他カテゴリの項目は不変 / **delete 後に `ItemRepositoryImpl.watchAll` が
   未分類の項目を再送出する** / 存在しない id の rename・delete が例外にならない
6. `test/data/item_repository_impl_test.dart`: categoryId つきの add / edit が往復する、edit で null に戻せる
7. `test/state/category_list_notifier_test.dart`(新規。Fake を使う): 3 メソッドの全分岐(Rejected 各理由・Ignored・Failed は `writeError`)。
   rename で自分と同じ名前(変更なし)は Succeeded
8. `test/state/category_filter_test.dart`(新規): `resolveCategoryId` と `filterByCategory`(null / 一致のみ / 入力順維持 / 0 件)、
   `CategoryFilterNotifier` の初期値 null と `select`
9. `item_list_notifier_test.dart` / `item_view_test.dart`: categoryId を渡した add / edit、`ItemView.categoryId` の写し
10. ウィジェット:
    - `test/ui/widgets/category_filter_bar_test.dart`: 「すべて」+ 順番どおりのチップ / 選択状態 / タップで id が返る / 選択済みを押しても同じ id
    - `test/ui/widgets/item_category_picker_test.dart`: 「未分類」+ カテゴリ + 追加チップ / 選択 / 削除済み id は未分類表示 /
      追加ダイアログで保存するとその id で `onChanged` / 重複名でダイアログが閉じず理由が出る / `enabled: false` で押せない
    - `test/ui/screens/category_manage_screen_test.dart`(新規): 一覧表示 / 空 / 追加 / 名前変更 / 削除確認でキャンセルなら残る /
      削除で消え、その項目が未分類になる(Fake を `FakeCategoryRepository(items: itemRepo)` で繋ぐ)/ 削除失敗で SnackBar
    - `item_list_screen_test.dart`: カテゴリ 0 件ならチップ無し / 絞り込みで該当だけ・並びは維持 / 0 件で専用の文言 /
      選択中のカテゴリを削除すると全件に戻る / 絞り込み中に FAB → 登録画面でそのカテゴリが選択済み / AppBar から管理画面へ
    - `item_add_screen_test.dart` / `item_edit_screen_test.dart`: カテゴリを選んで保存 / 未選択なら null / 編集は現在値で開く・未分類に戻せる
11. `test/ui/terminology_test.dart`: 禁止語に `'カテゴリー'` / `'タグ'` / `'ジャンル'` を足し、検査対象の画面に
    `CategoryManageScreen` を足す(既存の検査対象の組み方に合わせる)
12. `test/architecture/layer_dependency_test.dart` は変更不要のはず(新ファイルが層の規則を守っていれば通る)。落ちたら実装側を直す

## 判断9: ドキュメント

- `docs/product-requirements.md` F13 の行を
  `| F13 | カテゴリ機能 | 初期値は 生活 / 健康 / 趣味 / その他。ユーザーが追加・名前変更・削除できる。一覧上部のチップで絞り込む |` にする
- `docs/glossary.md`:
  - ドメイン用語に「### カテゴリ(Category)【P1】」を足す(項目を分ける区分。項目あたり 0 か 1 つ。初期値 4 つ。ユーザーが追加・名前変更・削除できる。**カテゴリの無い状態を「未分類」と呼ぶ**)
  - 「items テーブル」に `| \`category_id\` | TEXT NULL (FK → categories.id) | カテゴリ。**NULL = 未分類**。カテゴリの削除で NULL に戻る(ON DELETE SET NULL)。v4 で追加(#33) |`
  - 「### categories テーブル」を done_logs の後に足す(列 `id` / `name`(トリム後 1〜10 文字・重複不可はドメインで検証)/ `sort_order`。v4 で追加。初期 4 行)
  - 「### CategoryId」を ItemId の後に足す
  - 表記ゆれの禁止一覧に `| カテゴリ / 未分類 | カテゴリー、タグ、ジャンル |` を足す
- `docs/functional-design.md`:
  - データモデル: `Item` のコード例に `final CategoryId? categoryId;   // null = 未分類(F13)`、制約表に 1 行。
    「### エンティティ: Category」を足す。ER 図に `CATEGORIES` と `CATEGORIES ||--o{ ITEMS` を足し、図の前の文に「`categories` と `category_id` は v4 で追加した(#33)」
  - コンポーネント設計: リポジトリ例の `add` / `edit` に categoryId、`CategoryRepository` の節を短く足す
  - 画面遷移図: 一覧 → カテゴリ管理(AppBar)を足す
  - UI 設計: 「### カテゴリの絞り込み(F13)」を足す(チップ列・「すべて」・0 件の文言・選択中の削除で「すべて」へ・絞り込み中の追加で既定選択・並びは F30 のまま)
- `docs/architecture.md`「機能拡張性」表に `| P1 カテゴリ | \`categories\` テーブルと \`items.category_id\`(v4)。削除は SET NULL で項目と記録を残す |` を足す

## 判断10: 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` を通す。
生成物が analyze / format に引っかかったら既存の除外設定の範囲で扱う(新しい除外が要るなら停止して報告)。

---

## 追補: PR #42 レビュー指摘の修正(2026-09-24)

`/code-review` で見つかった重大度「低」の 2 件を直す。どちらもこの節に書いた内容だけを実装し、他の設計は変えない。

### 追補1: カテゴリ一覧が読めていないときに、項目のカテゴリを消さない

**問題**: `ref.read(categoryListProvider).value ?? const []` は、読み込み中や、最初の値が届く前にストリームが失敗したときに空の一覧になる。空の一覧で `resolveCategoryId` を通すと、実在するカテゴリ ID が `null` になり、項目名だけ変えて保存しても未分類になる(記録の信頼性を損なう)。

**方針**: 一覧が**まだ無い**(`value == null`)ときは「存在しない」と判定しない。**選択中の ID をそのまま使う。** 本当に削除済みだった場合は保存が外部キー違反で失敗し、既存の `EditItemFailed` / `AddItemFailed` の経路でエラーが出る(データは失われない)。

1. `lib/ui/screens/item_edit_screen.dart` の `_save`:

   ```dart
   // 一覧がまだ無いときは存在を判定できない。選択を消さずにそのまま渡す。
   final categories = ref.read(categoryListProvider).value;
   ...
   categoryId: categories == null
       ? _categoryId
       : resolveCategoryId(_categoryId, categories),
   ```

   既存の「編集中にカテゴリが削除された場合に外部キー違反を起こさない。」のコメントは残す。

2. `lib/ui/screens/item_add_screen.dart` の `_save`: 1 と同じ形に直す。
3. `lib/ui/widgets/item_category_picker.dart` の `build`: 表示も同じ判定にそろえる(一覧が無いのに「未分類」を選択中と見せない)。

   ```dart
   final loaded = ref.watch(categoryListProvider).value;
   // 読み込み中・失敗でも「未分類」と追加チップは出す。
   final categories = loaded ?? const <Category>[];
   // 一覧が無いときは存在を判定できない。選択を「未分類」に見せない。
   final effectiveSelected = loaded == null
       ? selected
       : resolveCategoryId(selected, loaded);
   ```

   (一覧が無く `selected` が非 null のときは、どのチップも選択状態にならない。これで正しい)
4. `resolveCategoryId` 自体(`lib/state/category_filter.dart`)と `item_list_screen.dart` の絞り込みは**変えない**(絞り込みは「すべて」に戻っても記録は失われない)。

### 追補2: 追加・名前変更の直後に同じ名前を通さない

**問題**: 重複検査は `_latestCategories` を見るが、これはストリームの次の値が届くまで古いまま。追加直後にもう一度同じ名前を追加すると通る(`categories` に UNIQUE 制約は無い)。最初の値が届く前にも同じことが起きる。

**方針**: `lib/state/category_list_notifier.dart` だけを直す。スキーマ・リポジトリには触れない(UNIQUE 制約の追加はマイグレーションになるため採らない)。

1. `addCategory` と `renameCategory` の**先頭**(検証より前)で、最初の値を待つ:

   ```dart
   // 最初の値が届く前は `_latestCategories` が空で、重複を見逃す。
   try {
     await future;
   } catch (_) {
     return const AddCategoryFailed(); // renameCategory では RenameCategoryFailed()
   }
   ```

   ログは出さない(ストリームの失敗は購読側で扱われる)。
2. 保存が成功した直後、`return` の前に `_latestCategories` を手元で更新する(次のストリームの値で正しい一覧に置き換わる):
   - `addCategory`: `_latestCategories = [..._latestCategories, category];`
   - `renameCategory`: 該当 ID の要素を名前だけ差し替えた新しいリストにする。`Category` に `copyWith` があればそれを使い、無ければ既存のコンストラクタで作り直す(`copyWith` を新設しない)。
   - コメント: `// ストリームの次の値が届くまでの間も、重複検査に今の名前を使う。`
3. `state` は触らない(判断5 の方針どおり)。`deleteCategory` は変えない。

### 追補のテスト

- `test/state/category_list_notifier_test.dart`(既存の Fake の使い方に合わせる):
  - 追加が成功した直後(ストリームがまだ新しい値を流していない状態)に同じ名前を追加すると `AddCategoryRejected`(重複)になる。Fake の `watchAll` が追加を即時に流す作りなら、流さない状態を作れる形で書く。作れなければ、その旨を報告に書いてこのケースは省略してよい
  - 名前変更の直後に、別のカテゴリをその名前に変えると `RenameCategoryRejected` になる(同上)
  - ストリームの最初の値が届く前に `addCategory` を呼んでも、既存名との重複を検出する
- ウィジェットテスト(`item_edit_screen` の既存テストファイル。無ければ `test/ui/screens/item_edit_screen_test.dart` を既存の画面テストの形で作る):
  - カテゴリのストリームが値を流さずに失敗する状態で、カテゴリ付きの項目の名前だけを変えて保存すると、`editItem` に元のカテゴリ ID が渡る(未分類にならない)
