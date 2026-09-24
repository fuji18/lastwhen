import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../state/category_list_notifier.dart';
import '../../state/category_results.dart';
import '../category_name_error_text.dart';
import '../widgets/category_name_dialog.dart';
import '../widgets/centered_scrollable.dart';

/// カテゴリの管理画面。カテゴリの追加・名前変更・削除を行う唯一の入口(F13)。
class CategoryManageScreen extends ConsumerWidget {
  /// 管理画面を作る。
  const CategoryManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリを管理')),
      body: SafeArea(
        child: switch (categories) {
          AsyncData(:final value) when value.isEmpty => const _EmptyList(),
          AsyncData(:final value) => _CategoryList(categories: value),
          AsyncError() => const _LoadError(),
          _ => const Center(
            child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
          ),
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddDialog(context, ref),
        tooltip: 'カテゴリを追加',
        child: const Icon(Icons.add),
      ),
    );
  }
}

Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
  await showCategoryNameDialog(
    context,
    title: 'カテゴリを追加',
    confirmLabel: '追加',
    onSubmit: (rawName) => _submitAdd(ref, rawName),
  );
}

Future<String?> _submitAdd(WidgetRef ref, String rawName) async {
  final result = await ref
      .read(categoryListProvider.notifier)
      .addCategory(rawName);
  switch (result) {
    case AddCategorySucceeded():
      return null;
    case AddCategoryRejected(:final reason):
      return categoryNameErrorText(reason);
    case AddCategoryFailed():
      return '保存できませんでした。もう一度お試しください';
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Text('カテゴリはありません', style: theme.textTheme.bodyLarge),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Text('データを読み込めませんでした', style: theme.textTheme.bodyLarge),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return ListTile(
          title: Text(category.name),
          onTap: () => _openRenameDialog(context, ref, category),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '「${category.name}」を削除',
            onPressed: () => _delete(context, ref, category),
          ),
        );
      },
    );
  }
}

Future<void> _openRenameDialog(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  await showCategoryNameDialog(
    context,
    title: 'カテゴリ名を変更',
    confirmLabel: '保存',
    initialName: category.name,
    onSubmit: (rawName) => _submitRename(ref, category.id, rawName),
  );
}

Future<String?> _submitRename(
  WidgetRef ref,
  CategoryId id,
  String rawName,
) async {
  final result = await ref
      .read(categoryListProvider.notifier)
      .renameCategory(id, rawName);
  switch (result) {
    case RenameCategorySucceeded():
    case RenameCategoryIgnored():
      return null;
    case RenameCategoryRejected(:final reason):
      return categoryNameErrorText(reason);
    case RenameCategoryFailed():
      return '保存できませんでした。もう一度お試しください';
  }
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref,
  Category category,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('カテゴリを削除しますか?'),
      content: Text('「${category.name}」を削除します。このカテゴリの項目は未分類になります。項目と記録は消えません。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('削除'),
        ),
      ],
    ),
  );
  // バリアタップ・戻る操作は null。true 以外はすべて「削除しない」。
  if (!context.mounted || confirmed != true) {
    return;
  }
  final result = await ref
      .read(categoryListProvider.notifier)
      .deleteCategory(category.id);
  if (result is DeleteCategoryFailed && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('削除できませんでした。もう一度お試しください')));
  }
}
