# 設計: 項目ごとのアイコン設定(Issue #32 / F14)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **スコープ判断(司令塔)**: F14 は P1 だが、**P0 はすべてクローズ済み**で MVP 完了後の P1 として
>   着手する。「P0 以外を実装しない」の前倒しには当たらない(ユーザーが `/next-ticket` で着手を指示済み)
> - **このチケットは委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れる。Codex に委託しない**
> - **依存は増えない。** `pubspec.yaml` を変更しない。`drift_dev` / `build_runner` は導入済み
> - 追加の UI パッケージを入れない。アイコンは Flutter 同梱の `Icons.*` だけを使う

## 0. 全体像

```
domain  : ItemIcon(enum。保存キーを持つ) / Item.icon(ItemIcon?  null = 未選択)
data    : items.icon TEXT NULL(v3)  ←→  ItemIcon.fromKey / .key
          ItemRepository.add(name, icon:, now:) / edit(id, name:, icon:, now:)   ※ rename を置き換える
state   : ItemView.icon / ItemListNotifier.addItem(rawName, icon:) / editItem(id, rawName, icon:)
ui      : item_icon_glyph.dart(ItemIcon → IconData・日本語名)
          ItemIconPicker(登録・編集) / ItemCard(掠れつき) / ItemDetailSheet
```

- **NULL = 未選択**。未選択は UI で既定アイコン `Icons.event_repeat` を描く。「既定アイコン」を DB に書き込まない
  (#33 のカテゴリから既定アイコンを決める余地を残す)
- **DB に保存するのは `ItemIcon.key`(不変の文字列)**。`IconData.codePoint` や enum の `name` を保存しない
  (前者は Flutter の更新で変わりうる。後者は Dart のリネームで保存値の意味が変わる)

## 判断1: ドメイン `lib/domain/item_icon.dart`(新規)

`lib/domain/` は Flutter に依存できない(レイヤー依存テストあり)。**`IconData` と日本語名は UI 層に置く**(判断6)。

```dart
/// 項目に付けるアイコンの種類。**表示順 = 宣言順。**
///
/// [key] は DB(`items.icon`)に保存する値。**一度出荷したキーは変えない・消さない。**
/// 候補を減らすときも enum 値は残す(保存済みの項目が未選択に落ちるため)。
enum ItemIcon {
  cleaning('cleaning'),
  bath('bath'),
  trash('trash'),
  laundry('laundry'),
  bed('bed'),
  kitchen('kitchen'),
  airConditioner('air_conditioner'),
  lightbulb('lightbulb'),
  battery('battery'),
  plant('plant'),
  garden('garden'),
  pet('pet'),
  haircut('haircut'),
  beauty('beauty'),
  medicine('medicine'),
  hospital('hospital'),
  vaccine('vaccine'),
  exercise('exercise'),
  reading('reading'),
  car('car'),
  fuel('fuel'),
  shopping('shopping'),
  clothes('clothes'),
  cafe('cafe');

  const ItemIcon(this.key);

  /// DB に保存する不変のキー。
  final String key;

  /// 保存値から戻す。**null・未知のキーは null(未選択)にする。例外にしない。**
  static ItemIcon? fromKey(String? key) { ... }  // values を線形探索でよい(24 件)
}
```

`lib/domain/item.dart` の `Item`:

- `final ItemIcon? icon;` を足す。doc: `/// 項目のアイコン。**null は未選択**(UI が既定アイコンを描く)。`
- コンストラクタは `this.icon` の**省略可能な名前付き引数**(既定 null)。既存の `Item(...)` 呼び出しを壊さない
- `==` / `hashCode` に含める(`Object.hash` の引数に足す)

## 判断2: スキーマ v3(`lib/data/database/app_database.dart`)

`Items` に列を 1 つ足す(`sortOrder` の後):

```dart
  /// アイコンの保存キー(`ItemIcon.key`)。**NULL = 未選択。** v3 で追加。
  ///
  /// CHECK 制約を付けない。候補は今後増えるうえ、一度出荷した制約は修正できない。
  /// 未知の値はドメインへの変換で未選択として扱う。
  TextColumn get icon => text().named('icon').nullable()();
```

- `schemaVersion => 3`
- `AppDatabase` の doc コメントは変えなくてよい(テーブル構成は変わらない)

## 判断3: マイグレーション(`lib/data/migrations/migrations.dart`)

**手順(#20 と同じ `make-migrations`。順序を守る)**:

1. 判断2 の変更と `schemaVersion => 3`
2. `dart run build_runner build --delete-conflicting-outputs`
3. `dart run drift_dev make-migrations`
   → `drift_schemas/app_database/drift_schema_v3.json`、再生成された `lib/data/database/app_database.steps.dart`、
   `test/data/drift/app_database/generated/schema_v3.dart`(と `schema.dart` の更新)ができる。できなければ停止して報告
4. 生成物はすべてコミット対象。**生成物を手で編集しない**(format だけは `dart format` をかけてよい)
5. **`test/data/drift/app_database/migration_test.dart` が再生成で上書きされていたら**、#20 の内容に戻す:
   `AppDatabase(schema.newConnection())` → `AppDatabase.forTesting(schema.newConnection())`、
   `openTestedDatabase: AppDatabase.forTesting`、v1→v2 のデータ検証テストを復元する(`git diff` で確認できる)。
   上書きされていなければそのまま追記する

`stepByStep` に `from2To3` を**足す**(`from1To2` は一文字も変えない):

```dart
      from2To3: (m, schema) async {
        // 列の追加だけ。既存行は NULL(= 未選択)になる。データの移送は無い。
        await m.addColumn(schema.items, schema.items.icon);
      },
```

- ファイル先頭の doc コメントの「v3 を足すときは `from2To3` を新しく足す」を「v4 を足すときは `from3To4` を新しく足す」に直す
- 生成された `schema.items.icon` のゲッター名が違えば**生成物の名前に合わせる**(設計判断ではない)

## 判断4: リポジトリ

### `lib/domain/item_repository.dart`

```dart
  /// 項目を追加する。id は UUID v4 で実装側が採番する。[icon] が null なら未選択。
  Future<Item> add(String name, {ItemIcon? icon, required DateTime now});

  /// 項目名とアイコンを変更する。**最終実施日と履歴は変えない。**
  /// [icon] に null を渡すと未選択に戻す(「変更しない」の意味ではない)。
  Future<void> edit(
    ItemId id, {
    required String name,
    required ItemIcon? icon,
    required DateTime now,
  });
```

- **`rename` を削除し `edit` に置き換える**(`icon` の null が「未選択に戻す」を意味するため、
  optional 引数で足すと「変更しない」と区別できない)
- import に `item_icon.dart` を足す

### `lib/data/item_repository_impl.dart`

- `add`: `ItemRow(..., icon: icon?.key)`。戻り値の `_toDomain` もそのまま使える
- `edit`: `rename` の本体を置き換え、`ItemsCompanion(name: Value(name), icon: Value(icon?.key), updatedAt: Value(...))`。
  `lastDoneAt` を companion に載せない(既存のコメントを残す)
- `_toDomain`: `icon: ItemIcon.fromKey(row.icon)`

### `test/support/fake_item_repository.dart`

- `add` に `ItemIcon? icon` を足し、`Item(..., icon: icon)`
- `rename` → `edit`。`_copy(item, name: name, icon: icon, updatedAt: ...)`
- `_copy` に `Object? icon = _unset` を足す(`lastDoneAt` と同じ番兵方式。null が「未選択」の意味を持つため)。
  `icon: identical(icon, _unset) ? source.icon : icon as ItemIcon?`

## 判断5: 状態管理

### `lib/state/item_view.dart`

- `final ItemIcon? icon;` を足す(コンストラクタは省略可能な名前付き、既定 null)。doc: `/// 項目のアイコン。null は未選択(UI が既定アイコンを描く)。`
- `ItemView.from` で `icon: item.icon`
- `==` / `hashCode` に含める

### `lib/state/item_list_notifier.dart`

- `addItem(String rawName, {ItemIcon? icon})` → `repository.add(value, icon: icon, now: ...)`
- `renameItem(ItemId id, String rawName)` を **`editItem(ItemId id, String rawName, {required ItemIcon? icon})`** に置き換える。
  中身は同じ(検証 → 存在確認 → `repository.edit(id, name: value, icon: icon, now: ...)`)。
  ログ文言は `'項目の変更に失敗しました'`。doc の「項目名を変更する」を「項目名とアイコンを変更する」に直す

### `lib/state/edit_item_result.dart`

- `RenameItemResult` / `RenameItemSucceeded` / `RenameItemRejected` / `RenameItemIgnored` / `RenameItemFailed` を
  **`EditItemResult` / `EditItemSucceeded` / `EditItemRejected` / `EditItemIgnored` / `EditItemFailed`** にリネームする
  (中身・doc は「項目名の変更」→「項目の変更」以外そのまま)。参照箇所(lib / test)をすべて追従させる

## 判断6: UI の対応表 `lib/ui/item_icon_glyph.dart`(新規)

```dart
/// 未選択の項目に描く既定アイコン。
const IconData defaultItemIconData = Icons.event_repeat;

/// アイコンの描画データ。[icon] が null なら [defaultItemIconData]。
IconData itemIconData(ItemIcon? icon) => switch (icon) { null => defaultItemIconData, ItemIcon.cleaning => ..., ... };

/// 選択肢の読み上げ・ツールチップに使う日本語名。
String itemIconLabel(ItemIcon icon) => switch (icon) { ... };
```

`switch` は網羅(`default` を書かない。enum を足したときにコンパイルエラーで気づけるように)。

| ItemIcon | `Icons.*` | 日本語名 |
| --- | --- | --- |
| cleaning | `cleaning_services` | 掃除 |
| bath | `bathtub` | 風呂 |
| trash | `delete` | ゴミ出し |
| laundry | `local_laundry_service` | 洗濯 |
| bed | `bed` | 寝具 |
| kitchen | `kitchen` | 冷蔵庫 |
| airConditioner | `air` | エアコン |
| lightbulb | `lightbulb` | 電球 |
| battery | `battery_charging_full` | 電池 |
| plant | `local_florist` | 植物 |
| garden | `yard` | 庭 |
| pet | `pets` | ペット |
| haircut | `content_cut` | 美容院 |
| beauty | `face` | 美容 |
| medicine | `medication` | 薬 |
| hospital | `local_hospital` | 病院 |
| vaccine | `vaccines` | 予防接種 |
| exercise | `fitness_center` | 運動 |
| reading | `menu_book` | 読書 |
| car | `directions_car` | 車 |
| fuel | `local_gas_station` | 給油 |
| shopping | `shopping_cart` | 買い物 |
| clothes | `checkroom` | 衣類 |
| cafe | `local_cafe` | カフェ |

「指定なし」の選択肢の日本語名は `'指定なし'`(ピッカー側に定数で持つ)。

## 判断7: アイコンの掠れ(`lib/ui/theme/app_theme.dart`)

経年ステージが進むほどアイコンを薄くする。テーマファイルに関数を 1 つ足す(`AgingPalette` の後):

```dart
/// 経年ステージごとの項目アイコンの不透明度(掠れ)。`colorScheme.onSurface` に掛ける。
///
/// **テキストには掛けない**(テキストの色は変えない方針)。アイコンは装飾なので薄くしてよいが、
/// 形が読めるよう紙に対して 3:1 以上を保つ(`test/ui/theme/aging_palette_test.dart`)。
double agingIconOpacity(AgingStage stage) => switch (stage) {
  AgingStage.fresh => 1.0,
  AgingStage.slightlyAged => 0.9,
  AgingStage.dueSoon => 0.8,
  AgingStage.aged => 0.7,
  AgingStage.heavilyAged => 0.6,
};
```

## 判断8: 一覧カード(`lib/ui/widgets/item_card.dart`)

- 定数 `const double itemCardIconSize = 24;` と、非公開ウィジェット `_ItemGlyph({required ItemView item})` を足す:
  `Icon(itemIconData(item.icon), size: itemCardIconSize, color: theme.colorScheme.onSurface.withValues(alpha: agingIconOpacity(item.agingStage)))`
- **配置**: アイコンは読み上げ用 `Semantics(label: itemCardSemanticsLabel(item), excludeSemantics: true)` の**内側**に置く
  (= 読み上げに含まれない。`itemCardSemanticsLabel` は変えない)
  - `_InlineLayout`: 内側の `Row` を `[_ItemGlyph, SizedBox(width: 8), Expanded(_NameAndLastDone), SizedBox(width: 12), _Elapsed]` にする
  - `_StackedLayout`: `_NameAndLastDone(item: item)` を `Row(children: [_ItemGlyph, SizedBox(width: 8), Expanded(child: _NameAndLastDone)])` に置き換える
- **縦積みのしきい値を 1.3 → 1.2 に下げる**(`itemCardStackThreshold = 1.2`)。アイコン 24dp + 間隔 8dp の分だけ項目名の取り分が減るため。
  doc コメントを次に直す:

  ```dart
  /// 1.2 未満なら「アイコン 24dp + 経過日数の実寸 + ボタン 56dp」を 360dp 幅に置いても項目名の取り分が
  /// 残る(1.19 倍で約 61dp)。1.2 以上では取り分が細るので縦に積む(#9 判断1 / #32 判断8)。
  ```

- クラス doc の「「項目名 + 最終実施日」「経過日数」「やった」を横に並べ」を「「アイコン + 項目名 + 最終実施日」…」に直し、
  「アイコンは経年ステージに応じて掠れる(`agingIconOpacity`)」を 1 行足す

## 判断9: 詳細シート(`lib/ui/widgets/item_detail_sheet.dart`)

見出しの `Semantics(header: true, child: Text(item.name, ...))` を次で包む:

```dart
Row(
  children: [
    // 装飾。見出しの読み上げは項目名だけにする。
    ExcludeSemantics(
      child: Icon(itemIconData(item.icon), size: 32, color: theme.colorScheme.onSurface),
    ),
    const SizedBox(width: 12),
    Expanded(child: /* 既存の Semantics(header: true, child: Text(...)) */),
  ],
),
```

シートでは掠れを掛けない(状態は文言で示している)。

## 判断10: ピッカー `lib/ui/widgets/item_icon_picker.dart`(新規)

```dart
/// アイコンの選択欄。先頭が「指定なし」(null)、以降は `ItemIcon.values` の順。
class ItemIconPicker extends StatelessWidget {
  const ItemIconPicker({required this.selected, required this.onChanged, this.enabled = true, super.key});

  /// 選択中のアイコン。null は「指定なし」。
  final ItemIcon? selected;
  final ValueChanged<ItemIcon?> onChanged;

  /// 保存中は false(タップを塞ぐ)。
  final bool enabled;
}
```

- 構成: `Column(crossAxisAlignment: start, mainAxisSize: min)` に
  `Text('アイコン', style: theme.textTheme.titleSmall)` → `SizedBox(height: 8)` → `Wrap(spacing: 8, runSpacing: 8, children: tiles)`
- 各タイル: `IconButton.outlined(isSelected: value == selected, onPressed: enabled ? () => onChanged(value) : null, tooltip: label, icon: Icon(itemIconData(value)))`
  - 「指定なし」タイルは `value = null`、`label = '指定なし'`、アイコンは `defaultItemIconData`
  - **`IconButton` は M3 で `isSelected` を `Semantics(selected: ...)` として出し、`tooltip` が読み上げラベルになる**。
    自前で `Semantics` を足さない。タップ領域は既定の 48dp(`tapTargetSize` を変えない)
- 選んだタイルをもう一度押しても選択は外れない(`onChanged(value)` が同じ値を返すだけ)。外すのは「指定なし」を押す

## 判断11: 登録・編集画面

### `lib/ui/screens/item_add_screen.dart`

- state に `ItemIcon? _icon;`(初期 null)
- `TextField` の後に `const SizedBox(height: 24)`、`ItemIconPicker(selected: _icon, onChanged: (v) => setState(() => _icon = v), enabled: !_isSaving)`、
  続けて既存の `SizedBox(height: 24)` + 保存ボタン
- `_save` は `addItem(_controller.text, icon: _icon)`
- `autofocus: true` は**維持**(30 秒要件)
- クラス doc の「カテゴリ・アイコン・目安期間は P1。ここで入力項目を増やすと…」を次に直す:
  「**必須の入力は項目名 1 つだけ**(F2)。アイコン(F14)は任意で、選ばなければ既定アイコンになる。
  必須の入力を増やすと「30 秒以内に登録できる」という成功指標と衝突する。」

### `lib/ui/screens/item_edit_screen.dart`

- コンストラクタに `this.initialIcon`(`final ItemIcon? initialIcon;` 省略可能・既定 null。doc: 開いた時点のアイコン(保存済みの値))
- state に `late ItemIcon? _icon = widget.initialIcon;`
- `TextField` と保存ボタンの間に、登録画面と同じ並びでピッカー(`enabled: !_isBusy`)
- `_save` は `editItem(widget.itemId, _controller.text, icon: _icon)`、結果型は `EditItem*`
- クラス doc の「変更できるのは項目名だけ」を「変更できるのは項目名とアイコン(F6 / F14)」に直す

### `lib/ui/screens/item_list_screen.dart`

- `_openEditScreen` で `ItemEditScreen(itemId: item.id, initialName: item.name, initialIcon: item.icon)`

## 判断12: テスト

既存テストは rename → edit / `RenameItem*` → `EditItem*` の追従以外、期待値を変えない。追加するもの:

1. `test/domain/item_icon_test.dart`(新規): キーが全て一意 / `fromKey` がキーから戻る / `fromKey(null)`・`fromKey('unknown')` が null
2. `test/domain/item_test.dart`: `icon` が `==` に効く(1 ケース)
3. `test/data/drift/app_database/migration_test.dart`: **v2 → v3 のデータ検証テスト**を足す。
   v2 の `items` 2 行(記録済み・未実施)と `done_logs` 1 行を入れ、v3 で `items` の既存列が不変・`icon` が null、
   `done_logs` が不変であることを `v3.ItemsData` / `v3.DoneLogsData` との比較で確かめる(v1→v2 テストと同じ書き方)
4. `test/data/item_repository_impl_test.dart`:
   - `schemaVersion は 2` → `3` に直す
   - アイコンつきで `add` すると `watchAll` にそのアイコンで出る / 省略すると null
   - `edit` でアイコンだけ変えても `lastDoneAt` と `recentDoneAts` が変わらない / `icon: null` で未選択に戻る
   - DB に未知のキーを直接書く(`customStatement('UPDATE items SET icon = ? WHERE id = ?', ['unknown', id])`)と null で読める
   - 同じシナリオを Fake にも当てるグループがあれば、そちらにも add / edit のアイコンのケースを足す
5. `test/state/item_list_notifier_test.dart`: `group('renameItem')` を `group('editItem')` にし、呼び出しを `editItem(id, name, icon: null)` へ。
   アイコンが保存されるケース・`addItem(name, icon: ItemIcon.bath)` のケースを 1 つずつ足す
6. `test/state/item_view_test.dart`: `ItemView.from` が `icon` を引き継ぐ
7. `test/ui/widgets/item_icon_picker_test.dart`(新規): 25 タイルが出る / タップで `onChanged` に値が渡る /
   選択中のタイルの semantics が `isSelected: true` / `enabled: false` でタップしても呼ばれない /
   各タイルが 48x48 以上
8. `test/ui/widgets/item_card_test.dart`:
   - 未選択で `Icons.event_repeat`、`ItemIcon.bath` で `Icons.bathtub` が出る
   - `heavilyAged` のアイコンの色の alpha が `fresh` より小さい
   - カードの読み上げラベルが変わらない(既存テストがそのまま通ればよい)
   - 360x640・文字倍率 1.19・経過日数 `999日前` で例外(オーバーフロー)が出ない / 倍率 1.2 で縦積み
     (縦積みの判定は、経過日数の `Text` の上端がやったボタンの上端より上にあるか等、既存テストの判定方法に合わせる)
9. `test/ui/widgets/item_detail_sheet_test.dart`: アイコンが出る / 見出しの読み上げは項目名だけ
10. `test/ui/item_add_screen_test.dart`: アイコンを選ばず保存 → カードに既定アイコン / 「風呂」を選んで保存 → カードに `Icons.bathtub` /
    入力欄の自動フォーカスが維持される(既存テスト)
11. `test/ui/item_edit_screen_test.dart`: 現在のアイコンが選択状態で開く / アイコンを変えて保存すると一覧に反映、経過日数は不変 /
    「指定なし」で保存すると既定アイコンに戻る
12. `test/ui/theme/aging_palette_test.dart`: 全ステージ × 明暗で
    `Color.alphaBlend(onSurface.withValues(alpha: agingIconOpacity(stage)), paper)` と `paper`、
    および stain を重ねた紙とのコントラストが **3.0 以上**。`agingIconOpacity` がステージ順に単調非増加
13. `test/ui/terminology_test.dart` が UI 文言を検査しているなら、新しい文言(`アイコン` / `指定なし` / 日本語名)が
    禁止語に当たらないことを確認する(当たったら停止して報告)

## 判断13: ドキュメント

- `docs/glossary.md`「items テーブル」: 冒頭の「MVP で唯一のテーブル。」を「MVP から存在するテーブル。」にし、
  行 `| \`icon\` | TEXT NULL | アイコンの保存キー(\`ItemIcon.key\`)。**NULL = 未選択**(既定アイコンで表示)。v3 で追加(#32) |` を足す
- `docs/functional-design.md`:
  - データモデルの Dart コード例(`Item`)に `final ItemIcon? icon;   // null = 未選択(F14)` を足し、制約表に
    `| \`icon\` | NULL 許容。\`ItemIcon.key\` を保存。未知のキーは未選択として読む。CHECK 制約は付けない(候補が増えるため) |` を足す
  - ER 図の `ITEMS` に `text icon "nullable, ItemIcon.key"` を足し、図の前の文に「`icon` 列は v3 で追加した(#32)」を足す
  - リポジトリのインターフェース例(`rename`)を判断4 の `add` / `edit` に、状態管理の例(`renameItem`)を `editItem` に直す
  - 「一覧のカード」の表示項目表の先頭に `| アイコン | 項目のアイコン(未選択は既定) | Material Symbols 24dp。経年ステージで掠れる | 装飾(読み上げない) |` を足し、
    配置の文を「左に「アイコン + 項目名 + 最終実施日」…」に直す
  - 「色の使い方」末尾の「アイコンの掠れは項目アイコン(#32)の導入時に掛ける。」を
    「項目アイコンはステージが進むほど薄くなる(不透明度 1.0 → 0.6。`agingIconOpacity`)。紙に対して 3:1 以上を保つ。」に直す
  - 「詳細シート(F29)」に「見出しの左に項目アイコンを出す(読み上げない)」を 1 行足す
- `docs/architecture.md`「機能拡張性」表に `| P1 アイコン | \`items\` に \`icon\` 列を追加(v3)。UI 層に対応表を置き、ドメインは保存キーだけを持つ |` を足す
- `docs/development-guidelines.md` 32 行目の `rename(name, id)` は引数取り違えの説明例なので**変えない**
- PRD は変えない(F14 の行はそのまま。F2 の「他の入力を必須にしない」を守っている)

## 判断14: 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` を通す。
生成物が analyze / format に引っかかったら、#20 で `analysis_options.yaml` に足した除外設定の範囲で扱う(新しい除外を足す必要が出たら停止して報告)。
