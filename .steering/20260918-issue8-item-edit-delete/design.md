# 設計: 項目の編集と削除(Issue #8)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> `pubspec.yaml` に依存を足す必要が出たときも同じ。
> **データ層(`lib/data/`)とドメイン層(`lib/domain/`)は一切変更しない。** 必要な API
> (`rename` / `delete` / `validateItemName`)は #3・#4 で実装・テスト済み。

## 0. 全体方針

`docs/functional-design.md`「画面遷移図」の `一覧 → 編集 → 削除確認` をそのまま写す。
#6(登録)・#7(記録)で確立した「**状態管理層が sealed な結果型を返し、UI がその分岐を
画面の振る舞いに写す**」パターンの横展開で、新しい仕組みは 1 つも要らない。

```
一覧の行をタップ
  → ItemEditScreen(itemId, initialName) を push(遷移前に clearSnackBars)

[保存]
  → ItemListNotifier.renameItem(id, 入力値)
      → validateItemName          … 落ちたら RenameItemRejected(reason)(書き込まない)
      → 一覧の直前値に id が無い  … RenameItemIgnored(書き込まない)
      → ItemRepository.rename(id, name, now: Clock.now())  … 例外なら RenameItemFailed
      → RenameItemSucceeded
  → 成功 / Ignored なら pop。watchAll() の再送出で一覧の行名が変わる

[削除]
  → AlertDialog で確認(キャンセル / バリアタップなら何もしない)
  → ItemListNotifier.deleteItem(id)
      → 一覧の直前値に id が無い  … DeleteItemIgnored(書き込まない)
      → ItemRepository.delete(id)  … 例外なら DeleteItemFailed
      → DeleteItemSucceeded
  → 成功 / Ignored なら pop。watchAll() の再送出で一覧から行が消える
```

**`renameItem` / `deleteItem` は `state` を書かない。** 一覧は `watchAll()` の購読結果だけを
反映する。#6 の `addItem`・#7 の `markDone` と同じ約束で、「保存に失敗しても一覧は元のまま」
「削除に失敗しても一覧から消えない」という受け入れ条件がこの約束から自動的に満たされる。

## 1. 設計判断(実装者はこれを蒸し返さない)

**判断1: 削除だけ確認を挟む。「やった」は確認なしのまま。**
`CLAUDE.md`「譲らない設計判断」/ `docs/product-requirements.md` F7 の注記で確定済み。
基準は**元に戻せるか**。記録は取り消せるが、削除は蓄積した記録ごと失われる。
**一覧にスワイプ削除を置かない**(F7 の設計判断)。削除の入口は編集画面だけ。

**判断2: 結果型で返す。`writeErrorProvider` を導入しない。**
#7 判断2 と同じ。書き込みは編集画面に留まったまま起きるので、発生源の画面がそのまま
`context` を持っており、グローバルな `StateProvider` を経由させる理由がない。
`AddItemResult` / `MarkDoneResult` と同じ形に揃える。

**判断3: 編集画面へ渡すのは `ItemId` と現在の項目名の 2 つだけ。`ItemView` を渡さない。**
編集画面が扱うのは項目名だけで、経過日数・最終実施日は表示しない(F6 のスコープ)。
`ItemView` を渡すと画面が持つ情報が増え、「ついでに最終実施日も直せるのでは」という
P1(F16)の前倒しを誘う。`ItemEditScreen({required ItemId itemId, required String initialName})`。

**判断4: 行タップは `ItemRow` に `onTap` を足し、`InkWell` で受ける。**
`onDonePressed` と同じく**必須の名前付き引数**にする(任意にすると結線漏れが黙って通る)。
`InkWell` は `Padding` の外側に置き、行全体をタップ領域にする。行内の `DoneButton` は
自分でタップを消費するので、「やった」を押しても編集画面は開かない(§9-3 でテストする)。

**判断5: `itemNameErrorText` を `lib/ui/item_name_error_text.dart` へ移す。**
#6 で `item_add_screen.dart` に置いた関数を、編集画面でもそのまま使う(Issue #8 技術メモ
「登録画面と編集画面で書き分けない」)。2 画面目の利用が現れたので移す
(`docs/repository-structure.md`「2 箇所目の利用が現れてから移す」)。
**ウィジェットではないので `lib/ui/widgets/` には置かない**(置くと中身と場所が食い違う)。
移設に伴い `item_add_screen.dart` から関数定義を削り import を足す。
`test/ui/item_add_screen_test.dart` の import も直す(関数そのものは変えない)。
`docs/repository-structure.md` のツリーとの差分は `requirements.md`「ドキュメントとの差分」に記載済み。

**判断6: 項目名が変わっていなくても保存する(差分判定をしない)。**
「変わっていなければ書かない」最適化は、`updatedAt` の意味(最後に書き込みが起きた日時)を
壊さずに入れようとすると条件分岐が増えるだけで、ユーザーに見える差は無い。
`rename` は `last_done_at` を companion に載せないので、**何度呼んでも最終実施日は動かない**
(受け入れ条件「最終実施日が編集操作で変化しない」はここで構造的に満たされる)。

**判断7: 「対象なし」は `Ignored` を返し、UI は何も表示せずに一覧へ戻る。**
`docs/functional-design.md`「エラーの分類」の「対象項目が存在しない(削除と同時操作)」=
**無視して一覧を再取得・表示しない**。一覧は `watchAll()` の購読で既に整合しているので、
UI は `pop` するだけでよい(明示的な再取得コードを書かない)。
判定は #7 判断4 と同じく `_latestItems` を引く。**書き込みを試みない。**

**判断8: 検証 → 存在確認の順で見る。**
`renameItem` は先に `validateItemName` を通し、通ってから `_latestItems` の存在を見る。
入力エラーは入力欄に出す種類の情報で、対象の有無より先にユーザーへ返すべきものだから。
(どちらが先でも受け入れ条件は満たせる。**実装者が迷わないよう順序を固定する。**)

**判断9: 保存中・削除中は 1 つの `_isBusy` で両方を塞ぐ。**
#6 判断7(`_isSaving`)の横展開。保存ボタン・削除ボタン・閉じるボタンの 3 つを同時に無効化する。
削除は取り返しがつかないので、「保存中にもう一度押せる」状態を残さない。

**判断10: 確認ダイアログは `showDialog<bool>` + `AlertDialog`。`barrierDismissible` は既定のまま。**
バリアタップや戻る操作で閉じたときは `null` が返る。**`true` 以外はすべて「削除しない」** として扱う
(`if (confirmed != true) return;`)。破壊的操作の既定は「やらない」側に倒す。
ダイアログに出す名前は**保存済みの名前(`widget.initialName`)**であって、入力欄の編集中の文字列ではない。
消えるのは保存済みの項目だから。

**判断11: 削除は `Clock` を使わない。**
`ItemRepository.delete(ItemId)` は `now` を取らない(#4 で確定。行ごと消えるので `updatedAt` に
書く先が無い)。`deleteItem` の中で `clockProvider` を読まない。

**判断12: 失敗のログは `dart:developer` の `log` で出す(#6 判断9 / #7 判断10 と同じ)。**
`lib/state/` は `package:flutter/` を import できない(`test/architecture/layer_dependency_test.dart`)。
`name` は `'lastwhen.state'` で揃える。

**判断13: 画面遷移の前に `clearSnackBars()` を呼ぶ(#7 判断7 の横展開)。**
`ScaffoldMessenger` は `Navigator` の上にあるため、何もしないと取り消し導線が編集画面にも残る。
`_openEditScreen` の先頭で呼ぶ。

**判断14: 削除ボタンは保存ボタンから離して本文の下端に置く。`AppBar` のアクションに置かない。**
`docs/ui-design-guidelines.md` §7 の範囲内で、Material 3 の `TextButton.icon` に
`colorScheme.error` を与えるだけで組む。保存との間に余白を空け、指が滑って押す距離を稼ぐ。
**`FilledButton` にしない**(破壊的操作を最も目立つボタンにしない)。

**判断15: 編集画面の入力欄は `autofocus` しない。**
#6 の登録画面は「開いた瞬間に入力できる = タップが 1 つ減る」ことが受け入れ条件だったが、
編集は既に文字が入っており、開いた瞬間にキーボードが出ると**削除ボタンが隠れる**。
`maxLength: maxItemNameLength` は登録画面と同じく付ける(51 文字目を打てなくする。
ドメイン側の検証は消さない = #6 判断3)。

## 2. 実装するファイル

| ファイル | 変更 |
| --- | --- |
| `lib/ui/item_name_error_text.dart` | **新規**(`item_add_screen.dart` からの移設。中身は変えない) |
| `lib/ui/screens/item_add_screen.dart` | `itemNameErrorText` の定義を削り、移設先を import する |
| `lib/state/edit_item_result.dart` | **新規**。`RenameItemResult` / `DeleteItemResult` |
| `lib/state/item_list_notifier.dart` | `renameItem` / `deleteItem` を追加 |
| `lib/ui/widgets/item_row.dart` | 必須の `onTap` を追加し、`InkWell` で包む |
| `lib/ui/screens/item_edit_screen.dart` | **新規**。編集画面(名称変更 + 削除 + 確認ダイアログ) |
| `lib/ui/screens/item_list_screen.dart` | 行タップの結線と `_openEditScreen` |
| `test/state/item_list_notifier_test.dart` | §9-1 のケースを追加 |
| `test/ui/item_edit_screen_test.dart` | **新規**。§9-2 のケース |
| `test/ui/item_list_screen_test.dart` | §9-3 のケースを追加 |
| `test/ui/item_add_screen_test.dart` | import の修正のみ(テスト内容は変えない) |

**触らないファイル**: `lib/domain/`(全部)、`lib/data/`(全部)、`lib/ui/theme/`、
`lib/ui/widgets/done_button.dart`、`lib/ui/widgets/empty_state.dart`、`lib/app.dart`、
`pubspec.yaml`、`docs/`、`test/support/`(`FakeItemRepository` は `rename` / `delete` を
実装済みなので変更不要)。

## 3. `lib/ui/item_name_error_text.dart`(新規 = 移設)

`item_add_screen.dart` の末尾にある `itemNameErrorText` を、**中身を 1 文字も変えずに**この
ファイルへ移す(ドキュメントコメントも含めて移す)。

```dart
import '../domain/item_name.dart';

/// 検証に落ちた理由を入力欄の文言へ変換する。
///
/// 文言は `docs/functional-design.md`「エラーの分類」が正。
/// **文字列への変換は UI 層の責務**(`elapsedText` と同じ置き方)。
/// 登録画面(#6)と編集画面(#8)の両方が使う。
String itemNameErrorText(ItemNameReason reason) => switch (reason) {
  ItemNameReason.empty => '項目名を入力してください',
  ItemNameReason.tooLong => '$maxItemNameLength文字以内で入力してください',
};
```

`item_add_screen.dart` 側は末尾の定義を削り、`import '../item_name_error_text.dart';` を足す。
`import '../../domain/item_name.dart';` は `maxItemNameLength` を使っているので**残す**。
`test/ui/item_add_screen_test.dart` の `import 'package:lastwhen/ui/screens/item_add_screen.dart';`
はそのまま残し(`ItemAddScreen` を使っている)、
`import 'package:lastwhen/ui/item_name_error_text.dart';` を足す。

## 4. `lib/state/edit_item_result.dart`(新規)

`add_item_result.dart` と同じ置き方・同じ粒度のドキュメントコメントを付ける。

```dart
import '../domain/item_name.dart';

/// 項目名の変更結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
sealed class RenameItemResult {
  const RenameItemResult();
}

/// 保存まで成功した。呼び出し元は一覧へ戻ってよい。
final class RenameItemSucceeded extends RenameItemResult {
  const RenameItemSucceeded();
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class RenameItemRejected extends RenameItemResult {
  const RenameItemRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final ItemNameReason reason;
}

/// 対象が一覧に無かった(削除と同時操作)。**書き込みを試みていない。**
///
/// `docs/functional-design.md`「エラーの分類」に従い、UI は何も表示せず一覧へ戻る。
final class RenameItemIgnored extends RenameItemResult {
  const RenameItemIgnored();
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。一覧は元の値のまま。
final class RenameItemFailed extends RenameItemResult {
  const RenameItemFailed();
}

/// 項目の削除結果。**例外を投げない。**
sealed class DeleteItemResult {
  const DeleteItemResult();
}

/// 削除まで成功した。呼び出し元は一覧へ戻ってよい。
final class DeleteItemSucceeded extends DeleteItemResult {
  const DeleteItemSucceeded();
}

/// 対象が一覧に無かった(既に消えている)。**書き込みを試みていない。**
final class DeleteItemIgnored extends DeleteItemResult {
  const DeleteItemIgnored();
}

/// 削除に失敗した。一覧から消えない。
final class DeleteItemFailed extends DeleteItemResult {
  const DeleteItemFailed();
}
```

## 5. `lib/state/item_list_notifier.dart`

`undoMarkDone` の下に 2 メソッドを足す。**`state` を書かないこと。**
`build()` と `_latestItems` は #7 のまま変更しない。

```dart
  /// 項目名を変更する。**最終実施日は変わらない**(判断6)。
  ///
  /// 検証は登録と同じ `validateItemName`(`docs/product-requirements.md` F6)。
  /// 一覧に無い ID は書き込まず [RenameItemIgnored] を返す(判断7)。
  Future<RenameItemResult> renameItem(ItemId id, String rawName) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return RenameItemRejected(reason);
      case ValidItemName(:final value):
        // 検証 → 存在確認の順(判断8)。
        if (!_latestItems.any((item) => item.id == id)) {
          return const RenameItemIgnored();
        }
        try {
          await ref
              .read(itemRepositoryProvider)
              .rename(id, value, now: ref.read(clockProvider).now());
          return const RenameItemSucceeded();
        } catch (error, stackTrace) {
          developer.log(
            '項目名の変更に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const RenameItemFailed();
        }
    }
  }

  /// 項目を削除する。**記録ごと消える。取り消せない。**
  ///
  /// 確認を取るのは UI の責務(`docs/product-requirements.md` F7 / 判断1)。
  /// ここは確認済みの前提で呼ばれる。**`Clock` を使わない**(判断11)。
  Future<DeleteItemResult> deleteItem(ItemId id) async {
    if (!_latestItems.any((item) => item.id == id)) {
      return const DeleteItemIgnored();
    }
    try {
      await ref.read(itemRepositoryProvider).delete(id);
      return const DeleteItemSucceeded();
    } catch (error, stackTrace) {
      developer.log(
        '項目の削除に失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const DeleteItemFailed();
    }
  }
```

import に `edit_item_result.dart` を足す(`item.dart` / `item_name.dart` は #7 までで入っている)。

> **`_latestItems` は購読が 1 回でも emit してから埋まる。** テストで `renameItem` /
> `deleteItem` を呼ぶ前に `await container.read(itemListProvider.future)` を通すこと
> (通さないと空リストのままで、必ず `Ignored` が返る)。

## 6. `lib/ui/widgets/item_row.dart`

コンストラクタに**必須の** `onTap` を足し(判断4)、`Padding` を `InkWell` で包む。
中身のレイアウト(`Row` 以下)は 1 文字も変えない。

```dart
  /// 1 行を作る。
  const ItemRow({
    required this.item,
    required this.onDonePressed,
    required this.onTap,
    super.key,
  });

  /// 表示する項目。
  final ItemView item;

  /// 「やった」ボタンのタップ時の処理。
  final VoidCallback onDonePressed;

  /// 行そのもののタップ時の処理(編集画面への遷移)。
  ///
  /// **一覧に破壊的操作を置かないため、削除の入口は編集画面だけ**
  /// (`docs/product-requirements.md` F7 の設計判断)。スワイプ削除を足さない。
  final VoidCallback onTap;
```

`build` の戻り値を次の形にする(`Padding` 以下は既存のまま)。

```dart
    return InkWell(
      // 行内の DoneButton は自分でタップを消費するので、「やった」では発火しない。
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row( ... 既存のまま ... ),
      ),
    );
```

## 7. `lib/ui/screens/item_edit_screen.dart`(新規)

`item_add_screen.dart` と同じ骨格(`ConsumerStatefulWidget` + `TextEditingController` +
`_errorText` + ビジー制御)にする。**下のコードをそのまま使ってよい。**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item.dart';
import '../../domain/item_name.dart';
import '../../state/edit_item_result.dart';
import '../../state/item_list_notifier.dart';
import '../item_name_error_text.dart';

/// 項目の編集画面。**変更できるのは項目名だけ**(`docs/product-requirements.md` F6)。
///
/// 最終実施日の手動修正は P1(F16)。ここに足さない。
/// **削除の唯一の入口**でもある(F7。一覧にスワイプ削除を置かない)。
class ItemEditScreen extends ConsumerStatefulWidget {
  /// [itemId] の項目を編集する画面を作る。[initialName] は入力欄の初期値。
  const ItemEditScreen({
    required this.itemId,
    required this.initialName,
    super.key,
  });

  /// 編集対象の項目 ID。
  final ItemId itemId;

  /// 開いた時点の項目名(保存済みの値)。
  final String initialName;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  /// 入力欄に出す理由。null なら正常。
  String? _errorText;

  /// 保存中・削除中は保存・削除・キャンセルをまとめて塞ぐ(判断9)。
  bool _isBusy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目を編集'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'キャンセル',
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                // 開いた瞬間にキーボードを出すと削除ボタンが隠れる(判断15)。
                autofocus: false,
                // 51 文字目を打てなくする。ドメイン側の検証は消さない(#6 判断3)。
                maxLength: maxItemNameLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '項目名',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                onChanged: _handleChanged,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isBusy ? null : _save,
                child: const Text('保存'),
              ),
              // 破壊的操作を保存から離す(判断14)。
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _isBusy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('削除'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 入力し直したら、前回の理由を消す。直せたのに赤いままにしない。
  void _handleChanged(String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _save() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final result = await ref
        .read(itemListProvider.notifier)
        .renameItem(widget.itemId, _controller.text);
    if (!mounted) {
      return;
    }
    switch (result) {
      // 保存の完了を待ってから戻る(楽観的 UI 更新を採らない)。
      case RenameItemSucceeded():
      // 対象が既に無い。エラーを出さずに戻る(判断7)。
      case RenameItemIgnored():
        Navigator.of(context).pop();
      // 画面を閉じない。入力もそのまま残す(受け入れ条件)。
      case RenameItemRejected(:final reason):
        setState(() {
          _isBusy = false;
          _errorText = itemNameErrorText(reason);
        });
      case RenameItemFailed():
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
    }
  }

  Future<void> _delete() async {
    if (_isBusy) {
      return;
    }
    // 削除は確認を挟む(判断1)。基準は元に戻せるかどうか。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目を削除しますか?'),
        // 消えるのは保存済みの項目なので、編集中の入力値ではなく初期値を出す(判断10)。
        content: Text('「${widget.initialName}」とこれまでの記録を削除します。元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    // バリアタップ・戻る操作は null。true 以外はすべて「削除しない」(判断10)。
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _isBusy = true);
    final result = await ref
        .read(itemListProvider.notifier)
        .deleteItem(widget.itemId);
    if (!mounted) {
      return;
    }
    switch (result) {
      case DeleteItemSucceeded():
      // 対象が既に無い。目的は達成されているのでエラーを出さない(判断7)。
      case DeleteItemIgnored():
        Navigator.of(context).pop();
      case DeleteItemFailed():
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除できませんでした。もう一度お試しください')));
    }
  }
}
```

## 8. `lib/ui/screens/item_list_screen.dart`

### 8-1. 行の結線

```dart
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemRow(
          item: item,
          onDonePressed: () => _handleDone(context, ref, item.id),
          onTap: () => _openEditScreen(context, item),
        );
      },
```

### 8-2. 遷移関数(`_openAddScreen` の下に置く)

```dart
/// 編集画面へ遷移する。**削除の入口でもある**(`docs/product-requirements.md` F7)。
void _openEditScreen(BuildContext context, ItemView item) {
  // ScaffoldMessenger は Navigator の上にあり、閉じないと遷移後も導線が残る(判断13)。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) =>
          ItemEditScreen(itemId: item.id, initialName: item.name),
    ),
  );
}
```

import に `item_edit_screen.dart` を足す(`ItemView` / `ItemId` は既に入っている)。

## 9. テスト

### 9-1. `test/state/item_list_notifier_test.dart` に足す

既存の `_container` / `_CountingClock` ヘルパーをそのまま使う。
**`renameItem` / `deleteItem` を呼ぶ前に必ず `await container.read(itemListProvider.future)` を通す**
(§5 の注記。通さないと `_latestItems` が空で `Ignored` になる)。
`group('renameItem', ...)` と `group('deleteItem', ...)` を `addItem` / `markDone` の群と同じ形で足す。

| ケース | 検証 |
| --- | --- |
| 名前を変えても最終実施日が動かない | 記録済み(9/12)の項目をリネーム後、`elapsed` が `DaysAgo(4)`・`lastDoneText` が `2026年9月12日` のまま |
| 変更が一覧に反映される | リネーム後の `ItemView.name` が新しい名前 |
| 前後の空白はトリムされる | `'  美容院  '` → 保存された `name` が `'美容院'` |
| 空文字・空白のみは保存されない | `RenameItemRejected(empty)`。リポジトリの `name` が元のまま |
| 51 文字は保存されない | `RenameItemRejected(tooLong)`。同上 |
| 50 文字は保存できる | `RenameItemSucceeded` |
| 一覧に無い ID | `RenameItemIgnored` が返り、**他の項目が変わらない** |
| 書き込み失敗 | `writeError` を仕込み `RenameItemFailed`。**一覧は `AsyncData` のまま**で名前も変わらない |
| 更新日時は `Clock` の時刻 | リネーム後の `updatedAt` が `FakeClock` の時刻 |
| 削除すると一覧から消える | `DeleteItemSucceeded`。`watchAll().first` が対象を含まない |
| 他の項目に影響しない | 2 件のうち 1 件を削除しても、残る 1 件の `name` / `lastDoneAt` / `sortOrder` が変わらない |
| 一覧に無い ID | `DeleteItemIgnored`。リポジトリの件数が変わらない |
| 書き込み失敗 | `writeError` を仕込み `DeleteItemFailed`。**一覧に残ったまま** |
| 削除は `Clock` を呼ばない | `_CountingClock` の `calls` が `deleteItem` の前後で増えない(判断11) |

`repository.writeError` は書き込みだけに効き、`watchAll()` には影響しない
(`test/support/fake_item_repository.dart`)。**`FakeItemRepository` は変更しない。**

### 9-2. `test/ui/item_edit_screen_test.dart`(新規)

`test/ui/item_add_screen_test.dart` と同じ `_app` ヘルパー・同じ `setUp` を写す。
`pumpItems`(「美容院」= 2026年9月12日記録済み、「歯ブラシ交換」= 未実施、`FakeClock` は
2026-09-16)を写し、**行をタップして編集画面を開く** `openEditScreen(tester, '美容院')` を置く。

| ケース | 検証 |
| --- | --- |
| 行タップで編集画面が開く | `ItemEditScreen` が 1 つ、`TextField` に `美容院` が入っている |
| 名前を変えて保存できる | `保存` 後に編集画面が閉じ、一覧に `シャンプー` が出て `美容院` が消える |
| 最終実施日が変わらない | 保存後の一覧に `4日前` と `2026年9月12日` が残っている |
| 空にして保存 | `項目名を入力してください` が出て**画面が閉じない**。一覧の名前も変わらない |
| 空白のみで保存 | 同上 |
| キャンセルで戻る | 入力を変えてから閉じるアイコン → 一覧の名前が元のまま |
| 保存失敗 | `writeError` を仕込むと `保存できませんでした。もう一度お試しください` が出て画面が閉じず、一覧の名前も変わらない |
| 削除は確認を挟む | `削除` を押すと `AlertDialog` が出る。**この時点では消えていない** |
| 確認のキャンセル | `キャンセル` → ダイアログが閉じ、編集画面に留まり、一覧は 2 件のまま |
| 削除の実行 | `削除`(ダイアログ内)→ 編集画面が閉じ、一覧から `美容院` が消え、`歯ブラシ交換` は残る |
| 他の項目に影響しない | 上のケースで `歯ブラシ交換` と `未実施` が残っていること |
| 削除失敗 | `writeError` を仕込むと `削除できませんでした。もう一度お試しください` が出て、一覧に `美容院` が残り、編集画面に留まる |

**ダイアログ内の「削除」ボタンは `find.widgetWithText(TextButton, '削除')` で押す。**
画面本体の削除ボタンは `TextButton.icon` = `TextButton` なので、`find.text('削除')` で押すと
どちらか分からなくなる。ダイアログを開いた後は
`find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, '削除'))`
で対象を確定させる。
入力の書き換えは `await tester.enterText(find.byType(TextField), '新しい名前')`。
タップ後は `await tester.pumpAndSettle()` で書き込み完了と遷移を待つ。

### 9-3. `test/ui/item_list_screen_test.dart` に足す

| ケース | 検証 |
| --- | --- |
| 「やった」では編集画面が開かない | `DoneButton` をタップしても `ItemEditScreen` が出ない(判断4) |
| 行タップで取り消し導線が閉じる | 記録 → 行タップ → `SnackBar` が消えている(判断13) |

### 9-4. `test/ui/item_add_screen_test.dart`

`itemNameErrorText` の import 先を直すだけ。**テストの中身は変えない。**

## 10. 完了の定義

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test`(**委託先はネットワーク無効の sandbox で実行できない。検収側 / CI が回す**)
- `requirements.md` の受け入れ条件がすべて満たされている
