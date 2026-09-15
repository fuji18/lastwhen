import 'package:flutter/material.dart';

import 'ui/theme/app_theme.dart';

/// `MaterialApp` の組み立て。
///
/// ルーティングは画面が増える #5 以降で足す。`themeMode` は既定の
/// [ThemeMode.system] に任せ、端末の設定に追従させる。
class App extends StatelessWidget {
  /// アプリのルートウィジェットを作る。
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LastWhen',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _PlaceholderHome(),
    );
  }
}

/// 一覧画面(#5)ができるまでの仮の画面。テーマだけが効いた空の画面を出す。
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
