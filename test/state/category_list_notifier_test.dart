import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/category.dart';
import 'package:lastwhen/domain/category_name.dart';
import 'package:lastwhen/state/category_list_notifier.dart';
import 'package:lastwhen/state/category_results.dart';
import 'package:lastwhen/state/providers.dart';

import '../support/fake_category_repository.dart';

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
}
