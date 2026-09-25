import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../state/category_filter.dart';
import '../../state/category_list_notifier.dart';
import '../../state/category_results.dart';
import '../category_name_error_text.dart';
import 'category_name_dialog.dart';

/// 「未分類」の選択肢の日本語名。
const String uncategorizedLabel = '未分類';

/// 登録・編集画面のカテゴリ選択欄。先頭が「未分類」(null)、以降は [CategoryListNotifier] の
/// 一覧の順、末尾に「カテゴリを追加」。
class ItemCategoryPicker extends ConsumerWidget {
  /// ピッカーを作る。
  const ItemCategoryPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// 選択中のカテゴリ。null は未分類。
  final CategoryId? selected;

  /// 選択が変わったときの処理。
  final ValueChanged<CategoryId?> onChanged;

  /// 保存中は false(タップを塞ぐ)。
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loaded = ref.watch(categoryListProvider).value;
    // 読み込み中・失敗でも「未分類」と追加チップは出す。
    final categories = loaded ?? const <Category>[];
    // 一覧が無いときは存在を判定できない。選択を「未分類」に見せない。
    final effectiveSelected = loaded == null
        ? selected
        : resolveCategoryId(selected, loaded);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('カテゴリ', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text(uncategorizedLabel),
              selected: effectiveSelected == null,
              onSelected: enabled ? (_) => onChanged(null) : null,
            ),
            for (final category in categories)
              ChoiceChip(
                label: Text(category.name),
                selected: effectiveSelected == category.id,
                onSelected: enabled ? (_) => onChanged(category.id) : null,
              ),
            ActionChip(
              avatar: const Icon(Icons.add),
              label: const Text('カテゴリを追加'),
              onPressed: enabled ? () => _openAddDialog(context, ref) : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    CategoryId? addedId;
    final closed = await showCategoryNameDialog(
      context,
      title: 'カテゴリを追加',
      confirmLabel: '追加',
      onSubmit: (rawName) async {
        final result = await ref
            .read(categoryListProvider.notifier)
            .addCategory(rawName);
        switch (result) {
          case AddCategorySucceeded(:final category):
            addedId = category.id;
            return null;
          case AddCategoryRejected(:final reason):
            return categoryNameErrorText(reason);
          case AddCategoryFailed():
            return '保存できませんでした。もう一度お試しください';
        }
      },
    );
    if (closed && context.mounted) {
      final id = addedId;
      if (id != null) {
        onChanged(id);
      }
    }
  }
}
