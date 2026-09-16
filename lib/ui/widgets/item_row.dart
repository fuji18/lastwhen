import 'package:flutter/material.dart';

import '../../domain/elapsed_days.dart';
import '../../state/item_view.dart';
import 'done_button.dart';

/// 一覧の 1 行。**このアプリで最も重要なコンポーネント。**
///
/// 左に「項目名 + 最後にやった日」、右寄りに「経過日数」、右端に「やった」ボタンを置く
/// (`docs/functional-design.md`「UI設計」)。**経過日数が行内で最大・最も太い。**
/// ボタンを右端に置くのは片手操作で親指が届く範囲だから。
class ItemRow extends StatelessWidget {
  /// 1 行を作る。
  const ItemRow({required this.item, required this.onDonePressed, super.key});

  /// 表示する項目。
  final ItemView item;

  /// 「やった」ボタンのタップ時の処理。
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastDoneText = item.lastDoneText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Flexible にして、文字サイズを上げても横にはみ出さないようにする。
          Flexible(
            flex: 2,
            child: Text(
              elapsedText(item.elapsed),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 行内で最大・最も太い。**強調はサイズとウェイトだけで作り、色を使わない**
              // (MVP は状態を色で分けない。`docs/functional-design.md`「色の使い方」)。
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          DoneButton(onPressed: onDonePressed),
        ],
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
