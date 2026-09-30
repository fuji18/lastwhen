# 設計書: 下部ナビの「設定」と設定画面(Issue #81)

<!-- status: ready -->

> 決定と理由は `requirements.md`。ここには実装者が手を動かす部分(`lib/` と `test/`)だけを書く。
> docs(PRD / functional-design / glossary / repository-structure / development-guidelines)は司令塔が書き終えている。
> **新規依存を足さない**(`pubspec.yaml` を触らない)。

## 1. `lib/ui/app_info.dart`(新規)

```dart
/// 設定画面の「このアプリについて」に出す情報。
abstract final class AppInfo {
  /// アプリ名(ブランド表記)。
  static const String name = 'LastWhen';

  /// `pubspec.yaml` の `version` と同じ値。**バージョンを上げるときは両方を直す。**
  /// 食い違いは `test/ui/app_info_test.dart` が検出する。
  static const String version = '1.0.0+1';

  /// 画面に出すバージョン(`+` より前 = versionName)。
  static String get versionName => version.split('+').first;

  /// プライバシーポリシーの公開先(原稿は `site/privacy-policy/index.html`)。
  static const String privacyPolicyUrl =
      'https://fuji18.github.io/lastwhen/privacy-policy/';
}
```

## 2. `lib/ui/screens/settings_screen.dart`(新規)

`StatelessWidget` の `SettingsScreen`。Riverpod は使わない。`Scaffold` は `CollectionScreen` と同じく
`backgroundColor` を指定しない(`PaperBackground` を透かす)。色・文字は `Theme.of(context)` から取る。

構成(上から。`body: SafeArea(child: ListView(children: [...]))`):

1. `ListTile`: leading `Icon(Icons.label_outline)` / title `カテゴリの管理` / trailing `Icon(Icons.chevron_right)` /
   onTap: `ScaffoldMessenger.of(context).clearSnackBars()` の後に
   `Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (context) => const CategoryManageScreen()))`
2. `Divider()`
3. 見出し `注意事項`(下記 `_SectionHeader`)
4. 注意事項の `ListTile` 3 行(onTap なし。title の `Text` は行数制限しない):
   | leading | title |
   | --- | --- |
   | `Icons.smartphone_outlined` | `項目と記録は、この端末の中にだけ保存されます。アプリがインターネットへ送信することはありません。` |
   | `Icons.delete_outline` | `アプリを削除すると、項目と記録もすべて消えます。` |
   | `Icons.cloud_outlined` | `端末のバックアップ(Android の自動バックアップなど)が有効な場合は、機種変更で引き継げるように、項目と記録の複製が OS の提供元のクラウドに保存されます。` |
5. `Divider()`
6. 見出し `このアプリについて`
7. `ListTile`: leading `Icon(Icons.privacy_tip_outlined)` / title `プライバシーポリシー` / subtitle `Text(AppInfo.privacyPolicyUrl)` /
   trailing `IconButton(icon: const Icon(Icons.copy), tooltip: 'URL をコピー', onPressed: () => _copyPrivacyPolicyUrl(context))` /
   onTap: 同じく `_copyPrivacyPolicyUrl(context)`
8. `ListTile`: leading `Icon(Icons.info_outline)` / title `バージョン` / subtitle `Text(AppInfo.versionName)`(onTap なし)
9. `ListTile`: leading `Icon(Icons.description_outlined)` / title `ライセンス` / trailing `Icon(Icons.chevron_right)` /
   onTap: `showLicensePage(context: context, applicationName: AppInfo.name, applicationVersion: AppInfo.versionName)`

AppBar は `AppBar(title: const Text('設定'))`。

見出しはファイル内のプライベートウィジェット:

```dart
/// 設定画面の区切りの見出し。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
```

コピーはファイル内のトップレベル関数:

```dart
/// プライバシーポリシーの URL をクリップボードへ写し、結果を知らせる。
Future<void> _copyPrivacyPolicyUrl(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: AppInfo.privacyPolicyUrl));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('URL をコピーしました')));
}
```

import は `package:flutter/material.dart` / `package:flutter/services.dart` / `../app_info.dart` / `category_manage_screen.dart`。

## 3. `lib/ui/screens/home_shell.dart` の変更

- クラスの doc コメント 1 行目を
  `/// 下部ナビで一覧(ホーム)・図鑑・設定を切り替える外枠(F31)。起動直後は必ずホーム。` にする。
  「図鑑側は専用の `ScaffoldMessenger` で包む。」の段落の先頭を「図鑑と設定は専用の `ScaffoldMessenger` で包む。」に、
  続く「図鑑の `Scaffold` も」を「図鑑・設定の `Scaffold` も」、「オフステージの図鑑にも」を「オフステージのタブにも」に直す
- `_HomeShellState` にフィールドを足す:
  ```dart
  /// 設定タブの `ScaffoldMessenger`。タブ切替でコピー完了の `SnackBar` を閉じるために持つ。
  final _settingsMessengerKey = GlobalKey<ScaffoldMessengerState>();
  ```
- `IndexedStack` の `children` から `const` を外し、3 つ目を足す(`ItemListScreen()` と図鑑の行には `const` を付ける):
  ```dart
  // 設定も図鑑と同じ理由で専用の ScaffoldMessenger で包む(#34 判断9)。
  ScaffoldMessenger(
    key: _settingsMessengerKey,
    child: const SettingsScreen(),
  ),
  ```
- `destinations` の末尾に足す:
  ```dart
  NavigationDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: '設定',
  ),
  ```
- `_select` の `ScaffoldMessenger.of(context).clearSnackBars();` の直後に
  `_settingsMessengerKey.currentState?.clearSnackBars();` を足す
- import に `settings_screen.dart` を足す

## 4. `lib/ui/screens/item_list_screen.dart` の変更

- AppBar の `actions` から「カテゴリを管理」の `IconButton` を消す(並び順のボタンだけ残す)
- `_openCategoryManageScreen` 関数と、未使用になる `category_manage_screen.dart` の import を消す
- AppBar の `title` の上のコメント 1 行目を
  `// 並び順のボタンと並べると、文字サイズ 150% 以上で幅が足りず省略されうる。` に直す(2 行目はそのまま)。`FittedBox` は残す

## 5. テスト

既存テストのフェイクと `App` の組み立ては `test/ui/screens/collection_screen_test.dart` の `_app` / `pumpItems` と同じ形で書く。

### 5.1 `test/ui/app_info_test.dart`(新規)

- `AppInfo.version` が `pubspec.yaml` の `version` と一致する:
  `File('pubspec.yaml').readAsStringSync()` を `RegExp(r'^version:\s*(\S+)', multiLine: true)` で抜き、`AppInfo.version` と比べる
- `AppInfo.versionName` が `version` の `+` より前と一致する(`1.0.0`)

### 5.2 `test/ui/screens/settings_screen_test.dart`(新規)

下部ナビの「設定」をタップするヘルパ `_openSettings`(`find.descendant(of: find.byType(NavigationBar), matching: find.text('設定'))`)を使う。

1. 起動直後はホームで、下部ナビに「ホーム」「図鑑」「設定」がある(`SettingsScreen` は `findsNothing`)
2. 設定を開くと「カテゴリの管理」「注意事項」「プライバシーポリシー」`AppInfo.privacyPolicyUrl`「バージョン」`AppInfo.versionName`「ライセンス」が表示される(画面外なら `ensureVisible` / `scrollUntilVisible` を使う)
3. 「カテゴリの管理」をタップすると `CategoryManageScreen` が開く
4. 「URL をコピー」をタップすると、クリップボードに `AppInfo.privacyPolicyUrl` が入り、「URL をコピーしました」の `SnackBar` が出る。
   クリップボードは `tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, ...)` で
   `Clipboard.setData` の引数を捕まえる(`addTearDown` でハンドラを `null` に戻す)
5. コピー後にホームへ移って設定に戻ると `SnackBar` が無い
6. 「ライセンス」をタップすると `LicensePage` が開く。**`pumpAndSettle` を使わない**(ライセンス読み込み中のインジケータで終わらない)。
   `tester.pump()` と `tester.pump(const Duration(milliseconds: 500))` の後に `find.byType(LicensePage)` を検査する
7. ホームで記録した直後(`collection_screen_test.dart` の「ホームで記録した直後に図鑑を開くと取り消し導線が消える」と同じ操作)に
   設定を開くと `SnackBar` が無く、`tester.takeException()` が `null`
8. 一覧の AppBar に「カテゴリを管理」のボタンが無い(`find.byTooltip('カテゴリを管理')` が `findsNothing`)

### 5.3 既存テストの修正

- `test/ui/item_list_screen_test.dart` の「AppBar のボタンから管理画面へ遷移する」を消す(5.2 の 3 と 8 に移った)
- `test/ui/terminology_test.dart`:
  - `'カテゴリ管理'` の case を「下部ナビの『設定』→『カテゴリの管理』」の操作に変える
  - 画面の一覧の末尾に `'設定'` を足し、case `'設定'` で下部ナビの「設定」をタップして `SettingsScreen` が出ることを確かめる
- `test/ui/accessibility_test.dart`: 「文字サイズ 200% で記録の詳細が破綻しない」と同じ形で
  「文字サイズ 200% で設定画面が破綻しない」を足す(`tester.takeException()` が `null`、「カテゴリの管理」「ライセンス」に `scrollUntilVisible` で届く)

## 6. 検証と停止条件

- `dart format --output=none --set-exit-if-changed .` と `flutter analyze --fatal-infos` を通す(テストは検収側が回す)
- 同じエラーで 2 回直して通らなければ止めて報告する
- ここに書いていない UI 文言・部品を足さない

## 7. CI 失敗の修正(PR #88)

`settings_screen_test.dart` の「コピー後にホームへ移って設定に戻ると SnackBar が無い」が 150 行目
(`expect(find.byType(SnackBar), findsOneWidget)`)で落ちる。

**原因**: このテストは `SystemChannels.platform` をモックしていない。モックが無いと
`Clipboard.setData` の応答は実際の非同期で返り、`testWidgets` の FakeAsync 内の `pumpAndSettle` では
完了しない。`_copyPrivacyPolicyUrl` が `await` から戻らず、`SnackBar` が出ない。
製品コード(`settings_screen.dart`)は変えない。

**修正**:

- `settings_screen_test.dart` にクリップボードのモックを入れるヘルパを足す。
  「URL をコピーすると…」のテストにあるモックの登録と `addTearDown` をこのヘルパに移す:
  ```dart
  /// `Clipboard.setData` を受け止めるモックを入れ、写された文字列を返す関数を返す。
  String? Function() _mockClipboard(WidgetTester tester) {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<dynamic, dynamic>)['text'] as String;
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
    return () => copiedText;
  }
  ```
- 「URL をコピーすると…」は `final copied = _mockClipboard(tester);` を使い、`expect(copied(), AppInfo.privacyPolicyUrl)` にする
- 「コピー後にホームへ…」は `_openSettings` の後に `_mockClipboard(tester);` を呼ぶ。それ以外の手順は変えない
- 検証: `flutter test test/ui/screens/settings_screen_test.dart` が全件通ること(fork はホストで実行できる)。続けて `dart format` と `flutter analyze --fatal-infos`
