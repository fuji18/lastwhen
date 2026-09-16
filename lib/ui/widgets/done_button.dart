import 'package:flutter/material.dart';

/// 「やった」ボタンの最小辺(dp)。
///
/// Material の既定タップ領域は 48dp だが、このアプリは**片手・1 タップ**が中心価値なので
/// 自前で 56dp を指定する(`docs/ui-design-guidelines.md` §7「タッチターゲット」)。
const double doneButtonMinSize = 56;

/// 記録(「やった」)のボタン。
///
/// ラベルは「やった」で固定する(`docs/glossary.md`「表記ゆれの禁止一覧」)。
/// **押したときの動作は呼び出し元が決める。**
class DoneButton extends StatelessWidget {
  /// ボタンを作る。[onPressed] はタップ時の処理。
  const DoneButton({required this.onPressed, super.key});

  /// タップ時の処理。
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(doneButtonMinSize, doneButtonMinSize),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 既定の `padded` だと「見た目 40dp + 透明パディング」になり、
        // ウィジェットの実寸が 56dp を表さなくなる(判断10)。
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text('やった'),
    );
  }
}
