import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_info.dart';
import 'category_manage_screen.dart';

/// カテゴリ管理への入口と、保存に関する注意事項・アプリ情報を表示する。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('設定')),
    body: SafeArea(
      child: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('カテゴリの管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).clearSnackBars();
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const CategoryManageScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const _SectionHeader('注意事項'),
          const ListTile(
            leading: Icon(Icons.smartphone_outlined),
            title: Text('項目と記録は、この端末の中にだけ保存されます。アプリがインターネットへ送信することはありません。'),
          ),
          const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('アプリを削除すると、項目と記録もすべて消えます。'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text(
              '端末のバックアップ(Android の自動バックアップなど)が有効な場合は、機種変更で引き継げるように、項目と記録の複製が OS の提供元のクラウドに保存されます。',
            ),
          ),
          const Divider(),
          const _SectionHeader('このアプリについて'),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('プライバシーポリシー'),
            subtitle: const Text(AppInfo.privacyPolicyUrl),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'URL をコピー',
              onPressed: () => _copyPrivacyPolicyUrl(context),
            ),
            onTap: () => _copyPrivacyPolicyUrl(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('バージョン'),
            subtitle: Text(AppInfo.versionName),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('ライセンス'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: AppInfo.name,
              applicationVersion: AppInfo.versionName,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 設定画面の区切りの見出し。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// プライバシーポリシーの URL をクリップボードへ写し、結果を知らせる。
Future<void> _copyPrivacyPolicyUrl(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: AppInfo.privacyPolicyUrl));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('URL をコピーしました')));
}
