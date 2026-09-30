# 設計書

<!-- status: ready -->

> **完成マーカー**: 上の行は機械が読む印です。`draft` = 執筆中(実装に渡してはいけない)、`ready` = 実装可能(設計判断は書き切られている)。

## アーキテクチャ概要

```
ItemListScreen の AppBar.title
  └ FittedBox(scaleDown)
      └ AppLogo(新規・lib/ui/widgets/app_logo.dart)
          └ Image.asset('assets/branding/logo_wordmark.png',
                        color: onSurface, colorBlendMode: srcIn, semanticLabel: AppInfo.name)
```

## 設計判断(確定事項。実装者は変えない)

1. **アセットは司令塔が用意済み**: `assets/branding/logo_wordmark.png`(619×120・RGBA・約 45KB)。
   元画像 `docs/ideas/LastWhen_logo_haikeinashi.png`(2172×724)の透過部分を切り詰め(不透明部分の外接矩形)、高さ 120px に面積平均で縮小したもの。
   **実装者は画像を作り直さない・加工しない。** 元画像 `docs/ideas/LastWhen_logo_haikeinashi.png` も素材の出所としてコミットする
2. **解像度別アセット(`2.0x/` `3.0x/`)は作らない**: 表示の高さ 28dp に対して 120px あれば 4.2 倍の密度まで足りる。1 枚で持つ
3. **バンドルはこのファイルだけ**: `pubspec.yaml` の `flutter: assets:` には**ファイル単位**で `assets/branding/logo_wordmark.png` を足す。ディレクトリ(`assets/branding/`)は登録しない(アイコン・スプラッシュの生成用の入力画像はアプリに入れない方針のまま)
4. **着色**: 単色ロゴなので `Image.asset` の `color: Theme.of(context).colorScheme.onSurface` + `colorBlendMode: BlendMode.srcIn` で塗る。ライトでは焦げ茶(`0xFF261B14`)、ダークではクリーム(`0xFFF0E3D3`)になり、本文と同じ組み合わせなので既存のコントラスト検査(onSurface × surface 系)の範囲内。画像を 2 枚持たない
5. **高さは 28dp の固定値**: `titleLarge` の行の高さ(28)に揃える。ロゴは「文字の画像」だがロゴタイプなので文字サイズ設定で拡大しない(WCAG 1.4.5 の例外。テキストの拡大の対象は本文)。定数 `appLogoHeight = 28` を `app_logo.dart` のトップレベルに置く(`done_button.dart` の `doneButtonMinSize` と同じ流儀)。幅は指定しない(縦横比から約 144dp)
6. **はみ出し対策は今の `FittedBox(fit: BoxFit.scaleDown)` を残す**: 狭い画面で並び順ボタンと並んだとき、足りないときだけ縮める(既存の判断H)
7. **読み上げ**: `Image.asset` の `semanticLabel: AppInfo.name` で「LastWhen」と読ませる。`excludeFromSemantics` は付けない。`Semantics` で別に包まない
8. **`filterQuality: FilterQuality.medium`**: 縮小表示で文字の縁が荒れないように指定する
9. **図鑑・設定の AppBar、`MaterialApp.title`、`AppInfo.name` は変えない**(スコープ外)
10. **幅も固定する(追補・Codex 委託 1 回目の後)**: 判断5の「幅は指定しない」を**撤回する**。画像のデコードが終わるまで `Image` の幅が 0 になり、`FittedBox(scaleDown)` の縮尺が 0/0 = NaN になる(テスト G で実測。実機でも読み込み後にタイトルのレイアウトが跳ねる)。
    `app_logo.dart` にトップレベル定数 `const double appLogoAspectRatio = 619 / 120;`(doc: 「ロゴ画像の縦横比(幅 / 高さ)。`logo_wordmark.png` の 619×120。画像を差し替えたら直す。読み込み前から幅を確保し、`FittedBox` の縮尺が決まるようにする(#92 判断10)」)を `appLogoHeight` の直後に置き、`Image.asset` に `width: appLogoHeight * appLogoAspectRatio` を足す(`height` の直後)。
    `appLogoHeight` の doc と判断5の本文は直さなくてよい
11. **`SemanticsHandle` はテスト本文の末尾で `handle.dispose()` する(追補)**: `addTearDown(handle.dispose)` はテスト終了時の検査(「SemanticsHandle が破棄されていない」)より後に走るので失敗する。テスト D・F は `addTearDown(handle.dispose);` の行を消し、最後の `expect` の後に `handle.dispose();` を置く
12. **テスト C に幅の検査を足す(追補)**: `tester.getSize(find.byType(AppLogo)).width` が `appLogoHeight * appLogoAspectRatio`(判断10が効いていることの検査)

## 実装内容

### §1 `lib/ui/widgets/app_logo.dart`(新規)

```dart
import 'package:flutter/material.dart';

import '../app_info.dart';

/// ロゴの高さ(論理ピクセル)。AppBar のタイトル(`titleLarge`)の行の高さに揃える。
/// ロゴタイプなので文字サイズ設定では拡大しない(#92 判断5)。
const double appLogoHeight = 28;

/// アプリの文字ロゴ。ホームの AppBar に出す(#92)。
///
/// 単色の画像を `onSurface` で塗るので、画像 1 枚でライト・ダークの両方に合う。
/// 読み上げではアプリ名が読まれる。
class AppLogo extends StatelessWidget {
  /// ロゴを作る。
  const AppLogo({super.key});

  /// ロゴ画像のアセットパス。`pubspec.yaml` にファイル単位で登録している。
  static const String assetPath = 'assets/branding/logo_wordmark.png';

  @override
  Widget build(BuildContext context) => Image.asset(
    assetPath,
    height: appLogoHeight,
    color: Theme.of(context).colorScheme.onSurface,
    colorBlendMode: BlendMode.srcIn,
    filterQuality: FilterQuality.medium,
    semanticLabel: AppInfo.name,
  );
}
```

(`app_info.dart` は `lib/ui/app_info.dart`。相対 import は上のとおり `../app_info.dart`)

### §2 `lib/ui/screens/item_list_screen.dart`

AppBar の `title` を置き換える。コメントも合わせて直す:

```dart
        // 並び順のボタンと並べると、狭い画面では幅が足りなくなりうる。
        // ロゴはブランド表記なので、足りないときだけ縮める(判断H / #92)。
        title: const FittedBox(fit: BoxFit.scaleDown, child: AppLogo()),
```

`import '../widgets/app_logo.dart';` を widgets の import 群にアルファベット順で足す(`../widgets/centered_scrollable.dart` の前)。

### §3 `pubspec.yaml`

`flutter: assets:` を次のようにする(既存のフォントのライセンス行は残す):

```yaml
  # ライセンス全文。起動時に LicenseRegistry へ登録する(lib/ui/theme/app_fonts.dart)。
  # ホームの AppBar の文字ロゴ(#92)。assets/branding/ の他の画像は生成用の入力なので登録しない。
  assets:
    - assets/fonts/ZenMaruGothic-OFL.txt
    - assets/branding/logo_wordmark.png
```

### §4 テスト

**`test/ui/widgets/app_logo_test.dart`(新規)**

`MaterialApp(theme: AppTheme.light() / AppTheme.dark(), home: const Scaffold(body: Center(child: AppLogo())))` を pump する(`AppTheme` は `package:lastwhen/ui/theme/app_theme.dart`)。

- テスト A「ライトテーマでは onSurface で塗る」: `tester.widget<Image>(find.byType(Image))` の `color` が `AppTheme.light().colorScheme.onSurface`、`colorBlendMode` が `BlendMode.srcIn`
- テスト B「ダークテーマでは onSurface で塗る」: 同じく `AppTheme.dark()`
- テスト C「高さは appLogoHeight」: `tester.getSize(find.byType(AppLogo)).height` が `appLogoHeight`
- テスト D「読み上げはアプリ名」: `final handle = tester.ensureSemantics();` → `expect(find.bySemanticsLabel(AppInfo.name), findsOneWidget);` → `handle.dispose();`

**`test/ui/item_list_screen_test.dart`(既存に追記)**

`main()` の末尾に group `'AppBar のロゴ'` を足す。既存の `_app` と `pumpItems` を使う:

- テスト E「ホームの AppBar にロゴが出て、アプリ名の文字は出ない」: `pumpItems(tester)` → `find.descendant(of: find.byType(AppBar), matching: find.byType(AppLogo))` が `findsOneWidget`、`find.text('LastWhen')` が `findsNothing`
- テスト F「ロゴは「LastWhen」と読み上げられる」: `final handle = tester.ensureSemantics();` → `pumpItems(tester)` → `find.bySemanticsLabel('LastWhen')` が `findsOneWidget` → `handle.dispose();`

**`test/ui/accessibility_test.dart`(既存に追記)**

group `'アクセシビリティ'` の中に 1 件足す。既存の `_setScreenSize` / `seedItems` / `_app(textScale:)` を使う:

- テスト G「文字サイズ 200% で AppBar のロゴがはみ出さない」: `_setScreenSize(tester)` → `await seedItems();`(並び順ボタンを出すため)→ `_app(repository, FakeClock(now), textScale: 2)` を pump → `pumpAndSettle` → `expect(tester.takeException(), isNull)` → ロゴの矩形 `tester.getRect(find.byType(AppLogo))` が AppBar の矩形 `tester.getRect(find.byType(AppBar))` に含まれる(`left >= `・`right <=`・`top >=`・`bottom <=` の 4 つを検査)→ ロゴの右端が並び順ボタン(`find.byTooltip('並び順')`)の左端以下
  - 同じ 200% 検査を**ライト・ダーク**で回す必要はない(色はテスト A・B で検査済み)

既存テストで `find.text('LastWhen')` に依存しているものは無い(司令塔が確認済み)。

### §5 docs

- `docs/repository-structure.md` のディレクトリ図の `assets/branding/` 行のコメントを次に変える:
  `# アイコン・スプラッシュ生成の入力画像と、ホームの文字ロゴ(logo_wordmark.png だけをバンドルする)`
  (図の桁揃えが崩れる場合は揃えなくてよい。同じ図の他の行は触らない)
- `docs/architecture.md` の「### 同梱フォント(#56)」節の**後ろ**(次の見出しの前)に節を足す:

  ```markdown
  ### 同梱画像(#92)

  | 画像 | 配置 | 用途 | 出所 |
  |------|------|------|------|
  | 文字ロゴ | `assets/branding/logo_wordmark.png`(619×120・背景透過・単色) | ホームの AppBar のタイトル(`AppLogo`) | 自作(元画像 `docs/ideas/LastWhen_logo_haikeinashi.png` を切り詰めて縮小) |

  - `pubspec.yaml` には**ファイル単位で**登録する。`assets/branding/` の他の画像はアイコン・スプラッシュ生成の入力で、アプリに入れない
  - 単色の画像を `ColorScheme.onSurface` で塗る(`BlendMode.srcIn`)。ライト・ダークで画像を分けない
  - 表示の高さは 28dp で、120px あれば 4 倍超の密度まで足りるため、解像度別の画像は持たない
  ```
- `docs/functional-design.md` の「AppBar は通常は透明で、内容が下に潜ったときだけ `surfaceContainer` になる。」の行の直後に 1 行足す:
  `ホームの AppBar のタイトルはアプリ名の文字ロゴ(画像)で、`onSurface` で塗る。読み上げではアプリ名「LastWhen」と読む(#92)。図鑑・設定の AppBar は文字のまま。`

## 触らないもの

- `lib/data/database/` / `lib/data/migrations/`
- `lib/app.dart`(`MaterialApp.title`)/ `lib/ui/app_info.dart`
- `assets/branding/` の既存画像と `flutter_launcher_icons` / `flutter_native_splash` の設定
- `assets/branding/logo_wordmark.png` 自体(判断1)
