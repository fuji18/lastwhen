# 設計: 紙の質感を画面イメージに合わせる(Issue #57)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
>
> - **`docs/` は触らない**(司令塔が見た目を確認してから更新する)
> - パッケージ・アセットを追加しない。`pubspec.yaml` を変更しない
> - `AgingPalette` の **`paper` / `edge` の値を変えない**(変えてよいのは §2 の `stain` だけ)。テキストの色・`ColorScheme` を変えない
> - **既存テストの期待値・コントラストの閾値(4.5 / 3.0)を緩めない。** 落ちたら §7 の手順だけを試し、それでも落ちたら止めて報告する
> - 見た目の良し悪しは判断しなくてよい(司令塔がプレビュー画像で判断する)。数値は本書のとおりに入れる

## 設計判断(司令塔が確定済み)

| # | 判断 | 理由 |
| --- | --- | --- |
| A | 質感は **`CustomPainter` の描画だけ**で作る。画像アセットは使わない | ユーザー選択。素材の入手・ライセンス・ダーク用画像・APK サイズの問題が出ない。ダークは色が変わるだけで同じ描画 |
| B | 紙は **下から「紙の面 → 斑(まだら) → 繊維と斑点 → シミと輪染み → 縁の焼け → 1px の縁線」** の層で描く。縁の焼けは**ぼかした太線を紙の形でクリップ**して内側へ減衰させる | 画面イメージの紙は、焼けが縁から内側へ滲み、シミの縁が濃い(輪染み)。単色の線と楕円では出ない |
| C | 装飾の各層は **1 本の `Path` にまとめて 1 回だけ塗る**(繊維・斑点・シミ・輪染みそれぞれ) | 重なった部分の不透明度が積み上がらず、テキスト下の最暗部が読める範囲に収まる(既存の方針と同じ) |
| D | テキストのコントラストは、**実際に描いた画素**をテキスト領域(紙の端から 12px 内側)で全数走査して検査する | 層が増えると色の合成式では最悪値を追えない。カードの内側余白は `ItemCard` / `CollectionCard` とも 12 で、テキストはその内側にしか載らない |
| E | シミの色の不透明度を **0x29(0.16)→ 0x1A(0.10)** に下げる(明暗とも・全ステージ) | 輪染みと繊維が重なる分の予算。0.16 のままだと heavilyAged の `onSurfaceVariant` が 4.5 を割る(司令塔の試算) |
| F | 画面の背景は **`PaperBackground`** で `surface` の地 + ごく薄い繊維を敷く。**`Scaffold` の背景はテーマで透明**にし、各ルートの根に `PaperBackground` を置く | ユーザー選択。`MaterialApp.builder` で 1 枚だけ敷くと、`Scaffold` が透明なので画面遷移中に前の画面が透けて重なる。ルートごとに不透明な地を持たせる |
| G | `AppBar` の背景は **通常は透明・スクロールで下に潜ったときだけ `surfaceContainer`** にする | 背景の紙が AppBar の裏まで続く。スクロール中は内容と重ならないよう不透明にする |
| H | 背景の繊維は **`RepaintBoundary` で内容と別レイヤー**にする。カードは既存どおり(一覧の各項目は `ListView` の既定で別レイヤー) | スクロールのたびに背景を描き直さない。項目 100 件の性能要件 |
| I | 詳細シートは変更しない | ユーザー選択(#58 に回す) |

## §1 `lib/ui/widgets/aged_paper.dart` の改修

### 1-1 共通: 繊維と斑点を描く関数(公開)

背景とカードで共有する。ファイル内の `AgedPaperPainter` より前に置く。

```dart
/// 紙の繊維と斑点を描く。繊維・斑点はそれぞれ 1 本の Path にまとめて 1 回で塗る
/// (重なりで濃くならない)。個数は面積に比例させる。
void paintPaperFibers(
  Canvas canvas,
  Size size,
  math.Random random, {
  required double fibersPer1000,
  required double specksPer1000,
  required Color fiberColor,
  required Color speckColor,
}) {
  final area = size.width * size.height / 1000;
  final fibers = Path();
  for (var i = 0; i < (area * fibersPer1000).round(); i++) {
    final start = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final angle = random.nextDouble() * math.pi;
    final length = 4 + random.nextDouble() * 10;
    final direction = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-direction.dy, direction.dx);
    final end = start + direction * length;
    final control =
        (start + end) / 2 + normal * (random.nextDouble() * 4 - 2);
    fibers
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }
  canvas.drawPath(
    fibers,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round
      ..color = fiberColor,
  );
  final specks = Path();
  for (var i = 0; i < (area * specksPer1000).round(); i++) {
    specks.addOval(
      Rect.fromCircle(
        center: Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        radius: 0.4 + random.nextDouble() * 0.6,
      ),
    );
  }
  canvas.drawPath(specks, Paint()..color = speckColor);
}
```

### 1-2 ステージごとのパラメータ

`_PaperParameters` を次のフィールドに置き換える(`edgeWidth` は廃止)。値は明暗共通。

```dart
typedef _PaperParameters = ({
  double specksPer1000,
  int mottles,
  double mottleOpacity,
  int stains,
  double minRadius,
  double maxRadius,
  double burnWidth,
  double burnSigma,
  double burnOpacity,
  double amplitude,
  int chips,
});
```

| ステージ | specksPer1000 | mottles | mottleOpacity | stains | minRadius | maxRadius | burnWidth | burnSigma | burnOpacity | amplitude | chips |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| fresh | 0.5 | 0 | 0 | 0 | 0 | 0 | 4 | 2 | 0.30 | 0 | 0 |
| slightlyAged | 1.0 | 0 | 0 | 2 | 5 | 10 | 5 | 2 | 0.40 | 0 | 0 |
| dueSoon | 1.5 | 2 | 0.04 | 3 | 6 | 14 | 6 | 3 | 0.50 | 0.8 | 0 |
| aged | 2.0 | 3 | 0.06 | 4 | 8 | 18 | 7 | 3 | 0.60 | 1.5 | 0 |
| heavilyAged | 3.0 | 4 | 0.06 | 6 | 10 | 22 | 7 | 3 | 0.70 | 2.5 | 2 |

ファイル先頭付近に定数を置く:

```dart
/// カードの繊維の密度(1000 平方ピクセルあたりの本数)。全ステージ共通。
const double _cardFibersPer1000 = 1.5;

/// カードの繊維の不透明度(`edge` の色に掛ける)。
const double _cardFiberOpacity = 0.06;

/// カードの斑点の不透明度(`edge` の色に掛ける)。
const double _cardSpeckOpacity = 0.12;

/// シミの輪染み(縁の濃い線)の太さ。
const double _stainRimWidth = 1.0;
```

### 1-3 `AgedPaperPainter.paint` の手順

コンストラクタ・フィールド・`shouldRepaint`・`stableSeedOf`・`agedPaperCornerRadius` は変えない。`paint` を次の順で書き直す。`random` は `math.Random(seed)` 1 つを最初から最後まで順に使う(順序を入れ替えない)。

1. **輪郭**: 既存のコード(角丸 → `amplitude > 0` ならギザギザ → `chips > 0` なら隅の欠け)をそのまま使う
2. **紙の面**: `canvas.drawPath(outline, Paint()..color = colors.paper)`
3. `canvas.save(); canvas.clipPath(outline);`
4. **斑**(`mottles > 0` のとき): `mottles` 回、中心 `Offset(random.nextDouble() * size.width, random.nextDouble() * size.height)`、半径 `size.shortestSide * (0.25 + random.nextDouble() * 0.2)` の円を、`Paint()..color = colors.edge.withValues(alpha: mottleOpacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.6))` で 1 つずつ `drawCircle` する(ぼかしが円ごとに違うため、これだけは 1 本にまとめない)
5. **繊維と斑点**: `paintPaperFibers(canvas, size, random, fibersPer1000: _cardFibersPer1000, specksPer1000: parameters.specksPer1000, fiberColor: colors.edge.withValues(alpha: _cardFiberOpacity), speckColor: colors.edge.withValues(alpha: _cardSpeckOpacity))`
6. **シミと輪染み**(`stains > 0` のとき): 中心と半径の決め方は既存のコード(端から 8px 内側、`size` が 16 以下なら中央)のまま。形を楕円から**不定形**に変える:
   - 頂点 10 個。`i` 番目の角度 `2π * i / 10`、半径 `radius * (0.7 + random.nextDouble() * 0.5)`。横方向だけ既存の `0.7 + random.nextDouble() * 0.6` 倍を掛ける(既存の楕円の縦横比を保つ)
   - 頂点列を「隣り合う頂点の中点を通る 2 次ベジェ」で閉じた滑らかな形にする(`moveTo(中点0)` → 各 `i` で `quadraticBezierTo(頂点(i+1), 中点(i+1))` → `close()`。添字は 10 で剰余)
   - 全シミを 1 本の `stains` Path に足し、`Paint()..color = colors.stain` で 1 回塗る
   - 続けて同じ `stains` Path を `Paint()..style = PaintingStyle.stroke..strokeWidth = _stainRimWidth..color = colors.stain.withValues(alpha: colors.stain.a * 0.5)` で 1 回描く(輪染み)
7. **縁の焼け**(全ステージ): `canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = burnWidth * 2..color = colors.edge.withValues(alpha: burnOpacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, burnSigma))`。クリップ中なので内側の半分だけが残り、縁から内側へ減衰する
8. `canvas.restore();`
9. **縁線**: 既存どおり 1px の `colors.edge` で `outline` を描く

クラスの doc コメントに「層の順序(判断 B)」と「装飾は Path 1 本で 1 回塗る(判断 C)」を 1〜2 行で書く。

## §2 `lib/ui/theme/app_theme.dart`

1. `AgingPalette.light` の全ステージの `stain` を `Color(0x1A8B6A2E)`、`AgingPalette.dark` の全ステージの `stain` を `Color(0x1AC9A461)` にする(判断 E)。他の値は変えない
2. `AppTheme._build` の `ThemeData(...)` に次を足す(判断 F / G):

```dart
      // 画面の地は各ルートの根の PaperBackground が塗る(紙の繊維を敷くため)。
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        // 紙の地を AppBar の裏まで見せ、内容が下に潜ったときだけ不透明にする。
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? colorScheme.surfaceContainer
              : Colors.transparent,
        ),
      ),
```

3. `AppTheme` の doc コメントに「画面の地は `PaperBackground` が塗る。新しいルートの根には必ず `PaperBackground` を置く(`Scaffold` の背景は透明)」を 1 行足す

## §3 `lib/ui/widgets/paper_background.dart`(新規)

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aged_paper.dart';

/// 背景の繊維の密度(1000 平方ピクセルあたり)。カードより疎にする。
const double _backgroundFibersPer1000 = 0.6;
const double _backgroundSpecksPer1000 = 0.4;

/// 背景の繊維・斑点の不透明度(`onSurface` に掛ける)。
const double paperGrainOpacity = 0.05;

/// 背景の繊維の配置を固定するシード(再描画しても動かない)。
const int _backgroundSeed = 0x5EED;

/// 画面の地(`surface` + ごく薄い紙の繊維)を敷く。
///
/// `Scaffold` の背景はテーマで透明にしてあるので、**各ルートの根に必ず置く**。
/// `MaterialApp.builder` で 1 枚だけ敷くと、画面遷移中に前の画面が透けて重なる。
/// 繊維は `RepaintBoundary` で内容と別レイヤーにし、スクロールのたびに描き直さない。
class PaperBackground extends StatelessWidget {
  /// 地を敷く。
  const PaperBackground({required this.child, super.key});

  /// 地の上に載せる画面。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PaperGrainPainter(
                  color: scheme.onSurface.withValues(alpha: paperGrainOpacity),
                ),
                isComplex: true,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 背景の紙の繊維を描く。
class PaperGrainPainter extends CustomPainter {
  /// 繊維の色(不透明度込み)で作る。
  const PaperGrainPainter({required this.color});

  /// 繊維と斑点の色。
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    paintPaperFibers(
      canvas,
      size,
      math.Random(_backgroundSeed),
      fibersPer1000: _backgroundFibersPer1000,
      specksPer1000: _backgroundSpecksPer1000,
      fiberColor: color,
      speckColor: color,
    );
  }

  @override
  bool shouldRepaint(PaperGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

`Stack` の既定(`StackFit.loose`)で、非配置の `child`(`Scaffold` / `Column`)が制約いっぱいに広がりサイズを決める。

## §4 各ルートの根に `PaperBackground` を置く

| ファイル | 変更 |
| --- | --- |
| `lib/ui/screens/home_shell.dart` | `build` が返す `Column` を `PaperBackground(child: Column(...))` で包む |
| `lib/ui/screens/item_add_screen.dart` | `build` が返す `Scaffold` を `PaperBackground(child: Scaffold(...))` で包む |
| `lib/ui/screens/item_edit_screen.dart` | 同上 |
| `lib/ui/screens/category_manage_screen.dart` | 同上 |

`ItemListScreen` / `CollectionScreen` は `HomeShell` の中に入るので**包まない**(二重に敷かない)。詳細シート・ダイアログは変更しない。

## §5 テスト

### 5-1 `test/ui/widgets/aged_paper_contrast_test.dart`(新規 / 判断 D)

`main()` の先頭で `TestWidgetsFlutterBinding.ensureInitialized();`。`test()`(非 widget)で書く。`toImage` / `toByteData` が `test()` で完了しない場合に限り、`testWidgets` + `tester.runAsync` に切り替えてよい。

- 対象: `('light', AppTheme.light(), AgingPalette.light)` / `('dark', AppTheme.dark(), AgingPalette.dark)` × `AgingStage.values` × サイズ `[Size(336, 72), Size(112, 140)]` × シード `stableSeedOf('item-$i')`(`i` = 0〜15)
- 描き方: `PictureRecorder` の `Canvas` に、まず全面を `theme.colorScheme.surface` で塗り、その上に `AgedPaperPainter(stage, colors: palette.colorsOf(stage), seed).paint(canvas, size)`。`picture.toImage(w, h)` → `toByteData(format: ImageByteFormat.rawRgba)`。使い終わった `Picture` / `Image` は `dispose()` する
- 検査: `Offset.zero & size` を `deflate(12)` した矩形内の全画素について、`onSurface` と `onSurfaceVariant` それぞれとのコントラスト比の**最小値が 4.5 以上**。失敗メッセージに theme・stage・size・seed・最小値を含める
- コントラスト比は WCAG の相対輝度で計算する(`aging_palette_test.dart` の `_contrast` と同じ式)。画素の sRGB→線形は 256 要素のルックアップ表を作って引く
- テスト名は `'$name ${stage.name} $size のテキスト領域は4.5以上'` の形でステージ × 明暗 × サイズごとに 1 本(シードはテスト内でループ)

加えて同ファイルに背景の検査を 1 本ずつ(明暗): `Size(360, 640)` に `surface` を塗り `PaperGrainPainter(color: onSurface.withValues(alpha: paperGrainOpacity))` を描き、全画素で `onSurfaceVariant` とのコントラスト最小値が 4.5 以上。

### 5-2 既存テストの更新

- `test/ui/widgets/aged_paper_test.dart`: 変更不要のはず(`paint` の例外なし・`shouldRepaint`)。`paintPaperFibers` を `Size(10, 10)` と `Size.zero` で呼んで例外が出ないテストを 1 本足す
- `test/ui/theme/aging_palette_test.dart`: 変更しない(`stain` を薄くしたので既存の検査はそのまま通る)
- `test/ui/theme/app_theme_test.dart`: 明暗それぞれで (1) `scaffoldBackgroundColor` が透明、(2) `appBarTheme.backgroundColor` を `WidgetStateColor` として `{WidgetState.scrolledUnder}` で解決すると `colorScheme.surfaceContainer`、空集合で解決すると透明、を検査する 1 本ずつ
- `test/ui/widgets/paper_background_test.dart`(新規): (1) `PaperBackground` の子が描画され、`ColoredBox` の色が `colorScheme.surface`、(2) `PaperGrainPainter.shouldRepaint` が色の違いでだけ `true`
- ルートの根の検査: `App` を起動した直後(`HomeShell`)に `find.byType(PaperBackground)` が 1 つ。`ItemAddScreen` / `ItemEditScreen` / `CategoryManageScreen` を単体で pump するテストがある既存ファイルに、`find.byType(PaperBackground)` が見つかる検査を 1 本ずつ足す(既存のテストの pump の仕方をそのまま使う)

### 5-3 プレビュー(見た目の確認用 / CI では skip)

`test/ui/widgets/aged_paper_preview_test.dart`(新規)。**環境変数 `PAPER_PREVIEW` が無いときは skip**(`skip: !Platform.environment.containsKey('PAPER_PREVIEW')`。`dart:io` の `Platform`)。

- 明暗それぞれ 1 枚の PNG を `build/paper_preview/paper_light.png` / `paper_dark.png` に書く(ディレクトリは作る)
- 2 倍解像度(`canvas.scale(2)`)。論理サイズは幅 `16 + 5 * (336 + 16)`、高さ `16 + 72 + 16 + 72 + 16 + 140 + 16`
- 全面に `surface` を塗り、`PaperGrainPainter` を全面に描く
- 列 = 経年ステージ 5 つ(左から fresh → heavilyAged)。行 = (1) 336×72 シード `'item-0'`、(2) 336×72 シード `'item-1'`、(3) 112×140 シード `'item-2'`。各セルは `canvas.save(); canvas.translate(x, y); painter.paint(...); canvas.restore();`
- テキストは描かない
- 実行方法をファイル冒頭のコメントに書く: `PAPER_PREVIEW=1 flutter test test/ui/widgets/aged_paper_preview_test.dart`

## §6 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test`(`performance_test.dart` を含む全件)。最後にプレビューを 1 回生成して、2 枚の PNG ができていることだけ確認する(見た目は判断しない)。

## §7 コントラスト検査(§5-1)が落ちたときの手順

落ちた**ステージだけ**に、次を 1 段ずつ適用して再実行する。各段の結果(最小値)を報告に残す。

1. そのステージの `mottleOpacity` を 0.02 下げる(下限 0.02。0 のステージは飛ばす)
2. `_cardSpeckOpacity` を 0.08 にする(全ステージ共通の定数なので、これだけは全体に効く)
3. そのステージの `burnWidth` を 1 下げる(下限 4)

3 段目まで適用しても落ちるなら、**それ以上いじらず止めて報告する**(紙の色を変えるかどうかは司令塔が決める)。背景の検査が落ちた場合は何も変えずに止めて報告する。

## §8 司令塔の判断(1 回目の判断待ちへの回答 / 2026-09-27)

**原因の判断**: fork の仮説を採る。テキスト矩形の四隅は角丸(半径 12)の中心に一致し、ぼかした焼けが円弧全周から集まる。§7 の 1・2 段目で最小値が動かなかったことも、律速が焼けであることと整合する。焼けの減衰を急にして 12px 内側へ届かせない。

見た目の確認(プレビュー)で、シミの輪郭が角ばって石のように見える点も併せて直す。

1. **§7 で入れた値を元に戻す**: heavilyAged の `mottleOpacity` を 0.06、`_cardSpeckOpacity` を 0.12、heavilyAged の `burnWidth` を 7 に戻す(1・2 段目は効果が無かったため)
2. **`burnSigma` を全ステージ 2 にする**(dueSoon / aged / heavilyAged の 3 → 2)。`burnWidth` / `burnOpacity` は §1-2 の表のまま
3. **シミを丸く柔らかくする**(§1-3 の手順 6 を改める)
   - 頂点の半径を `radius * (0.8 + random.nextDouble() * 0.3)` にする(0.7 + 0.5 から変更)。乱数を引く回数・順序は変えない
   - 塗り(`colors.stain` の fill)の `Paint` に `..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)` を足す。輪染みの stroke はぼかさない
4. これでも §5-1 が落ちる場合は、**値をいじらずに止めて**、ステージ × 明暗 × サイズごとの最小値を報告する(紙の色の変更は司令塔が決める)
5. 検証後、プレビューを生成し直す(`build/paper_preview/*.png`)

## §9 司令塔の判断(2 回目の判断待ちへの回答 / 2026-09-27)

**原因の判断(改める)**: 律速は角丸ではなく **heavilyAged だけにある隅の欠け(chips)**。欠けの脚が 12〜18px なので、斜辺はテキスト矩形の角 (12, 12) から最短 (24 − 18) / √2 ≈ 4.2px を通り、焼けの帯(幅 7)がテキスト領域に直接かかる。sigma を絞ると帯が濃くなって悪化したのもこれと整合する。

§8 の変更(`burnSigma` 2・シミの形・§7 の値の戻し)は**そのまま残す**。加えて:

1. **欠けを小さくする**: 脚の長さを `8 + random.nextDouble() * 4`(8〜12px)にする(現在の `12 + random.nextDouble() * 6` から変更。乱数を引く回数は変えない)
2. **焼けは欠ける前の輪郭に沿って描く**: §1-3 の手順 1 で、ギザギザまで適用し終えた時点の Path を `burnOutline` として取っておき(欠けの差分を取る前)、手順 7 の焼けの `drawPath` は `outline` ではなく **`burnOutline`** に対して描く。クリップは従来どおり欠けた `outline`
3. **欠けの切り口には細い焼けを足す**(`chips > 0` のときだけ): 手順 7 の直後、同じクリップ中に `canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = colors.edge.withValues(alpha: burnOpacity)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1))`(幅 3 相当・sigma 1)
4. heavilyAged の `burnWidth` を **6** にする(ギザギザの振れ幅 2.5 で帯が内側へ寄る分を戻す)
5. §5-1 のテストの失敗メッセージに、**最小値を取った画素の座標 (x, y)** を足す
6. それでも落ちる場合は、値をいじらずに止めて、ステージ × 明暗 × サイズごとの最小値と座標を報告する

## §10 司令塔の判断(3 回目の判断待ちへの回答 / 2026-09-27)

**原因の判断(確定)**: 最小値の座標はいずれも紙の内側(端から 35px 前後)で、焼けや欠けではない。**斑 + 斑点 + シミ + 輪染みが 1 点に重なる**のが律速。合成式で light heavilyAged を再計算すると 4.416 で、実測 4.4155 と一致した。112×140 がさらに低いのは、斑を円ごとに別々に塗っているため斑同士の重なりで濃さが積み上がるから(判断 C の「重なりで濃くしない」から漏れていた)。

§8 / §9 の変更はそのまま残す。加えて:

1. **斑を重ねても濃くならないようにする**(§1-3 手順 4 を改める): 斑の円を描く前に `canvas.saveLayer(Offset.zero & size, Paint()..color = colors.edge.withValues(alpha: mottleOpacity))` を呼び、各円は **`Paint()..color = colors.edge..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(0.5, radius * 0.6))`(不透明)** で描いて、最後に `canvas.restore()` する。レイヤーの不透明度が 1 回だけ掛かるので、重なっても `mottleOpacity` を超えない。`mottles == 0` のときは `saveLayer` を呼ばない
2. `_cardSpeckOpacity` を **0.06** にする(全ステージ共通)
3. heavilyAged の `mottleOpacity` を **0.04** にする

司令塔の試算では、light heavilyAged の最悪値は約 4.60 になる。**これでも落ちる場合は値をいじらずに止めて**、最小値と座標を報告する。

## §11 古びを強くする(ユーザーの見た目判断 / 2026-09-27)

**ユーザー判断**: プレビューを見て「古びをもっと強く」。内側(テキスト領域)の濃さは 4.5:1 の制約で上げられないため、**テキストが載らない縁の帯(端から 12px 以内)で古びを強める**。焼けを縁線と同じ色から切り離し、見本の焦げ茶に寄せる。

§8〜§10 の変更はそのまま残す。加えて:

1. **`AgingPaperColors` に `burn`(縁の焼けの色)を足す**(`lib/ui/theme/app_theme.dart`)。コンストラクタは `required this.burn`、doc コメントは「縁の焼け。縁から内側へぼかして重ねる(不透明度は描画側で掛ける)」。`lerp` / `==` / `hashCode` に `burn` を足す。値:

   | ステージ | light `burn` | dark `burn` |
   | --- | --- | --- |
   | fresh | `0xFFD8CBB0` | `0xFF3A342A` |
   | slightlyAged | `0xFFC8B185` | `0xFF4A4030` |
   | dueSoon | `0xFFB08A4E` | `0xFF5A4A33` |
   | aged | `0xFF8E6A35` | `0xFF6E5A3A` |
   | heavilyAged | `0xFF6E4E24` | `0xFF806640` |

   dark は既存の `edge` と同じ値(暗い紙の焼けは明るい縁として見せる現行の表現を保つ)。`paper` / `edge` / `stain` は変えない
2. `AgedPaperPainter.paint` の**焼け 2 本**(§1-3 手順 7 の `burnOutline` と、§9 手順 3 の欠けの切り口)の色を `colors.edge` から **`colors.burn`** に替える。1px の縁線・斑・繊維・斑点は `colors.edge` のまま
3. `burnOpacity` を次に上げる(`burnWidth` / `burnSigma` は現状の値のまま):

   | ステージ | burnOpacity |
   | --- | --- |
   | fresh | 0.30(据え置き) |
   | slightlyAged | 0.45 |
   | dueSoon | 0.65 |
   | aged | 0.80 |
   | heavilyAged | 0.90 |

4. §5-1 のコントラスト検査が落ちたら、**落ちたステージだけ** `burnOpacity` を 0.05 ずつ下げて再実行する(下限は §1-2 表の元の値)。下限でも落ちるなら値をいじらずに止めて、最小値と座標を報告する
5. `AgingPaperColors` を直接組み立てているテストがあれば `burn` を足す(値は同じステージの `edge` でよい)
6. 検証後にプレビュー PNG を生成し直す
7. (レビュー指摘の反映)`test/ui/widgets/paper_background_test.dart` に、`PaperGrainPainter` を持つ `CustomPaint` の祖先に `RepaintBoundary` があることを検査するテストを 1 本足す(`find.ancestor(of: <PaperGrainPainter の CustomPaint>, matching: find.byType(RepaintBoundary))` が見つかる)。判断 H の退行検知
