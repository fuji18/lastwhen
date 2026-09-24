import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../domain/item.dart';
import '../../domain/item_icon.dart';
import '../../domain/item_name.dart';
import '../../state/category_filter.dart';
import '../../state/category_list_notifier.dart';
import '../../state/edit_item_result.dart';
import '../../state/item_list_notifier.dart';
import '../item_name_error_text.dart';
import '../widgets/item_category_picker.dart';
import '../widgets/item_icon_picker.dart';

/// 項目の編集画面。**変更できるのは項目名・アイコン・カテゴリ(F6 / F14 / F13)**。
///
/// 最終実施日の手動修正は P1(F16)。ここに足さない。
/// **削除の唯一の入口**でもある(F7。一覧にスワイプ削除を置かない)。
class ItemEditScreen extends ConsumerStatefulWidget {
  /// [itemId] の項目を編集する画面を作る。[initialName] は入力欄の初期値。
  /// [initialIcon] は開いた時点のアイコン(保存済みの値)。[initialCategoryId] は
  /// 開いた時点のカテゴリ(保存済みの値)。
  const ItemEditScreen({
    required this.itemId,
    required this.initialName,
    this.initialIcon,
    this.initialCategoryId,
    super.key,
  });

  /// 編集対象の項目 ID。
  final ItemId itemId;

  /// 開いた時点の項目名(保存済みの値)。
  final String initialName;

  /// 開いた時点のアイコン(保存済みの値)。
  final ItemIcon? initialIcon;

  /// 開いた時点のカテゴリ(保存済みの値)。
  final CategoryId? initialCategoryId;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  /// 入力欄に出す理由。null なら正常。
  String? _errorText;

  /// 保存中・削除中は保存・削除・キャンセルをまとめて塞ぐ(判断9)。
  bool _isBusy = false;

  /// 選択中のアイコン。null は未選択(既定アイコンになる)。
  late ItemIcon? _icon = widget.initialIcon;

  /// 選択中のカテゴリ。null は未分類。
  late CategoryId? _categoryId = widget.initialCategoryId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('項目を編集'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'キャンセル',
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
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
                // 開いた瞬間にキーボードを出すと削除ボタンが隠れる(判断15)。
                autofocus: false,
                // 51 文字目を打てなくする。ドメイン側の検証は消さない(#6 判断3)。
                maxLength: maxItemNameLength,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '項目名',
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
                enabled: !_isBusy,
              ),
              const SizedBox(height: 24),
              ItemCategoryPicker(
                selected: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
                enabled: !_isBusy,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isBusy ? null : _save,
                child: const Text('保存'),
              ),
              // 破壊的操作を保存から離す(判断14)。
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: _isBusy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('削除'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
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
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    final categories = ref.read(categoryListProvider).value ?? const [];
    final result = await ref
        .read(itemListProvider.notifier)
        .editItem(
          widget.itemId,
          _controller.text,
          icon: _icon,
          // 編集中にカテゴリが削除された場合に外部キー違反を起こさない。
          categoryId: resolveCategoryId(_categoryId, categories),
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      // 保存の完了を待ってから戻る(楽観的 UI 更新を採らない)。
      case EditItemSucceeded():
      // 対象が既に無い。エラーを出さずに戻る(判断7)。
      case EditItemIgnored():
        Navigator.of(context).pop();
      // 画面を閉じない。入力もそのまま残す(受け入れ条件)。
      case EditItemRejected(:final reason):
        setState(() {
          _isBusy = false;
          _errorText = itemNameErrorText(reason);
        });
      case EditItemFailed():
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存できませんでした。もう一度お試しください')));
    }
  }

  Future<void> _delete() async {
    if (_isBusy) {
      return;
    }
    // 削除は確認を挟む(判断1)。基準は元に戻せるかどうか。
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('項目を削除しますか?'),
        // 消えるのは保存済みの項目なので、編集中の入力値ではなく初期値を出す(判断10)。
        content: Text('「${widget.initialName}」とこれまでの記録を削除します。元に戻せません。'),
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
            child: const Text('削除'),
          ),
        ],
      ),
    );
    // バリアタップ・戻る操作は null。true 以外はすべて「削除しない」(判断10)。
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _isBusy = true);
    final result = await ref
        .read(itemListProvider.notifier)
        .deleteItem(widget.itemId);
    if (!mounted) {
      return;
    }
    switch (result) {
      case DeleteItemSucceeded():
      // 対象が既に無い。目的は達成されているのでエラーを出さない(判断7)。
      case DeleteItemIgnored():
        Navigator.of(context).pop();
      case DeleteItemFailed():
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('削除できませんでした。もう一度お試しください')));
    }
  }
}
