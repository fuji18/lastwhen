import 'package:flutter/material.dart';

import '../../domain/category.dart';

/// 「すべて」の選択肢の日本語名。
const String allCategoriesLabel = 'すべて';

/// 一覧上部の絞り込みチップ列(F13)。先頭が「すべて」(null)、以降は [categories] の順。
///
/// 図鑑(#34)でも使い回す想定で、**provider を読まない**(値とコールバックだけを受ける)。
class CategoryFilterBar extends StatelessWidget {
  /// 絞り込みチップ列を作る。
  const CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// 表示するカテゴリ一覧。
  final List<Category> categories;

  /// 選択中のカテゴリ。null は「すべて」。呼び出し側で `resolveCategoryId` 済みの値。
  final CategoryId? selected;

  /// 選択が変わったときの処理。
  final ValueChanged<CategoryId?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text(allCategoriesLabel),
            selected: selected == null,
            // 選択済みのチップを押しても選択を外さない(bool 引数は無視して同じ値を渡す)。
            onSelected: (_) => onSelected(null),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(category.name),
              selected: selected == category.id,
              onSelected: (_) => onSelected(category.id),
            ),
          ],
        ],
      ),
    );
  }
}
