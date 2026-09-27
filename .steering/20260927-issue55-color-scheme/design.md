# 設計: 配色を画面イメージに合わせる(Issue #55)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **色の値は §1 の表のとおりに書く。** 変えてよいのはテストが落ちたときではない(落ちたら止めて報告する。値は司令塔が実測済み)
> - **`docs/` は司令塔が更新済み**。実装者は `docs/` を触らない
> - 依存は追加しない。`AgingPalette` / `AgingPaperColors` / `agingIconOpacity` は変更しない
> - 触るファイルは `lib/ui/theme/app_theme.dart` とテスト 3 ファイルだけ。画面・ウィジェットのファイルは変更しない

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | **`ColorScheme.fromSeed(seedColor: テラコッタ)`(既定の `tonalSpot`)を土台に、画面イメージに効くロールだけ `copyWith` で上書きする**。`ColorScheme(...)` の全ロール直書きはしない | 上書きしないロール(tertiary・error・inverse 系・fixed 系など)も同じ色相から整合した値で埋まる。`tonalSpot` の tertiary は色相 +60°(黄土)で青にならない。`fidelity` は tertiary が補色(青緑 h181)になるため採らない(実測) |
| B | primary は画面イメージのテラコッタ **`#B45A3A`** をそのまま使う(`fromSeed` の primary `#8F4C35` はくすみすぎる) | 白文字とのコントラスト 4.70:1 で AA を満たす |
| C | ダークは画面イメージに無いので、**同じ色相の焦げ茶地 + クリーム文字 + 明るいテラコッタ**で組む | light と同じ印象を保つ |
| D | `AgingPalette` の値は**変えない** | 既にクリーム〜黄土の同系色で、新しい `onSurface` / `onSurfaceVariant` とのコントラスト(4.5:1)とアイコンの掠れ(3:1)は実測で全ステージ通る。整合はテストで担保する |
| E | FAB は画面イメージどおり**テラコッタ塗り + 白アイコン**にする。`floatingActionButtonTheme` で `primary` / `onPrimary` を指定する(M3 既定の `primaryContainer` では淡色になる) | 画面イメージの ＋ ボタン |
| F | 下部ナビ・チップ・`FilledButton.tonal` は M3 既定のロール(`secondaryContainer` / `onSecondaryContainer` / `surfaceContainer`)のまま。**component theme は FAB 以外追加しない** | 形状・構成の変更はスコープ外。上書きしたロールで淡いテラコッタ系に描かれる |
| G | `AppTheme.seedColor` は残し、値をテラコッタにする(公開定数のまま) | 既存テストとドキュメントが参照する名前を保つ |
| H | 「青系が残っていない」は **`ColorScheme` の全ロールの色相をテストで検査**して担保する(§3-3)。画面ごとのゴールデンテストは作らない | ウィジェットは生の色を持たない(§4 で確認)ので、ロールに青が無ければ画面にも出ない |

## §1 色の値(実測済み)

採取元: 画面イメージの背景 `#F0E3D0`〜`#F2E6D3`・ナビ `#F8F2E8`・記録ボタン/FAB `#B45436`〜`#B65F3E`・バッジ地 `#F2D4C5`。

| ロール | light | dark | 用途(このアプリ) |
| --- | --- | --- | --- |
| シード(`seedColor`) | `#B45A3A` | 同左 | `fromSeed` の土台 |
| `primary` | `#B45A3A` | `#E8A184` | FAB・保存ボタン・選択中の強調 |
| `onPrimary` | `#FFFFFF` | `#4A1A08` | |
| `surfaceTint` | `#B45A3A` | `#E8A184` | `primary` と揃える |
| `primaryContainer` | `#F6D9CB` | `#7A3620` | |
| `onPrimaryContainer` | `#6E2F18` | `#FFDBCF` | |
| `secondaryContainer` | `#EFD9C7` | `#5E3A2C` | やったボタン・選択中チップ・ナビのインジケータ |
| `onSecondaryContainer` | `#4F3526` | `#F6D9CB` | |
| `surface` | `#F3E8D6` | `#1C1714` | 画面の地(クリーム / 焦げ茶) |
| `onSurface` | `#261B14` | `#F0E3D3` | 本文(焦げ茶 / クリーム) |
| `onSurfaceVariant` | `#524134` | `#D6C5B2` | 補助文字 |
| `surfaceContainerLowest` | `#FFFBF5` | `#161210` | |
| `surfaceContainerLow` | `#FAF4EA` | `#221C18` | |
| `surfaceContainer` | `#F8F1E6` | `#27201B` | 下部ナビの地 |
| `surfaceContainerHigh` | `#EFE3D0` | `#312924` | ダイアログ |
| `surfaceContainerHighest` | `#E9DCC7` | `#3C332D` | |
| `outline` | `#85735F` | `#A08C7A` | 枠線 |
| `outlineVariant` | `#D9C9B2` | `#4E4238` | 区切り線(装飾) |

実測の要点(下限に近いもの): light `onPrimary`/`primary` 4.70、light `primary`/`surfaceContainerHighest` 3.48、light `outline`/`surfaceContainerHighest` 3.36、light heavilyAged のアイコン掠れ/シミ 3.14、light heavilyAged の `onSurfaceVariant`/シミ 4.89(`onSurface` を `#261B14` まで暗くしたのはアイコン掠れの 3:1 を満たすため)。

## §2 `lib/ui/theme/app_theme.dart`

`AppTheme` クラスだけを次の形に書き換える。**`AgingPaperColors` / `AgingPalette` / `agingIconOpacity` は一切変更しない。**

```dart
/// アプリ全体のテーマ。
///
/// 配色は画面イメージ(`docs/ideas/LastWhen_gamen.png`)のクリーム地・テラコッタ・焦げ茶。
/// テラコッタのシード色から `ColorScheme.fromSeed` で全ロールを生成し、
/// 画面イメージに効くロール(地・文字・primary など)だけを上書きする
/// (`docs/ui-design-guidelines.md` §7 / `docs/functional-design.md`「色の使い方」)。
/// ウィジェット側に生の色・余白・タイポの値を書かず、必ず `Theme.of(context)` 経由で参照すること。
///
/// 経年変化(F28)は `AgingPalette` の紙の色と `ItemCard` の形状変化で示す。
///
/// `TextTheme` の実値は一覧の行(#5)を組むときに決める。
abstract final class AppTheme {
  /// テーマのシード色(テラコッタ)。上書きしないロールはここから生成される。
  static const Color seedColor = Color(0xFFB45A3A);

  /// ライトテーマ。
  static ThemeData light() => _build(Brightness.light);

  /// ダークテーマ。
  static ThemeData dark() => _build(Brightness.dark);

  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(seedColor: seedColor).copyWith(
        primary: const Color(0xFFB45A3A),
        onPrimary: const Color(0xFFFFFFFF),
        surfaceTint: const Color(0xFFB45A3A),
        primaryContainer: const Color(0xFFF6D9CB),
        onPrimaryContainer: const Color(0xFF6E2F18),
        secondaryContainer: const Color(0xFFEFD9C7),
        onSecondaryContainer: const Color(0xFF4F3526),
        surface: const Color(0xFFF3E8D6),
        onSurface: const Color(0xFF261B14),
        onSurfaceVariant: const Color(0xFF524134),
        surfaceContainerLowest: const Color(0xFFFFFBF5),
        surfaceContainerLow: const Color(0xFFFAF4EA),
        surfaceContainer: const Color(0xFFF8F1E6),
        surfaceContainerHigh: const Color(0xFFEFE3D0),
        surfaceContainerHighest: const Color(0xFFE9DCC7),
        outline: const Color(0xFF85735F),
        outlineVariant: const Color(0xFFD9C9B2),
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFE8A184),
        onPrimary: const Color(0xFF4A1A08),
        surfaceTint: const Color(0xFFE8A184),
        primaryContainer: const Color(0xFF7A3620),
        onPrimaryContainer: const Color(0xFFFFDBCF),
        secondaryContainer: const Color(0xFF5E3A2C),
        onSecondaryContainer: const Color(0xFFF6D9CB),
        surface: const Color(0xFF1C1714),
        onSurface: const Color(0xFFF0E3D3),
        onSurfaceVariant: const Color(0xFFD6C5B2),
        surfaceContainerLowest: const Color(0xFF161210),
        surfaceContainerLow: const Color(0xFF221C18),
        surfaceContainer: const Color(0xFF27201B),
        surfaceContainerHigh: const Color(0xFF312924),
        surfaceContainerHighest: const Color(0xFF3C332D),
        outline: const Color(0xFFA08C7A),
        outlineVariant: const Color(0xFF4E4238),
      );

  static ThemeData _build(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark
        ? _darkScheme
        : _lightScheme;
    return ThemeData(
      useMaterial3: true,
      extensions: [
        if (brightness == Brightness.dark)
          AgingPalette.dark
        else
          AgingPalette.light,
      ],
      colorScheme: colorScheme,
      // 画面イメージの ＋ ボタンはテラコッタ塗り。M3 既定の primaryContainer では淡色になる。
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
    );
  }
}
```

- 整形は `dart format` の出力に従う(上のインデントと違っても format の結果を正とする)
- `_lightScheme` / `_darkScheme` は `static final`(`fromSeed` は const にできない)

## §3 テスト

### §3-1 `test/widget_test.dart`

「light と dark が同じ 1 つのシード色から生成されている」テストを**削除し**、次のテストに差し替える(同じ位置):

```dart
  test('light と dark の primary がシード色と同じ色相(テラコッタ)', () {
    final seedHue = HSLColor.fromColor(AppTheme.seedColor).hue;
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(
        HSLColor.fromColor(theme.colorScheme.primary).hue,
        closeTo(seedHue, 5),
        reason: '${theme.brightness}',
      );
    }
  });
```

(シード `#B45A3A` の色相は約 16°、dark の `#E8A184` は約 17°。)

### §3-2 `test/ui/accessibility_test.dart`

「コントラスト比が light / dark の全ペアで WCAG AA を満たす」の `pairs` を次のとおり変更する(他は変えない):

- `'FAB'` を `(colors.onPrimary, colors.primary)` に変更する(判断 E で FAB が primary 塗りになったため)
- 次の 2 ペアを追加する(選択中のナビ・チップは `'やった'` と同じペアなので追加しない):
  - `'ナビの文字': (colors.onSurfaceVariant, colors.surfaceContainer)`
  - `'チップの文字': (colors.onSurfaceVariant, colors.surfaceContainerLow)`

### §3-3 `test/ui/theme/app_theme_test.dart`(新規)

`aging_palette_test.dart` と同じ `_contrast` ヘルパー(`computeLuminance` を使う)をファイル内に定義する。テストは次の 3 群。

1. **青系のロールが無い**: light / dark それぞれ、下のロール全部について
   `HSLColor.fromColor(c)` の `saturation >= 0.15` かつ `0.08 <= lightness <= 0.95` のとき、`hue` が **180 以上 260 以下でない**ことを検査する。`reason` にテーマの明暗とロール名を入れる。
   対象ロール(`Map<String, Color>` で列挙する):
   `primary, onPrimary, primaryContainer, onPrimaryContainer, primaryFixed, primaryFixedDim, onPrimaryFixed, onPrimaryFixedVariant, secondary, onSecondary, secondaryContainer, onSecondaryContainer, secondaryFixed, secondaryFixedDim, onSecondaryFixed, onSecondaryFixedVariant, tertiary, onTertiary, tertiaryContainer, onTertiaryContainer, tertiaryFixed, tertiaryFixedDim, onTertiaryFixed, onTertiaryFixedVariant, error, onError, errorContainer, onErrorContainer, surface, onSurface, surfaceDim, surfaceBright, surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest, onSurfaceVariant, outline, outlineVariant, shadow, scrim, inverseSurface, onInverseSurface, inversePrimary, surfaceTint`
2. **アイコン・枠線が 3:1 以上**: light / dark それぞれ、背景 = `surface, surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh, surfaceContainerHighest` の 6 つに対して、前景 = `primary`(選択中のアイコン・強調)と `outline`(枠線)の 2 つが `_contrast >= 3.0`。テスト名は `'$name $前景 / $背景 が3:1以上'` の形
3. **FAB がテラコッタ塗り**: light / dark それぞれ `theme.floatingActionButtonTheme.backgroundColor == theme.colorScheme.primary` かつ `foregroundColor == theme.colorScheme.onPrimary`

(本文 4.5:1 は `accessibility_test.dart`、紙の上の文字とアイコンは `aging_palette_test.dart` が既に検査しているので重複させない。)

## §4 生の色が無いことの確認

```bash
grep -rnE "Color\(0x|Colors\." lib --include=*.dart | grep -v "lib/ui/theme/app_theme.dart"
```

出力が空であること。空でなければ**直さずに止めて報告する**(計画時点では空を確認済み)。
