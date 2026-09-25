import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/category_name.dart';
import 'package:lastwhen/domain/category_repository.dart';
import 'package:lastwhen/state/category_list_notifier.dart';
import 'package:lastwhen/state/category_results.dart';
import 'package:lastwhen/state/providers.dart';

import '../support/fake_category_repository.dart';

/// 一覧を 1 回流した後、ストリームをエラーにできる Fake。
///
/// `_container` の `FakeCategoryRepository` は書き込みでしか失敗を再現できないため、
/// 「一度値を受け取った後にストリームが失敗する」状態はこのテストファイル専用の Fake で作る
/// (`test/ui/item_edit_screen_test.dart` の `_FailingWatchCategoryRepository` と同じやり方)。
final class _FlakyWatchCategoryRepository implements CategoryRepository {
  final StreamController<List<Category>> _controller =
      StreamController<List<Category>>();

  void emit(List<Category> categories) => _controller.add(categories);

  void emitError() => _controller.addError(StateError('watch failed'));

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<Category>> watchAll() => _controller.stream;

  @override
  Future<Category> add(String name) async =>
      Category(id: const CategoryId('flaky-added'), name: name, sortOrder: 0);

  @override
  Future<void> rename(CategoryId id, String name) => throw UnimplementedError();

  @override
  Future<void> delete(CategoryId id) => throw UnimplementedError();
}

Future<ProviderContainer> _container(FakeCategoryRepository repository) async {
  final container = ProviderContainer.test(
    overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
  );
  container.listen(categoryListProvider, (_, _) {});
  // `_latestCategories` は初回 emit で埋まる。存在確認・重複判定に必須。
  await container.read(categoryListProvider.future);
  return container;
}

void main() {
  late FakeCategoryRepository repository;
  setUp(() {
    repository = FakeCategoryRepository();
    addTearDown(repository.dispose);
  });

  group('addCategory', () {
    test('検証を通れば保存され、追加したカテゴリを返す', () async {
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('健康');
      expect(result, isA<AddCategorySucceeded>());
      expect((result as AddCategorySucceeded).category.name, '健康');
      expect((await repository.watchAll().first).single.name, '健康');
    });

    test('空文字は保存されず理由が empty になる', () async {
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('');
      expect(
        result,
        isA<AddCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.empty,
        ),
      );
      expect(await repository.watchAll().first, isEmpty);
    });

    test('11文字は保存されず理由が tooLong になる', () async {
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('あ' * 11);
      expect(
        result,
        isA<AddCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.tooLong,
        ),
      );
    });

    test('既存と同じ名前は保存されず理由が duplicate になる', () async {
      await repository.add('健康');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('健康');
      expect(
        result,
        isA<AddCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.duplicate,
        ),
      );
    });

    test('保存に失敗すると Failed になる', () async {
      final container = await _container(repository);
      repository.writeError = StateError('write failed');
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('健康');
      expect(result, isA<AddCategoryFailed>());
    });
  });

  group('renameCategory', () {
    test('検証を通れば名前が変わる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(category.id, '健康2');
      expect(result, isA<RenameCategorySucceeded>());
      expect((await repository.watchAll().first).single.name, '健康2');
    });

    test('自分と同じ名前(変更なし)は Succeeded になる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(category.id, '健康');
      expect(result, isA<RenameCategorySucceeded>());
    });

    test('空文字は保存されず理由が empty になる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(category.id, '');
      expect(
        result,
        isA<RenameCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.empty,
        ),
      );
    });

    test('他のカテゴリと同じ名前は duplicate になる', () async {
      await repository.add('健康');
      final target = await repository.add('趣味');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(target.id, '健康');
      expect(
        result,
        isA<RenameCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.duplicate,
        ),
      );
    });

    test('存在しない id は Ignored になる', () async {
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(const CategoryId('missing'), '健康');
      expect(result, isA<RenameCategoryIgnored>());
    });

    test('保存に失敗すると Failed になる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      repository.writeError = StateError('write failed');
      final result = await container
          .read(categoryListProvider.notifier)
          .renameCategory(category.id, '健康2');
      expect(result, isA<RenameCategoryFailed>());
    });
  });

  group('deleteCategory', () {
    test('存在する id は削除され Succeeded になる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .deleteCategory(category.id);
      expect(result, isA<DeleteCategorySucceeded>());
      expect(await repository.watchAll().first, isEmpty);
    });

    test('存在しない id は Ignored になる', () async {
      final container = await _container(repository);
      final result = await container
          .read(categoryListProvider.notifier)
          .deleteCategory(const CategoryId('missing'));
      expect(result, isA<DeleteCategoryIgnored>());
    });

    test('削除に失敗すると Failed になる', () async {
      final category = await repository.add('健康');
      final container = await _container(repository);
      repository.writeError = StateError('write failed');
      final result = await container
          .read(categoryListProvider.notifier)
          .deleteCategory(category.id);
      expect(result, isA<DeleteCategoryFailed>());
    });
  });

  group('追補: 重複検査のタイミング(#42 レビュー指摘)', () {
    test('追加が成功した直後に同じ名前を追加すると重複として拒否される', () async {
      final container = await _container(repository);
      final notifier = container.read(categoryListProvider.notifier);
      final first = await notifier.addCategory('健康');
      expect(first, isA<AddCategorySucceeded>());
      // ストリームの次の値を待たずに、続けて同じ名前を追加する。
      final second = await notifier.addCategory('健康');
      expect(
        second,
        isA<AddCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.duplicate,
        ),
      );
    });

    test('名前変更の直後に、別のカテゴリをその名前に変えると重複として拒否される', () async {
      final categoryA = await repository.add('健康');
      final categoryB = await repository.add('趣味');
      final container = await _container(repository);
      final notifier = container.read(categoryListProvider.notifier);
      final renamed = await notifier.renameCategory(categoryA.id, '健康2');
      expect(renamed, isA<RenameCategorySucceeded>());
      // ストリームの次の値を待たずに、別のカテゴリを同じ名前に変える。
      final result = await notifier.renameCategory(categoryB.id, '健康2');
      expect(
        result,
        isA<RenameCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.duplicate,
        ),
      );
    });

    test('ストリームの最初の値が届く前に addCategory を呼んでも、既存名との重複を検出する', () async {
      await repository.add('健康');
      // `_container` と違い、最初の値を待たずにそのまま呼ぶ。
      final container = ProviderContainer.test(
        overrides: [categoryRepositoryProvider.overrideWithValue(repository)],
      );
      // 購読を開始するだけで、最初の値(`.future`)は待たない。
      container.listen(categoryListProvider, (_, _) {});
      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('健康');
      expect(
        result,
        isA<AddCategoryRejected>().having(
          (r) => r.reason,
          'reason',
          CategoryNameReason.duplicate,
        ),
      );
    });
  });

  group('追補3: 読み込み済みなら future を待たない(再レビュー指摘)', () {
    test('一覧を1回流した後にストリームが失敗しても、手元の一覧で確かめて保存できる', () async {
      final flaky = _FlakyWatchCategoryRepository();
      addTearDown(flaky.dispose);
      final container = ProviderContainer.test(
        overrides: [categoryRepositoryProvider.overrideWithValue(flaky)],
      );
      container.listen(categoryListProvider, (_, _) {});
      flaky.emit(const [
        Category(id: CategoryId('c1'), name: '健康', sortOrder: 0),
      ]);
      // 最初の値が届くまで待つ(`_latestCategories` が埋まる)。
      await container.read(categoryListProvider.future);
      flaky.emitError();
      // エラーが `state` に反映されるまで待つ(previousData は保持されたまま `AsyncError` になる)。
      await pumpEventQueue();
      expect(container.read(categoryListProvider).hasValue, isTrue);
      expect(container.read(categoryListProvider).hasError, isTrue);

      final result = await container
          .read(categoryListProvider.notifier)
          .addCategory('趣味');

      expect(result, isA<AddCategorySucceeded>());
    });
  });
}
