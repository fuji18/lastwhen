# 設計: アクセシビリティとパフォーマンスの仕上げ(Issue #9)

<!-- status: ready -->

> 実装者はこのファイルと `tasklist.md` だけを読む。**ここに書かれていない設計判断が必要になったら、
> 推測せず実装を止めて司令塔に戻すこと**(`.claude/rules/spec-driven.md`)。
> **`pubspec.yaml` に依存を足さない。** `integration_test` も追加しない。
> **`lib/domain/` / `lib/data/` / `lib/state/` は一切変更しない。** 触るのは `lib/ui/` と `test/` と `docs/` だけ。

## 0. 全体方針

このチケットは**新しい仕組みを 1 つも作らない**。やることは 3 つだけ。

1. **一覧の行(`ItemRow`)を文字サイズに追従させる** — 唯一のレイアウト変更
2. **`Semantics` を足す** — `ItemRow` / `DoneButton` / 空状態・エラーの装飾アイコン / 読み込み中
3. **既に満たしている非機能要件をテストで固定する** — コントラスト・タッチターゲット・クエリ本数・遅延生成

計画時の実測(2026-09-20 / `flutter test` / 360×640dp)で、**コントラスト比は light / dark の
使用ペアすべてで 5.02:1 以上**、**「やった」ボタンは 200% でも高さ 56dp** と分かっている。
つまりこの 2 つは**直すものが無い**。回帰テストを書くのが仕事。

```
lib/ui/widgets/item_row.dart        レイアウトを 2 種に分岐 + 読み上げラベル   ← 変更の本体
lib/ui/widgets/done_button.dart     semanticsLabel を必須引数として受け取る
lib/ui/widgets/centered_scrollable.dart  新規。中央寄せのまま縦スクロールできる箱
lib/ui/widgets/empty_state.dart     CenteredScrollable + 装飾アイコンを読み上げ対象外に
lib/ui/screens/item_list_screen.dart  _LoadError を同上 + 読み込み中にラベル
lib/ui/screens/item_add_screen.dart   本文を縦スクロール可能に
lib/ui/screens/item_edit_screen.dart  同上
test/ui/accessibility_test.dart     新規
test/ui/performance_test.dart       新規
test/ui/terminology_test.dart       新規
docs/development-guidelines.md      実機計測の手順を追記
```

## 1. 計画時の実測値(判断の根拠。実装中に測り直さなくてよい)

| 文字倍率 | 経過日数 `431日前` の実寸 | 「やった」ボタン | 省略された文字列 |
| --- | --- | --- | --- |
| 100% | 91.9 × 32dp(**省略されている**) | 74.3 × 56dp | 項目名 / 経過日数 |
| 150% | 83.5 × 48dp(省略) | 95.3 × 56dp | 項目名 / 最終実施日 / 経過日数 |
| 200% | 75.1 × 64dp(省略) | 116.3 × 56dp | 項目名 / 最終実施日 / 経過日数 |

コントラスト比(`ColorScheme.fromSeed(seedColor: 0xFF2F6690)`):

| ペア | light | dark |
| --- | --- | --- |
| `onSurface` / `surface` | 16.27 | 14.28 |
| `onSurfaceVariant` / `surface` | 8.89 | 10.88 |
| `onSecondaryContainer` / `secondaryContainer`(「やった」) | 7.25 | 7.25 |
| `onPrimary` / `primary`(保存ボタン) | 6.50 | 7.75 |
| `onPrimaryContainer` / `primaryContainer`(FAB) | 7.27 | 7.27 |
| `error` / `surface`(削除) | 6.14 | 10.89 |
| `onSurface` / `surfaceContainerHigh`(ダイアログ) | 13.98 | 11.13 |
| `onInverseSurface` / `inverseSurface`(SnackBar) | 11.58 | 10.12 |
| `inversePrimary` / `inverseSurface`(SnackBar のアクション) | 7.72 | **5.02** |

**最小でも 5.02:1 で AA(4.5:1)を満たす。色を変えない。**

## 2. 設計判断

| # | 判断 | 理由 |
| --- | --- | --- |
| 1 | 文字倍率 **1.3 以上で行を縦積みに切り替える** | 1.3 未満なら「経過日数の実寸 + ボタン 56dp」を 360dp 幅に置いても項目名の取り分が残る(1.29 倍で約 97dp)。1.3 以上では項目名が消えるため、横並びを維持する意味が無くなる |
| 2 | 幅が足りないとき**削るのは項目名。経過日数は絶対に削らない** | 経過日数は製品の中心価値(`docs/ui-design-guidelines.md` §7「経過日数が最大・最も太い」)。現状は逆に経過日数が切れている |
| 3 | 項目名は **2 行まで表示し、超えた分だけ省略する** | 項目名は任意長の入力なので「絶対に省略しない」は成立しない。1 行から 2 行に広げたうえで省略を残す |
| 4 | 最終実施日は **2 行 + 省略** | 縦積みでは全幅が使えるので実際には省略されない。省略指定は幅が足りなくなったときに文字が描画領域からはみ出して塗られるのを防ぐ保険 |
| 5 | 縦積みでも**ボタンは右端** | 片手操作(`docs/product-requirements.md`「ユーザビリティ」)。親指の可動域は文字サイズで変わらない |
| 6 | **読み上げは行の説明文とボタンで 2 ノードに分ける** | 一覧には見た目が同じボタンが行数だけ並ぶ。ボタン側に項目名が無いと「やった、やった、やった」としか読まれない |
| 7 | **`Text.semanticsLabel` でボタンのラベルを差し替える** | `Semantics(excludeSemantics: true)` でボタンを包むと `button` / `enabled` / タップ動作まで落ちる。`ButtonStyleButton` は子の `Text` のラベルを自分のノードへ取り込むので、`Text` 側で差し替えるのが最小で安全 |
| 8 | 空状態・エラーは **`CenteredScrollable`** で包む | `Center` だけでは 200% ではみ出した分が押せない。`SingleChildScrollView` だけでは中央寄せが崩れて既存テストが落ちる。両立には `LayoutBuilder` + `ConstrainedBox(minHeight)` が要る |
| 9 | **実機計測はこのチケットでやらない** | devcontainer に Android 端末・エミュレータ・`adb` が無く、リリースビルドで測れない(計画時に `flutter devices` で確認済み。検出されたのは Linux desktop のみ)。ユーザー承認のうえ手順書 + テスト内計測で代替する |
| 10 | 計測系テストは **時間を assert しない**(上限 5 秒の安全網のみ) | `flutter test` はデバッグ JIT + CI のマシン差があり、300ms のような実機基準をここで課すと落ち続ける。数値は `debugPrint` で記録し PR ボディへ転記する |

## 3. `lib/ui/widgets/done_button.dart`

`semanticsLabel` を**必須引数**として増やす。呼び出し元は `ItemRow` の 2 箇所だけ。
**見た目・サイズ・スタイルは一切変えない。**

```dart
import 'package:flutter/material.dart';

/// 「やった」ボタンの最小辺(dp)。
///
/// Material の既定タップ領域は 48dp だが、このアプリは**片手・1 タップ**が中心価値なので
/// 自前で 56dp を指定する(`docs/ui-design-guidelines.md` §7「タッチターゲット」)。
const double doneButtonMinSize = 56;

/// 記録(「やった」)のボタン。
///
/// ラベルは「やった」で固定する(`docs/glossary.md`「表記ゆれの禁止一覧」)。
/// **押したときの動作は呼び出し元が決める。**
class DoneButton extends StatelessWidget {
  /// ボタンを作る。[onPressed] はタップ時の処理。
  const DoneButton({
    required this.onPressed,
    required this.semanticsLabel,
    super.key,
  });

  /// タップ時の処理。
  final VoidCallback onPressed;

  /// スクリーンリーダーへ読み上げるラベル。**どの項目のボタンかを含めること。**
  ///
  /// 一覧には見た目が同じボタンが行数だけ並ぶため、読み上げだけは項目名で区別する(判断6)。
  /// `Semantics(excludeSemantics: true)` で包むとボタンとしての意味とタップ動作まで
  /// 落ちるので、子の `Text` 側で差し替える(判断7)。
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(doneButtonMinSize, doneButtonMinSize),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 既定の `padded` だと「見た目 40dp + 透明パディング」になり、
        // ウィジェットの実寸が 56dp を表さなくなる(判断10)。
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text('やった', semanticsLabel: semanticsLabel),
    );
  }
}
```

## 4. `lib/ui/widgets/item_row.dart`(このチケットの本体)

**下のコードをそのまま採用する。** `elapsedText` は現行のまま変更しない。

```dart
import 'package:flutter/material.dart';

import '../../domain/elapsed_days.dart';
import '../../state/item_view.dart';
import 'done_button.dart';

/// 横並びから縦積みへ切り替える文字倍率のしきい値。
///
/// 1.3 未満なら「経過日数の実寸 + ボタン 56dp」を 360dp 幅に置いても項目名の取り分が
/// 残る(1.29 倍で約 97dp)。1.3 以上では取り分が消えるので縦に積む(design.md 判断1)。
const double itemRowStackThreshold = 1.3;

/// しきい値を判定するときの基準フォントサイズ(dp)。
///
/// 倍率そのものは取得できないので、基準サイズを渡して返り値と比べる。
const double _referenceFontSize = 16;

/// 一覧の 1 行。**このアプリで最も重要なコンポーネント。**
///
/// 通常の文字サイズでは「項目名 + 最終実施日」「経過日数」「やった」を横に並べ、
/// 文字が大きいときは縦に積む(design.md 判断1)。どちらの並びでも
/// **経過日数が最大・最も太く、絶対に省略されない**(`docs/functional-design.md`「UI設計」)。
/// ボタンを右端に置くのは片手操作で親指が届く範囲だから。
class ItemRow extends StatelessWidget {
  /// 1 行を作る。
  const ItemRow({
    required this.item,
    required this.onDonePressed,
    required this.onTap,
    super.key,
  });

  /// 表示する項目。
  final ItemView item;

  /// 「やった」ボタンのタップ時の処理。
  final VoidCallback onDonePressed;

  /// 行そのもののタップ時の処理(編集画面への遷移)。
  ///
  /// 削除の入口は編集画面だけ。一覧にスワイプ削除を置かない。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(_referenceFontSize);
    final isStacked = scaled >= _referenceFontSize * itemRowStackThreshold;
    return InkWell(
      // 行内の DoneButton は自分でタップを消費する。
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: isStacked
            ? _StackedLayout(item: item, onDonePressed: onDonePressed)
            : _InlineLayout(item: item, onDonePressed: onDonePressed),
      ),
    );
  }
}

/// 通常の文字サイズでの並び。左に説明、右寄りに経過日数、右端にボタン。
class _InlineLayout extends StatelessWidget {
  const _InlineLayout({required this.item, required this.onDonePressed});

  final ItemView item;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: itemRowSemanticsLabel(item),
            excludeSemantics: true,
            child: Row(
              children: [
                Expanded(child: _NameAndLastDone(item: item)),
                const SizedBox(width: 12),
                // **Flexible で包まない。** 幅が足りないときに削るのは項目名側で、
                // 経過日数は実寸のまま置く(design.md 判断2)。
                _Elapsed(item: item, textAlign: TextAlign.end),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        DoneButton(
          onPressed: onDonePressed,
          semanticsLabel: doneButtonSemanticsLabel(item.name),
        ),
      ],
    );
  }
}

/// 文字が大きいときの並び。説明を全幅で積み、ボタンを次の行の右端に置く。
class _StackedLayout extends StatelessWidget {
  const _StackedLayout({required this.item, required this.onDonePressed});

  final ItemView item;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: itemRowSemanticsLabel(item),
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _NameAndLastDone(item: item),
              const SizedBox(height: 8),
              _Elapsed(item: item, textAlign: TextAlign.start),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // 縦に積んでもボタンは右端のまま(design.md 判断5)。
        Align(
          alignment: Alignment.centerRight,
          child: DoneButton(
            onPressed: onDonePressed,
            semanticsLabel: doneButtonSemanticsLabel(item.name),
          ),
        ),
      ],
    );
  }
}

/// 項目名と最終実施日。読み上げは親の [Semantics] がまとめて行う。
class _NameAndLastDone extends StatelessWidget {
  const _NameAndLastDone({required this.item});

  final ItemView item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastDoneText = item.lastDoneText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.name,
          style: theme.textTheme.titleMedium,
          // 任意長の入力なので「絶対に省略しない」は成立しない。2 行まで許す(判断3)。
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // 未実施の行には日付を出さない(`docs/glossary.md`「項目の表示状態」)。
        if (lastDoneText != null) ...[
          const SizedBox(height: 4),
          Text(
            lastDoneText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            // 実際には 2 行に収まる。省略指定ははみ出して塗られないための保険(判断4)。
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// 経過日数。**行内で最大・最も太く、決して省略しない。**
class _Elapsed extends StatelessWidget {
  const _Elapsed({required this.item, required this.textAlign});

  final ItemView item;

  /// 横並びでは右寄せ、縦積みでは左寄せ。
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      elapsedText(item.elapsed),
      textAlign: textAlign,
      maxLines: 1,
      // 折り返しも省略もしない。ここが切れると製品の中心価値が消える(判断2)。
      softWrap: false,
      overflow: TextOverflow.visible,
      // **強調はサイズとウェイトだけで作り、色を使わない**
      // (MVP は状態を色で分けない。`docs/functional-design.md`「色の使い方」)。
      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

/// 経過日数の表示文字列。
///
/// 文言は `docs/glossary.md`「項目の表示状態」が正。**`NeverDone` を「0日前」と書かない**
/// (「今日やった」と区別がつかなくなる)。
String elapsedText(ElapsedLabel label) => switch (label) {
  NeverDone() => '未実施',
  Today() => '今日',
  Yesterday() => '昨日',
  DaysAgo(:final days) => '$days日前',
};

/// 行全体をスクリーンリーダーへ読み上げるための説明文。
///
/// **数字だけにならないよう、単位と文脈を必ず含める**(Issue #9 受け入れ条件)。
/// 画面には「4日前」としか出ないが、読み上げでは項目名と最終実施日を添える。
String itemRowSemanticsLabel(ItemView item) {
  final lastDoneText = item.lastDoneText;
  return switch (item.elapsed) {
    NeverDone() => '${item.name}、未実施',
    Today() => '${item.name}、最終実施日は今日',
    Yesterday() => '${item.name}、最終実施日は昨日',
    // lastDoneText が null になるのは未実施のときだけだが、型の上では null を取りうる。
    DaysAgo(:final days) => lastDoneText == null
        ? '${item.name}、${days}日経過'
        : '${item.name}、最終実施日は${lastDoneText}、${days}日経過',
  };
}

/// 「やった」ボタンの読み上げ文。**どの項目のボタンかを含める**(design.md 判断6)。
String doneButtonSemanticsLabel(String itemName) => '${itemName}をやったと記録';
```

## 5. `lib/ui/widgets/centered_scrollable.dart`(新規)

```dart
import 'package:flutter/material.dart';

/// 中央寄せのまま、縦に入り切らないときだけスクロールできるようにする箱。
///
/// 文字サイズ 200% では空状態・エラー表示が画面の高さを超える。`Center` だけだと
/// はみ出した分に触れられず、`SingleChildScrollView` だけだと中央寄せが崩れる
/// (design.md 判断8)。
class CenteredScrollable extends StatelessWidget {
  /// 中身を中央に置く箱を作る。
  const CenteredScrollable({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  /// 中央に置く中身。
  final Widget child;

  /// 中身の周りの余白。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: Padding(padding: padding, child: child)),
        ),
      ),
    );
  }
}
```

## 6. `lib/ui/widgets/empty_state.dart`

- 外側の `Center` + `Padding` を **`CenteredScrollable`** に置き換える(`padding` は既定の 24 のまま)
- `Icon(Icons.inbox_outlined, ...)` を **`ExcludeSemantics` で包む**
  — 装飾であって情報ではない。読み上げは下の 2 つのテキストで足りる
- **`Column` は 1 つのまま**にする(`mainAxisSize: MainAxisSize.min` / 子の並び・文言・余白は変更しない)。
  既存テスト `test/ui/item_list_screen_test.dart`「空状態の内容は画面中央に配置される」が
  `find.descendant(of: EmptyState, matching: find.byType(Column))` で 1 つだけ見つかることに依存している

## 7. `lib/ui/screens/item_list_screen.dart`

3 箇所だけ変える。**画面遷移・SnackBar・`_handleDone` / `_handleUndo` は一切触らない。**

1. 読み込み中: `const Center(child: CircularProgressIndicator())`
   → `const Center(child: CircularProgressIndicator(semanticsLabel: '読み込み中'))`
2. `_LoadError` の外側 `Center` + `Padding` を **`CenteredScrollable`** に置き換える
   (`Column` は 1 つのまま)
3. `_LoadError` の `Icon(Icons.error_outline, ...)` を **`ExcludeSemantics` で包む**

## 8. `lib/ui/screens/item_add_screen.dart` / `item_edit_screen.dart`

両方とも `body` の組み立てだけを次の形に変える。**`Column` の子・文言・`_save` / `_delete` は触らない。**

```dart
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // スクロールビューの中では高さが無限になるので min を明示する。
            mainAxisSize: MainAxisSize.min,
            children: [
              /* 既存の子をそのまま */
            ],
          ),
        ),
      ),
```

元の `Padding(padding: const EdgeInsets.all(16), child: ...)` は
`SingleChildScrollView` の `padding` に移すので、二重に余白を入れない。

## 9. テスト

### 9.1 `test/ui/accessibility_test.dart`(新規)

共通ヘルパー:

```dart
Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) => MediaQuery(
  data: MediaQueryData(
    textScaler: TextScaler.linear(textScale),
    platformBrightness: brightness,
  ),
  child: ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(clock),
    ],
    child: const App(),
  ),
);
```

> `MaterialApp` より上の `MediaQuery` が勝つことは計画時に実測で確認済み
> (倍率を上げると実際に文字の実寸が変わった)。

画面サイズは各テストの冒頭で固定する:

```dart
tester.view.physicalSize = const Size(360 * 3, 640 * 3);
tester.view.devicePixelRatio = 3;
addTearDown(tester.view.reset);
```

省略検出のヘルパー(`import 'package:flutter/rendering.dart';` が要る):

```dart
/// 画面上で省略(…)されているテキストを集める。
List<String> _ellipsizedTexts(WidgetTester tester) {
  final found = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph && object.didExceedMaxLines) {
      found.add(object.text.toPlainText());
    }
    object.visitChildren(visit);
  }
  visit(tester.binding.renderViews.first);
  return found;
}
```

書くテスト(`group` は「アクセシビリティ」):

| テスト名 | 内容 |
| --- | --- |
| `コントラスト比が light / dark の全ペアで WCAG AA を満たす` | §1 の 9 ペアを `AppTheme.light()` / `AppTheme.dark()` の `ColorScheme` から取り、相対輝度から比を計算して `greaterThanOrEqualTo(4.5)`。相対輝度は `Color` の `r` / `g` / `b`(0〜1 の double)から WCAG の式で求める |
| `文字サイズ 100% / 150% / 200% で一覧の文字が省略されない` | 項目 2 件(`美容院` = 4日前 / `歯ブラシ交換` = 未実施)を入れ、3 倍率それぞれで `_ellipsizedTexts(tester)` が `isEmpty`。`tester.takeException()` が `isNull` |
| `項目名が長い場合だけ 2 行まで表示して省略する` | 40 文字の項目名で倍率 1.0。`_ellipsizedTexts` に**その項目名だけ**が含まれる。経過日数は含まれない |
| `文字サイズ 200% で登録画面と編集画面が破綻しない` | それぞれ `MaterialApp` + 対象画面を倍率 2.0 / 高さ 320dp で描画し、例外なし・省略なし |
| `やったボタンは文字サイズ 100% / 200% のどちらでも 56dp 以上` | `tester.getSize(find.byType(DoneButton).first)` の幅・高さが `greaterThanOrEqualTo(56)` |
| `行のタップ領域が 48dp 以上` | `tester.getSize(find.byType(ItemRow).first).height` が `greaterThanOrEqualTo(48)`(倍率 1.0 / 2.0) |
| `やったボタンと項目追加ボタンが画面の右半分にある` | `tester.getCenter(...).dx` が `Scaffold` の幅の半分より大きい(`DoneButton` と `FloatingActionButton`) |
| `dark テーマでも一覧が破綻しない` | `brightness: Brightness.dark` で描画。`Theme.of` の `brightness` が `Brightness.dark` であることを確かめたうえで、例外なし・省略なし |
| `行に項目名と最終実施日と経過日数を含む読み上げラベルがある` | `tester.ensureSemantics()` のうえ `find.bySemanticsLabel('美容院、最終実施日は2026年9月12日、4日経過')` と `find.bySemanticsLabel('歯ブラシ交換、未実施')` が `findsOneWidget`。最後に `handle.dispose()` |
| `やったボタンの読み上げラベルに項目名が含まれる` | 同上で `find.bySemanticsLabel('美容院をやったと記録')` が `findsOneWidget` |
| `空状態と読み込みエラーの装飾アイコンは読み上げ対象から外れている` | `find.ancestor(of: find.byIcon(Icons.inbox_outlined), matching: find.byType(ExcludeSemantics))` が `findsOneWidget`。エラー側は `Icons.error_outline` |
| `読み込み中のインジケータにラベルがある` | 下記 `_NeverEmittingRepository` を使い、`pumpWidget` 後に `pumpAndSettle` せず `find.bySemanticsLabel('読み込み中')` が `findsOneWidget` |

読み込み中・エラーの再現には、このテストファイル内にスタブを置く
(`FakeItemRepository` は `final class` で継承できず、共有テストの契約も変えたくないため):

```dart
/// 何も流さないまま購読が続く状態(= 読み込み中)を作る。
final class _NeverEmittingRepository implements ItemRepository {
  @override
  Stream<List<Item>> watchAll() =>
      Stream<List<Item>>.fromFuture(Completer<List<Item>>().future);

  // watchAll 以外は呼ばれない。
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

エラー表示用は `Stream<List<Item>>.error(StateError('DB オープン失敗'))` を返す
`_FailingRepository` を同じ形で置く。

> `_NeverEmittingRepository` を使うテストは `_app` ヘルパーを使えない(型が
> `FakeItemRepository` のため)。`ProviderScope` を直接組むこと。

### 9.2 `test/ui/performance_test.dart`(新規)

| テスト名 | 内容 |
| --- | --- |
| `項目100件でも構築される行は可視範囲に収まる` | `FakeItemRepository` に 100 件入れて描画。`find.byType(ItemRow, skipOffstage: false).evaluate().length` が `lessThan(20)` |
| `100件をスクロールしても構築される行数が増え続けない` | `tester.fling(find.byType(ListView), const Offset(0, -2000), 3000)` → `pumpAndSettle`。例外なし、行数が `lessThan(20)` のまま |
| `100件の一覧で発行されるクエリは watchAll の 1 本だけ` | 下記の `QueryInterceptor` 版 |
| `参考値: 100件の初回描画にかかった時間を記録する` | `Stopwatch` で `pumpWidget` + `pumpAndSettle` を測り `debugPrint('[perf] ...')`。assert は `lessThan(5000)` の安全網だけ(判断10) |

クエリ本数のテスト(**実 DB を使う唯一のテスト**):

```dart
/// 実行された SQL を数える。`watchAll` 以外のクエリが混じっていないことを確かめる。
final class _StatementCounter extends QueryInterceptor {
  final List<String> selects = <String>[];
  final List<String> writes = <String>[];

  void reset() {
    selects.clear();
    writes.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add(statement);
    return executor.runSelect(statement, args);
  }

  // runInsert / runUpdate / runDelete / runCustom も同じ形で writes に積んでから委譲する。
}
```

手順:

1. `final counter = _StatementCounter();`
2. `final db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true).interceptWith(counter));`(`addTearDown(db.close)`)
3. `final repository = ItemRepositoryImpl(db);` で 100 件 `add` する
4. `counter.reset()`
5. `App` を描画して `pumpAndSettle`
6. `expect(counter.selects.where((s) => s.toLowerCase().contains('from items')).length, 1)`
7. `expect(counter.writes, isEmpty)`

> ここで数えているのは「一覧を出すのに何本の SQL が要るか」。`ListView.builder` が
> 行ごとにクエリを出す実装に退行したら 100 本になって落ちる。

### 9.3 `test/ui/terminology_test.dart`(新規)

**画面に実際に描画された文字列**が `docs/glossary.md`「表記ゆれの禁止一覧」に違反しないことを見る。
ソースを走査しない(コメントに「〜と書かない」という説明が入っており誤検知するため)。

```dart
/// 使ってはいけない表記(`docs/glossary.md`「表記ゆれの禁止一覧」)。
const List<String> _bannedTerms = [
  'タスク', '習慣', 'アイテム', 'エントリ',
  '完了する', 'チェックする', '達成する',
  '最終更新日', '前回日', '実施日',
  '経過時間', '日数差', 'インターバル',
  '未完了', '未着手', '0日前',
  '推奨間隔', 'サイクル', '周期',
];

/// 画面に描画されている文字列をすべて集める。
List<String> _renderedTexts(WidgetTester tester) { /* RenderParagraph を辿る */ }

/// 「最終実施日」は正しい用語なので、「実施日」の検査前に取り除く。
String _stripAllowed(String text) => text.replaceAll('最終実施日', '');
```

検査対象(それぞれ描画してから `_renderedTexts` を集め、`_stripAllowed` を通してから
`_bannedTerms` のいずれも含まないことを検証する):

1. 一覧(項目あり)
2. 一覧(空状態)
3. 登録画面
4. 編集画面
5. 削除確認ダイアログ(編集画面で「削除」をタップした状態)

加えて、読み上げ文も同じ検査に通す(文字列を直接組み立てて確かめる):

```dart
test('読み上げラベルが表記ゆれの禁止一覧に違反しない', () {
  final labels = [
    itemRowSemanticsLabel(/* 未実施 */),
    itemRowSemanticsLabel(/* 4日前 */),
    doneButtonSemanticsLabel('美容院'),
  ];
  // 各ラベルを _stripAllowed に通してから _bannedTerms を含まないことを検証する
});
```

### 9.4 既存テストの扱い

- `DoneButton` を直接組み立てているテストは無い(`find.byType` のみ)。**既存テストの修正は原則不要。**
- もし既存テストが落ちたら、**落ちた原因をこのファイルの判断と突き合わせてから直す。**
  レイアウト変更が理由で期待値がずれた場合は期待値を直してよい。
  **「テストを消す」「`skip` する」は禁止。**

## 10. `docs/development-guidelines.md` への追記

「テスト戦略」節の末尾(`## コードレビュー基準` の直前)に
`## パフォーマンス計測手順(実機)` を追加する。書く内容:

- **devcontainer では測れない。** Android 端末・エミュレータ・`adb` が無く、
  検出されるのは Linux desktop だけ。**リリースビルドで測るのが前提**(デバッグビルドは遅い)
- 測る 4 項目と基準(`docs/product-requirements.md`「非機能要件 / パフォーマンス」より):
  コールドスタート → 一覧表示 1.5 秒以内 / 「やった」→ 画面反映 100ms 以内 /
  100 件のスクロールでフレーム落ちなし / 100 件の初回描画 300ms 以内
- 手順: ミドルレンジ Android 実機を USB 接続 → `flutter build apk --release` →
  `flutter run --release --trace-startup` で起動時間、DevTools のタイムラインで
  フレーム時間を見る。項目 20 件 / 100 件の 2 条件で測る
- **結果は PR ボディに計測環境(端末名 / OS バージョン / ビルド種別)とともに記載する**
- devcontainer で回せる代替は `test/ui/performance_test.dart`(遅延生成・クエリ本数・参考時間)で、
  **実機基準の代わりにはならない**

## 11. やらないこと(念押し)

- 色・シード色・テーマの変更(AA を満たしているので触らない)
- `lib/domain/` / `lib/data/` / `lib/state/` の変更
- `pubspec.yaml` への依存追加
- 新機能・P1 の前倒し(不足が見つかったら実装せず、司令塔へ報告する)
- 実機計測(判断9)
