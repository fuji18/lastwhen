import 'package:flutter/material.dart';

/// 項目が 0 件のときの表示。
///
/// **空状態そのものを新規登録への導線にする**(`docs/ui-design-guidelines.md` §7
/// 「状態の表現」)。何も無い画面を見せて終わらせない。
class EmptyState extends StatelessWidget {
  /// 空状態を作る。[onAddPressed] は新規登録への導線。
  const EmptyState({required this.onAddPressed, super.key});

  /// 新規登録への導線が押されたときの処理。
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
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
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('項目を追加'),
            ),
          ],
        ),
      ),
    );
  }
}
