# 設計: 丸ゴシック系フォントを同梱する(Issue #56)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **フォントファイルは司令塔が取得済み**(`assets/fonts/`)。実装者はネットワークから何も取得しない。`assets/fonts/` のファイルを変更・追加・削除しない
> - **`docs/` は司令塔が更新済み**。実装者は `docs/` を触らない
> - パッケージの依存は追加しない(`google_fonts` を含む)。`pubspec.yaml` で変えてよいのは `flutter:` 節の `fonts:` / `assets:` だけ
> - 画面・ウィジェットのファイル(`lib/ui/screens/` / `lib/ui/widgets/`)は変更しない
> - **既存テストが落ちたら、テストの期待値や画面の実装を直さずに止めて報告する**(特に §6-3 の 200% 検査。書体の寸法で落ちた場合の対処は司令塔が決める)

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 書体は **Zen Maru Gothic**(SIL OFL 1.1)。family 名は **`ZenMaruGothic`** | 画面イメージのやわらかい丸ゴシックに最も近い(ユーザー選択) |
| B | ウェイトは **Regular(400)/ Medium(500)/ Bold(700)** の 3 つ。**サブセット化しない** | M3 のタイプスケールが使うのは body 400 / title・label 500 / 経過日数の強調 700。項目名は自由入力なので収録を削らない(ユーザー選択) |
| C | 適用は **`ThemeData(fontFamily: ...)` の 1 箇所だけ**。`TextTheme` を個別に組み直さない。ウィジェットに `fontFamily` を書かない | `ThemeData.fontFamily` は `textTheme` と `primaryTextTheme` の全スタイルに当たる。サイズ・ウェイトは M3 既定のままなので「経過日数 = `headlineSmall` + Bold」の強調規則(`item_card.dart`)は変わらない |
| D | ライセンスは **`LicenseRegistry.addLicense` で登録するだけ**。一覧を開く画面の入口は作らない。受け入れ条件「一覧に出る」は `LicenseRegistry.licenses` に載ることをテストで検査して担保する | アプリにライセンス一覧の画面が無い(マイページは中身が決まるまで置かない)。入口を作るのは画面構成の変更でスコープ外 |
| E | `accessibility_test.dart` は **`setUpAll` で同梱フォントを `FontLoader` で読み込んでから**既存の検査を回す。他のテストファイルは既定のテスト用フォントのまま | ウィジェットテストは既定で全文字を同じ幅の四角で描くため、書体を変えても 200% 検査が実寸を測らない。実フォントを読むのはレイアウト検査のファイルだけに限る(他は文言・操作の検査で書体に依存しない) |
| F | family 名・ライセンスのアセットパス・登録処理は **`lib/ui/theme/app_fonts.dart` の `AppFonts`** にまとめる | テーマ(`app_theme.dart`)・起動(`main.dart`)・テストが同じ定数を参照する |

## §1 取得済みファイル(司令塔が配置済み・変更しない)

| ファイル | 内容 |
| --- | --- |
| `assets/fonts/ZenMaruGothic-Regular.ttf` | 400 |
| `assets/fonts/ZenMaruGothic-Medium.ttf` | 500 |
| `assets/fonts/ZenMaruGothic-Bold.ttf` | 700 |
| `assets/fonts/ZenMaruGothic-OFL.txt` | ライセンス全文(1 行目 `Copyright 2021 The Zen Maru Gothic Project Authors ...`、本文に `SIL Open Font License, Version 1.1` を含む) |

取得元: `google/fonts` の `ofl/zenmarugothic`(上流 `googlefonts/zen-marugothic` @ `553c872b`)。

## §2 `pubspec.yaml`

`flutter:` 節の `uses-material-design: true` の直後に次を追加する。既存のコメントアウトされた雛形(`# fonts:` の例)は削除してよい(残してもよい。どちらでも可)。

```yaml
flutter:
  uses-material-design: true

  # ライセンス全文。起動時に LicenseRegistry へ登録する(lib/ui/theme/app_fonts.dart)。
  assets:
    - assets/fonts/ZenMaruGothic-OFL.txt

  # 同梱フォント(#56 / docs/architecture.md「同梱フォント」)。
  fonts:
    - family: ZenMaruGothic
      fonts:
        - asset: assets/fonts/ZenMaruGothic-Regular.ttf
          weight: 400
        - asset: assets/fonts/ZenMaruGothic-Medium.ttf
          weight: 500
        - asset: assets/fonts/ZenMaruGothic-Bold.ttf
          weight: 700
```

`flutter:` 節に既に `assets:` がある場合は、その一覧に 1 行追加する(新しい `assets:` キーを重複させない)。

## §3 `lib/ui/theme/app_fonts.dart`(新規)

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 同梱フォント(Zen Maru Gothic)。
///
/// `pubspec.yaml` の `fonts:` で Regular(400)/ Medium(500)/ Bold(700)を同梱している。
/// 適用は `AppTheme` の `ThemeData.fontFamily` の 1 箇所だけで、ウィジェットに `fontFamily` を書かない
/// (`docs/architecture.md`「同梱フォント」/ `docs/ui-design-guidelines.md` §7)。
abstract final class AppFonts {
  /// `pubspec.yaml` の `fonts:` に書いた family 名。
  static const String family = 'ZenMaruGothic';

  /// ライセンス一覧に出す名前。
  static const String displayName = 'Zen Maru Gothic';

  /// ライセンス全文のアセット(SIL OFL 1.1)。
  static const String licenseAsset = 'assets/fonts/ZenMaruGothic-OFL.txt';

  /// フォントのライセンスを [LicenseRegistry] に登録する。起動時に 1 回だけ呼ぶ。
  ///
  /// アセットは一覧が開かれたときに初めて読まれる(起動を遅らせない)。
  static void registerLicenses() {
    LicenseRegistry.addLicense(() async* {
      final text = await rootBundle.loadString(licenseAsset);
      yield LicenseEntryWithLineBreaks(const [displayName], text);
    });
  }
}
```

## §4 `lib/ui/theme/app_theme.dart`

1. `import 'app_fonts.dart';` を追加する(既存の import 群の並びに合わせる)
2. `_build` の `ThemeData(` の引数に **`fontFamily: AppFonts.family,`** を追加する(`useMaterial3: true,` の直後)。**他の引数・`ColorScheme`・`AgingPalette` などは一切変更しない**
3. `AppTheme` の doc コメントの最終行 `/// `TextTheme` の実値は一覧の行(#5)を組むときに決める。` を次の 2 行に置き換える:

```dart
/// 書体は同梱の Zen Maru Gothic([AppFonts])を `fontFamily` で全 `TextTheme` に当てる(#56)。
/// サイズとウェイトは Material 3 の既定のまま。経過日数の強調(`headlineSmall` + Bold)はウィジェット側で行う。
```

## §5 `lib/main.dart`

1. `import 'ui/theme/app_fonts.dart';` を追加する(既存の import の並びに合わせる)
2. `WidgetsFlutterBinding.ensureInitialized();` の直後に次の 2 行を追加する:

```dart
  // 同梱フォントのライセンスを一覧に載せる(#56)
  AppFonts.registerLicenses();
```

## §6 テスト

### §6-1 `test/support/app_font.dart`(新規)

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/ui/theme/app_fonts.dart';

/// 同梱フォントの 3 ウェイトを実際に読み込む。
///
/// ウィジェットテストは既定で全文字を同じ幅の四角で描くため、書体に依存するレイアウトを
/// 実寸で検査するファイルだけが `setUpAll(loadAppFont)` で呼ぶ(#56 design.md 判断 E)。
Future<void> loadAppFont() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final loader = FontLoader(AppFonts.family);
  for (final weight in ['Regular', 'Medium', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/ZenMaruGothic-$weight.ttf'));
  }
  await loader.load();
}
```

### §6-2 `test/ui/theme/app_fonts_test.dart`(新規)

次の 4 つのテストを書く。import は `dart:convert` / `package:flutter/foundation.dart` / `package:flutter/material.dart` / `package:flutter/services.dart` / `package:flutter_test/flutter_test.dart` / `package:lastwhen/ui/theme/app_fonts.dart` / `package:lastwhen/ui/theme/app_theme.dart` から必要なものだけ。

1. **`'pubspec の fonts に 3 ウェイトが同梱されている'`**(`test`):
   - `rootBundle.loadString('FontManifest.json')` を `jsonDecode` し、`family == AppFonts.family` の要素がちょうど 1 つあること
   - その要素の `fonts` の `asset` の集合が `{'assets/fonts/ZenMaruGothic-Regular.ttf', 'assets/fonts/ZenMaruGothic-Medium.ttf', 'assets/fonts/ZenMaruGothic-Bold.ttf'}` と一致し、各 `asset` に対応する `weight` がそれぞれ `400` / `500` / `700` であること
   - 3 つの `asset` それぞれについて `rootBundle.load(asset)` の `lengthInBytes` が `0` より大きいこと
   - 先頭で `TestWidgetsFlutterBinding.ensureInitialized();` を呼ぶ(`main()` の先頭で 1 回でよい)
2. **`'light / dark の全テキストスタイルが同梱フォントで描かれる'`**(`test`):
   - `AppTheme.light()` と `AppTheme.dark()` のそれぞれで、`textTheme` と `primaryTextTheme` の 15 スタイル(`displayLarge` / `displayMedium` / `displaySmall` / `headlineLarge` / `headlineMedium` / `headlineSmall` / `titleLarge` / `titleMedium` / `titleSmall` / `bodyLarge` / `bodyMedium` / `bodySmall` / `labelLarge` / `labelMedium` / `labelSmall`)すべての `fontFamily` が `AppFonts.family` であること。`reason` に明暗とスタイル名を入れる
3. **`'ライセンス一覧に Zen Maru Gothic の OFL が載る'`**(`test`):
   - `addTearDown(LicenseRegistry.reset);` を先に登録する
   - `AppFonts.registerLicenses();` を呼び、`await LicenseRegistry.licenses.toList()` から `packages` に `AppFonts.displayName` を含むエントリを探す。**ちょうど 1 つ**あること
   - そのエントリの `paragraphs` の `text` を連結した文字列が `'SIL Open Font License'` を含むこと
   - `LicenseRegistry.reset` は `@visibleForTesting` なので analyze の警告は出ない(テストから呼ぶため)。**出た場合は止めて報告する**
4. **`'App の画面で使うテーマも同梱フォントを当てている'`**(`testWidgets`):
   - `MaterialApp(theme: AppTheme.light(), locale: const Locale('ja'), supportedLocales: const [Locale('ja')], localizationsDelegates: GlobalMaterialLocalizations.delegates, home: Builder(builder: (context) { captured = Theme.of(context).textTheme; return const SizedBox(); }))` を pump し、`captured` の `bodyLarge` / `titleMedium` / `headlineSmall` の `fontFamily` が `AppFonts.family` であること(`MaterialApp` が日本語ロケールで `Typography` を差し替えても family が残ることの確認)
   - `GlobalMaterialLocalizations` のため `package:flutter_localizations/flutter_localizations.dart` を import する(`lib/app.dart` と同じ)

### §6-3 `test/ui/accessibility_test.dart`

- `import '../support/app_font.dart';` を既存の `../support/` の import 群に追加する
- `void main() {` の直後(`late FakeItemRepository repository;` より前)に **`setUpAll(loadAppFont);`** を 1 行追加する
- **それ以外は変更しない。** 追加後にこのファイルのテストが落ちたら、期待値・`_setScreenSize`・画面側を直さずに、落ちたテスト名と失敗メッセージを添えて止めて報告する

## §7 `fontFamily` の指定箇所の確認

```bash
grep -rn "fontFamily" lib | grep -v "^lib/ui/theme/"
```

出力が空であること(ウィジェットに `fontFamily` を書かない)。空でなければ止めて報告する(既存の画面を直さない)。

## §8 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` がすべて通ること。
`flutter test` の前に `flutter pub get` が必要なら実行してよい(依存の追加ではないので `pubspec.lock` は変わらない想定。**変わったら止めて報告する**)。
