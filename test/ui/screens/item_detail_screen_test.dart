import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/item_detail_screen.dart';
import 'package:lastwhen/ui/screens/item_edit_screen.dart';
import 'package:lastwhen/ui/screens/item_list_screen.dart';

import '../../support/fake_category_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_item_repository.dart';

Widget _app(FakeItemRepository repository, Clock clock) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
    clockProvider.overrideWithValue(clock),
  ],
  child: const App(),
);

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Future<void> openDetail(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('その他の操作'));
    await tester.pumpAndSettle();
  }

  group('表示', () {
    testWidgets('記録3件で最後にやった日・平均の間隔・前回からの間隔・履歴を示す', (tester) async {
      final item = await repository.add('美容院', now: now);
      for (final doneAt in [
        DateTime.utc(2026, 8, 29, 3),
        DateTime.utc(2026, 9, 5, 3),
        DateTime.utc(2026, 9, 12, 3),
      ]) {
        await repository.markDone(item.id, doneAt);
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.byType(ItemDetailScreen), findsOneWidget);
      expect(find.text('美容院'), findsWidgets);
      expect(find.text('最後にやった日'), findsOneWidget);
      expect(find.text('2026年9月12日（4日前）'), findsOneWidget);
      expect(find.text('平均の間隔'), findsOneWidget);
      expect(find.text('7日'), findsWidgets);
      expect(find.text('前回からの間隔'), findsOneWidget);
      expect(find.text('4日'), findsOneWidget);
      expect(find.text('記録の履歴'), findsOneWidget);
      expect(find.text('2026年9月12日'), findsOneWidget);
      expect(find.text('2026年9月5日'), findsOneWidget);
      expect(find.text('2026年8月29日'), findsOneWidget);
    });

    testWidgets('記録1件なら平均が学習中、履歴1行で間隔の表示なし', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.text('学習中'), findsOneWidget);
      expect(find.text('2026年9月12日（4日前）'), findsOneWidget);
      // 履歴 1 行は間隔なしのプレーンな日付表示(括弧付きの最後にやった日の行とは別)。
      expect(find.text('2026年9月12日'), findsOneWidget);
    });

    testWidgets('未実施はまだ記録がありませんが2箇所出て前回からの間隔が無く平均は学習中', (tester) async {
      await repository.add('美容院', now: now);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.text('まだ記録がありません'), findsNWidgets(2));
      expect(find.text('前回からの間隔'), findsNothing);
      expect(find.text('学習中'), findsOneWidget);
    });

    testWidgets('aged相当でいつもより長めが出る', (tester) async {
      final item = await repository.add('美容院', now: now);
      // 古い順に記録する(最後の呼び出しが最終実施日になる)。
      for (final daysAgo in [29, 22, 15]) {
        await repository.markDone(
          item.id,
          now.subtract(Duration(days: daysAgo)),
        );
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.text('いつもより長め'), findsOneWidget);
    });

    testWidgets('dueSoon相当ではいつもより長めが出ない', (tester) async {
      final item = await repository.add('美容院', now: now);
      // 古い順に記録する(最後の呼び出しが最終実施日になる)。
      for (final daysAgo in [22, 15, 8]) {
        await repository.markDone(
          item.id,
          now.subtract(Duration(days: daysAgo)),
        );
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.text('そろそろかも。'), findsOneWidget);
      expect(find.text('いつもより長め'), findsNothing);
    });

    testWidgets('記録が10件で直近10件まで表示していますが出る', (tester) async {
      final item = await repository.add('美容院', now: now);
      // 古い順に記録する(最後の呼び出しが最終実施日になる)。
      for (var i = 9; i >= 0; i--) {
        await repository.markDone(item.id, now.subtract(Duration(days: i)));
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      expect(find.text('直近10件まで表示しています'), findsOneWidget);
    });
  });

  group('記録する', () {
    testWidgets('確認ダイアログを出さず記録しましたが出て履歴の先頭が今日になり取り消せる', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      await tester.tap(find.text('記録する'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('記録しました'), findsOneWidget);
      expect(find.text('2026年9月16日'), findsOneWidget);

      await tester.tap(find.text('取り消す'));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月16日'), findsNothing);
      expect(find.text('2026年9月12日（4日前）'), findsOneWidget);
    });

    testWidgets('記録後に戻ると取り消し導線が消えている', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');

      await tester.tap(find.text('記録する'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);

      await tester.tap(find.byTooltip('戻る'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('記録の削除', () {
    Future<void> ready(WidgetTester tester, {bool sameDayOnly = false}) async {
      final item = await repository.add('美容院', now: now);
      for (final date in [
        if (!sameDayOnly) DateTime(2026, 9, 5, 12),
        DateTime(2026, 9, 12, 12),
        if (sameDayOnly) DateTime(2026, 9, 12, 23),
      ]) {
        await repository.addDoneLog(item.id, date.toUtc(), now: now);
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
    }

    Future<void> confirm(WidgetTester tester) async {
      final button = find.byTooltip('2026年9月12日の記録を削除');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> delete(WidgetTester tester) async {
      await confirm(tester);
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
    }

    testWidgets('各行の削除ボタンに日付つきのラベルがある', (tester) async {
      await ready(tester);
      expect(find.byTooltip('2026年9月12日の記録を削除'), findsOneWidget);
      expect(find.byTooltip('2026年9月5日の記録を削除'), findsOneWidget);
    });
    testWidgets('確認をキャンセルすると履歴は変わらず結果も出さない', (tester) async {
      await ready(tester);
      final before = await repository.watchAll().first;
      await confirm(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('9月12日の記録を削除しますか?'), findsOneWidget);
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('2026年9月12日'), findsOneWidget);
      expect(await repository.watchAll().first, before);
    });
    testWidgets('削除で行が消え、取り消すと履歴と最後にやった日が戻る', (tester) async {
      await ready(tester);
      await delete(tester);
      expect(find.text('2026年9月12日'), findsNothing);
      expect(find.text('9月12日の記録を削除しました'), findsOneWidget);
      expect(find.text('2026年9月5日（11日前）'), findsOneWidget);
      await tester.tap(find.text('取り消す'));
      await tester.pumpAndSettle();
      expect(find.text('2026年9月12日'), findsOneWidget);
      expect(find.text('2026年9月12日（4日前）'), findsOneWidget);
    });
    testWidgets('同じ暦日の 2 件がすべて消えると未実施と学習中になる', (tester) async {
      await ready(tester, sameDayOnly: true);
      await delete(tester);
      expect(find.text('まだ記録がありません'), findsNWidgets(2));
      expect(find.text('学習中'), findsOneWidget);
      expect((await repository.watchAll().first).single.recentDoneAts, isEmpty);
    });
    testWidgets('削除の直前に書き込みが失敗すると履歴を保ちエラーを表示する', (tester) async {
      await ready(tester);
      await confirm(tester);
      final before = await repository.watchAll().first;
      repository.writeError = StateError('write failed');
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      expect(find.text('削除できませんでした。もう一度お試しください'), findsOneWidget);
      expect(find.text('2026年9月12日'), findsOneWidget);
      expect(await repository.watchAll().first, before);
    });
    testWidgets('取り消し導線は 4 秒後に消える', (tester) async {
      await ready(tester);
      await delete(tester);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 4));
      expect(snackBar.persist, isFalse);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
    test('historyDeleteButtonLabel は長い日付を含む', () {
      expect(
        historyDeleteButtonLabel(
          DoneHistoryEntry(
            dateText: '2026年9月12日',
            shortDateText: '9月12日',
            dayKey: HistoryDayKey(DateTime.utc(2026, 9, 12)),
          ),
        ),
        '2026年9月12日の記録を削除',
      );
    });
  });

  group('メニュー', () {
    testWidgets('日付を指定して記録と編集があり削除は無い', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
      await openMenu(tester);

      expect(find.text('日付を指定して記録'), findsOneWidget);
      expect(find.text('編集'), findsOneWidget);
      expect(find.text('削除'), findsNothing);
    });

    testWidgets('日付を指定して記録で日付の選択が開く', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
      await openMenu(tester);
      await tester.tap(find.text('日付を指定して記録'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('編集から削除すると一覧に戻り記録の詳細が残らない', (tester) async {
      final item = await repository.add('美容院', now: now);
      await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
      await repository.add('歯ブラシ交換', now: now);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
      await openMenu(tester);
      await tester.tap(find.text('編集'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemEditScreen), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(TextButton, '削除'));
      await tester.tap(find.widgetWithText(TextButton, '削除'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, '削除'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailScreen), findsNothing);
      expect(find.byType(ItemEditScreen), findsNothing);
      expect(find.byType(ItemListScreen), findsOneWidget);
      expect(find.text('歯ブラシ交換'), findsOneWidget);
    });
  });

  group('NFC タグ', () {
    testWidgets('メニューからダイアログを開くとリンクが表示される', (tester) async {
      final item = await repository.add('美容院', now: now);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
      await openMenu(tester);
      await tester.tap(find.text('NFC タグに登録'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('lastwhen://done/${item.id.value}'), findsOneWidget);
    });

    testWidgets('コピーでクリップボードに入りダイアログが閉じる', (tester) async {
      final item = await repository.add('美容院', now: now);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<dynamic, dynamic>)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      await openDetail(tester, '美容院');
      await openMenu(tester);
      await tester.tap(find.text('NFC タグに登録'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('コピー'));
      await tester.pumpAndSettle();

      expect(copied, 'lastwhen://done/${item.id.value}');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('リンクをコピーしました'), findsOneWidget);
    });
  });

  group('表示用の関数', () {
    ItemView view({
      ElapsedLabel elapsed = const DaysAgo(4),
      String? lastDoneText = '2026年9月12日',
      double? baselineIntervalDays = 7,
      AgingStage stage = AgingStage.slightlyAged,
    }) => ItemView(
      id: const ItemId('item-1'),
      name: '美容院',
      elapsed: elapsed,
      lastDoneText: lastDoneText,
      baselineIntervalDays: baselineIntervalDays,
      agingStage: stage,
    );

    test('detailLastDoneText: 未実施はまだ記録がありません', () {
      expect(
        detailLastDoneText(
          view(elapsed: const NeverDone(), lastDoneText: null),
        ),
        'まだ記録がありません',
      );
    });

    test('detailLastDoneText: 記録済みは日付と経過日数を全角括弧で示す', () {
      expect(detailLastDoneText(view()), '2026年9月12日（4日前）');
    });

    test('detailLastDoneText: 今日は（今日）', () {
      expect(
        detailLastDoneText(
          view(elapsed: const Today(), lastDoneText: '2026年9月16日'),
        ),
        '2026年9月16日（今日）',
      );
    });

    test('detailLastDoneText: 昨日は（昨日）', () {
      expect(
        detailLastDoneText(
          view(elapsed: const Yesterday(), lastDoneText: '2026年9月15日'),
        ),
        '2026年9月15日（昨日）',
      );
    });

    test('detailAverageIntervalText: null は学習中', () {
      expect(detailAverageIntervalText(null), '学習中');
    });

    test('detailAverageIntervalText: 四捨五入して日を付ける', () {
      expect(detailAverageIntervalText(6.5), '7日');
      expect(detailAverageIntervalText(6.4), '6日');
    });

    test('detailSinceLastText: 未実施は null', () {
      expect(detailSinceLastText(const NeverDone()), isNull);
    });

    test('detailSinceLastText: 今日は0日', () {
      expect(detailSinceLastText(const Today()), '0日');
    });

    test('detailSinceLastText: 昨日は1日', () {
      expect(detailSinceLastText(const Yesterday()), '1日');
    });

    test('detailSinceLastText: N日前はN日', () {
      expect(detailSinceLastText(const DaysAgo(4)), '4日');
    });

    test('isLongerThanUsual: aged 以上で true', () {
      expect(isLongerThanUsual(AgingStage.aged), isTrue);
      expect(isLongerThanUsual(AgingStage.heavilyAged), isTrue);
    });

    test('isLongerThanUsual: dueSoon 以下で false', () {
      expect(isLongerThanUsual(AgingStage.dueSoon), isFalse);
      expect(isLongerThanUsual(AgingStage.slightlyAged), isFalse);
      expect(isLongerThanUsual(AgingStage.fresh), isFalse);
    });

    const hints = {
      AgingStage.fresh: null,
      AgingStage.slightlyAged: null,
      AgingStage.dueSoon: 'そろそろかも。',
      AgingStage.aged: 'いつもより間が空いているかも。',
      AgingStage.heavilyAged: 'だいぶ間が空いているかも。',
    };
    for (final entry in hints.entries) {
      test('agingStageHintText: ${entry.key} の一言', () {
        expect(agingStageHintText(entry.key), entry.value);
      });
    }

    test('historyEntrySemanticsLabel: 間隔ありは前回からを添える', () {
      expect(
        historyEntrySemanticsLabel(
          DoneHistoryEntry(
            dateText: '2026年9月12日',
            shortDateText: '9月12日',
            dayKey: HistoryDayKey(DateTime.utc(2026, 9, 12)),
            intervalDays: 7,
          ),
        ),
        '2026年9月12日、前回から7日',
      );
    });

    test('historyEntrySemanticsLabel: 間隔なしは日付のみ', () {
      expect(
        historyEntrySemanticsLabel(
          DoneHistoryEntry(
            dateText: '2026年9月12日',
            shortDateText: '9月12日',
            dayKey: HistoryDayKey(DateTime.utc(2026, 9, 12)),
          ),
        ),
        '2026年9月12日',
      );
    });
  });
}
