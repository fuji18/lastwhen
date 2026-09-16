# 設計: 項目の新規登録(Issue #6)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> `pubspec.yaml` に依存を足す必要が出たときも同じ。

## 0. 全体方針

「項目名 1 つを入れて保存する」以外の入力を一切足さない。UC2(`docs/functional-design.md`)の
シーケンスをそのまま写し、**検証 → 保存 → 一覧へ戻る**の 3 段だけで作る。

流れは 1 本道:

```
ItemListScreen(FAB / EmptyState)
  → Navigator.push → ItemAddScreen
      → ItemListNotifier.addItem(rawName)
          → validateItemName()  … 落ちたら AddItemRejected(理由)
          → ItemRepository.add(name, now: clock.now())  … 例外なら AddItemFailed
          → AddItemSucceeded
      → 成功だけ Navigator.pop()
  → watchAll() の再送出で一覧に「未実施」の行が増える
```

**`addItem` は `state` を書かない。** 一覧は `watchAll()` の購読結果だけを反映する。

## 1. 設計判断(実装者はこれを蒸し返さない)

**判断1: 保存の結果は sealed な結果型で返す。例外を投げない。**
`docs/development-guidelines.md`「エラーハンドリング」に従う。呼び出し元は 3 分岐
(成功 / 入力が不正 / 保存失敗)をそのまま画面の振る舞いに写す。`try-catch` を UI に書かせない。

**判断2: `writeErrorProvider` はこのチケットで作らない。**
`docs/functional-design.md` は書き込み失敗を `writeErrorProvider` 経由で `SnackBar` に出すと
書いているが、あれは**失敗を出す画面が失敗の発生源と別**の場合(#7 の「やった」= 一覧に留まったまま
書き込む)のための仕組み。#6 は登録画面が発生源であり、要件が「エラー時に画面を閉じず入力を保持する」と
言っている以上、**失敗を見せる場所は登録画面そのもの**になる。グローバルな 1 本のチャネルを経由させると、
まだ前面にいる登録画面ではなく背後の一覧に出す形になり、要件と噛み合わない。
`writeErrorProvider` の新設は #7 の担当。

**判断3: 長さの上限は「UI の入力制限」と「ドメインの検証」の二重にする。どちらも消さない。**
`TextField.maxLength` は入力の時点で 51 文字目を打てなくする(受け入れ条件「51 文字以上を入力できない」)。
一方 `validateItemName` は**コードポイント数**、Flutter の `maxLength` は**書記素クラスタ数**で数えるため、
ZWJ 絵文字などで前者だけが超えることがある。**ドメイン側が最終的な権威**で、`AddItemRejected(tooLong)` の
分岐は UI に必ず残す。画面側に長さ判定のロジックを書き直さない(Issue #6 技術メモ)。

**判断4: 名前付きルートを導入しない。`MaterialPageRoute` を直接積む。**
`lib/app.dart` に「#6 / #8 で必要になった時点で足す」と書いてあるが、通常操作の画面は 3 つだけで
(`docs/functional-design.md`「画面遷移図」)、ディープリンクも扱わない。ルート表を作ると
遷移先とルート名の二重管理になるだけで得が無い。`lib/app.dart` のコメントだけを現状に合わせて直す。

**判断5: 一覧側の追加導線は `FloatingActionButton`。ただし項目が 1 件以上あるときだけ出す。**
空状態には既に `EmptyState` の「項目を追加」ボタンがあり、両方出すと同じ導線が 2 つ並ぶ。
読み込み中・読み込み失敗のときも出さない(そもそも追加しても見えない)。
FAB が最終行の「やった」ボタンに被らないよう、`ListView` の下に 88dp の余白を入れる(56 + 16 × 2)。
FAB を選ぶ理由は片手操作 —— AppBar の右上は親指が届かない。

**判断6: 登録画面の保存ボタンは本文に 1 つだけ置く。AppBar には置かない。**
`autofocus` でキーボードが出た直後でも見える位置(入力欄の直下)に置く。
AppBar にも置くと「保存」というテキストが画面に 2 つ現れ、導線としても冗長。
キーボードの完了キー(`TextInputAction.done`)でも保存できるようにして、最短の動線を作る
(受け入れ条件「30 秒以内」)。AppBar の左は閉じる(キャンセル)アイコンにする。

**判断7: 保存中は保存ボタンとキャンセルを無効化する。**
楽観的 UI 更新を採らない(`CLAUDE.md`)以上、保存の完了までは画面が残る。この間に二度押しすると
項目が 2 件できる。`_isSaving` フラグで塞ぐ。

**判断8: `FakeItemRepository` に書き込み失敗の注入口(`writeError`)を足す。**
「保存に失敗したとき一覧を更新しない」は受け入れ条件なので、失敗を起こせないと検証できない。
**読み取り(`watchAll`)には影響させない** —— 「一覧は生きたまま書き込みだけ失敗する」状況を作るため。
#7 / #8 でも同じ注入口を使うので、`add` 専用にせず全書き込みメソッドに効かせる。

**判断9: 失敗のログは `dart:developer` の `log` で出す。**
`lib/state/` は `package:flutter/` を import できない(`test/architecture/layer_dependency_test.dart`)ため
`debugPrint` は使えない。`docs/functional-design.md`「エラーの分類」が「例外をログへ出し」と言っている分。

## 2. 実装するファイル

### 2.1 `lib/state/add_item_result.dart`(新規)

```dart
import '../domain/item_name.dart';

/// 項目の登録結果。**例外を投げない**(`docs/development-guidelines.md`「エラーハンドリング」)。
///
/// 呼び出し元(登録画面)は 3 分岐をそのまま画面の振る舞いに写す。
sealed class AddItemResult {
  const AddItemResult();
}

/// 保存まで成功した。呼び出し元は一覧へ戻ってよい。
final class AddItemSucceeded extends AddItemResult {
  const AddItemSucceeded();
}

/// 入力が検証を通らなかった。**保存を試みていない。**
final class AddItemRejected extends AddItemResult {
  const AddItemRejected(this.reason);

  /// 落ちた理由。UI 文言への変換は UI 層の責務。
  final ItemNameReason reason;
}

/// 検証は通ったが保存に失敗した(DB 書き込み失敗)。
final class AddItemFailed extends AddItemResult {
  const AddItemFailed();
}
```

### 2.2 `lib/state/item_list_notifier.dart`(追記のみ)

**`build()` は変更しない。** import を足し、クラスに `addItem` を 1 つ加えるだけ。

追加する import(既存の並びに合わせてアルファベット順に差し込む):

```dart
import 'dart:developer' as developer;
...
import '../domain/item_name.dart';
import 'add_item_result.dart';
```

クラス末尾に追加:

```dart
  /// 項目を登録する。検証を通ったときだけ保存し、結果を返す。
  ///
  /// **`state` を触らない。** 一覧は `watchAll()` の購読結果だけを反映させる
  /// (`docs/functional-design.md`「エラーハンドリング」)。保存に失敗しても一覧は
  /// 直前の値のまま残り、UI が一覧ごとエラー画面に切り替わることがない。
  ///
  /// **楽観的 UI 更新を採らない**(`CLAUDE.md`)。保存の完了を待ってから返る。
  Future<AddItemResult> addItem(String rawName) async {
    switch (validateItemName(rawName)) {
      case InvalidItemName(:final reason):
        return AddItemRejected(reason);
      case ValidItemName(:final value):
        try {
          await ref
              .read(itemRepositoryProvider)
              .add(value, now: ref.read(clockProvider).now());
          return const AddItemSucceeded();
        } catch (error, stackTrace) {
          // lib/state は package:flutter/ を import できないので debugPrint は使えない(判断9)。
          developer.log(
            '項目の登録に失敗しました',
            name: 'lastwhen.state',
            error: error,
            stackTrace: stackTrace,
          );
          return const AddItemFailed();
        }
    }
  }
```

- `ref.watch` ではなく `ref.read` を使う(メソッド内の一度きりの取得)
- `validateItemName` が返す `ValidItemName.value` は**既にトリム済み**。ここで再度 `trim()` しない

### 2.3 `lib/ui/screens/item_add_screen.dart`(新規)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item_name.dart';
import '../../state/add_item_result.dart';
import '../../state/item_list_notifier.dart';

/// 項目の登録画面。**入力は項目名 1 つだけ**(`docs/product-requirements.md` F2)。
///
/// カテゴリ・アイコン・目安期間は P1。ここで入力項目を増やすと
/// 「30 秒以内に登録できる」という成功指標と正面から衝突する。
class ItemAddScreen extends ConsumerStatefulWidget {
  /// 登録画面を作る。
  const ItemAddScreen({super.key});

  @override
  ConsumerState<ItemAddScreen> createState() => _ItemAddScreenState();
}

class _ItemAddScreenState extends ConsumerState<ItemAddScreen> {
  final TextEditingController _controller = TextEditingController();

  /// 入力欄に出す理由。null なら正常。
  String? _errorText;

  /// 保存中は二度押しを塞ぐ(判断7)。
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目を追加'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'キャンセル',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
                // 開いた瞬間に入力できる = タップが 1 つ減る(受け入れ条件)。
                autofocus: true,
                // 51 文字目を打てなくする。後から弾くより分かりやすい(Issue #6 技術メモ)。
                // ドメイン側の検証は消さない(判断3)。
                maxLength: maxItemNameLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '項目名',
                  hintText: '例: 美容院',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                onChanged: _handleChanged,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('保存'),
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
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final result = await ref
        .read(itemListProvider.notifier)
        .addItem(_controller.text);
    if (!mounted) {
      return;
    }
    switch (result) {
      // 保存の完了を待ってから戻る(楽観的 UI 更新を採らない)。
      case AddItemSucceeded():
        Navigator.of(context).pop();
      // 画面を閉じない。入力もそのまま残す(受け入れ条件)。
      case AddItemRejected(:final reason):
        setState(() {
          _isSaving = false;
          _errorText = itemNameErrorText(reason);
        });
      case AddItemFailed():
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
        );
    }
  }
}

/// 検証に落ちた理由を入力欄の文言へ変換する。
///
/// 文言は `docs/functional-design.md`「エラーの分類」が正。
/// **文字列への変換は UI 層の責務**(`elapsedText` と同じ置き方)。
String itemNameErrorText(ItemNameReason reason) => switch (reason) {
  ItemNameReason.empty => '項目名を入力してください',
  ItemNameReason.tooLong => '$maxItemNameLength文字以内で入力してください',
};
```

- 「保存」というテキストは画面に 1 つだけ(判断6)。AppBar に保存ボタンを足さない
- `mounted` の確認を `await` の後に必ず入れる(`use_build_context_synchronously`)
- 成功時に `_isSaving` を戻さない。そのまま `pop` する

### 2.4 `lib/ui/screens/item_list_screen.dart`(書き換え)

変更は 4 箇所だけ。`_LoadError` と `EmptyState` の中身には触らない。

1. import に `item_add_screen.dart` を足す
2. `build` に FAB を足し、`EmptyState` の `onAddPressed` を実際の遷移に繋ぐ
3. 空実装の `_handleAddPressed` メソッドを**削除**し、トップレベルの `_openAddScreen` に置き換える
4. `_ItemList` の `ListView.builder` に下余白を足す

`build` の差し替え後の形:

```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemListProvider);
    // 追加導線は空状態(EmptyState 側にボタンがある)と読み込み中・失敗では出さない(判断5)。
    final hasItems = switch (items) {
      AsyncData(:final value) => value.isNotEmpty,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('LastWhen')),
      body: SafeArea(
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: () => _openAddScreen(context),
          ),
          AsyncData(:final value) => _ItemList(items: value),
          AsyncError() => _LoadError(
            onRetry: () => ref.invalidate(itemListProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () => _openAddScreen(context),
              tooltip: '項目を追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// 登録画面へ遷移する。
///
/// 名前付きルートを使わない(design.md 判断4)。画面は一覧・登録・編集の 3 つだけで、
/// ディープリンクも扱わないため、ルート表を持つと二重管理になるだけ。
void _openAddScreen(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (context) => const ItemAddScreen()),
  );
}
```

`_ItemList` の `ListView.builder`:

```dart
    return ListView.builder(
      // FAB が最終行の「やった」ボタンに被らないようにする(判断5)。56 + 16 × 2。
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      ...
```

`ItemRow` の `onDonePressed: () {}` は**そのまま残す**(#7 の担当)。

### 2.5 `lib/app.dart`(コメントのみ修正)

`Navigator` の名前付きルートに関するコメントを、判断4 に合わせて書き換える。
**コードは変更しない。**

```dart
/// 通常操作の画面は一覧・登録・編集の 3 つだけで、起動直後は必ず一覧に出る
/// (`docs/functional-design.md`「画面遷移図」)。遷移は `Navigator.push` で直接積み、
/// 名前付きルートは使わない(#6 design.md 判断4)。
```

### 2.6 `test/support/fake_item_repository.dart`(追記のみ)

フィールドを 1 つと、プライベートヘルパーを 1 つ足し、**全書き込みメソッドの先頭**で呼ぶ。
`watchAll` / `_snapshot` / `dispose` には手を入れない。

```dart
  /// 非 null のとき、**すべての書き込み**がこの値を投げる。DB 書き込み失敗の再現用。
  ///
  /// **読み取り(`watchAll`)には影響しない。** 「一覧は生きたまま書き込みだけ失敗する」
  /// という `docs/functional-design.md`「エラーハンドリング」の状況を作るため。
  Object? writeError;
```

```dart
  /// 書き込み失敗が仕込まれていれば投げる。
  void _failIfConfigured() {
    final error = writeError;
    if (error != null) {
      throw error;
    }
  }
```

`add` / `rename` / `delete` / `markDone` / `restoreLastDoneAt` の本体 1 行目に
`_failIfConfigured();` を入れる。

## 3. テスト

### 3.1 `test/state/item_list_notifier_test.dart`(追記のみ)

既存のテストと `_container` ヘルパー・`_CountingClock` は**そのまま**。
末尾に `group('addItem', () { ... })` を足す。`container.read(itemListProvider.notifier).addItem(...)` で呼ぶ。

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | `addItem('美容院')` | `AddItemSucceeded`。一覧に 1 件増え、`elapsed` が `NeverDone`、`lastDoneText` が null |
| 2 | `addItem('  美容院  ')` | 成功し、保存された名前が `'美容院'`(前後の空白が落ちている) |
| 3 | `addItem('')` | `AddItemRejected(ItemNameReason.empty)`。一覧は 0 件のまま |
| 4 | `addItem('   ')`(空白のみ) | `AddItemRejected(ItemNameReason.empty)`。一覧は 0 件のまま |
| 5 | `addItem('あ' * 50)` | `AddItemSucceeded` |
| 6 | `addItem('あ' * 51)` | `AddItemRejected(ItemNameReason.tooLong)`。一覧は 0 件のまま |
| 7 | 保存される時刻 | `FakeClock` に渡した `now` が `createdAt` / `updatedAt` になる |
| 8 | `repository.writeError` を仕込んで `addItem('美容院')` | `AddItemFailed` が返り、**`container.read(itemListProvider)` が `AsyncError` にならず**、一覧の件数も変わらない |

- シナリオ 1・8 は、購読を開始してから(`await container.read(itemListProvider.future)`)呼ぶ
- 追加後の一覧を読むときは `async*` が継続購読へ進むのを待つ必要がある。既存テスト
  「初回読み込み後に追加すると2件の一覧が再通知される」と同じ `Completer` + `container.listen` の
  形を使うか、`await container.read(itemListProvider.future)` を再度読んで確かめる
- シナリオ 8 の検査は `expect(container.read(itemListProvider), isA<AsyncData<List<ItemView>>>())` の形で書く

### 3.2 `test/state/add_item_result_test.dart`(新規)

`itemNameErrorText` は UI 層なのでここには置かない。このファイルでは結果型の素の性質だけを見る。

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | `AddItemRejected(ItemNameReason.tooLong).reason` | `ItemNameReason.tooLong` |
| 2 | `const AddItemSucceeded()` と `const AddItemFailed()` | それぞれ `isA<AddItemResult>()` で、互いに別の型 |

### 3.3 `test/ui/item_add_screen_test.dart`(新規)

`test/ui/item_list_screen_test.dart` の `_app` ヘルパー(`ProviderScope` に
`itemRepositoryProvider` / `clockProvider` を override して `App` を積む)と同じ形をこのファイルにも置く。
**一覧画面から遷移して**テストする(遷移そのものも受け入れ条件のため)。

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | 空状態の「項目を追加」をタップ | `ItemAddScreen` が出る |
| 2 | 項目が 1 件ある状態で FAB をタップ | `ItemAddScreen` が出る |
| 3 | 登録画面を開いた直後 | 入力欄にフォーカスが当たっている(`tester.widget<TextField>(...).autofocus` が true、かつ `tester.testTextInput.isVisible` / `primaryFocus?.hasFocus` が true) |
| 4 | `'美容院'` を入れて「保存」 | 一覧へ戻り、`ItemRow` に `美容院` と `未実施` が出る。日付は出ない |
| 5 | `'  美容院  '` を入れて「保存」 | 一覧に `美容院` が出る(前後の空白なし) |
| 6 | 空のまま「保存」 | `ItemAddScreen` が残り、`項目名を入力してください` が出る。一覧は 0 件のまま |
| 7 | `'   '`(空白のみ)で「保存」 | 同上。加えて**入力欄の中身が `'   '` のまま残っている** |
| 8 | 51 文字を `enterText` | 入力欄の値が 50 文字に切り詰められている |
| 9 | キャンセル(閉じるアイコン)をタップ | 一覧へ戻り、項目は増えていない(空状態のまま) |
| 10 | `repository.writeError` を仕込んで「保存」 | `ItemAddScreen` が残り、`保存できませんでした。もう一度お試しください` の `SnackBar` が出る。一覧は 0 件のまま |
| 11 | `itemNameErrorText` の 2 分岐 | `empty` → `項目名を入力してください` / `tooLong` → `50文字以内で入力してください` |

- シナリオ 11 は `testWidgets` ではなく素の `test` でよい
- 遷移・`SnackBar` の後は `await tester.pumpAndSettle()` を挟む
- シナリオ 4 の「日付は出ない」は、`find.textContaining('年')` が `findsNothing` であることで見る

### 3.4 `test/ui/item_list_screen_test.dart`(追記のみ)

既存のテストは変更しない。末尾に 2 本足す。

| # | シナリオ | 期待 |
| --- | --- | --- |
| 1 | 項目が 2 件ある | `FloatingActionButton` が 1 つ出る |
| 2 | 0 件(空状態) | `FloatingActionButton` が出ない |

### 3.5 `test/architecture/layer_dependency_test.dart`

**変更しない。** 既存の 3 本が新しいファイルも自動的に対象にする
(`lib/ui` / `lib/state` をディレクトリごと走査しているため)。

## 4. 検証コマンド

`AGENTS.md` §2 と同じ。**変更したファイルだけを対象にする**(全体フォーマットは実行しない)。

```bash
dart format --output=none --set-exit-if-changed [変更したファイル]
flutter analyze --fatal-infos
flutter test
```

`flutter test` が sandbox で起動できない場合は**その旨を報告して止める**。
ローカルループバックを塞がれた環境では `flutter test` がテストランナーとの通信を作れず、
テスト内容に関係なく失敗する(#5 の申し送り)。成果物の失敗と読み替えない。

## 5. 触らないもの

- `lib/domain/` の**すべて**(`item_name.dart` は読むだけ。検証ロジックを書き換えない)
- `lib/data/`(**Codex 委託禁止領域**。`lib/data/database/` / `lib/data/migrations/`)
- `lib/state/item_view.dart` / `lib/state/providers.dart`
- `lib/ui/widgets/` の 3 ファイル(`done_button.dart` / `empty_state.dart` / `item_row.dart`)
- `lib/ui/theme/app_theme.dart`
- `pubspec.yaml`(依存を足さない。必要になったら止めて報告する)
- `test/support/fake_clock.dart`
- `test/architecture/layer_dependency_test.dart` / `test/widget_test.dart`
- `docs/` 配下(乖離は `/sync-docs` の担当)
