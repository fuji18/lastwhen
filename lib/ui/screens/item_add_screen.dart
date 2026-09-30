import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/category.dart';
import '../../domain/item_icon.dart';
import '../../domain/item_name.dart';
import '../../domain/item_template.dart';
import '../../state/add_item_result.dart';
import '../../state/category_filter.dart';
import '../../state/category_list_notifier.dart';
import '../../state/item_list_notifier.dart';
import '../item_name_error_text.dart';
import '../widgets/item_icon_picker.dart';
import '../widgets/item_category_picker.dart';
import '../widgets/paper_background.dart';
import '../widgets/item_template_chips.dart';

/// 登録画面に出すよくある項目の上限(#93)。多く並べると「保存」が画面外へ押し出される。
/// 空状態(`EmptyState`)は画面に余裕があるので上限を設けない。
const int maxAddScreenTemplates = 3;

/// 項目の登録画面。**必須の入力は項目名 1 つだけ**(F2)。アイコン(F14)は任意で、選ばなければ
/// 既定アイコンになる。必須の入力を増やすと「30 秒以内に登録できる」という成功指標と衝突する。
/// よくある項目(F17)を選ぶと項目名とアイコンが入る。登録済みと同名のものを除いた先頭
/// [maxAddScreenTemplates] 件だけ出す。「保存」は画面下に固定し、キーボード表示中も見せる(#93)。
class ItemAddScreen extends ConsumerStatefulWidget {
  /// 登録画面を作る。[initialCategoryId] は開いた時点で選ばれているカテゴリ
  /// (一覧の絞り込み)。
  const ItemAddScreen({this.initialCategoryId, super.key});

  /// 開いた時点で選ばれているカテゴリ(一覧の絞り込み)。
  final CategoryId? initialCategoryId;

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

  /// 選択中のカテゴリ。null は未分類。
  late CategoryId? _categoryId = widget.initialCategoryId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 一覧が未取得なら同名を判定できないので出さない(判断C)。
    final items = ref.watch(itemListProvider).value;
    final templates = items == null
        ? const <ItemTemplate>[]
        : availableItemTemplates(items.map((item) => item.name))
              .take(maxAddScreenTemplates)
              .toList();

    return PaperBackground(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('項目を追加'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'キャンセル',
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
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
                      if (templates.isNotEmpty) ...[
                        Text(
                          'よくある項目から選ぶ',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        ItemTemplateChips(
                          templates: templates,
                          enabled: !_isSaving,
                          tooltipBuilder: (template) => '${template.name}を入力',
                          onPressed: _applyTemplate,
                        ),
                        const SizedBox(height: 24),
                      ],
                      ItemIconPicker(
                        selected: _icon,
                        onChanged: (value) => setState(() => _icon = value),
                        enabled: !_isSaving,
                      ),
                      const SizedBox(height: 24),
                      ItemCategoryPicker(
                        selected: _categoryId,
                        onChanged: (value) =>
                            setState(() => _categoryId = value),
                        enabled: !_isSaving,
                      ),
                    ],
                  ),
                ),
              ),
              // スクロールの外に置き、キーボード表示中も直上に見せる(#93)。
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('保存'),
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

  /// よくある項目の名前とアイコンを入力欄に入れる。**保存はしない**(判断B)。カテゴリは変えない。
  void _applyTemplate(ItemTemplate template) {
    _controller.value = TextEditingValue(
      text: template.name,
      selection: TextSelection.collapsed(offset: template.name.length),
    );
    setState(() {
      _icon = template.icon;
      _errorText = null;
    });
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    // 一覧がまだ無いときは存在を判定できない。選択を消さずにそのまま渡す。
    final categories = ref.read(categoryListProvider).value;
    final result = await ref
        .read(itemListProvider.notifier)
        .addItem(
          _controller.text,
          icon: _icon,
          // 編集中にカテゴリが削除された場合に外部キー違反を起こさない。
          categoryId: categories == null
              ? _categoryId
              : resolveCategoryId(_categoryId, categories),
        );
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
