# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

```
CategoryManageScreen(ReorderableListView)
  └ onReorder → CategoryListNotifier.reorderCategories(orderedIds) → ReorderCategoryResult
        └ CategoryRepository.reorder(orderedIds)  … 1 トランザクションで sort_order を 0..n-1 に振り直す
              └ watchAll の再送出 → 一覧・チップ・図鑑・カテゴリ選択が新しい順で再描画
```

読み出し側(一覧のチップ・図鑑・`ItemCategoryPicker`・バックアップ)は既に `sort_order` 昇順 → `id` 昇順で読んでいる。**読み出し側のコードは変えない。**

## 設計判断(確定事項。実装者は変えない)

1. **振り直し方式**: 並び替えのたびに、渡された順で全カテゴリの `sort_order` を `0, 1, 2, …` に振り直す(差分更新はしない)
2. **引数は並び替え後の全 id の列**(`List<CategoryId>`)。「どれをどこへ」ではなく結果を渡す。リポジトリは、渡された id の集合が現在の全カテゴリの集合と**完全に一致**(件数一致・重複なし・過不足なし)しなければ `ArgumentError` を投げ、何も書かない(同時に追加・削除された場合の保護)
3. **1 トランザクション**: 集合の検査と全行の UPDATE を同じ `_db.transaction` に入れる。各 UPDATE は Drift の型付き `update(...)..where(id)` + `write(CategoriesCompanion(sortOrder: Value(i)))` で行う(`customStatement` は使わない。`watchAll` の購読に変更を確実に通知するため)
4. **楽観的 UI 更新を採らない**: `onReorder` では画面の並びを書き換えない。保存が済むと `watchAll` が新しい順を流し、それで再描画される。ドロップ直後は一瞬元の位置に戻って見えるが、ローカル SQLite なので体感上の問題は無い(CLAUDE.md「譲らない設計判断」)
5. **保存中の再操作**: 保存中(`reorderCategories` の Future 未完了)に来た `onReorder` は無視する(画面側の `bool _reordering` フラグ)。表示の並びと保存中の並びがずれた状態で次の列を作らないため
6. **ドラッグハンドル**: `buildDefaultDragHandles: false` にし、各行の `ListTile.leading` に `ReorderableDragStartListener(index: index, child: Icon(Icons.drag_handle))` を置く。行のタップ = 名前変更、`trailing` = 削除ボタンは今のまま。ハンドルを左、削除を右に分けて誤操作を避ける。ハンドルのアイコンには `semanticLabel` を付けない(読み上げの操作は判断 7 の組み込みカスタム操作で提供する。ハンドルを読ませても押して何も起きないため `ExcludeSemantics` で包む)
7. **アクセシビリティ**: `ReorderableListView`(内部の `SliverReorderableList`)が各行に付けるカスタム操作(ja ロケールで「先頭に移動」「上に移動」「下に移動」「最後に移動」)をそのまま使う。**独自の上下ボタンは置かない。** カスタム操作は `onReorder` を通るので、判断 4・5・8 がそのまま効く
8. **失敗時の知らせ方**: 既存の削除失敗と同じ `SnackBar` を出す。文言は **`並び替えを保存できませんでした。もう一度お試しください`**。並びは保存前のまま(= 何もしない)
9. **`onReorderItem` を使う(追補・fork 1 回目の後)**: `onReorder` は Flutter 3.41 以降で非推奨。代わりの `onReorderItem(oldIndex, newIndex)` は**取り除いた後の位置に補正済みの `newIndex`** を渡すので、自前の `if (newIndex > oldIndex) newIndex -= 1;` は書かない。現在の表示列のコピーに `removeAt(oldIndex)` → `insert(newIndex, …)` して id 列を作る。`oldIndex == newIndex` なら何もしない(保存しない)。`// ignore: deprecated_member_use` は残さない
10. **追加は末尾**: `add` の `MAX(sort_order) + 1` は変えない。振り直し後も最大値 + 1 なので末尾に入る
11. **`lib/data/database/` / `lib/data/migrations/` は一切変えない**(`app_database.dart` の「`MAX(sort_order) + 1` で採番する」コメントは追加時の説明として正しいまま)

## コンポーネント設計

### 1. `lib/domain/category_repository.dart`(変更)

`delete` の後に追加:

```dart
  /// 表示順を [orderedIds] の順に振り直す(sort_order = 0, 1, 2, …)。1 トランザクションで行う。
  ///
  /// [orderedIds] の集合が現在の全カテゴリと一致しない(件数・重複・過不足)ときは
  /// [ArgumentError] を投げ、何も書かない。
  Future<void> reorder(List<CategoryId> orderedIds);
```

`add` の doc は `sort_order は MAX + 1(空なら 0)。並び替えの後も末尾に入る。` に変える。

### 2. `lib/domain/category.dart`(コメントのみ)

`sortOrder` の doc を `/// 表示順。追加時は末尾(`MAX(sort_order) + 1`)。カテゴリの管理で並び替えると 0 始まりで振り直す。` に変える。

### 3. `lib/data/category_repository_impl.dart`(変更)

```dart
  @override
  Future<void> reorder(List<CategoryId> orderedIds) {
    // 集合の検査と全行の UPDATE を同じトランザクションに入れる。途中で失敗しても
    // sort_order が中途半端に残らない。
    return _db.transaction(() async {
      final rows = await _db.select(_db.categories).get();
      final current = rows.map((r) => r.id).toSet();
      final requested = orderedIds.map((id) => id.value).toList();
      if (requested.length != current.length ||
          requested.toSet().length != requested.length ||
          !current.containsAll(requested)) {
        throw ArgumentError.value(orderedIds, 'orderedIds', '現在のカテゴリの集合と一致しません');
      }
      for (var i = 0; i < requested.length; i++) {
        await (_db.update(_db.categories)
              ..where((t) => t.id.equals(requested[i])))
            .write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
  }
```

(フォーマットは `dart format` に従う。上は意図を示すもの)

### 4. `test/support/fake_category_repository.dart`(変更)

`reorder` を実装に揃える: `_failIfConfigured()` → 同じ集合検査(不一致なら `ArgumentError`、何も変えない)→ 各カテゴリを `Category(id, name, sortOrder: i)` で置き換え → `_emit()`。

### 5. `lib/state/category_results.dart`(変更)

末尾に追加:

```dart
/// カテゴリの並び替え結果。**例外を投げない。**
sealed class ReorderCategoryResult {
  const ReorderCategoryResult();
}

/// 保存まで成功した。並びは購読で届く。
final class ReorderCategorySucceeded extends ReorderCategoryResult {
  const ReorderCategorySucceeded();
}

/// 保存に失敗した(DB 書き込み失敗、または同時に追加・削除されて集合が合わなかった)。
/// 並びは変わらない。
final class ReorderCategoryFailed extends ReorderCategoryResult {
  const ReorderCategoryFailed();
}
```

### 6. `lib/state/category_list_notifier.dart`(変更)

`deleteCategory` の後に追加。`state` を触らない(判断 4)。

```dart
  /// カテゴリの並びを [orderedIds] の順にする。**並びの更新は購読に任せる**(楽観的に書き換えない)。
  Future<ReorderCategoryResult> reorderCategories(
    List<CategoryId> orderedIds,
  ) async {
    try {
      await ref.read(categoryRepositoryProvider).reorder(orderedIds);
      return const ReorderCategorySucceeded();
    } catch (error, stackTrace) {
      developer.log(
        'カテゴリの並び替えに失敗しました',
        name: 'lastwhen.state',
        error: error,
        stackTrace: stackTrace,
      );
      return const ReorderCategoryFailed();
    }
  }
```

`_latestCategories` は触らない(名前だけで重複検査に使っており、並びは関係しない)。

### 7. `lib/ui/screens/category_manage_screen.dart`(変更)

- クラス doc を `カテゴリの追加・名前変更・削除・並び替えを行う唯一の入口(F13)。` に変える
- `_CategoryList` を `ConsumerStatefulWidget` にし、`bool _reordering = false` を持つ
- `ListView.builder` → `ReorderableListView.builder`:
  - `padding: const EdgeInsets.only(bottom: 88)`(今と同じ)
  - `buildDefaultDragHandles: false`
  - `itemCount` / `itemBuilder` は今と同じ行に `key: ValueKey(category.id)` と `leading` を足す:
    ```dart
    leading: ReorderableDragStartListener(
      index: index,
      child: const ExcludeSemantics(child: Icon(Icons.drag_handle)),
    ),
    ```
  - `onReorderItem: (oldIndex, newIndex) => _reorder(oldIndex, newIndex)`(判断 9)
- `_reorder`:
  ```dart
  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_reordering) return;
    if (oldIndex == newIndex) return;
    final ids = [for (final c in widget.categories) c.id];
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    setState(() => _reordering = true);
    final result = await ref.read(categoryListProvider.notifier).reorderCategories(ids);
    if (!mounted) return;
    setState(() => _reordering = false);
    if (result is ReorderCategoryFailed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('並び替えを保存できませんでした。もう一度お試しください')),
      );
    }
  }
  ```
- 色・余白は生の値を足さない(padding 88 は既存値のまま)

### 8. 読み出し側

変更しない。`collection_screen.dart` / `item_list_screen.dart` / `item_category_picker.dart` / `item_add_screen.dart` / `item_edit_screen.dart` / `backup_repository_impl.dart` はすべて `categoryListProvider`(= `watchAll` の順)または `sort_order, id` 順で読んでいる。

## テスト戦略

### 統合テスト(`test/data/category_repository_impl_test.dart` に追加。既存の `_createDatabase` を使う)

1. `reorder で sort_order が渡した順の 0 始まりに振り直される`: 初期 4 件(生活・健康・趣味・その他)を `[その他, 生活, 趣味, 健康]` の id 順で `reorder` → `watchAll().first` の名前がその順、`sortOrder` が `[0,1,2,3]`
2. `reorder の後に add すると末尾に入る`: 1 と同じ並び替え → `add('新規')` → 末尾が「新規」で `sortOrder` 4
3. `集合が一致しない reorder は ArgumentError で何も変えない`: (a) 1 件欠けた列、(b) 存在しない id を含む列、(c) 重複を含む列 のそれぞれで `throwsArgumentError`、その後の `watchAll().first` の名前・`sortOrder` が初期のまま
4. `reorder が途中で失敗すると sort_order は元のまま(ロールバック)`: `db.customStatement` で次のトリガーをテスト内でだけ作る —
   `CREATE TRIGGER fail_reorder BEFORE UPDATE OF sort_order ON categories WHEN NEW.id = '<3 番目に渡す id>' BEGIN SELECT RAISE(ABORT, 'boom'); END`
   → 4 件すべてを含む正しい列で `reorder` → 例外(`throwsA(anything)`)→ `watchAll().first` の名前・`sortOrder` が初期のまま(1・2 件目の UPDATE も巻き戻っている)
5. `reorder 後に watchAll が新しい順を再送出する`: `watchAll()` を購読した状態で `reorder` → 次に届く値が新しい順(`backup_repository_impl_test.dart` の「通知の取り直しの契機」テストと同じ書き方)

### 統合テスト(`test/data/backup_repository_impl_test.dart` に追加)

6. `並び替えたカテゴリの順が書き出し → 復元で保たれる`: `CategoryRepositoryImpl(source).reorder(...)` → 既存の往復テストと同じ手順(readAll → encode → decode → 別 DB へ replaceAll)→ 復元先の `CategoryRepositoryImpl(target).watchAll().first` の名前の順が並び替え後と一致

### state(`test/state/category_list_notifier_test.dart` に `group('reorderCategories', …)` を追加。既存のフェイクと `ProviderContainer.test` を使う)

7. 成功すると `ReorderCategorySucceeded` を返し、その後の `categoryListProvider` の値が新しい順
8. `repository.writeError` を設定すると `ReorderCategoryFailed` を返し、並びは変わらない
9. 集合が合わない列(1 件欠け)を渡すと `ReorderCategoryFailed`

### ウィジェットテスト(`test/ui/screens/category_manage_screen_test.dart` に追加)

10. `ドラッグハンドルで並び替えると保存され、その順で表示される`: 「健康」「趣味」「その他」を追加 → 先頭行の `Icons.drag_handle` を `tester.drag(..., Offset(0, 行の高さ × 2 + 余裕))` で下へ(`timedDrag` でもよい)→ `pumpAndSettle` → `repository.watchAll().first` の名前順が変わっていること、画面上のテキストの y 座標の順が同じであること
11. `並び替えに失敗すると SnackBar が出て並びは変わらない`: `repository.writeError = Exception()` → 10 と同じドラッグ → `並び替えを保存できませんでした。もう一度お試しください` が出る・画面の順が元のまま
12. `各行に読み上げの並び替え操作がある`: `final handle = tester.ensureSemantics();` → 2 行目(中間の行)の Semantics に `CustomSemanticsAction(label: '上に移動')` と `'下に移動'` があることを確かめる(`tester.getSemantics(find.text('趣味'))` から親をたどるか、`find.bySemanticsLabel` 等で見つける方法は任せる)。さらに可能ならその「下に移動」を `tester.binding.pipelineOwner.semanticsOwner!.performAction(node.id, SemanticsAction.customAction, CustomSemanticsAction.getIdentifier(const CustomSemanticsAction(label: '下に移動')))` で実行し、並びが保存されることを確かめる。**実行まで安定して書けない場合は存在の確認だけでよい**(tasklist にその旨を残す)。`handle.dispose()` を忘れない
13. 既存テスト(タップで名前変更・削除確認・削除失敗の SnackBar)がそのまま通ること

### 反映先(`test/ui/item_list_screen_test.dart` に 1 件追加)

14. `カテゴリの並び替えがチップの順に反映される`: フェイクのカテゴリリポジトリで `reorder` した後に一覧を表示し、チップ(「すべて」の後)の並びがその順であることを x 座標で確かめる(既存のチップのテストの組み立て方に合わせる)

## docs の更新内容

### `docs/product-requirements.md` 226 行(F13)
`ユーザーが追加・名前変更・削除できる。` → `ユーザーが追加・名前変更・削除・並び替えできる。`

### `docs/functional-design.md`
- 84 行の doc コメント: `ユーザーが追加・名前変更・削除・並び替えできる。`
- 88 行: `final int sortOrder;    // 表示順。追加は MAX(sort_order) + 1(末尾)。並び替えで 0 始まりに振り直す`
- 「CategoryRepository」節: インターフェースの列挙に `reorder` を足し、次の 1 文を追加 —「`reorder` は渡された全 id の順で `sort_order` を 0 始まりに振り直す。集合が現在の全カテゴリと一致しなければ何も書かない。検査と更新を 1 トランザクションで行う(#91)。」
- 「カテゴリの絞り込み(F13)」節の最後の箇条: `カテゴリの追加・名前変更・削除・並び替えは設定から開くカテゴリ管理画面で行う(…)` とし、箇条を 1 つ追加 —「チップの順はカテゴリ管理で並び替えた順(`sort_order`)。図鑑の絞り込み・項目の追加/編集のカテゴリ選択・バックアップも同じ順(#91)」
- カテゴリ管理画面の並び替えの UI 仕様を「カテゴリの絞り込み(F13)」節の直後に小節「### カテゴリの並び替え(F13 / #91)」として追加: ハンドル(左)からドラッグ・行タップは名前変更・右は削除 / 保存の完了を待って並びを変える(楽観的更新をしない)/ 失敗は SnackBar「並び替えを保存できませんでした。もう一度お試しください」/ 読み上げは組み込みのカスタム操作(先頭に移動・上に移動・下に移動・最後に移動)/ 取り消し導線は置かない(並べ直せば戻せるため)

### `docs/glossary.md` 72 行
`ユーザーが追加・名前変更・削除・並び替えできる(F13)。`

## 実装の順序

domain → data(+ フェイク)→ state → UI → テスト → docs
