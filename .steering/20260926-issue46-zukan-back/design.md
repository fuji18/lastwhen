# 設計: 図鑑の検索中にシステムの戻るで検索を閉じる(Issue #46)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **スコープ判断(司令塔)**: P2 だが残る唯一のチケットで、ユーザーが着手を承認済み(前倒しではない)
> - **委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)に触れない。** DB は変わらない
> - **依存は増えない。** `pubspec.yaml` を変更しない
> - **`docs/` は司令塔が更新済み**(`docs/functional-design.md`「図鑑(F31)」の検索の項)。実装者は `docs/` を触らない
> - 変更するファイルは次の 2 つだけ: `lib/ui/screens/collection_screen.dart` / `test/ui/screens/collection_screen_test.dart`

## 判断1: `PopScope` で包む(`lib/ui/screens/collection_screen.dart`)

`_CollectionScreenState.build` が返している `Scaffold(...)` を、そのまま `PopScope` の `child` にする。
`Scaffold` の中身は一切変えない。

```dart
    return PopScope(
      // 検索中はシステムの戻るで検索を閉じる(アプリを終了させない)。
      // 図鑑は HomeShell の IndexedStack に常駐するため、タブが見えていないときは
      // 戻るを横取りしない(Visibility.of は非選択のタブで false を返す)。
      canPop: !(_searching && Visibility.of(context)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeSearch();
        }
      },
      child: Scaffold(
        ...(既存のまま)
      ),
    );
```

- **`Visibility.of(context)` を使う理由**: Flutter 3.47 の `IndexedStack` は各子を `_VisibilityScope` で包み、
  非選択の子では `Visibility.of` が `false` を返す(依存登録もされるのでタブ切替で再ビルドされる)。
  `HomeShell` に引数を足さずに済む。**`HomeShell` は変更しない**
- `onPopInvokedWithResult` の型引数は推論に任せる(`PopScope<Object?>` を明示しなくてよい)。analyze が型を要求したら `PopScope<Object?>` と書く
- 非表示タブのとき `canPop` は `true` になるので `onPopInvokedWithResult` の `didPop` は `true` になり、`_closeSearch` は呼ばれない
- クラスの doc コメント(`/// 図鑑画面。…`)は変えない

## 判断2: テスト(`test/ui/screens/collection_screen_test.dart`)

既存の `group('検索', ...)` の末尾に 3 件追加する。

### システムの戻るの再現と「アプリが閉じた」の判定

- 戻るは `await tester.binding.handlePopRoute();` の後に `await tester.pumpAndSettle();` で再現する
- アプリの終了は、ルートが 1 つしか無いとき `WidgetsApp` が呼ぶ `SystemNavigator.pop` のプラットフォーム呼び出しで判定する。
  `SystemChannels.platform` にモックハンドラを置き、メソッド名 `'SystemNavigator.pop'` の呼び出し回数を数える。
  `import 'package:flutter/services.dart';` を追加する

`group('検索', ...)` の中(先頭の `testWidgets` より前)にヘルパーを置く:

```dart
    /// `SystemNavigator.pop`(アプリの終了)が呼ばれた回数を数える。
    List<String> recordSystemPops(WidgetTester tester) {
      final pops = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') {
            pops.add(call.method);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      return pops;
    }
```

### 追加する 3 件

1. `'検索中にシステムの戻るを押すと検索が閉じ、アプリは閉じない'`
   - `pumpItems` → `_openCollection` → `recordSystemPops` → `find.byTooltip('検索')` をタップ → `pumpAndSettle`
   - `enterText(find.byType(TextField), '存在しない項目名')` → `pumpAndSettle`
   - `handlePopRoute` → `pumpAndSettle`
   - 期待: `pops` が空 / `find.byTooltip('検索')` が `findsOneWidget`(通常の AppBar に戻った)/ `find.byType(TextField)` が `findsNothing` / `find.widgetWithText(CollectionCard, '美容院')` が `findsOneWidget`(条件が消えて全件に戻った)
2. `'検索中でなければシステムの戻るはアプリの既定の動き(終了)になる'`
   - `pumpItems` → `_openCollection` → `recordSystemPops` → `handlePopRoute` → `pumpAndSettle`
   - 期待: `pops` の長さが 1
3. `'図鑑で検索を開いたままホームへ移ると、戻るを横取りしない'`
   - `pumpItems` → `_openCollection` → `recordSystemPops` → 検索ボタンをタップ → `pumpAndSettle`
   - テストではキーボードが出ない(`viewInsets` が 0)ので下部ナビは表示されたまま。`find.descendant(of: find.byType(NavigationBar), matching: find.text('ホーム'))` をタップ → `pumpAndSettle`
   - `handlePopRoute` → `pumpAndSettle`
   - 期待: `pops` の長さが 1

- 既存テストは変更しない
- 3 件目で `find.text('ホーム')` だけだと他に一致しうるため、上のとおり `NavigationBar` の子孫で絞る
