import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/data/database/app_database.dart' show AppDatabase;
import 'package:lastwhen/data/item_repository_impl.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/item_repository.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/widgets/item_row.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

Widget _app(ItemRepository repository, Clock clock) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
    clockProvider.overrideWithValue(clock),
  ],
  child: const App(),
);

void _setScreenSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(360 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  final now = DateTime(2026, 9, 16, 12);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Future<void> seedItems(ItemRepository target) async {
    for (var i = 0; i < 100; i++) {
      await target.add('項目$i', now: now);
    }
  }

  group('パフォーマンス', () {
    testWidgets('項目100件でも構築される行は可視範囲に収まる', (tester) async {
      _setScreenSize(tester);
      await seedItems(repository);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      final count = find.byType(ItemRow, skipOffstage: false).evaluate().length;
      expect(count, greaterThan(0));
      expect(count, lessThan(20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('100件をスクロールしても構築される行数が増え続けない', (tester) async {
      _setScreenSize(tester);
      await seedItems(repository);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(find.text('項目0'), findsNothing);
      final count = find.byType(ItemRow, skipOffstage: false).evaluate().length;
      expect(count, greaterThan(0));
      expect(count, lessThan(20));
      expect(tester.takeException(), isNull);
    });

    testWidgets('100件の一覧で発行されるクエリは watchAll の 1 本だけ', (tester) async {
      _setScreenSize(tester);
      final counter = _StatementCounter();
      final db = AppDatabase.forTesting(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ).interceptWith(counter),
      );
      addTearDown(db.close);
      final realRepository = ItemRepositoryImpl(db);
      await seedItems(realRepository);
      counter.reset();
      await tester.pumpWidget(_app(realRepository, FakeClock(now)));
      await tester.pumpAndSettle();
      expect(find.byType(ItemRow), findsWidgets);
      expect(
        counter.selects
            .where(
              (sql) => RegExp(
                r'from\s+"?items"?',
                caseSensitive: false,
              ).hasMatch(sql),
            )
            .length,
        1,
      );
      expect(counter.writes, isEmpty);
      expect(tester.takeException(), isNull);
      // DB を閉じる前に一覧の購読を破棄する。
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('参考値: 100件の初回描画にかかった時間を記録する', (tester) async {
      _setScreenSize(tester);
      await seedItems(repository);
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      stopwatch.stop();
      debugPrint(
        '[perf] 100件の初回描画: ${stopwatch.elapsedMilliseconds}ms (debug / widget test)',
      );
      expect(find.byType(ItemRow), findsWidgets);
      // JIT とホスト性能の差があるため、実機の 300ms 基準は課さない。
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      expect(tester.takeException(), isNull);
    });
  });
}

/// 一覧表示中に行ごとの追加クエリや書き込みが発生しないことを検証する。
final class _StatementCounter extends QueryInterceptor {
  final List<String> selects = <String>[];
  final List<String> writes = <String>[];

  void reset() {
    selects.clear();
    writes.clear();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add(statement);
    return executor.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes.add(statement);
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes.add(statement);
    return executor.runUpdate(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes.add(statement);
    return executor.runDelete(statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    writes.add(statement);
    return executor.runCustom(statement, args);
  }
}
