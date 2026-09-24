import 'package:flutter/material.dart';

import '../../domain/category_name.dart';

/// 保存を試み、成功なら null、失敗なら入力欄に出す文言を返す。
typedef CategoryNameSubmit = Future<String?> Function(String rawName);

/// カテゴリ名を入力する `AlertDialog` を開く。
///
/// **検証エラーでは閉じずに理由を出す**必要があるため、保存処理を引数で受ける。
/// 保存に成功して閉じたら true、キャンセル・バリアタップなら false。
Future<bool> showCategoryNameDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialName = '',
  required CategoryNameSubmit onSubmit,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _CategoryNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initialName: initialName,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialName,
    required this.onSubmit,
  });

  final String title;
  final String confirmLabel;
  final String initialName;
  final CategoryNameSubmit onSubmit;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  /// 入力欄に出す理由。null なら正常。
  String? _errorText;

  /// 保存中はキャンセル・確定ボタンを両方塞ぐ。
  bool _isBusy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: maxCategoryNameLength,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: 'カテゴリ名', errorText: _errorText),
        onChanged: _handleChanged,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        TextButton(
          onPressed: _isBusy ? null : _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  /// 入力し直したら、前回の理由を消す。直せたのに赤いままにしない。
  void _handleChanged(String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final errorText = await widget.onSubmit(_controller.text);
    if (!mounted) {
      return;
    }
    if (errorText == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _isBusy = false;
      _errorText = errorText;
    });
  }
}
