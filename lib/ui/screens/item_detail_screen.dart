import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/aging_stage.dart';
import '../../domain/baseline_interval.dart';
import '../../domain/elapsed_days.dart';
import '../../domain/item.dart';
import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../item_icon_glyph.dart';
import '../item_navigation.dart';
import '../theme/app_theme.dart';
import '../widgets/aged_paper.dart';
import '../widgets/item_card.dart' show elapsedText;
import '../widgets/paper_background.dart';

/// 経年ステージの一言。断定や催促をしない。
String? agingStageHintText(AgingStage stage) => switch (stage) {
  AgingStage.fresh => null,
  AgingStage.slightlyAged => null,
  AgingStage.dueSoon => 'そろそろかも。',
  AgingStage.aged => 'いつもより間が空いているかも。',
  AgingStage.heavilyAged => 'だいぶ間が空いているかも。',
};

/// 「最後にやった日」の行の値。未実施なら記録がないことだけを示す。
String detailLastDoneText(ItemView item) {
  final lastDoneText = item.lastDoneText;
  if (item.elapsed is NeverDone || lastDoneText == null) {
    return 'まだ記録がありません';
  }
  return '$lastDoneText（${elapsedText(item.elapsed)}）';
}

/// 「平均の間隔」の行の値。基準間隔(記録 1 件以下は null)を四捨五入して示す。
String detailAverageIntervalText(double? baselineIntervalDays) =>
    baselineIntervalDays == null ? '学習中' : '${baselineIntervalDays.round()}日';

/// 「前回からの間隔」の行の値。未実施なら行ごと出さないので null。
String? detailSinceLastText(ElapsedLabel elapsed) => switch (elapsed) {
  NeverDone() => null,
  Today() => '0日',
  Yesterday() => '1日',
  DaysAgo(:final days) => '$days日',
};

/// 経年ステージが `aged` 以上(相対経過度 1.5 以上)なら「いつもより長め」を出す。
bool isLongerThanUsual(AgingStage stage) =>
    stage == AgingStage.aged || stage == AgingStage.heavilyAged;

/// 履歴 1 行の読み上げ文。間隔があれば添える。
String historyEntrySemanticsLabel(DoneHistoryEntry entry) {
  final intervalDays = entry.intervalDays;
  return intervalDays == null
      ? entry.dateText
      : '${entry.dateText}、前回から$intervalDays日';
}

/// 履歴 1 行の削除ボタンの読み上げ文(tooltip)。日付を含める。
String historyDeleteButtonLabel(DoneHistoryEntry entry) =>
    '${entry.dateText}の記録を削除';

/// 記録の詳細画面(F29)。カードのタップで一覧・図鑑から開く。
///
/// **最終実施日・平均の間隔・前回からの間隔・経年ステージの一言・記録の履歴**を示し、
/// 下部の「記録する」で確認なしに記録できる。右上のメニューから日付を指定して記録・編集へ進む。
/// 項目の削除の入口はここに置かない(編集画面の中だけ。F7)。
/// 記録の履歴の各行からは、その日の記録を削除できる(#63)。
class ItemDetailScreen extends ConsumerStatefulWidget {
  /// [itemId] の項目の詳細画面を作る。
  const ItemDetailScreen({required this.itemId, super.key});

  /// 表示対象の項目 ID。
  final ItemId itemId;

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _isRecording = false;

  /// 対象が一覧から消えたときに自分のルートを取り除いたら true。二重に取り除かない。
  bool _removed = false;

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemListProvider).value;
    final item = items?.where((v) => v.id == widget.itemId).firstOrNull;

    // 判断J: 表示中の項目が一覧から消えたら(編集画面での削除)、自分のルートを取り除く。
    // 編集画面の pop に相乗りしない(それだと編集画面と別のルートを閉じてしまう)。
    ref.listen(itemListProvider, (previous, next) {
      final nextItems = next.value;
      if (_removed || nextItems == null) {
        return;
      }
      if (nextItems.any((v) => v.id == widget.itemId)) {
        return;
      }
      _removed = true;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });

    // 判断K: この画面から戻るときも取り消し導線を閉じる。
    final messenger = ScaffoldMessenger.of(context);
    return PaperBackground(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            messenger.clearSnackBars();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('記録の詳細'),
            actions: item == null ? null : [_DetailMenuButton(item: item)],
          ),
          body: SafeArea(
            child: items == null
                ? const Center(
                    child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
                  )
                : item == null
                ? const SizedBox.shrink()
                : _DetailBody(item: item),
          ),
          bottomNavigationBar: item == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: _isRecording ? null : _record,
                      child: const Text('記録する'),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _record() async {
    setState(() => _isRecording = true);
    await markDoneWithUndo(context, widget.itemId);
    if (mounted) {
      setState(() => _isRecording = false);
    }
  }
}

/// 「…」メニューで選べる操作。
enum _DetailMenuAction { recordPastDate, edit }

/// 右上の「…」メニュー(判断G)。削除の入口は置かない(F7 は編集画面の中だけ)。
class _DetailMenuButton extends StatelessWidget {
  const _DetailMenuButton({required this.item});

  final ItemView item;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DetailMenuAction>(
      icon: const Icon(Icons.more_horiz),
      tooltip: 'その他の操作',
      onSelected: (action) {
        switch (action) {
          case _DetailMenuAction.recordPastDate:
            unawaited(recordPastDateWithUndo(context, item.id));
          case _DetailMenuAction.edit:
            openItemEditScreen(context, item);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _DetailMenuAction.recordPastDate,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_calendar_outlined),
            title: Text('日付を指定して記録'),
          ),
        ),
        PopupMenuItem(
          value: _DetailMenuAction.edit,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('編集'),
          ),
        ),
      ],
    );
  }
}

/// 本文(見出しのカード・情報の行・記録の履歴)。
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.item});

  final ItemView item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neverDone = item.elapsed is NeverDone;
    final sinceLastText = detailSinceLastText(item.elapsed);
    final hintText = neverDone ? null : agingStageHintText(item.agingStage);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderCard(item: item),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            label: '最後にやった日',
            value: detailLastDoneText(item),
          ),
          _InfoRow(
            icon: Icons.bar_chart,
            label: '平均の間隔',
            value: detailAverageIntervalText(item.baselineIntervalDays),
          ),
          if (sinceLastText != null)
            _InfoRow(
              icon: Icons.schedule,
              label: '前回からの間隔',
              value: sinceLastText,
              badge: isLongerThanUsual(item.agingStage) ? 'いつもより長め' : null,
            ),
          if (hintText != null)
            _InfoRow(icon: Icons.chat_bubble_outline, label: hintText),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              '記録の履歴',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (item.history.isEmpty)
            Text(
              'まだ記録がありません',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            for (final entry in item.history)
              _HistoryRow(itemId: item.id, entry: entry),
            if (item.historyTruncated) ...[
              const SizedBox(height: 8),
              Text(
                '直近$recentDoneAtsLimit件まで表示しています',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 見出しのカード。項目名とアイコンを、一覧・図鑑のカードと同じ紙の上に描く。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.item});

  final ItemView item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AgingPalette.of(context);
    return CustomPaint(
      painter: AgedPaperPainter(
        stage: item.agingStage,
        colors: palette.colorsOf(item.agingStage),
        seed: stableSeedOf(item.id.value),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                itemIconData(item.icon),
                size: 64,
                color: theme.colorScheme.onSurface.withValues(
                  alpha: agingIconOpacity(item.agingStage),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                item.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 情報 1 行。ラベルと値を縦に積む(横並びにしない。200% で右端がはみ出さないため)。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = this.value;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: value == null
                        ? theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                          )
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                  if (value != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(height: 4),
                    _Badge(text: badge!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「いつもより長め」などの小さなバッジ。
class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// 記録の履歴 1 行。
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.itemId, required this.entry});

  final ItemId itemId;

  final DoneHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intervalDays = entry.intervalDays;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: historyEntrySemanticsLabel(entry),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.dateText,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (intervalDays != null)
                    Text(
                      '$intervalDays日',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () =>
              unawaited(deleteHistoryDayWithUndo(context, itemId, entry)),
          tooltip: historyDeleteButtonLabel(entry),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
