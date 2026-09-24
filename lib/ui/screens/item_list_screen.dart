import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/item.dart';
import '../../state/mark_done_result.dart';
import '../../state/item_list_notifier.dart';
import '../../state/item_view.dart';
import '../widgets/centered_scrollable.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_card.dart';
import '../widgets/item_detail_sheet.dart';
import 'item_add_screen.dart';
import 'item_edit_screen.dart';

/// 一覧画面。**起動直後に出る唯一の画面**(`docs/functional-design.md`「画面遷移図」)。
class ItemListScreen extends ConsumerStatefulWidget {
  /// 一覧画面を作る。
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  /// 復帰で並びを確定し直す(F30)。記録では組み替えない。
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(itemListProvider.notifier).refreshOrder(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(itemListProvider);
    // 追加導線は空状態(EmptyState 側にボタンがある)と読み込み中・失敗では出さない(判断5)。
    final hasItems = switch (items) {
      AsyncData(:final value) => value.isNotEmpty,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('LastWhen')),
      body: SafeArea(
        child: switch (items) {
          AsyncData(:final value) when value.isEmpty => EmptyState(
            onAddPressed: () => _openAddScreen(context),
          ),
          AsyncData(:final value) => _ItemList(items: value),
          AsyncError() => _LoadError(
            onRetry: () => ref.invalidate(itemListProvider),
          ),
          _ => const Center(
            child: CircularProgressIndicator(semanticsLabel: '読み込み中'),
          ),
        },
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton(
              onPressed: () => _openAddScreen(context),
              tooltip: '項目を追加',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// 登録画面へ遷移する。
///
/// 名前付きルートを使わない(design.md 判断4)。画面は一覧・登録・編集の 3 つだけで、
/// ディープリンクも扱わないため、ルート表を持つと二重管理になるだけ。
void _openAddScreen(BuildContext context) {
  // ScaffoldMessenger は Navigator の上にあり、閉じないと遷移後も導線が残る。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (context) => const ItemAddScreen()),
  );
}

/// 詳細シートを開く。編集画面への入口はシートの中にある。
Future<void> _openDetailSheet(BuildContext context, ItemView item) async {
  // 画面遷移と同じく、取り消し導線を閉じる。
  ScaffoldMessenger.of(context).clearSnackBars();
  final openEdit = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ItemDetailSheet(
      item: item,
      onEditPressed: () => Navigator.of(sheetContext).pop(true),
    ),
  );
  if (openEdit == true && context.mounted) {
    _openEditScreen(context, item);
  }
}

/// 編集画面へ遷移する。**削除の入口でもある**(`docs/product-requirements.md` F7)。
void _openEditScreen(BuildContext context, ItemView item) {
  // ScaffoldMessenger は Navigator の上にあり、閉じないと遷移後も導線が残る(判断13)。
  ScaffoldMessenger.of(context).clearSnackBars();
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => ItemEditScreen(
        itemId: item.id,
        initialName: item.name,
        initialIcon: item.icon,
      ),
    ),
  );
}

/// 項目が 1 件以上あるときの一覧。
class _ItemList extends ConsumerWidget {
  const _ItemList({required this.items});

  final List<ItemView> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 100 件で全行を同時に構築しない(`docs/functional-design.md`「パフォーマンス最適化」)。
    return ListView.builder(
      // FAB が最終行の「やった」ボタンに被らないようにする。56 + 16 × 2。
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ItemCard(
          item: item,
          onDonePressed: () => _handleDone(context, ref, item.id),
          onTap: () => unawaited(_openDetailSheet(context, item)),
        );
      },
    );
  }
}

/// 一覧そのものを読み込めなかったときの表示。
///
/// DB のオープン失敗・購読の切断がここに来る(`docs/functional-design.md`
/// 「エラーハンドリング」)。書き込みの失敗はここに来ない(`SnackBar` に出す)。
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CenteredScrollable(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'データを読み込めませんでした',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('再試行')),
        ],
      ),
    );
  }
}

/// 「やった」を記録し、直後に取り消し導線を出す。
///
/// **確認ダイアログを挟まない**(`docs/product-requirements.md` F3)。
Future<void> _handleDone(BuildContext context, WidgetRef ref, ItemId id) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(itemListProvider.notifier).markDone(id);
  switch (result) {
    case MarkDoneSucceeded(:final undo):
      // キューに積ませない。積むと前の導線が先に出て「直近 1 件のみ」が崩れる(判断5)。
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('記録しました'),
          // アクションを付けると persist が既定で true になり、4 秒で消えない(判断6)。
          persist: false,
          action: SnackBarAction(
            label: '取り消す',
            onPressed: () => _handleUndo(messenger, ref, undo),
          ),
        ),
      );
    // 削除と同時操作。何も出さない(`docs/functional-design.md`「エラーの分類」)。
    case MarkDoneIgnored():
      break;
    case MarkDoneFailed():
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('保存できませんでした。もう一度お試しください')),
      );
  }
}

/// 直前の「やった」を取り消す。
///
/// `BuildContext` ではなく [ScaffoldMessengerState] を受け取る。取り消しは `SnackBar` の
/// アクションから走るため、押された時点で元の行のコンテキストが生きている保証がない。
void _handleUndo(
  ScaffoldMessengerState messenger,
  WidgetRef ref,
  MarkDoneUndo undo,
) {
  unawaited(() async {
    final result = await ref.read(itemListProvider.notifier).undoMarkDone(undo);
    if (result is UndoFailed) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('取り消せませんでした。もう一度お試しください')),
      );
    }
  }());
}
