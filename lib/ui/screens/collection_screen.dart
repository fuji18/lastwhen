import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../state/category_filter.dart';
import '../../state/category_list_notifier.dart';
import '../../state/collection.dart';
import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../item_navigation.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/centered_scrollable.dart';
import '../widgets/collection_card.dart';
import '../widgets/load_error.dart';

/// 図鑑画面。1 回以上記録した項目のカードをグリッドで並べる(F31)。
///
/// 記録の入口・項目の追加導線は置かない。カードのタップで詳細シートを開く。
class CollectionScreen extends ConsumerStatefulWidget {
  /// 図鑑画面を作る。
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  bool _searching = false;
  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    _queryController.clear();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(collectionItemsProvider);
    final categories = ref.watch(categoryListProvider).value ?? const [];
    final filter = resolveCategoryId(
      ref.watch(collectionCategoryFilterProvider),
      categories,
    );
    return PopScope(
      // 検索中はシステムの戻るで検索を閉じる(アプリを終了させない)。
      // 図鑑は HomeShell の IndexedStack に常駐するため、タブが見えていないときは
      // 戻るを横取りしない(Visibility.of は非選択のタブで false を返す)。
      canPop: !(_searching && Visibility.of(context)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeSearch();
        }
      },
      child: Scaffold(
        appBar: _searching
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '検索を閉じる',
                  onPressed: _closeSearch,
                ),
                title: TextField(
                  controller: _queryController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: '項目名で検索',
                    border: InputBorder.none,
                  ),
                ),
              )
            : AppBar(
                title: const Text('図鑑'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: '検索',
                    onPressed: _openSearch,
                  ),
                ],
              ),
        body: SafeArea(
          child: switch (items) {
            AsyncData(:final value) => _buildCollection(
              value,
              categories,
              filter,
            ),
            AsyncError() => LoadError(
              onRetry: () => ref.invalidate(itemListProvider),
            ),
            _ => const Center(
              child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildCollection(
    List<ItemView> value,
    List<Category> categories,
    CategoryId? filter,
  ) {
    final recorded = collectionOf(value);
    if (recorded.isEmpty) {
      return const _CollectionEmpty();
    }
    final visible = collectionOf(
      value,
      category: filter,
      query: _queryController.text,
    );
    return Column(
      children: [
        if (categories.isNotEmpty)
          CategoryFilterBar(
            categories: categories,
            selected: filter,
            onSelected: (id) =>
                ref.read(collectionCategoryFilterProvider.notifier).select(id),
          ),
        Expanded(
          child: visible.isEmpty
              ? const _CollectionFilteredEmpty()
              : _CollectionGrid(items: visible),
        ),
      ],
    );
  }
}

/// 図鑑に記録済みの項目が 1 件も無いときの表示。
class _CollectionEmpty extends StatelessWidget {
  const _CollectionEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'まだ図鑑にカードがありません',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '「やった」を記録した項目がここに並びます',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 絞り込みの結果、表示する項目が 0 件になったときの表示。
class _CollectionFilteredEmpty extends StatelessWidget {
  const _CollectionFilteredEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Text(
        '条件に合う項目はありません',
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// 図鑑のカードをグリッドで並べる。
class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({required this.items});

  final List<ItemView> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: collectionColumnCount(textScaler),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: collectionCardExtent(theme.textTheme, textScaler),
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return CollectionCard(
          item: item,
          onTap: () => unawaited(openItemDetailSheet(context, item)),
        );
      },
    );
  }
}
