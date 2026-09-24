import 'package:flutter/material.dart';

import '../../domain/item_icon.dart';
import '../item_icon_glyph.dart';

/// 「指定なし」の選択肢の日本語名。
const String noItemIconLabel = '指定なし';

/// アイコンの選択欄。先頭が「指定なし」(null)、以降は `ItemIcon.values` の順。
class ItemIconPicker extends StatelessWidget {
  /// ピッカーを作る。
  const ItemIconPicker({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  /// 選択中のアイコン。null は「指定なし」。
  final ItemIcon? selected;

  /// 選択が変わったときの処理。
  final ValueChanged<ItemIcon?> onChanged;

  /// 保存中は false(タップを塞ぐ)。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('アイコン', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _IconTile(
              value: null,
              label: noItemIconLabel,
              iconData: defaultItemIconData,
              selected: selected == null,
              enabled: enabled,
              onChanged: onChanged,
            ),
            for (final value in ItemIcon.values)
              _IconTile(
                value: value,
                label: itemIconLabel(value),
                iconData: itemIconData(value),
                selected: selected == value,
                enabled: enabled,
                onChanged: onChanged,
              ),
          ],
        ),
      ],
    );
  }
}

/// 1 つのアイコン選択肢。
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.value,
    required this.label,
    required this.iconData,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final ItemIcon? value;
  final String label;
  final IconData iconData;
  final bool selected;
  final bool enabled;
  final ValueChanged<ItemIcon?> onChanged;

  @override
  Widget build(BuildContext context) {
    // IconButton は M3 で isSelected を Semantics(selected: ...) として出し、
    // tooltip が読み上げラベルになる。自前で Semantics を足さない(判断10)。
    return IconButton.outlined(
      isSelected: selected,
      onPressed: enabled ? () => onChanged(value) : null,
      tooltip: label,
      icon: Icon(iconData),
    );
  }
}
