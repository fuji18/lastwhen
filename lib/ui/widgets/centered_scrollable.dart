import 'package:flutter/material.dart';

/// 中央寄せのまま、縦に入り切らないときだけスクロールできるようにする箱。
///
/// 文字サイズ 200% では空状態・エラー表示が画面の高さを超える。`Center` だけだと
/// はみ出した分に触れられず、`SingleChildScrollView` だけだと中央寄せが崩れる
/// (design.md 判断8)。
class CenteredScrollable extends StatelessWidget {
  /// 中身を中央に置く箱を作る。
  const CenteredScrollable({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  /// 中央に置く中身。
  final Widget child;

  /// 中身の周りの余白。
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
