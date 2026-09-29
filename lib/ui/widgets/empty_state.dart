import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/item_template.dart';
import 'centered_scrollable.dart';
import 'item_template_chips.dart';

/// 項目が 0 件のときの表示。
///
/// **空状態そのものを新規登録への導線にする**(`docs/ui-design-guidelines.md` §7
/// 「状態の表現」)。何も無い画面を見せて終わらせない。
/// よくある項目(F17)を 1 タップで追加できる。確認は出さない。
class EmptyState extends StatefulWidget {
  /// 空状態を作る。[onAddPressed] は新規登録への導線。
  const EmptyState({
    required this.onAddPressed,
    required this.onTemplatePressed,
    super.key,
  });

  /// 新規登録への導線が押されたときの処理。
  final VoidCallback onAddPressed;

  /// よくある項目を追加する。true を返したら塞いだままにする(判断D)。
  final Future<bool> Function(ItemTemplate) onTemplatePressed;

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> {
  /// 追加中は全チップを塞ぐ。成功したら塞いだまま、一覧の再送出で空状態ごと消える(design.md 判断D)。
  bool _isAdding = false;

  Future<void> _addTemplate(ItemTemplate template) async {
    // 再描画の前に 2 回目のタップが届いても二重登録しない(判断E)。
    if (_isAdding) {
      return;
    }
    setState(() => _isAdding = true);
    final added = await widget.onTemplatePressed(template);
    if (!mounted || added) {
      return;
    }
    setState(() => _isAdding = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'まだ項目がありません',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '「最後にやったのはいつ?」を知りたいことを登録します',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: widget.onAddPressed,
            icon: const Icon(Icons.add),
            label: const Text('項目を追加'),
          ),
          const SizedBox(height: 32),
          Text(
            'よくある項目からすぐ追加',
            style: theme.textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ItemTemplateChips(
            templates: itemTemplates,
            alignment: WrapAlignment.center,
            enabled: !_isAdding,
            tooltipBuilder: (template) => '${template.name}を追加',
            onPressed: (template) => unawaited(_addTemplate(template)),
          ),
        ],
      ),
    );
  }
}
