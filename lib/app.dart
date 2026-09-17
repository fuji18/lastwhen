import 'package:flutter/material.dart';

import 'ui/screens/item_list_screen.dart';
import 'ui/theme/app_theme.dart';

/// `MaterialApp` の組み立て。
///
/// 通常操作の画面は一覧・登録・編集の 3 つだけで、起動直後は必ず一覧に出る
/// (`docs/functional-design.md`「画面遷移図」)。遷移は `Navigator.push` で直接積み、
/// 名前付きルートは使わない(#6 design.md 判断4)。
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
      home: const ItemListScreen(),
    );
  }
}
