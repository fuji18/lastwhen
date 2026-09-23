# 設計: 相対経過度でカードが古びていく表示(Issue #21 / F28)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> **このチケットで依存は増えない**(`pubspec.yaml` を変更しない。`assets` も足さない)。
> 委託禁止領域(`lib/data/database/` / `lib/data/migrations/`)には触れない。
> **`lib/data/` 配下の Drift の `ItemRow`(`@DataClassName('ItemRow')`)は別物。リネームしない。**

## 0. 全体方針

```
Item ──ItemView.from(item, now)──▶ ItemView
                                    ├ relativeElapsed(#20 で実装済み)
                                    └ agingStage = agingStageOf(relativeElapsed)   ← 変換時に 1 回だけ
ItemCard(item: ItemView)
  └ CustomPaint(painter: AgedPaperPainter(stage, colors, seed))   ← 紙(面・シミ・縁・欠け)
      └ Material(transparency) → InkWell → Padding → 既存の横並び / 縦積みレイアウト
colors = AgingPalette.of(context).of(stage)   ← ThemeExtension(ライト / ダーク)
```

- 古びは**紙の面と装飾だけ**に掛ける。テキストの色は `ColorScheme` のまま(不透明度で下げない)
- ステージの判定は純関数、描画は `CustomPainter`。乱数は項目 ID から作る固定シードで、再描画しても形が変わらない

## 判断1: `ItemRow` → `ItemCard` のリネーム

| 変更前 | 変更後 |
| --- | --- |
| `lib/ui/widgets/item_row.dart` | `lib/ui/widgets/item_card.dart`(`git mv` で移す) |
| `class ItemRow` | `class ItemCard` |
| `itemRowStackThreshold` | `itemCardStackThreshold` |
| `itemRowSemanticsLabel` | `itemCardSemanticsLabel` |

- 参照箇所をすべて追従させる: `lib/ui/screens/item_list_screen.dart` と `test/ui/` 配下
  (`accessibility_test.dart` / `item_list_screen_test.dart` / `item_add_screen_test.dart` /
  `item_edit_screen_test.dart` / `performance_test.dart` / `terminology_test.dart`)。
  `find.byType(ItemRow)` → `find.byType(ItemCard)`、import パスも直す
- テストの `description` 文字列やコメント中の「行」は、**カードそのものを指す箇所だけ**「カード」に直す
  (「1 行目」のような行の意味は直さない)。迷ったら直さない
- `lib/data/` と `test/data/` の `ItemRow`(Drift の生成クラス)には**触れない**

## 判断2: 経年ステージの判定(`lib/domain/aging_stage.dart` 新規)

```dart
/// 経年ステージ。相対経過度から判定する(`docs/glossary.md`「経年ステージ」)。
enum AgingStage {
  /// 真新しい(`〜0.5`)。相対経過度が null のときもこれ。
  fresh,

  /// 少し経過(`0.5〜1.0`)。
  slightlyAged,

  /// そろそろ(`1.0〜1.5`)。
  dueSoon,

  /// 経過(`1.5〜2.0`)。
  aged,

  /// かなり経過(`2.0〜`)。
  heavilyAged,
}

/// 相対経過度 → 経年ステージ。**境界は下側を含む**(0.5 は slightlyAged)。
///
/// **null(基準間隔が分からない = 記録 1 件以下・未実施)は fresh。** 絶対日数で代用しない。
/// アプリが勝手に期限を決めないための中心的な仕様。
AgingStage agingStageOf(double? relativeElapsed) => switch (relativeElapsed) {
  null => AgingStage.fresh,
  < 0.5 => AgingStage.fresh,
  < 1.0 => AgingStage.slightlyAged,
  < 1.5 => AgingStage.dueSoon,
  < 2.0 => AgingStage.aged,
  _ => AgingStage.heavilyAged,
};
```

- 上のコードをそのまま使ってよい(Dart 3 の関係パターン)。**import は何も要らない**(domain は何にも依存しない)
- 負の値は来ない前提(#20 の算出が負を返さない)。来ても `< 0.5` で fresh になるので追加の分岐は書かない

## 判断3: `ItemView` に `agingStage` を足す(`lib/state/item_view.dart`)

- import に `'../domain/aging_stage.dart'` を足す
- フィールド: `final AgingStage agingStage;` doc コメントは
  `/// 経年ステージ。相対経過度から変換時に 1 回だけ算出する(ビルドのたびに再計算しない)。`
- コンストラクタ引数は **`this.agingStage = AgingStage.fresh`**(任意・既定 fresh。既存の `const ItemView(...)` 呼び出しを壊さない)
- `ItemView.from` の中で、`relativeElapsed` をローカル変数に取り出してから両方に使う:

  ```dart
  final relative = baseline.relativeElapsed(...);  // 既存の引数のまま
  return ItemView(
    ...,
    relativeElapsed: relative,
    agingStage: agingStageOf(relative),
  );
  ```

- `operator ==` と `hashCode` に `agingStage` を足す
- `toItemViews` は変更しない(`now` を 1 回だけ受け取る既存の形で「`Clock.now()` は変換 1 回につき 1 回」を満たしている)

## 判断4: 紙の色(`lib/ui/theme/app_theme.dart` に追記)

### 4-1. 型

同じファイルに 2 つのクラスを足す。`import '../../domain/aging_stage.dart';` を足す。

```dart
/// 1 つの経年ステージの紙の色。
@immutable
final class AgingPaperColors {
  const AgingPaperColors({required this.paper, required this.edge, required this.stain});

  /// 紙の面。**テキストはこの上に載る。**
  final Color paper;

  /// 縁の線と縁の焼け。
  final Color edge;

  /// シミ(半透明)。紙の上に重ねる。
  final Color stain;

  static AgingPaperColors lerp(AgingPaperColors a, AgingPaperColors b, double t) =>
      AgingPaperColors(
        paper: Color.lerp(a.paper, b.paper, t)!,
        edge: Color.lerp(a.edge, b.edge, t)!,
        stain: Color.lerp(a.stain, b.stain, t)!,
      );

  // operator == / hashCode は 3 フィールドで実装する
}

/// 経年ステージごとの紙の色。
///
/// `ColorScheme.fromSeed` に黄ばみ・古紙のロールは無いので `ThemeExtension` で持つ。
/// ライト / ダークの両方に値がある。**古びは彩度と明度で作り、テキストの色は変えない。**
@immutable
final class AgingPalette extends ThemeExtension<AgingPalette> {
  const AgingPalette({
    required this.fresh,
    required this.slightlyAged,
    required this.dueSoon,
    required this.aged,
    required this.heavilyAged,
  });

  static const AgingPalette light = AgingPalette(...);  // 4-2 の表
  static const AgingPalette dark = AgingPalette(...);   // 4-2 の表

  /// テーマに登録されていればそれを、無ければ明暗に合う既定値を返す。
  ///
  /// `AppTheme` を通さずに `MaterialApp` を組むテストでも落ちないようにするため。
  static AgingPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AgingPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  final AgingPaperColors fresh;
  final AgingPaperColors slightlyAged;
  final AgingPaperColors dueSoon;
  final AgingPaperColors aged;
  final AgingPaperColors heavilyAged;

  /// ステージに対応する色。
  AgingPaperColors colorsOf(AgingStage stage) => switch (stage) { ... };

  @override
  AgingPalette copyWith({...5 つとも任意...}) => ...;

  @override
  AgingPalette lerp(covariant AgingPalette? other, double t) {
    if (other == null) return this;
    return AgingPalette(fresh: AgingPaperColors.lerp(fresh, other.fresh, t), ...);
  }
}
```

- `AppTheme._build` の `ThemeData(...)` に
  `extensions: [if (brightness == Brightness.dark) AgingPalette.dark else AgingPalette.light],` を足す
- `AppTheme` のクラス doc コメントと `seedColor` のコメントにある「P1 の状態表示(F10)で…色 + ラベルで示す予定」
  「MVP は状態を色で分けない」の記述を、「P1 の経年変化(F28)は `AgingPalette` の紙の色と `ItemCard` の形状変化で示す。
  シードの青は紙に使わない」という趣旨に書き換える。「`TextTheme` の実値は…(#5)を組むときに決める」の 1 文は残す

### 4-2. 色の値(確定値。司令塔がコントラストを実測済み)

**ライト**

| ステージ | `paper` | `edge` | `stain` |
| --- | --- | --- | --- |
| fresh | `0xFFFBF8F1` | `0xFFE3DACA` | `0x298B6A2E` |
| slightlyAged | `0xFFF6EFDF` | `0xFFD8C9A8` | `0x298B6A2E` |
| dueSoon | `0xFFF0E3C4` | `0xFFC9B283` | `0x298B6A2E` |
| aged | `0xFFE8D5AC` | `0xFFB4945C` | `0x298B6A2E` |
| heavilyAged | `0xFFDDC393` | `0xFF97773F` | `0x298B6A2E` |

**ダーク**

| ステージ | `paper` | `edge` | `stain` |
| --- | --- | --- | --- |
| fresh | `0xFF1E1C18` | `0xFF3A342A` | `0x29C9A461` |
| slightlyAged | `0xFF26221B` | `0xFF4A4030` | `0x29C9A461` |
| dueSoon | `0xFF2F291E` | `0xFF5A4A33` | `0x29C9A461` |
| aged | `0xFF3A3021` | `0xFF6E5A3A` | `0x29C9A461` |
| heavilyAged | `0xFF463924` | `0xFF806640` | `0x29C9A461` |

- 司令塔の実測(stain の不透明度 20% の時点): `onSurfaceVariant` × `alphaBlend(stain, paper)` の最小がライト heavilyAged で 4.55:1。
  上の表は余裕を取って 16%(`0x29`)にしてある。判断7 のコントラストテストが落ちたら**値を勝手に調整せず停止して報告する**
- `Color(0x...)` リテラルを書いてよいのは `app_theme.dart` だけ。ウィジェット・ペインターには書かない

## 判断5: 紙を描く `CustomPainter`(`lib/ui/widgets/aged_paper.dart` 新規)

### 5-1. 公開 API

```dart
/// 項目 ID から、実行をまたいでも変わらないシードを作る(FNV-1a 32bit)。
///
/// `String.hashCode` は実行ごとに同じ値を返す保証が無い。シードが変わると、
/// アプリを開き直すたびにシミや欠けの位置が変わってしまう。
int stableSeedOf(String value) {
  var hash = 0x811C9DC5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// 経年ステージに応じた紙を描く。**テキストは描かない**(子ウィジェットが上に載る)。
class AgedPaperPainter extends CustomPainter {
  const AgedPaperPainter({required this.stage, required this.colors, required this.seed});
  final AgingStage stage;
  final AgingPaperColors colors;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) { ... }  // 5-3

  @override
  bool shouldRepaint(AgedPaperPainter oldDelegate) =>
      oldDelegate.stage != stage || oldDelegate.colors != colors || oldDelegate.seed != seed;
}
```

### 5-2. ステージごとの描画パラメータ

ファイル内の private な `const` レコードかクラスで持つ(`switch (stage)` で引く)。

| ステージ | シミの数 | シミの半径(dp) | 縁の焼けの線幅(dp) | 縁のギザギザ振幅(dp) | 欠けの数 |
| --- | --- | --- | --- | --- | --- |
| fresh | 0 | — | 0 | 0 | 0 |
| slightlyAged | 2 | 6〜12 | 0 | 0 | 0 |
| dueSoon | 3 | 8〜16 | 4 | 0 | 0 |
| aged | 4 | 10〜20 | 6 | 1.5 | 0 |
| heavilyAged | 6 | 12〜24 | 8 | 2.5 | 2 |

- 角丸の半径は **12dp** 固定(ファイル内 `const double _cornerRadius = 12;`。`ItemCard` の `InkWell.borderRadius` と同じ値を使うので、
  **`aged_paper.dart` で `const double agedPaperCornerRadius = 12;` として公開し、`item_card.dart` から参照する**)
- 各ステージは 1 つ前のステージの特徴をすべて含み、**形状の特徴が単調に増える**(色だけでステージを伝えない)

### 5-3. `paint` の手順(この順序で、1 つの `math.Random(seed)` を上から順に消費する)

1. **外形パス** `outline` を作る
   - 振幅 0: `Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(agedPaperCornerRadius)))`
   - 振幅 > 0(ギザギザ): 上の角丸矩形パスを `computeMetrics()` で辿り、**6dp ごと**に点を取る。各点を
     「その点から `size.center(Offset.zero)` へ向かう単位ベクトル × `random.nextDouble() * 振幅`」だけ内側へずらし、
     `moveTo`(最初の点)→ `lineTo`(残り)→ `close()` で多角形にする。内側にしかずらさないので `size` からはみ出さない
2. **欠け**(欠けの数 > 0 のとき): 4 隅(左上・右上・右下・左下)から `random` で重複なく 2 つ選ぶ
   (例: `[0,1,2,3]..shuffle(random)` の先頭 2 つ)。選んだ隅ごとに、脚の長さ `12 + random.nextDouble() * 6`(dp)の直角三角形
   (頂点 = 隅の点、隅から横へ脚の長さ、隅から縦へ脚の長さ)を作り、
   `outline = Path.combine(PathOperation.difference, outline, triangle)` で切り取る
3. **紙の面**: `canvas.drawPath(outline, Paint()..color = colors.paper)`
4. `canvas.save(); canvas.clipPath(outline);`
5. **シミ**(シミの数 > 0 のとき): **全部を 1 本の `Path` に `addOval` で入れてから 1 回だけ `drawPath` する**
   (`Paint()..color = colors.stain`)。重なった部分が二重に濃くならず、コントラストの最悪値が
   `alphaBlend(stain, paper)` に固定される(判断7 の検査の前提)。各シミは:
   - 中心: `Offset(8 + random.nextDouble() * (size.width - 16), 8 + random.nextDouble() * (size.height - 16))`
     (幅・高さが 16 以下なら中心は `size.center(Offset.zero)`)
   - 半径 `r = 最小 + random.nextDouble() * (最大 - 最小)`、楕円の幅 `2r × (0.7 + random.nextDouble() * 0.6)`、高さ `2r`
6. **縁の焼け**(線幅 > 0 のとき): `canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = 線幅..color = colors.edge.withValues(alpha: 0.35))`。
   クリップ済みなので内側の半分(最大 4dp)だけが見える
7. `canvas.restore();`
8. **縁の線**: `canvas.drawPath(outline, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = colors.edge)`

- `paint` の中で `Theme` や `BuildContext` を参照しない(色はコンストラクタで受け取る)
- 縁の焼け・ギザギザ・欠けは外周 8dp 以内に収まる。カードの内側余白は 12dp 以上なので、テキストに掛からない

## 判断6: `ItemCard`(`lib/ui/widgets/item_card.dart`)

### 6-1. 外側の構造

`build` を次の構造にする(既存の `isStacked` 判定と `_InlineLayout` / `_StackedLayout` はそのまま使う):

```dart
final palette = AgingPalette.of(context);
return Padding(
  // カード同士の間隔。
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  child: CustomPaint(
    painter: AgedPaperPainter(
      stage: item.agingStage,
      colors: palette.colorsOf(item.agingStage),
      seed: stableSeedOf(item.id.value),
    ),
    // InkWell のインクは最寄りの Material に描かれる。Scaffold の Material は紙の下にあるので、
    // 透明な Material を紙の上に挟まないとタップの波紋が紙に隠れる。
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(agedPaperCornerRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: isStacked ? _StackedLayout(...) : _InlineLayout(...),
        ),
      ),
    ),
  ),
);
```

- 左右の合計余白は 16dp → 24dp に増える。`itemCardStackThreshold`(1.3)は**変えない**。
  doc コメントの「(1.29 倍で約 97dp)」を「(1.29 倍で約 81dp)」に、「1 行」「行」をカードの意味では「カード」に直す
- `ItemCard` のクラス doc コメントに「経年ステージに応じて紙が古びる(`AgedPaperPainter`)。古びは紙の面と装飾だけに掛け、
  テキストの色と大きさは変えない」を足す
- `RepaintBoundary` は足さない(`ListView.builder` が項目ごとに挟む)

### 6-2. テキストの色を明示する

紙の上のコントラストを判断7 の検査と一致させるため、色を明示する:

- 項目名(`_NameAndLastDone` の 1 つ目の `Text`): `theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface)`
- 最終実施日: 既存のまま `onSurfaceVariant`
- 経過日数(`_Elapsed`): `copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)`。
  直上のコメント「強調はサイズとウェイトだけで作り、色を使わない(MVP は…)」は
  「強調はサイズとウェイトで作る。経年変化は紙に掛け、経過日数の色は変えない(`docs/functional-design.md`「色の使い方」)」に直す

### 6-3. 読み上げ

```dart
/// 経年ステージの読み上げ文。**fresh は null**(何も足さない。相対経過度が null の項目も fresh)。
String? agingStageSemanticsText(AgingStage stage) => switch (stage) {
  AgingStage.fresh => null,
  AgingStage.slightlyAged => '少し経過',
  AgingStage.dueSoon => 'そろそろ',
  AgingStage.aged => '経過',
  AgingStage.heavilyAged => 'かなり経過',
};
```

- `itemCardSemanticsLabel(item)` は、既存の文字列を作ったあと、`agingStageSemanticsText(item.agingStage)` が null でなければ
  末尾に `、状態は{文}` を足す。例: `風呂掃除、最終実施日は2026年9月2日、14日経過、状態はかなり経過`
- fresh のときは既存の文字列と完全に同じ(既存テストの期待値 `美容院、最終実施日は2026年9月12日、4日経過` などは変わらない)
- 形状(シミ・欠け)は読み上げない。`CustomPaint` は `Semantics` を持たないので追加の対応は要らない

## 判断7: テスト

既存テストの書き方(`test/state/item_view_test.dart` の `_item` ヘルパー、`test/support/fake_clock.dart`)に合わせる。

### 7-1. `test/domain/aging_stage_test.dart`(新規)

相対経過度 `0 / 0.49 / 0.5 / 0.99 / 1.0 / 1.49 / 1.5 / 1.99 / 2.0 / 5.0 / null` の 11 ケースを表で回す。
期待値: fresh / fresh / slightlyAged / slightlyAged / dueSoon / dueSoon / aged / aged / heavilyAged / heavilyAged / fresh

### 7-2. `test/state/item_view_test.dart`(追記)

- `now = DateTime.utc(2026, 9, 16, 3)` で、`recentDoneAts` が `[9/2, 8/26]`(UTC 3 時)→ 基準間隔 7・経過 14 → `agingStage == heavilyAged`
- `recentDoneAts` が `[9/2, 2026/3/6]`(同)→ 基準間隔 180・経過 14 → `agingStage == fresh`
- 記録 1 件(`recentDoneAts: [9/12]`)→ `fresh`、未実施 → `fresh`
- `agingStage` だけが違う 2 つの `ItemView`(コンストラクタで直接作る)は等しくない
- いずれも `lastDoneAt` は `recentDoneAts.first` と同じ値を渡す

### 7-3. `test/ui/theme/aging_palette_test.dart`(新規)

- `AppTheme.light().extension<AgingPalette>()` が `AgingPalette.light`、dark も同様
- **コントラスト**: ライト / ダーク × 5 ステージの全 10 通りで、`ColorScheme` の `onSurface` と `onSurfaceVariant` のそれぞれについて
  `paper` との比 ≥ 4.5、`Color.alphaBlend(stain, paper)` との比 ≥ 4.5。比は
  `(max(L1, L2) + 0.05) / (min(L1, L2) + 0.05)`(`Color.computeLuminance()`)。テスト名に明暗・ステージ・色の名前を入れる
- `lerp(other, 0)` が自分と等しい色、`lerp(other, 1)` が相手と等しい色を返す(1 ケースでよい)

### 7-4. `test/ui/widgets/aged_paper_test.dart`(新規)

- `stableSeedOf('abc')` が 2 回呼んで同じ値、`'abc'` と `'abd'` で違う値
- `shouldRepaint`: 同じ引数の 2 つ → false / stage だけ違う → true / colors だけ違う → true / seed だけ違う → true
- 5 ステージそれぞれ、`PictureRecorder` + `Canvas` に `Size(360, 72)` で `paint` して例外が出ない。
  `Size(10, 10)`(シミの中心の分岐)でも例外が出ない

### 7-5. `test/ui/widgets/item_card_test.dart`(新規)

`MaterialApp(theme: AppTheme.light(), home: Scaffold(body: ItemCard(item: ..., onDonePressed: () {}, onTap: () {})))` を組むヘルパーを置く。
紙のペインターは `find.byWidgetPredicate((w) => w is CustomPaint && w.painter is AgedPaperPainter)` で取る。

- 5 ステージ + 相対経過度 null のそれぞれ(`ItemView` を直接作り `agingStage` を渡す。null は `agingStage` 省略)で、
  ペインターの `stage` が期待どおり、読み上げラベルが期待どおり(fresh / null は `、状態は` を含まない。他は `、状態は少し経過` 等を含む)
- **同じ「14日前」で見た目が違う**: 7-2 の 2 つの `Item` を `ItemView.from` で変換してそれぞれ描き、ペインターの `stage` が
  `heavilyAged` と `fresh` で異なる、かつ `colors.paper` が異なる、かつ画面上の経過日数の文字列はどちらも `14日前`
- ダークテーマ(`AppTheme.dark()`)でペインターの `colors` が `AgingPalette.dark.colorsOf(stage)` と等しい
- 文字サイズ 200%(`MediaQuery` で `TextScaler.linear(2)`)・heavilyAged で、`tester.takeException()` が null、
  `DoneButton` が `hitTestable()`、経過日数の `Text` が省略されていない
- 経過日数の `Text` の `fontSize` が、項目名・最終実施日の `Text` の `fontSize` より大きい(heavilyAged で確認)

### 7-6. 既存テスト

判断1 のリネームに追従させるだけで、期待値は変えない。`terminology_test.dart` の読み上げラベル検査には
`agingStage: AgingStage.heavilyAged` の `ItemView` を 1 つ足し、`状態は…` の文言が禁止一覧に違反しないことも見る。

## 判断8: ドキュメント追記

- `docs/product-requirements.md`「P1 機能」の表の F27 の次に 1 行足す:
  `| F28 | 相対経過度による経年変化 | 相対経過度(経過日数 ÷ 基準間隔)で一覧のカードが 5 段階に古びる。基準間隔が無い項目は古びない。**色だけでなくシミ・縁の傷み・欠けの形状でも示す**。F10 を設定なしで実現する形 |`
- `docs/functional-design.md`
  - 「一覧の行(最重要コンポーネント)」の見出しを「一覧のカード(最重要コンポーネント)」にし、本文の「行」をカードの意味の箇所だけ「カード」に直す
  - 「色の使い方」節を次の内容に置き換える: (1) 状態は**経年ステージ**で表す。Issue #21 の 5 段階表(相対経過度・ステージ・紙の表現)と
    「null は真新しいと同じ描画」「境界は下側を含む」を載せる (2) 紙の色は `AgingPalette`(`ThemeExtension`)で持ち、ライト / ダーク両方に値がある
    (3) 古びは紙の面と装飾だけに掛け、テキストの色は `ColorScheme` のまま。全ステージ × 明暗でテキストのコントラスト 4.5:1 以上をテストで検査する
    (4) 色だけに頼らず、シミ・縁の焼け・端の傷み・欠けの形状を段階的に足す。読み上げにはステージ名を含める
    (5) アイコンの掠れは項目アイコン(#32)の導入時に掛ける
- `docs/ui-design-guidelines.md` §7
  - 「参照デザイン(トーン)」の行の末尾に「**例外: 経年変化(F28)の紙の装飾は許容する。ただしテキストの可読性は落とさない**」を足す
  - 「このプロダクト固有の翻訳」表の「色だけに頼らない」行を「経年ステージは紙の色に加えて形状(シミ・縁の傷み・欠け)と読み上げでも示す(§5 / WCAG AA)」に直す
- `docs/glossary.md`
  - 「ステータス・状態」の「目安期間に対する状態【P1】」の後に「### 経年ステージ(Aging Stage)【P1】」を足す。
    5 段階の表(相対経過度 / ステージ / コード上の表記 `AgingStage.fresh` 等)と「相対経過度が null のときは真新しい(古びない)」を書く
  - 「アーキテクチャ用語」の「表示モデル(ItemView)」の後に「### カード(ItemCard)」を足す:
    「一覧で 1 項目を表す紙の見た目のコンポーネント。経年ステージに応じて古びる。**一覧の 1 項目を『行』と呼ばず『カード』と呼ぶ**」
  - 既存の見出しと同じ書式(説明文 + `- **コード上の表記**:` の箇条)に揃える

## 判断9: 検証

`dart format --output=none --set-exit-if-changed .` / `flutter analyze --fatal-infos` / `flutter test` を通す。
**テストを通すために判断4-2 の色・判断5-2 のパラメータ・既存テストの期待値を変えない。** 変えないと通らないなら停止して報告する。
