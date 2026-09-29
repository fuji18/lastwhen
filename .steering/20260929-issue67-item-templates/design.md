# 設計: よくある項目のワンタップ追加(F17 / Issue #67)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - パッケージ・アセットを追加しない。`pubspec.yaml` を変更しない
> - **`lib/data/` を触らない**(スキーマ・マイグレーション・リポジトリは変えない)。`lib/state/` も変えない(既存の `addItem` をそのまま使う)
> - 色・余白・タイポは `Theme.of(context)` から取る。UI 文言は本書の表記どおり
> - 既存テストの期待値を緩めない。§6-4 の「finder の絞り込み」だけは許可する

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | UI 上の呼び名は**「よくある項目」**。「テンプレート」は画面に出さない(コード上の型名は `ItemTemplate`) | 利用者に馴染みのない語を避ける。glossary に追加して表記を固定する |
| B | 入口は **2 つ**。**一覧の空状態**ではタップで**即追加**(1 タップ)。**登録画面**ではタップで**項目名とアイコンを入力欄に入れるだけ**(保存は「保存」ボタン) | 空状態は 1 件追加した時点で消えるため、空状態だけでは 2 件目以降に届かない。登録画面は入力途中のフォームがあるため、即保存すると入力とカテゴリの選択を捨ててしまう |
| C | 登録画面では、**登録済みの項目と同名(前後の空白を除いて完全一致)のよくある項目を出さない**。1 件も残らなければ欄ごと出さない | 同じ名前の二重登録を防ぐ。無効化で残すより、選べないものを見せないほうが迷わない |
| D | 空状態は項目 0 件のときだけ出るので同名は起こらない。代わりに**追加中は全チップを塞ぎ**、成功したら塞いだまま(空状態は一覧の再送出で消える)。失敗したら塞ぎを解く | 追加の完了から一覧の再送出までの間に同じチップを押すと二重登録になるため |
| E | 二度押しの判定は**ハンドラの先頭**でも行う(`if (_busy) return;`)。UI の無効化だけに頼らない | `setState` の再描画前に 2 回目のタップが届くと、古い `onPressed` が呼ばれる |
| F | よくある項目は**アイコンを持ち、カテゴリは持たない**。空状態から追加するときのカテゴリは、既存の「項目を追加」ボタンと同じく**一覧で選択中のカテゴリ**(`filter`) | カテゴリはユーザーが名前変更・削除できるため、名前で引く初期値は壊れやすい。F13 の「絞り込み中に追加すると選択中のカテゴリが既定」に揃える |
| G | 定義は **`lib/domain/item_template.dart` の定数**。名前は `validateItemName` を通る値(テストで保証) | 何にも依存しない値なので domain に置く(`domain/` は flutter も import しない) |
| H | 名前は「歯ブラシ」ではなく**「歯ブラシ交換」**にする。他の 5 件は PRD のまま | 「歯ブラシ」だけでは何をした日か読めない。他の 5 件は場所・行為として読める |
| I | 楽観的更新をしない。追加の完了を待ち、`watchAll()` の再送出で一覧に出る | CLAUDE.md「譲らない設計判断」 |
| J | 空状態からの追加に成功しても `SnackBar` を出さない。失敗したら登録画面と同じ文言の `SnackBar` を出す | 成功は一覧にカードが現れることで伝わる |

## §1 ドメイン: `lib/domain/item_template.dart`(新規)

```dart
import 'item_icon.dart';

/// よくある項目(F17)。一覧の空状態からワンタップで追加し、登録画面では入力欄に入れる。
///
/// **カテゴリは持たない**(ユーザーが名前変更・削除できるため。design.md 判断F)。
final class ItemTemplate {
  const ItemTemplate({required this.name, required this.icon});

  /// 項目名。`validateItemName` を通る値(前後の空白なし・1〜50 文字)。
  final String name;

  /// 追加する項目のアイコン。
  final ItemIcon icon;
}

/// よくある項目の一覧。**表示順 = 宣言順。**
const List<ItemTemplate> itemTemplates = [
  ItemTemplate(name: '歯ブラシ交換', icon: ItemIcon.cleaning),
  ItemTemplate(name: '美容院', icon: ItemIcon.haircut),
  ItemTemplate(name: 'エアコン掃除', icon: ItemIcon.airConditioner),
  ItemTemplate(name: '歯医者', icon: ItemIcon.hospital),
  ItemTemplate(name: '洗車', icon: ItemIcon.car),
  ItemTemplate(name: '布団干し', icon: ItemIcon.bed),
];

/// [existingNames](登録済みの項目名)と同名のものを除いたよくある項目。順序は [itemTemplates] のまま。
///
/// 比較は前後の空白を除いた完全一致(項目名は保存前にトリムされるため)。
List<ItemTemplate> availableItemTemplates(Iterable<String> existingNames) {
  final names = {for (final name in existingNames) name.trim()};
  return [
    for (final template in itemTemplates)
      if (!names.contains(template.name)) template,
  ];
}
```

## §2 UI: `lib/ui/widgets/item_template_chips.dart`(新規)

よくある項目のチップ列。**`Wrap` だけを返す(`Column` で包まない)**。見出しは呼び出し側が置く
(空状態のテストが `EmptyState` 配下の `Column` を 1 つと仮定しているため。§6-4)。

```dart
import 'package:flutter/material.dart';

import '../../domain/item_template.dart';
import '../item_icon_glyph.dart';

/// よくある項目(F17)のチップ列。
class ItemTemplateChips extends StatelessWidget {
  /// チップ列を作る。
  const ItemTemplateChips({
    required this.templates,
    required this.onPressed,
    required this.tooltipBuilder,
    this.enabled = true,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  /// 並べるよくある項目。この順に並ぶ。
  final List<ItemTemplate> templates;

  /// チップが押されたときの処理。
  final ValueChanged<ItemTemplate> onPressed;

  /// チップのツールチップ(読み上げにも使われる)。押すと何が起きるかを書く。
  final String Function(ItemTemplate) tooltipBuilder;

  /// false なら全チップを塞ぐ(追加中・保存中)。
  final bool enabled;

  /// 行内の寄せ方。
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final template in templates)
          ActionChip(
            avatar: Icon(itemIconData(template.icon)),
            label: Text(template.name),
            tooltip: tooltipBuilder(template),
            onPressed: enabled ? () => onPressed(template) : null,
          ),
      ],
    );
  }
}
```

## §3 UI: 一覧の空状態

### `lib/ui/widgets/empty_state.dart`

`EmptyState` を **`StatefulWidget`** に変える。

- 引数: 既存の `onAddPressed` に加えて `required Future<bool> Function(ItemTemplate) onTemplatePressed`
  (よくある項目を追加する。**追加できたら true**)。doc コメントに「true を返したら塞いだままにする(判断D)」と書く
- State に `bool _isAdding = false;`(doc: 「追加中は全チップを塞ぐ。成功したら塞いだまま、一覧の再送出で空状態ごと消える(design.md 判断D)」)
- ハンドラ:

```dart
  Future<void> _addTemplate(ItemTemplate template) async {
    // 再描画の前に 2 回目のタップが届いても二重登録しない(判断E)。
    if (_isAdding) {
      return;
    }
    setState(() => _isAdding = true);
    final added = await widget.onTemplatePressed(template);
    if (!mounted || added) {
      return;
    }
    setState(() => _isAdding = false);
  }
```

- build: 既存の `Column` の children の**末尾**(「項目を追加」ボタンの後)に次を足す。新しい `Column` を作らない:

```dart
          const SizedBox(height: 32),
          Text(
            'よくある項目からすぐ追加',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ItemTemplateChips(
            templates: itemTemplates,
            alignment: WrapAlignment.center,
            enabled: !_isAdding,
            tooltipBuilder: (template) => '${template.name}を追加',
            onPressed: (template) => unawaited(_addTemplate(template)),
          ),
```

  (`dart:async` の `unawaited` を import する。既存の文言・アイコン・ボタンは変えない)

- クラスの doc コメントに 1 行足す: 「よくある項目(F17)を 1 タップで追加できる。確認は出さない」

### `lib/ui/screens/item_list_screen.dart`

`EmptyState(...)` の呼び出しに `onTemplatePressed` を渡す:

```dart
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: () =>
                _openAddScreen(context, initialCategoryId: filter),
            onTemplatePressed: (template) =>
                _addTemplate(template, categoryId: filter),
          ),
```

`_ItemListScreenState` にメソッドを足す:

```dart
  /// よくある項目を確認なしで追加する(F17)。追加できたら true。
  ///
  /// カテゴリは「項目を追加」と同じく選択中の絞り込み(design.md 判断F)。
  Future<bool> _addTemplate(ItemTemplate template, {CategoryId? categoryId}) async {
    final result = await ref
        .read(itemListProvider.notifier)
        .addItem(template.name, icon: template.icon, categoryId: categoryId);
    if (result is AddItemSucceeded) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
    }
    return false;
  }
```

(`AddItemRejected` はよくある項目では起きない(§6-1 で保証)が、起きても失敗と同じ扱いにする。
import: `../../domain/item_template.dart` / `../../state/add_item_result.dart`)

## §4 UI: 登録画面 `lib/ui/screens/item_add_screen.dart`

- `build` の先頭で、登録済みの名前から出すものを決める:

```dart
    // 一覧が未取得なら同名を判定できないので出さない(判断C)。
    final items = ref.watch(itemListProvider).value;
    final templates = items == null
        ? const <ItemTemplate>[]
        : availableItemTemplates(items.map((item) => item.name));
```

- `TextField` と `ItemIconPicker` の間(`const SizedBox(height: 24)` の直後)に、`templates` が空でなければ次を挟む
  (既存の `Column` の children に `if (templates.isNotEmpty) ...[ ... ]` で足す):

```dart
                  Text('よくある項目から選ぶ', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ItemTemplateChips(
                    templates: templates,
                    enabled: !_isSaving,
                    tooltipBuilder: (template) => '${template.name}を入力',
                    onPressed: _applyTemplate,
                  ),
                  const SizedBox(height: 24),
```

- メソッドを足す:

```dart
  /// よくある項目の名前とアイコンを入力欄に入れる。**保存はしない**(判断B)。カテゴリは変えない。
  void _applyTemplate(ItemTemplate template) {
    _controller.value = TextEditingValue(
      text: template.name,
      selection: TextSelection.collapsed(offset: template.name.length),
    );
    setState(() {
      _icon = template.icon;
      _errorText = null;
    });
  }
```

- クラスの doc コメントに 1 行足す: 「よくある項目(F17)を選ぶと項目名とアイコンが入る。登録済みと同名のものは出さない」
- import: `../../domain/item_template.dart` / `../widgets/item_template_chips.dart`

## §5 docs の更新

### `docs/product-requirements.md`

1. KPI 節の「計測の前提」段落の末尾の括弧書き「テンプレート項目 F17 は P2 で、前倒しの判断材料になる」を
   「よくある項目 F17 はこの理由で P1 に前倒しした(#67)」に置き換える
2. P2 表の F17 行を削除し、**P1 表の F16 行の直後**に次の行を足す:
   `| F17 | よくある項目のワンタップ追加 | 歯ブラシ交換・美容院・エアコン掃除・歯医者・洗車・布団干しを、一覧の空状態から 1 タップで**未実施**の項目として追加する(確認なし)。登録画面ではタップで項目名とアイコンを入力欄に入れる。登録済みと同名のものは出さない。ユーザーによる追加・編集はしない |`
3. P1 の「追記(#63)」段落の後に段落を足す:
   > **追記(#67)**: F17 を P2 から P1 に前倒しした。KPI「初回 3 件以上登録」に最も効く機能で、Android 先行リリースの
   > 前に入れる。空状態は 1 件追加した時点で消えるため、2 件目以降に届くよう登録画面にも入口を置く。登録画面では
   > 入力途中のフォームを捨てないよう、即追加ではなく入力欄に入れるだけにする。呼び名は「よくある項目」とし、
   > 「歯ブラシ」は何をした日か読めるよう「歯ブラシ交換」にした。
4. P2 表の直後の注記「F17(テンプレート項目)は P2 に置いたが…」の 2 行を削除する

### `docs/functional-design.md`

1. 「画面遷移図」の mermaid に 1 行足す(`一覧 --> 一覧: 「やった」をタップ(遷移しない)` の直後):
   `一覧 --> 一覧: 空状態のよくある項目をタップ(遷移しない / F17)`
2. 「UC2: 項目を登録する(F2)」の mermaid の後に注記を足す:
   > よくある項目(F17)は同じ `addItem` を通る。空状態のチップは項目名とアイコンをそのまま渡して即保存し、
   > 登録画面のチップは入力欄を埋めるだけで、保存はこの UC と同じ流れになる。
3. 「UI設計」の「### 図鑑(F31)」節の直前に節を足す:

   ```markdown
   ### よくある項目(F17)

   歯ブラシ交換・美容院・エアコン掃除・歯医者・洗車・布団干しの 6 件。定義は `lib/domain/item_template.dart` の定数で、
   それぞれアイコンを持つ(カテゴリは持たない)。

   - **一覧の空状態**: 「項目を追加」の下に「よくある項目からすぐ追加」とチップを並べる。**タップで未実施の項目として
     即追加する(確認なし)**。カテゴリは「項目を追加」と同じく選択中の絞り込み。追加中は全チップを塞ぎ、失敗したら
     登録画面と同じ `SnackBar` を出して塞ぎを解く。成功時は何も出さない(カードが現れる)
   - **登録画面**: 項目名の下に「よくある項目から選ぶ」とチップを並べる。**タップで項目名とアイコンを入力欄に入れるだけ**
     で、保存は「保存」ボタン。カテゴリの選択は変えない
   - **登録済みの項目と同名(前後の空白を除いて完全一致)のものは出さない。** 1 件も残らなければ欄ごと出さない
   - 画面上の呼び名は「よくある項目」。「テンプレート」とは書かない
   ```

4. 「状態ごとの表示」表の「項目 0 件」行を
   `空状態。「まだ項目がありません」+ 追加への導線 + よくある項目(F17)を画面中央に置く` にする
5. 「ウィジェットテスト」表の末尾に行を足す:
   `| よくある項目 | 空状態のチップ 1 タップで確認なしに未実施の項目が一覧に出る。登録画面では同名のものが出ず、タップで入力欄が埋まる |`

### `docs/glossary.md`

「### 並び順(Sort Order)【P1】」節の直後(「## アプリの技術用語」の前)に節を足す。書式は直前の節に合わせる:

- 見出し: `### よくある項目(Item Template)【P1】`
- 本文: 「一覧の空状態・登録画面からワンタップで使える項目名とアイコンの組(F17)。歯ブラシ交換・美容院・エアコン掃除・歯医者・洗車・布団干しの 6 件。画面では「よくある項目」と呼び、「テンプレート」とは書かない。コード上の型名は `ItemTemplate`。」

## §6 テスト

### §6-1 `test/domain/item_template_test.dart`(新規)

- `itemTemplates` の名前が順に `['歯ブラシ交換', '美容院', 'エアコン掃除', '歯医者', '洗車', '布団干し']`
- すべての名前が `validateItemName` で `ValidItemName` になり、`value` が名前と等しい(トリムで変わらない)
- 名前に重複がない
- `availableItemTemplates([])` は `itemTemplates` と等しい
- `availableItemTemplates(['  美容院 ', '洗車', '散髪'])` は美容院・洗車を除いた 4 件を元の順で返す

### §6-2 `test/ui/item_list_screen_test.dart` に `group('よくある項目(F17)', ...)` を足す

既存の `_app` / `repository` / `now` を使う。チップは `find.widgetWithText(ActionChip, '洗車')` で引く。

1. **空状態によくある項目が並ぶ**: 0 件で起動 → `EmptyState` 配下の `ActionChip` が 6 個、`よくある項目からすぐ追加` が出る
2. **1 タップで確認なしに未実施で追加される**: 0 件で起動 → 「洗車」をタップ → `pumpAndSettle` → `AlertDialog` が無い /
   `EmptyState` が無い / `ItemCard` が 1 つで「洗車」と「未実施」を含む / `repository.watchAll().first` が 1 件で、
   `name == '洗車'`・`icon == ItemIcon.car`・`lastDoneAt == null`
3. **二度押しで二重登録しない**: 0 件で起動 → 同じチップに `tester.tap` を**間に pump を挟まず 2 回** → `pumpAndSettle` →
   リポジトリが 1 件
4. **保存失敗なら SnackBar を出してもう一度押せる**: `repository.writeError = StateError('write failed')` → タップ →
   `pumpAndSettle` → `保存できませんでした。もう一度お試しください` が出る / `EmptyState` が残る /
   「洗車」チップの `onPressed` が null でない / リポジトリが 0 件

### §6-3 `test/ui/item_add_screen_test.dart` にテストを足す

1. **タップで項目名とアイコンが入り、保存で登録される**: 既存の `openAddScreen` で開く → 「布団干し」チップをタップ →
   `TextField` の `controller.text == '布団干し'` / リポジトリは 0 件のまま(保存していない) → 「保存」をタップ →
   リポジトリが 1 件で `name == '布団干し'`・`icon == ItemIcon.bed`
2. **登録済みと同名のよくある項目は出ない**: `repository.add('美容院', now: now)` してから起動 → FAB で登録画面を開く →
   `ItemAddScreen` 配下の `ActionChip` が 5 個で、「美容院」の `ActionChip` が無い
3. **すべて登録済みなら欄を出さない**: `itemTemplates` の 6 件をすべて `repository.add` してから起動 → FAB →
   `よくある項目から選ぶ` が無い / `ActionChip` が無い

### §6-4 既存テストへの影響(許可する変更はこれだけ)

空状態・登録画面に「美容院」「洗車」などの**チップの文字列**が出るようになるため、既存テストの
`find.text('美容院')` 等が**チップにも当たって**件数がずれる(例: 削除後に空状態へ戻り `findsNothing` を期待する箇所)。
該当箇所に限り、**finder を項目のカードや入力欄に絞る**(`find.descendant(of: find.byType(ItemCard), matching: ...)`、
`find.widgetWithText(ItemCard, ...)` など)ことを許可する。**期待値(`findsNothing` / `findsOneWidget` 等)は変えない。**
変更した箇所は `tasklist.md` の該当タスクにファイル名と行で列挙する。これ以外の理由で既存テストが落ちたら止めて報告する。

### §6-5 `test/ui/accessibility_test.dart`

既存の「文字サイズ 200%」テストと同じ設定方法で 1 件足す: **文字サイズ 200% で空状態のよくある項目が押せる** —
0 件で起動 → `tester.takeException()` が null → 「布団干し」チップを `ensureVisible` してタップ → `pumpAndSettle` →
`ItemCard` が 1 つ出る。

## §7 完了条件

- `dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` が 0 件
- `flutter test` が通る(委託先で実行できない場合は「ホスト委任」と記録して検収側に委ねる)
- `lib/data/` / `lib/state/` / `pubspec.yaml` に差分が無い
