# 設計書: NFC タグをかざして「やった」を記録する(#98)

<!-- status: ready -->

## アーキテクチャ概要

```
NFC タグ(URI レコード lastwhen://done/<id>)
  → Android が NDEF_DISCOVERED / VIEW intent で MainActivity を起動
  → Flutter エンジン: コールド = 初期ルート文字列 / 起動中 = pushRouteInformation
  → DoneLinkReceiver(ui/。WidgetsBindingObserver。main で WidgetsApp より先に登録)
  → HomeShell がホームタブへ切り替え、recordFromDoneLink(item_navigation.dart)を呼ぶ
  → ItemListNotifier.markDoneFromLink(state/) → 既存の markDone → リポジトリ
  → スナックバー(取り消しは既存の _undoMarkDone を再利用)
```

- **新規依存なし**。Flutter 組み込みのディープリンク(`flutter_deeplinking_enabled` 既定 true)で受ける。`app_links` は足さない
- **データ層・スキーマは触らない**(`lib/data/` は変更なし)
- **iOS の設定は触らない**(`ios/` は変更なし)

## 設計判断(確定事項。実装者は変えない)

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | URL は `lastwhen://done/<項目ID>`(scheme `lastwhen`、host `done`、パス 1 段 = `ItemId.value`) | 項目 ID は UUID で名前変更でも変わらない。host に動作名を置けば将来別の動作を足せる |
| 2 | URL の受け取りは Flutter 組み込みのディープリンク。コールドスタートは `PlatformDispatcher.defaultRouteName`(Android は `intent.getData().toString()` = URL 全体が入る)、起動中は `WidgetsBindingObserver.didPushRouteInformation` | 依存を増やさない。エンジン実装(`FlutterActivityAndFragmentDelegate.maybeGetInitialRouteFromIntent` / `onNewIntent`)で両経路とも URL 全体が届くことを確認済み |
| 3 | `DoneLinkReceiver` は **`main()` で `runApp` の前に `addObserver` する** | `handlePushRoute` は登録順に observer を呼び、最初に true を返したものが勝つ。`WidgetsApp` が先だと `pushNamed('/<id>')` され、ルートが無くエラーになる。先に登録して `lastwhen` スキームなら true を返して握りつぶす |
| 4 | コールドスタート時の初期ルート(URL 文字列)は `MaterialApp` にそのまま任せる | `/` で始まらない初期ルートは `Navigator.defaultGenerateInitialRoutes` が黙って `/`(= `home`)にフォールバックする。追加の設定は不要 |
| 5 | `lastwhen` スキームだが形式が不正な URL(host 違い・パス段数違い・ID 空)は「見つからない」として扱う | ユーザーにとっては「タグが効かない」の 1 種類で足りる。書き込みはしない |
| 6 | **リンク経由で、今日(ローカル暦日)すでに記録済みなら書き込まない**。「「<名前>」は今日すでに記録しています」を出す。ボタンの「やった」の挙動は変えない | タグは連続で反応しやすく、履歴(F29)に同日の重複が残る。経過日数は暦日なので表示上も変化がない |
| 7 | 記録のスナックバーは項目名入り「「<名前>」を記録しました」+「取り消す」(`persist: false`)。取り消しは既存の `_undoMarkDone` を使う | タグ経由はユーザーがどの項目を記録したかを画面で見ていない。取り消しは「やった」と同じ経路で、未実施なら未実施に戻る |
| 8 | リンクを受けたら **ホームタブへ切り替える**(`_select(0)` 相当。スナックバーも閉じる)。積まれた画面(詳細・編集・登録)は **閉じない** | 図鑑・設定タブは専用の `ScaffoldMessenger` を持つため、ホーム以外ではスナックバーが見えない。積まれた画面を閉じると入力途中のフォームを失う。積まれた画面はアプリの `ScaffoldMessenger` 配下なのでスナックバーはそこに出る |
| 9 | 一覧の初回読み込み前に届いたリンクは、`markDoneFromLink` が **`await future`(最初の一覧)を待ってから**判定する | コールドスタートでは一覧の読み込み前にリンクが来る。`markDone` は `_latestItems` に無いと `MarkDoneIgnored` を返すため、待たないと必ず「見つからない」になる |
| 10 | URL の導線は記録の詳細の「…」メニュー「NFC タグに登録」→ ダイアログ(説明・URL・「閉じる」「コピー」) | 項目ごとの操作は詳細のメニューに集まっている(判断G)。タグへの書き込みは市販アプリに任せるので、URL と手順が見えれば足りる |
| 11 | 「NFC タグ」は用語の禁止一覧の「タグ」(カテゴリの言い換え)に当たらない。glossary に用語として足し、`terminology_test.dart` の許可語に `NFC タグ` を足す | 機器の名前で言い換えではない |
| 12 | `ItemListScreen` の「ディープリンクも扱わない」コメントは「ディープリンクは記録のリンク(F32)だけで、画面へは遷移しない」に直す。名前付きルートは引き続き使わない | 実態と食い違うコメントを残さない |

## 実装内容

### §1 `lib/domain/done_link.dart`(新規。Flutter に依存しない)

```dart
import 'item.dart';

/// 記録のリンク(F32)のスキーム。Android の intent-filter と揃える。
const String doneLinkScheme = 'lastwhen';

/// 記録のリンクの host(動作名)。
const String doneLinkHost = 'done';

/// [id] を記録するリンク(`lastwhen://done/<id>`)を作る。NFC タグに書き込む URL。
Uri doneLinkFor(ItemId id) =>
    Uri(scheme: doneLinkScheme, host: doneLinkHost, pathSegments: [id.value]);

/// このアプリ宛てのリンクか(スキームだけを見る)。形式の正否は問わない。
bool isAppLink(Uri uri) => uri.scheme == doneLinkScheme;

/// 記録のリンクから項目 ID を取り出す。形式が違えば null(判断5)。
///
/// 末尾のスラッシュ(空のパス段)は無視する。クエリ・フラグメントは見ない。
ItemId? parseDoneLink(Uri uri) {
  if (uri.scheme != doneLinkScheme || uri.host != doneLinkHost) {
    return null;
  }
  final segments = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (segments.length != 1) {
    return null;
  }
  return ItemId(segments.single);
}
```

### §2 `lib/state/link_mark_done_result.dart`(新規)

`mark_done_result.dart` と同じ書き方(sealed・doc コメント)で:

```dart
import 'mark_done_result.dart';

/// リンク(NFC タグ)からの記録の結果(F32)。**例外を投げない。**
sealed class LinkMarkDoneResult { const LinkMarkDoneResult(); }

/// 記録した。[undo] を取り消し導線へ渡す。
final class LinkMarkDoneSucceeded extends LinkMarkDoneResult {
  const LinkMarkDoneSucceeded({required this.itemName, required this.undo});
  final String itemName;
  final MarkDoneUndo undo;
}

/// 今日(ローカル暦日)すでに記録済みだった。**書き込みを試みていない**(判断6)。
final class LinkMarkDoneAlreadyToday extends LinkMarkDoneResult {
  const LinkMarkDoneAlreadyToday({required this.itemName});
  final String itemName;
}

/// 項目が見つからなかった(削除済み・ID 不正)。**書き込みを試みていない。**
final class LinkMarkDoneNotFound extends LinkMarkDoneResult { const LinkMarkDoneNotFound(); }

/// 一覧の読み込みか書き込みに失敗した。
final class LinkMarkDoneFailed extends LinkMarkDoneResult { const LinkMarkDoneFailed(); }
```

### §3 `lib/state/item_list_notifier.dart` に `markDoneFromLink` を足す

`undoMarkDone` の直後に置く。import に `../domain/elapsed_days.dart` と `link_mark_done_result.dart` を足す。

```dart
/// リンク(NFC タグ)から「やった」を記録する(F32)。**確認は挟まない。**
///
/// コールドスタートでは一覧の読み込み前に呼ばれるので、最初の一覧を待ってから探す(判断9)。
/// 今日すでに記録済みなら書き込まない(判断6)。書き込みは [markDone] を通す。
Future<LinkMarkDoneResult> markDoneFromLink(ItemId id) async {
  try {
    await future;
  } catch (error, stackTrace) {
    developer.log(
      'リンクからの記録で一覧を読み込めませんでした',
      name: 'lastwhen.state',
      error: error,
      stackTrace: stackTrace,
    );
    return const LinkMarkDoneFailed();
  }
  final index = _latestItems.indexWhere((item) => item.id == id);
  if (index < 0) {
    return const LinkMarkDoneNotFound();
  }
  final item = _latestItems[index];
  final lastDoneAt = item.lastDoneAt;
  if (lastDoneAt != null &&
      elapsedDays(lastDoneAt: lastDoneAt, now: ref.read(clockProvider).now()) == 0) {
    return LinkMarkDoneAlreadyToday(itemName: item.name);
  }
  return switch (await markDone(id)) {
    MarkDoneSucceeded(:final undo) => LinkMarkDoneSucceeded(itemName: item.name, undo: undo),
    MarkDoneIgnored() => const LinkMarkDoneNotFound(),
    MarkDoneFailed() => const LinkMarkDoneFailed(),
  };
}
```

`future` は `$AsyncNotifierBase` の protected getter(riverpod 3.4.3 で確認済み)。`analyze` が `invalid_use_of_visible_for_testing_member` を出した場合は**停止して報告する**(自分で回避策を選ばない)。

### §4 `lib/ui/done_link_receiver.dart`(新規)

```dart
import 'package:flutter/widgets.dart';

import '../domain/done_link.dart';
import '../domain/item.dart';

/// 記録のリンク(F32)を受け取る。項目 ID が null のリンクは「形式が不正」を表す(判断5)。
typedef DoneLinkHandler = void Function(ItemId? id);

/// `lastwhen://` のリンクを OS から受け取り、[attach] した処理へ渡す(F32)。
///
/// **`main()` で `runApp` の前に `WidgetsBinding.instance.addObserver` すること**(判断3)。
/// `WidgetsApp` より後に登録すると、リンクが `pushNamed` されてエラーになる。
/// 処理が [attach] される前に届いたリンク(コールドスタートの初期ルートを含む)は溜めておき、
/// [attach] の時点で届いた順に渡す。
class DoneLinkReceiver with WidgetsBindingObserver {
  /// [initialRoute] はコールドスタートの初期ルート(`PlatformDispatcher.defaultRouteName`)。
  DoneLinkReceiver({String? initialRoute}) {
    final uri = initialRoute == null ? null : Uri.tryParse(initialRoute);
    if (uri != null && isAppLink(uri)) {
      _pending.add(parseDoneLink(uri));
    }
  }

  final List<ItemId?> _pending = [];
  DoneLinkHandler? _handler;

  /// リンクの処理を登録し、溜まっていたリンクを渡す。
  void attach(DoneLinkHandler handler) {
    _handler = handler;
    final pending = List<ItemId?>.of(_pending);
    _pending.clear();
    for (final id in pending) {
      handler(id);
    }
  }

  /// 処理の登録を外す。以降のリンクは次の [attach] まで溜める。
  void detach() {
    _handler = null;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    if (!isAppLink(uri)) {
      return false;
    }
    final id = parseDoneLink(uri);
    final handler = _handler;
    if (handler == null) {
      _pending.add(id);
    } else {
      handler(id);
    }
    return true;
  }
}
```

### §5 `lib/main.dart`

`container.read(notificationSyncProvider);` の後、`runApp` の前に:

```dart
  // 記録のリンク(F32)。WidgetsApp より先に登録する(design.md 判断3)。
  final doneLinks = DoneLinkReceiver(
    initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
  );
  WidgetsBinding.instance.addObserver(doneLinks);
```

`runApp(UncontrolledProviderScope(container: container, child: App(doneLinks: doneLinks)));`(`const` を外す)。import `ui/done_link_receiver.dart` を足す。

### §6 `lib/app.dart`

- コンストラクタを `const App({super.key, this.doneLinks});` にし、フィールド `final DoneLinkReceiver? doneLinks;`(doc: 「記録のリンクの受け口(F32)。テストでは省略できる」)
- `home: HomeShell(doneLinks: doneLinks)`
- 既存テストの `const App()` はそのまま通る(引数は任意)

### §7 `lib/ui/screens/home_shell.dart`

- `HomeShell` に `const HomeShell({super.key, this.doneLinks});` / `final DoneLinkReceiver? doneLinks;` を足す
- `_HomeShellState`:
  - `initState` で `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) widget.doneLinks?.attach(_onDoneLink); });`(initState 中は `ScaffoldMessenger.of` を引けないため 1 フレーム後)
  - `dispose` で `widget.doneLinks?.detach();`
  - 追加メソッド:

    ```dart
    /// 記録のリンク(F32)を受けた。ホームへ切り替えて記録する(design.md 判断8)。
    void _onDoneLink(ItemId? id) {
      if (!mounted) {
        return;
      }
      _select(0);
      unawaited(recordFromDoneLink(context, id));
    }
    ```

  - `_select(0)` は既にホームなら何もしない(既存の早期 return)。それで問題ない(スナックバーは `recordFromDoneLink` 側で `clearSnackBars` する)
- import: `dart:async`、`../../domain/item.dart`、`../done_link_receiver.dart`、`../item_navigation.dart`

### §8 `lib/ui/item_navigation.dart` に `recordFromDoneLink` を足す

`_undoMarkDone` の直後に置く。import `../state/link_mark_done_result.dart` を足す。

```dart
/// 記録のリンク(NFC タグ)から記録し、結果を出す(F32)。**確認ダイアログは出さない。**
///
/// [id] が null = 形式が不正なリンク。見つからないときと同じ表示にする(design.md 判断5)。
Future<void> recordFromDoneLink(BuildContext context, ItemId? id) async {
  final messenger = ScaffoldMessenger.of(context);
  if (id == null) {
    _showDoneLinkMessage(messenger, 'この項目は見つかりませんでした');
    return;
  }
  final notifier = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(itemListProvider.notifier);
  final result = await notifier.markDoneFromLink(id);
  switch (result) {
    case LinkMarkDoneSucceeded(:final itemName, :final undo):
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('「$itemName」を記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _undoMarkDone(messenger, notifier, undo),
          ),
        ),
      );
    case LinkMarkDoneAlreadyToday(:final itemName):
      _showDoneLinkMessage(messenger, '「$itemName」は今日すでに記録しています');
    case LinkMarkDoneNotFound():
      _showDoneLinkMessage(messenger, 'この項目は見つかりませんでした');
    case LinkMarkDoneFailed():
      _showDoneLinkMessage(messenger, '保存できませんでした。もう一度お試しください');
  }
}

/// 記録のリンクの結果を 1 件だけ出す。
void _showDoneLinkMessage(ScaffoldMessengerState messenger, String message) {
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
```

### §9 `lib/ui/screens/item_detail_screen.dart` にメニューとダイアログを足す

- `enum _DetailMenuAction { recordPastDate, edit, nfcTag }`
- `itemBuilder` の末尾(「編集」の後)に:

  ```dart
  PopupMenuItem(
    value: _DetailMenuAction.nfcTag,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.nfc),
      title: Text('NFC タグに登録'),
    ),
  ),
  ```

- `onSelected` に `case _DetailMenuAction.nfcTag: unawaited(_showNfcTagDialog(context, item));`
- 同ファイル内に private 関数を足す(`import 'package:flutter/services.dart';` と `../../domain/done_link.dart` を足す):

  ```dart
  /// NFC タグに書き込むリンクを見せる(F32 / design.md 判断10)。書き込みは市販の NFC アプリに任せる。
  Future<void> _showNfcTagDialog(BuildContext context, ItemView item) {
    final link = doneLinkFor(item.id).toString();
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: const Text('NFC タグに登録'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NFC タグ書き込みアプリで、次のリンクを URL としてタグに書き込んでください。'
                  'タグにスマホをかざすと「${item.name}」を記録します(Android のみ)。',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SelectableText(link, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!dialogContext.mounted) {
                  return;
                }
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('リンクをコピーしました')));
              },
              child: const Text('コピー'),
            ),
          ],
        );
      },
    );
  }
  ```

  - `item.name` は `ItemView.name`(項目名の `String`)
  - `context.mounted` も確認してから `ScaffoldMessenger.of(context)` を引く
  - ファイルが 500 行を超える場合は、ダイアログを `lib/ui/widgets/nfc_tag_dialog.dart`(公開関数 `showNfcTagDialog`)へ切り出す

### §10 `lib/ui/screens/item_list_screen.dart` のコメント

`_openAddScreen` の doc の「ディープリンクも扱わない」を「ディープリンクは記録のリンク(F32)だけで、画面へは遷移しない」に直す(判断12)。コードは変えない。

### §11 `android/app/src/main/AndroidManifest.xml`

`MainActivity` の LAUNCHER の intent-filter の後に 2 つ足す:

```xml
            <!-- 記録のリンク(F32 / #98)。NFC タグの URI レコードで起動する -->
            <intent-filter>
                <action android:name="android.nfc.action.NDEF_DISCOVERED"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <data android:scheme="lastwhen" android:host="done"/>
            </intent-filter>
            <!-- 同じリンクを他のアプリ・adb から開いたとき -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="lastwhen" android:host="done"/>
            </intent-filter>
```

NFC の `uses-permission` / `uses-feature` は足さない(アプリは NFC を読まない。OS のタグ配送に権限は要らない)。`launchMode="singleTop"` は既存のままで、起動中は `onNewIntent` → `pushRouteInformation` になる。

## テスト

### §T1 `test/domain/done_link_test.dart`(新規)

- `doneLinkFor(ItemId('abc-123')).toString()` が `lastwhen://done/abc-123`
- `parseDoneLink(doneLinkFor(id)) == id`(往復)
- `parseDoneLink(Uri.parse('lastwhen://done/abc/'))` が `ItemId('abc')`(末尾スラッシュ)
- null になる: `lastwhen://done`、`lastwhen://done/`、`lastwhen://done/a/b`、`lastwhen://other/abc`、`https://done/abc`
- `isAppLink`: `lastwhen://x` は true、`https://example.com` は false

### §T2 `test/state/item_list_notifier_test.dart` に `group('markDoneFromLink', ...)` を足す

既存の `_container` / `FakeItemRepository` / `FakeClock` を使う。`now = DateTime.utc(2026, 9, 16, 3)`(既存)。

1. 未実施の項目 → `LinkMarkDoneSucceeded`、`itemName` が項目名、リポジトリの最終実施日が `now`
2. 昨日記録済み(`now - 1 日`)→ `LinkMarkDoneSucceeded`
3. 今日記録済み(同じローカル暦日。`now` の 1 時間前など、ローカル暦日が変わらない値。既存テストのタイムゾーン前提に合わせる)→ `LinkMarkDoneAlreadyToday`、最終実施日は変わらない
4. 存在しない ID → `LinkMarkDoneNotFound`、書き込みなし
5. **一覧の初回読み込み前に呼んでも**(コンテナ作成直後に `await` せず呼ぶ)見つかって `LinkMarkDoneSucceeded` になる(判断9)
6. 成功時の `undo` を `undoMarkDone` に渡すと未実施に戻る

### §T3 `test/ui/done_link_receiver_test.dart`(新規。Flutter テスト)

- `initialRoute: 'lastwhen://done/abc'` で作り、`attach` すると `ItemId('abc')` が 1 回渡る
- `initialRoute: '/'` や `null` では何も渡らない
- `initialRoute: 'lastwhen://other/x'` では `null` が渡る(不正形式)
- `didPushRouteInformation(RouteInformation(uri: Uri.parse('lastwhen://done/x')))` が true を返し、attach 済みなら即座に渡る
- attach 前に push されたものは溜まり、attach 時に順に渡る
- `https://example.com` は false を返し、何も渡らない
- `detach` 後の push は溜まる

### §T4 `test/ui/done_link_flow_test.dart`(新規。ウィジェットテスト)

`terminology_test.dart` と同じ `ProviderScope` の overrides(`FakeItemRepository` / `FakeCategoryRepository` / `FakeClock`)で `App(doneLinks: receiver)` を出す。

1. **コールド**: 項目を 1 件足し、`DoneLinkReceiver(initialRoute: doneLinkFor(item.id).toString())` で起動 → `pumpAndSettle` → `「<名前>」を記録しました` と `取り消す` が見える。リポジトリの最終実施日が `now`。確認ダイアログ(`AlertDialog`)が無い
2. **起動中**: `DoneLinkReceiver()` で起動 → `pumpAndSettle` 後に `receiver.didPushRouteInformation(...)` → `pumpAndSettle` → 同じ表示
3. **取り消し**: 1 の後に「取り消す」をタップ → 項目が未実施に戻る
4. **今日記録済み**: 同じリンクを 2 回 push → 2 回目で `「<名前>」は今日すでに記録しています`。記録は 1 回分のまま
5. **見つからない**: `lastwhen://done/unknown` → `この項目は見つかりませんでした`
6. **不正形式**: `lastwhen://other/x` → `この項目は見つかりませんでした`
7. **図鑑タブ表示中**: 図鑑タブに切り替えてから push → ホームタブに戻り、スナックバーが見える

### §T5 `test/ui/screens/item_detail_screen_test.dart` に足す

- メニュー →「NFC タグに登録」→ ダイアログにリンク `lastwhen://done/<id>` が表示される
- 「コピー」でクリップボードにリンクが入り(`SystemChannels.platform` のモックで `Clipboard.setData` を受ける。`test/ui/screens/settings_screen_test.dart` の `_mockClipboard` と同じ書き方にする)、ダイアログが閉じて「リンクをコピーしました」が出る

### §T6 `test/ui/terminology_test.dart`

`_stripAllowed` で `NFC タグ` も除く(`text.replaceAll('最終実施日', '').replaceAll('NFC タグ', '')`)。判断11。

## docs

### §D1 `docs/product-requirements.md`

- P2 機能の表の F31 の後に行を足す:
  `| F32 | NFC タグで記録 | 項目ごとのリンク(`lastwhen://done/<項目ID>`)を NFC タグに書き込み、かざすと記録する。Android のみ。タグへの書き込みは市販の NFC アプリに任せる(#98) |`
- 表の後(`**優先度**: P2(できれば)` の前)に追記ブロック:

  > **追記(#98)**: F32 を足した。かざすだけで記録でき、「1 タップで記録」をさらに短くする。確認は出さず取り消しで救う(F3 と同じ)。タグは連続で反応しやすいので、**リンク経由に限り今日すでに記録済みなら書き込まない**。iOS は独自スキームではかざしただけで起動せず Universal Link(ドメイン)が要るため、iOS 公開の保留が外れるまで Android のみとする。

### §D2 `docs/functional-design.md`

- `### UC1b: 過去の日付で記録する(F16)` の節の後に `### UC1c: NFC タグで記録する(F32 / #98)` を足す。内容は「アーキテクチャ概要」の流れ図と、判断 3・5・6・8・9 を番号付き手順で(UC1b の書き方に揃える)
- `## UI設計` の `### 記録の詳細(F29)` 節に、メニュー「NFC タグに登録」とダイアログ(説明・リンク・閉じる/コピー)を 1〜2 行で足す
- `## セキュリティ考慮事項` に 1 行: 「記録のリンクは他のアプリや Web ページからも開ける。ローカル専用で被害は記録 1 件・取り消しできるため許容する(F32)」

### §D3 `docs/glossary.md`

`### バックアップ(書き出し・復元)【P1】` の節の後に:

```markdown
### NFC タグ / 記録のリンク【P2】

項目ごとのリンク `lastwhen://done/<項目ID>` を書き込んだ NFC タグ。かざすとその項目を記録する(F32)。
コード上の表記は `doneLinkFor` / `parseDoneLink` / `DoneLinkReceiver`。UI 文言は「NFC タグに登録」「リンク」。

- 「NFC タグ」は機器の名前で、カテゴリの言い換えとしての「タグ」(禁止)には当たらない。**「NFC」を付けずに「タグ」とだけ書かない**
```

## 自己検証

- `dart format --output=none --set-exit-if-changed .`
- `flutter analyze --fatal-infos`
- `flutter test`(全件)
- Flutter SDK は `/opt/flutter/bin` にある(`export PATH=/opt/flutter/bin:$PATH`)
