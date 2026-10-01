import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/done_link.dart';
import '../../state/item_view.dart';

/// NFC タグに書き込むリンクを見せる(F32 / design.md 判断10)。書き込みは市販の NFC アプリに任せる。
Future<void> showNfcTagDialog(BuildContext context, ItemView item) {
  final link = doneLinkFor(item.id).toString();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: const Text('NFC タグに登録'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NFC タグ書き込みアプリで、次のリンクを URL としてタグに書き込んでください。'
                'タグにスマホをかざすと「${item.name}」を記録します(Android のみ)。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SelectableText(link, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('リンクをコピーしました')));
            },
            child: const Text('コピー'),
          ),
        ],
      );
    },
  );
}
