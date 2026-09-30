import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/backup.dart';
import '../../state/backup_service.dart';
import '../../state/category_filter.dart';
import '../app_info.dart';
import 'category_manage_screen.dart';

/// カテゴリ管理・バックアップ(書き出し / 復元)への入口と、保存に関する注意事項・
/// アプリ情報を表示する。
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
          const _SectionHeader('バックアップ'),
          const _BackupSection(),
          const Divider(),
          const _SectionHeader('注意事項'),
          const ListTile(
            leading: Icon(Icons.smartphone_outlined),
            title: Text('項目と記録は、この端末の中にだけ保存されます。アプリがインターネットへ送信することはありません。'),
          ),
          const ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text(
              'アプリを削除すると、項目と記録もすべて消えます。機種変更の前に「データを書き出す」で保存しておくと、復元できます。',
            ),
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

/// バックアップの書き出し・復元の 2 行(F26 / #68)。
class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  /// 書き出し中・復元中は 2 行とも塞ぐ(二重タップ防止)。
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        enabled: !_busy,
        leading: const Icon(Icons.upload_file_outlined),
        title: const Text('データを書き出す'),
        subtitle: const Text('項目・記録・カテゴリを 1 つのファイルにまとめて、保存先や送り先を選びます'),
        onTap: _export,
      ),
      ListTile(
        enabled: !_busy,
        leading: const Icon(Icons.settings_backup_restore),
        title: const Text('データを復元する'),
        subtitle: const Text('書き出したファイルから戻します。今のデータは置き換わります'),
        onTap: _restore,
      ),
    ],
  );

  Future<void> _export() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).export();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('書き出せませんでした')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restore() async {
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _busy = true);
    try {
      final preparation = await ref
          .read(backupServiceProvider)
          .prepareRestore();
      if (!mounted) {
        return;
      }
      switch (preparation) {
        case RestoreCanceled():
          return;
        case RestoreRejected(:final error):
          await _showErrorDialog(_rejectionMessageOf(error));
        case RestoreReadFailed():
          await _showErrorDialog('ファイルを読み込めませんでした。もう一度お試しください。');
        case RestoreReady(:final snapshot):
          await _confirmAndRestore(snapshot);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _confirmAndRestore(BackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データを復元しますか?'),
        content: Text(
          '今の項目と記録はすべて消え、選んだファイルの内容に置き換わります。元に戻せません。\n\n'
          'ファイルの内容: 項目 ${snapshot.items.length} 件・'
          '記録 ${snapshot.doneLogs.length} 件・'
          'カテゴリ ${snapshot.categories.length} 件',
        ),
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
            child: const Text('復元する'),
          ),
        ],
      ),
    );
    // バリアタップ・戻る操作は null。true 以外はすべて「復元しない」。
    if (!mounted || confirmed != true) {
      return;
    }
    try {
      await ref.read(backupServiceProvider).restore(snapshot);
    } catch (_) {
      if (mounted) {
        await _showErrorDialog('復元できませんでした。データは変わっていません。');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    ref.read(categoryFilterProvider.notifier).select(null);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('復元しました')));
  }

  Future<void> _showErrorDialog(String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('復元できません'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

/// 復元の検証エラーの本文。
String _rejectionMessageOf(BackupFormatError error) => switch (error) {
  BackupFormatError.notBackupFile => 'このアプリで書き出したファイルではありません。データは変わっていません。',
  BackupFormatError.newerVersion =>
    '新しいバージョンのアプリで書き出されたファイルです。アプリを更新してから復元してください。データは変わっていません。',
  BackupFormatError.invalidContent => 'ファイルの内容が壊れているため、復元できません。データは変わっていません。',
};

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
