import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository_impl.dart';
import '../data/database/app_database.dart';
import '../data/item_repository_impl.dart';
import '../domain/category_repository.dart';
import '../domain/clock.dart';
import '../domain/item_repository.dart';

/// アプリ全体で 1 つの [AppDatabase]。**DB を開く唯一の場所。**
///
/// `ref.onDispose` で閉じるのは、テストが `ProviderContainer` を捨てたときに
/// ファイルハンドルを残さないため。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// 項目の永続化。**型はドメインのインターフェース**にする。
///
/// 上位層(Notifier・ウィジェットテスト)はこの 1 本を `FakeItemRepository` に
/// 差し替えるだけで、Drift を起動せずにテストできる。
final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ItemRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// カテゴリの永続化。上位層のテストは `FakeCategoryRepository` に差し替える。
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepositoryImpl(ref.watch(appDatabaseProvider)),
);

/// 現在時刻の供給元。テストは `FakeClock` に差し替える。
final clockProvider = Provider<Clock>((ref) => const SystemClock());
