import 'package:flutter/material.dart';

import 'collection_screen.dart';
import 'item_list_screen.dart';

/// 下部ナビで一覧(ホーム)と図鑑を切り替える外枠(F31)。起動直後は必ずホーム。
///
/// **`Scaffold` にしない。** 外枠を `Scaffold` にすると内側の各画面の `Scaffold` が
/// 「入れ子」扱いになり、`SnackBar` が外枠にだけ出て一覧の FAB と重なる。
/// 各画面の `Scaffold` をルートのまま保ち、ナビは `Column` の下段に置く。
///
/// 図鑑側は専用の `ScaffoldMessenger` で包む。包まないと図鑑の `Scaffold` もアプリの
/// `ScaffoldMessenger` に root として登録され、一覧の取り消し導線がオフステージの図鑑にも
/// 複製される。同じ内容の `SnackBar` が 2 つ載ると Hero タグが衝突し、記録直後の画面遷移で
/// 例外になる(#34 判断9)。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // キーボード表示中(図鑑の検索)はナビを隠す。残すと入力欄とキーボードの間にナビ分の隙間が空く。
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      children: [
        Expanded(
          // 下端の安全領域はナビ(または非表示時は各画面)が引き受ける。
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: !keyboardVisible,
            child: IndexedStack(
              index: _index,
              children: const [
                ItemListScreen(),
                // 図鑑の Scaffold をアプリの ScaffoldMessenger に登録させない。登録されると
                // 一覧の取り消し導線がオフステージの図鑑にも複製され、同じ Hero タグの
                // SnackBar が 2 つ載って遷移時に衝突する(#34 判断9)。
                ScaffoldMessenger(child: CollectionScreen()),
              ],
            ),
          ),
        ),
        if (!keyboardVisible)
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'ホーム',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: '図鑑',
              ),
            ],
          ),
      ],
    );
  }

  void _select(int index) {
    if (index == _index) {
      return;
    }
    // 画面遷移と同じく取り消し導線を閉じる(`docs/functional-design.md`「状態ごとの表示」)。
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _index = index);
  }
}
