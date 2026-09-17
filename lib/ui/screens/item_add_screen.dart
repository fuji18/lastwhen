import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item_name.dart';
import '../../state/add_item_result.dart';
import '../../state/item_list_notifier.dart';

/// 項目の登録画面。**入力は項目名 1 つだけ**(`docs/product-requirements.md` F2)。
///
/// カテゴリ・アイコン・目安期間は P1。ここで入力項目を増やすと
/// 「30 秒以内に登録できる」という成功指標と正面から衝突する。
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
        .addItem(_controller.text);
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

/// 検証に落ちた理由を入力欄の文言へ変換する。
///
/// 文言は `docs/functional-design.md`「エラーの分類」が正。
/// **文字列への変換は UI 層の責務**(`elapsedText` と同じ置き方)。
String itemNameErrorText(ItemNameReason reason) => switch (reason) {
  ItemNameReason.empty => '項目名を入力してください',
  ItemNameReason.tooLong => '$maxItemNameLength文字以内で入力してください',
};
