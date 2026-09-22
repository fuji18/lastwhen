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
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
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
    DaysAgo(:final days) =>
      lastDoneText == null
          ? '${item.name}、$days日経過'
          : '${item.name}、最終実施日は$lastDoneText、$days日経過',
  };
}

/// 「やった」ボタンの読み上げ文。**どの項目のボタンかを含める**(design.md 判断6)。
String doneButtonSemanticsLabel(String itemName) => '$itemNameをやったと記録';
