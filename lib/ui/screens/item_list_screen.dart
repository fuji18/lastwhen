import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../domain/item_template.dart';
import '../../state/add_item_result.dart';
import '../../state/category_filter.dart';
import '../../state/category_list_notifier.dart';
import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../../state/item_sort_order.dart';
import '../item_navigation.dart';
import '../widgets/app_logo.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/centered_scrollable.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/item_sort_menu_button.dart';
import '../widgets/load_error.dart';
import 'item_add_screen.dart';

/// 一覧画面。**起動直後に出る画面**(ホーム)。図鑑とは下部ナビで切り替える(#34)。
class ItemListScreen extends ConsumerStatefulWidget {
  /// 一覧画面を作る。
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  /// 復帰で並びを確定し直す(F30)。記録では組み替えない。
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(itemListProvider.notifier).refreshOrder(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemListProvider);
    // 追加導線は空状態(EmptyState 側にボタンがある)と読み込み中・失敗では出さない(判断5)。
    final hasItems = switch (items) {
      AsyncData(:final value) => value.isNotEmpty,
      _ => false,
    };
    final categories = ref.watch(categoryListProvider).value ?? const [];
    final filter = resolveCategoryId(
      ref.watch(categoryFilterProvider),
      categories,
    );
    return Scaffold(
      appBar: AppBar(
        // 並び順のボタンと並べると、狭い画面では幅が足りなくなりうる。
        // ロゴはブランド表記なので、足りないときだけ縮める(判断H / #92)。
        title: const FittedBox(fit: BoxFit.scaleDown, child: AppLogo()),
        actions: [
          // 追加の FAB と同じ条件で出す。空状態・読み込み中・失敗では並べるものが無い。
          if (hasItems)
            ItemSortMenuButton(
              selected: ref.watch(itemSortOrderProvider),
              onSelected: (order) =>
                  ref.read(itemSortOrderProvider.notifier).select(order),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: () =>
                _openAddScreen(context, initialCategoryId: filter),
            onTemplatePressed: (template) =>
                _addTemplate(template, categoryId: filter),
          ),
          AsyncData(:final value) => _buildList(value, categories, filter),
          AsyncError() => LoadError(
            onRetry: () => ref.invalidate(itemListProvider),
          ),
          _ => const Center(
            child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
          ),
        },
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () =>
                  _openAddScreen(context, initialCategoryId: filter),
              tooltip: '項目を追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// よくある項目を確認なしで追加する(F17)。追加できたら true。
  ///
  /// カテゴリは「項目を追加」と同じく選択中の絞り込み(design.md 判断F)。
  Future<bool> _addTemplate(
    ItemTemplate template, {
    CategoryId? categoryId,
  }) async {
    final result = await ref
        .read(itemListProvider.notifier)
        .addItem(template.name, icon: template.icon, categoryId: categoryId);
    if (result is AddItemSucceeded) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
    }
    return false;
  }

  Widget _buildList(
    List<ItemView> value,
    List<Category> categories,
    CategoryId? filter,
  ) {
    final visible = filterByCategory(value, filter);
    return Column(
      children: [
        if (categories.isNotEmpty)
          CategoryFilterBar(
            categories: categories,
            selected: filter,
            onSelected: (id) =>
                ref.read(categoryFilterProvider.notifier).select(id),
          ),
        Expanded(
          child: visible.isEmpty
              ? const _FilteredEmpty()
              : _ItemList(items: visible),
        ),
      ],
    );
  }
}

/// 登録画面へ遷移する。
///
/// 名前付きルートを使わない(design.md 判断4)。画面は一覧・登録・編集などの画面だけで、
/// ディープリンクも扱わないため、ルート表を持つと二重管理になるだけ。
void _openAddScreen(BuildContext context, {CategoryId? initialCategoryId}) {
  // ScaffoldMessenger は Navigator の上にあり、閉じないと遷移後も導線が残る。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => ItemAddScreen(initialCategoryId: initialCategoryId),
    ),
  );
}

/// 項目が 1 件以上あるときの一覧。
class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<ItemView> items;

  @override
  Widget build(BuildContext context) {
    // 100 件で全行を同時に構築しない(`docs/functional-design.md`「パフォーマンス最適化」)。
    return ListView.builder(
      // FAB が最終行の「やった」ボタンに被らないようにする。56 + 16 × 2。
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemCard(
          item: item,
          onDonePressed: () => unawaited(markDoneWithUndo(context, item.id)),
          onTap: () => openItemDetailScreen(context, item.id),
        );
      },
    );
  }
}

/// 絞り込みの結果、表示する項目が 0 件になったときの表示。
class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Text(
        'このカテゴリの項目はありません',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}
