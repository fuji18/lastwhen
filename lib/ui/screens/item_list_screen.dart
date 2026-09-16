import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_row.dart';

/// 一覧画面。**起動直後に出る唯一の画面**(`docs/functional-design.md`「画面遷移図」)。
class ItemListScreen extends ConsumerWidget {
  /// 一覧画面を作る。
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LastWhen')),
      body: SafeArea(
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: _handleAddPressed,
          ),
          AsyncData(:final value) => _ItemList(items: value),
          AsyncError() => _LoadError(
            onRetry: () => ref.invalidate(itemListProvider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// 新規登録への導線。
  ///
  /// **#6(項目の新規登録)で登録画面への遷移をここに入れる。** このチケットの
  /// スコープは導線の配置までで、遷移先の画面がまだ無い(判断12)。
  void _handleAddPressed() {}
}

/// 項目が 1 件以上あるときの一覧。
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<ItemView> items;

  @override
  Widget build(BuildContext context) {
    // 100 件で全行を同時に構築しない(`docs/functional-design.md`「パフォーマンス最適化」)。
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) => ItemRow(
        item: items[index],
        // #7(「やった」の記録)で `ItemListNotifier.markDone` に繋ぐ(判断12)。
        onDonePressed: () {},
      ),
    );
  }
}

/// 一覧そのものを読み込めなかったときの表示。
///
/// DB のオープン失敗・購読の切断がここに来る(`docs/functional-design.md`
/// 「エラーハンドリング」)。書き込みの失敗はここに来ない(#6 以降で `SnackBar` に出す)。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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
      ),
    );
  }
}
