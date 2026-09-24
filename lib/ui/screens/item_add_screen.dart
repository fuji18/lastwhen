import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item_icon.dart';
import '../../domain/item_name.dart';
import '../../state/add_item_result.dart';
import '../../state/item_list_notifier.dart';
import '../item_name_error_text.dart';
import '../widgets/item_icon_picker.dart';

/// 項目の登録画面。**必須の入力は項目名 1 つだけ**(F2)。アイコン(F14)は任意で、選ばなければ
/// 既定アイコンになる。必須の入力を増やすと「30 秒以内に登録できる」という成功指標と衝突する。
class ItemAddScreen extends ConsumerStatefulWidget {
  /// 登録画面を作る。
  const ItemAddScreen({super.key});

  @override
  ConsumerState<ItemAddScreen> createState() => _ItemAddScreenState();
}

class _ItemAddScreenState extends ConsumerState<ItemAddScreen> {
  final TextEditingController _controller = TextEditingController();

  /// 入力欄に出す理由。null なら正常。
  String? _errorText;

  /// 保存中は二度押しを塞ぐ(判断7)。
  bool _isSaving = false;

  /// 選択中のアイコン。null は未選択(既定アイコンになる)。
  ItemIcon? _icon;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目を追加'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'キャンセル',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            // スクロールビューの中では高さが無限になるので min を明示する。
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                // 開いた瞬間に入力できる = タップが 1 つ減る(受け入れ条件)。
                autofocus: true,
                // 51 文字目を打てなくする。後から弾くより分かりやすい(Issue #6 技術メモ)。
                // ドメイン側の検証は消さない(判断3)。
                maxLength: maxItemNameLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '項目名',
                  hintText: '例: 美容院',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                onChanged: _handleChanged,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              ItemIconPicker(
                selected: _icon,
                onChanged: (value) => setState(() => _icon = value),
                enabled: !_isSaving,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 入力し直したら、前回の理由を消す。直せたのに赤いままにしない。
  void _handleChanged(String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final result = await ref
        .read(itemListProvider.notifier)
        .addItem(_controller.text, icon: _icon);
    if (!mounted) {
      return;
    }
    switch (result) {
      // 保存の完了を待ってから戻る(楽観的 UI 更新を採らない)。
      case AddItemSucceeded():
        Navigator.of(context).pop();
      // 画面を閉じない。入力もそのまま残す(受け入れ条件)。
      case AddItemRejected(:final reason):
        setState(() {
          _isSaving = false;
          _errorText = itemNameErrorText(reason);
        });
      case AddItemFailed():
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
    }
  }
}
