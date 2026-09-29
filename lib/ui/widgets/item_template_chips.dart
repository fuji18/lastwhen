import 'package:flutter/material.dart';

import '../../domain/item_template.dart';
import '../item_icon_glyph.dart';

/// よくある項目(F17)のチップ列。
class ItemTemplateChips extends StatelessWidget {
  /// チップ列を作る。
  const ItemTemplateChips({
    required this.templates,
    required this.onPressed,
    required this.tooltipBuilder,
    this.enabled = true,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  /// 並べるよくある項目。この順に並ぶ。
  final List<ItemTemplate> templates;

  /// チップが押されたときの処理。
  final ValueChanged<ItemTemplate> onPressed;

  /// チップのツールチップ(読み上げにも使われる)。押すと何が起きるかを書く。
  final String Function(ItemTemplate) tooltipBuilder;

  /// false なら全チップを塞ぐ(追加中・保存中)。
  final bool enabled;

  /// 行内の寄せ方。
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final template in templates)
          ActionChip(
            avatar: Icon(itemIconData(template.icon)),
            label: Text(template.name),
            tooltip: tooltipBuilder(template),
            onPressed: enabled ? () => onPressed(template) : null,
          ),
      ],
    );
  }
}
