import 'package:flutter/material.dart';

import '../../domain/aging_stage.dart';
import '../../domain/elapsed_days.dart';
import '../../state/item_view.dart';
import 'item_card.dart';

/// 最終実施からの経過日数。未実施は日数と区別する。
String detailLastDoneLine(ElapsedLabel elapsed) => switch (elapsed) {
  NeverDone() => 'まだ記録がありません',
  _ => '最後：${elapsedText(elapsed)}',
};

/// 前回間隔がない場合は行ごと非表示にする。
String? detailPreviousIntervalLine(int? previousIntervalDays) =>
    previousIntervalDays == null ? null : '前回：$previousIntervalDays日間隔';

/// 経年ステージの一言。断定や催促をしない。
String? agingStageHintText(AgingStage stage) => switch (stage) {
  AgingStage.fresh => null,
  AgingStage.slightlyAged => null,
  AgingStage.dueSoon => 'そろそろかも。',
  AgingStage.aged => 'いつもより間が空いているかも。',
  AgingStage.heavilyAged => 'だいぶ間が空いているかも。',
};

/// 開いた時点の項目を最大3行で示し、編集への入口を提供する。
class ItemDetailSheet extends StatelessWidget {
  /// 詳細シートを作る。
  const ItemDetailSheet({
    required this.item,
    required this.onEditPressed,
    super.key,
  });

  /// 開いた時点の表示モデル。
  final ItemView item;

  /// 「編集」ボタンのタップ時の処理。
  final VoidCallback onEditPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      detailLastDoneLine(item.elapsed),
      if (item.elapsed is! NeverDone) ...[
        ?detailPreviousIntervalLine(item.previousIntervalDays),
        ?agingStageHintText(item.agingStage),
      ],
    ];
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                item.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final (index, line) in lines.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              Text(
                line,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onEditPressed,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('編集'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
