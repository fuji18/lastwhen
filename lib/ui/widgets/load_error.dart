import 'package:flutter/material.dart';

import 'centered_scrollable.dart';

/// 一覧そのものを読み込めなかったときの表示。
///
/// DB のオープン失敗・購読の切断がここに来る(`docs/functional-design.md`
/// 「エラーハンドリング」)。書き込みの失敗はここに来ない(`SnackBar` に出す)。
/// 一覧と図鑑の両方から使うため、画面から切り出した(#34)。
class LoadError extends StatelessWidget {
  const LoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'データを読み込めませんでした',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}
