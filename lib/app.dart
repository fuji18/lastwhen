import 'package:flutter/material.dart';

import 'ui/screens/home_shell.dart';
import 'ui/theme/app_theme.dart';

/// `MaterialApp` の組み立て。
///
/// 起動直後は必ず一覧(ホーム)に出る。一覧と図鑑は下部ナビで切り替える(#34)。
/// 遷移は `Navigator.push` で直接積み、名前付きルートは使わない(#6 design.md 判断4)。
/// `themeMode` は既定の [ThemeMode.system] に任せ、端末の設定に追従させる。
class App extends StatelessWidget {
  /// アプリのルートウィジェットを作る。
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastWhen',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
