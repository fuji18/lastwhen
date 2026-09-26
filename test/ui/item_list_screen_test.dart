import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/state/item_order.dart';
import 'package:lastwhen/ui/screens/category_manage_screen.dart';
import 'package:lastwhen/ui/screens/home_shell.dart';
import 'package:lastwhen/ui/screens/item_list_screen.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/screens/item_edit_screen.dart';
import 'package:lastwhen/ui/widgets/category_filter_bar.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/empty_state.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';
import 'package:lastwhen/ui/widgets/item_detail_sheet.dart';

import '../support/fake_category_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  FakeCategoryRepository? categoryRepository,
}) => ProviderScope(
  overrides: [
    itemRepositoryProvider.overrideWithValue(repository),
    categoryRepositoryProvider.overrideWithValue(
      categoryRepository ?? FakeCategoryRepository(),
    ),
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

  Future<void> pumpItems(WidgetTester tester) async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime.utc(2026, 9, 12, 3));
    await repository.add('歯ブラシ交換', now: now);
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
  }

  testWidgets('0件なら空状態と項目を追加する導線が出る', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('まだ項目がありません'), findsOneWidget);
    expect(find.text('項目を追加'), findsOneWidget);
    expect(find.byType(ItemCard), findsNothing);
  });

  testWidgets('空状態の内容は画面中央に配置される', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    final content = find.descendant(
      of: find.byType(EmptyState),
      matching: find.byType(Column),
    );
    final center = tester.getCenter(content);
    final screenSize = tester.getSize(find.byType(Scaffold));
    expect(center.dx, closeTo(screenSize.width / 2, 1));
    expect(center.dy, closeTo(screenSize.height / 2, kToolbarHeight));
  });

  testWidgets('記録済みのカードに日付が出て未実施のカードには出ない', (tester) async {
    await pumpItems(tester);
    expect(find.text('美容院'), findsOneWidget);
    expect(find.text('歯ブラシ交換'), findsOneWidget);
    expect(find.text('4日前'), findsOneWidget);
    expect(find.text('2026年9月12日'), findsOneWidget);
    expect(find.text('未実施'), findsOneWidget);
    final neverDoneRow = find.ancestor(
      of: find.text('歯ブラシ交換'),
      matching: find.byType(ItemCard),
    );
    final texts = tester.widgetList<Text>(
      find.descendant(of: neverDoneRow, matching: find.byType(Text)),
    );
    expect(texts.map((text) => text.data), ['歯ブラシ交換', '未実施', 'やった']);
  });

  testWidgets('各カードのやったボタンは幅と高さが56dp以上', (tester) async {
    await pumpItems(tester);
    final buttons = find.byType(DoneButton);
    expect(buttons, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      final size = tester.getSize(buttons.at(i));
      expect(size.width, greaterThanOrEqualTo(56));
      expect(size.height, greaterThanOrEqualTo(56));
    }
  });

  testWidgets('経過日数は項目名と日付より大きく太字で出る', (tester) async {
    await pumpItems(tester);
    final elapsed = tester.widget<Text>(find.text('4日前'));
    final name = tester.widget<Text>(find.text('美容院'));
    final lastDone = tester.widget<Text>(find.text('2026年9月12日'));
    expect(elapsed.style?.fontWeight, FontWeight.bold);
    expect(elapsed.style?.fontSize, greaterThan(name.style!.fontSize!));
    expect(elapsed.style?.fontSize, greaterThan(lastDone.style!.fontSize!));
  });

  testWidgets('一覧は必要なカードだけ構築する builder を使う', (tester) async {
    await pumpItems(tester);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
  });

  testWidgets('やったボタンは各カードの項目名より右にある', (tester) async {
    await pumpItems(tester);
    for (final name in ['美容院', '歯ブラシ交換']) {
      final row = find.ancestor(
        of: find.text(name),
        matching: find.byType(ItemCard),
      );
      final button = find.descendant(
        of: row,
        matching: find.byType(DoneButton),
      );
      expect(
        tester.getCenter(button).dx,
        greaterThan(tester.getCenter(find.text(name)).dx),
      );
    }
  });

  testWidgets('起動直後の home が一覧画面である', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.home, isA<HomeShell>());
    expect(find.byType(ItemListScreen), findsOneWidget);
  });

  testWidgets('項目が2件あれば FAB が1つ出る', (tester) async {
    await pumpItems(tester);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('空状態では FAB が出ない', (tester) async {
    await tester.pumpWidget(_app(repository, FakeClock(now)));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
  });
  Finder row(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(ItemCard));

  Finder rowText(String name, String text) =>
      find.descendant(of: row(name), matching: find.text(text));

  Future<void> record(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(of: row(name), matching: find.byType(DoneButton)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> undo(WidgetTester tester) async {
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();
  }

  testWidgets('記録で確認ダイアログが出ない', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('未実施のカードを記録すると今日になる', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(rowText('歯ブラシ交換', '未実施'), findsNothing);
    expect(rowText('歯ブラシ交換', '今日'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '2026年9月16日'), findsOneWidget);
  });

  testWidgets('記録後に取り消し導線が1つ出る', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('記録しました'), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
  });

  testWidgets('未実施の記録を取り消すと未実施に戻り日付が消える', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await undo(tester);
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '今日'), findsNothing);
    expect(rowText('歯ブラシ交換', '2026年9月16日'), findsNothing);
  });

  testWidgets('記録済みのカードは取り消すと元の日付に戻る', (tester) async {
    await pumpItems(tester);
    await record(tester, '美容院');
    expect(rowText('美容院', '今日'), findsOneWidget);
    await undo(tester);
    expect(rowText('美容院', '4日前'), findsOneWidget);
    expect(rowText('美容院', '2026年9月12日'), findsOneWidget);
  });

  testWidgets('カード2枚を続けて記録すると直近1件だけ取り消せる', (tester) async {
    await pumpItems(tester);
    await record(tester, '美容院');
    await record(tester, '歯ブラシ交換');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
    await undo(tester);
    expect(rowText('美容院', '今日'), findsOneWidget);
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
  });

  testWidgets('取り消し導線は4秒で消える', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('取り消す'), findsNothing);
  });

  testWidgets('書き込み失敗は一覧を残して伝える', (tester) async {
    await pumpItems(tester);
    repository.writeError = StateError('write failed');
    await record(tester, '歯ブラシ交換');
    expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
    expect(rowText('美容院', '4日前'), findsOneWidget);
    expect(find.byType(ItemCard), findsNWidgets(2));
    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
  });

  testWidgets('登録画面への遷移で取り消し導線を閉じる', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ItemAddScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('記録と取り消しは画面遷移を伴わない', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(ItemAddScreen), findsNothing);
    await undo(tester);
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(ItemAddScreen), findsNothing);
  });
  testWidgets('やったボタンでは編集画面が開かない', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(rowText('歯ブラシ交換', '今日'), findsOneWidget);
  });

  group('過去の日付で記録', () {
    Finder pickerText(String text) => find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text(text),
    );

    Future<void> openPicker(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日付を指定して記録'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    }

    Future<void> pickDay(WidgetTester tester, String day) async {
      await tester.tap(pickerText(day));
      await tester.pumpAndSettle();
      await tester.tap(pickerText('記録する'));
      await tester.pumpAndSettle();
    }

    testWidgets('詳細シートから日付を指定すると確認なしで記録される', (tester) async {
      await pumpItems(tester);
      await openPicker(tester, '歯ブラシ交換');
      await pickDay(tester, '14');
      expect(rowText('歯ブラシ交換', '2日前'), findsOneWidget);
      expect(find.text('9月14日で記録しました'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('日付の選択の最終日は今日', (tester) async {
      await pumpItems(tester);
      await openPicker(tester, '歯ブラシ交換');
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.lastDate.year, 2026);
      expect(picker.lastDate.month, 9);
      expect(picker.lastDate.day, 16);
    });

    testWidgets('過去日の記録を取り消すと未実施に戻る', (tester) async {
      await pumpItems(tester);
      await openPicker(tester, '歯ブラシ交換');
      await pickDay(tester, '14');
      expect(rowText('歯ブラシ交換', '2日前'), findsOneWidget);
      await tester.tap(find.text('取り消す'));
      await tester.pumpAndSettle();
      expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
    });

    testWidgets('日付の選択をキャンセルすると何も記録されない', (tester) async {
      await pumpItems(tester);
      await openPicker(tester, '歯ブラシ交換');
      await tester.tap(pickerText('キャンセル'));
      await tester.pumpAndSettle();
      expect(rowText('歯ブラシ交換', '未実施'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect((await repository.watchAll().first).last.recentDoneAts, isEmpty);
    });

    testWidgets('最新より古い日を記録しても経過日数は変わらない', (tester) async {
      await pumpItems(tester);
      await openPicker(tester, '美容院');
      await pickDay(tester, '10');
      expect(rowText('美容院', '4日前'), findsOneWidget);
      expect(find.text('9月10日で記録しました'), findsOneWidget);
      expect(
        (await repository.watchAll().first).first.recentDoneAts,
        hasLength(2),
      );
    });
  });

  testWidgets('カードタップで詳細シートが開き、取り消し導線が閉じる', (tester) async {
    await pumpItems(tester);
    await record(tester, '歯ブラシ交換');
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('美容院'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailSheet), findsOneWidget);
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('取り消す'), findsNothing);
  });

  testWidgets('詳細シートの編集から編集画面へ遷移する', (tester) async {
    await pumpItems(tester);
    await tester.tap(find.text('美容院'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('編集'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemEditScreen), findsOneWidget);
    expect(find.byType(ItemDetailSheet), findsNothing);
  });

  testWidgets('詳細シートを閉じると一覧に戻る', (tester) async {
    await pumpItems(tester);
    await tester.tap(find.text('美容院'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailSheet), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailSheet), findsNothing);
    expect(find.byType(ItemEditScreen), findsNothing);
    expect(find.byType(ItemListScreen), findsOneWidget);
  });
  group('並び順(F30)', () {
    Future<void> pumpOrderedItems(WidgetTester tester) async {
      final car = await repository.add('車の点検', now: now);
      await repository.add('美容院', now: now);
      final bath = await repository.add('風呂掃除', now: now);
      for (final days in [540, 360, 180]) {
        await repository.markDone(car.id, now.subtract(Duration(days: days)));
      }
      for (final days in [28, 21, 14]) {
        await repository.markDone(bath.id, now.subtract(Duration(days: days)));
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
    }

    Future<void> recordBath(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ItemCard, '風呂掃除'),
          matching: find.byType(DoneButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String name) =>
        tester.getTopLeft(find.text(name)).dy;

    testWidgets('14日前の風呂掃除が180日前の車の点検より上で未実施は末尾', (tester) async {
      await pumpOrderedItems(tester);
      expect(find.text('14日前'), findsOneWidget);
      expect(find.text('180日前'), findsOneWidget);
      expect(top(tester, '風呂掃除'), lessThan(top(tester, '車の点検')));
      expect(top(tester, '車の点検'), lessThan(top(tester, '美容院')));
    });

    testWidgets('記録してもカードの位置が変わらず今日と取り消しが表示される', (tester) async {
      await pumpOrderedItems(tester);
      final before = top(tester, '風呂掃除');
      await recordBath(tester);
      expect(top(tester, '風呂掃除'), before);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('取り消す'), findsOneWidget);
    });

    testWidgets('記録後にアプリが復帰すると風呂掃除が車の点検より下になる', (tester) async {
      await pumpOrderedItems(tester);
      await recordBath(tester);
      expect(top(tester, '風呂掃除'), lessThan(top(tester, '車の点検')));
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(top(tester, '車の点検'), lessThan(top(tester, '風呂掃除')));
      expect(top(tester, '風呂掃除'), lessThan(top(tester, '美容院')));
    });
  });

  group('カテゴリの絞り込み(F13)', () {
    late FakeCategoryRepository categoryRepository;

    setUp(() {
      categoryRepository = FakeCategoryRepository(items: repository);
      addTearDown(categoryRepository.dispose);
    });

    Future<void> pumpWithCategories(WidgetTester tester) async {
      final health = await categoryRepository.add('健康');
      await categoryRepository.add('趣味');
      await repository.add('美容院', categoryId: health.id, now: now);
      await repository.add('歯ブラシ交換', now: now);
      await tester.pumpWidget(
        _app(
          repository,
          FakeClock(now),
          categoryRepository: categoryRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('カテゴリ 0 件ならチップが出ない', (tester) async {
      await pumpItems(tester);
      await tester.pumpWidget(
        _app(
          repository,
          FakeClock(now),
          categoryRepository: categoryRepository,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFilterBar), findsNothing);
    });

    testWidgets('絞り込むと該当だけが残り並びは維持される', (tester) async {
      await pumpWithCategories(tester);
      expect(find.text('美容院'), findsOneWidget);
      expect(find.text('歯ブラシ交換'), findsOneWidget);
      await tester.tap(find.text('健康'));
      await tester.pumpAndSettle();
      expect(find.text('美容院'), findsOneWidget);
      expect(find.text('歯ブラシ交換'), findsNothing);
    });

    testWidgets('該当が 0 件になると専用の文言が出る', (tester) async {
      await pumpWithCategories(tester);
      await tester.tap(find.text('趣味'));
      await tester.pumpAndSettle();
      expect(find.text('このカテゴリの項目はありません'), findsOneWidget);
    });

    testWidgets('選択中のカテゴリを削除すると全件表示に戻る', (tester) async {
      final health = await categoryRepository.add('健康');
      await repository.add('美容院', categoryId: health.id, now: now);
      await repository.add('歯ブラシ交換', now: now);
      await tester.pumpWidget(
        _app(
          repository,
          FakeClock(now),
          categoryRepository: categoryRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('健康'));
      await tester.pumpAndSettle();
      expect(find.text('歯ブラシ交換'), findsNothing);
      await categoryRepository.delete(health.id);
      await tester.pumpAndSettle();
      expect(find.text('美容院'), findsOneWidget);
      expect(find.text('歯ブラシ交換'), findsOneWidget);
    });

    testWidgets('絞り込み中に FAB から開いた登録画面でそのカテゴリが選択済みになる', (tester) async {
      await pumpWithCategories(tester);
      await tester.tap(find.text('健康'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '健康'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('AppBar のボタンから管理画面へ遷移する', (tester) async {
      await pumpWithCategories(tester);
      await tester.tap(find.byTooltip('カテゴリを管理'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryManageScreen), findsOneWidget);
    });
  });
  group('並び順の選択(F15)', () {
    Future<void> pumpOrderedItems(WidgetTester tester) async {
      final car = await repository.add('車の点検', now: now);
      await repository.add('美容院', now: now);
      final bath = await repository.add('風呂掃除', now: now);
      for (final days in [540, 360, 180]) {
        await repository.markDone(car.id, now.subtract(Duration(days: days)));
      }
      for (final days in [28, 21, 14]) {
        await repository.markDone(bath.id, now.subtract(Duration(days: days)));
      }
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
    }

    Future<void> recordBath(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ItemCard, '風呂掃除'),
          matching: find.byType(DoneButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String name) =>
        tester.getTopLeft(find.text(name)).dy;

    Future<void> selectOrder(WidgetTester tester, String label) async {
      await tester.tap(find.byTooltip('並び順'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    CheckedPopupMenuItem<ItemSortOrder> menuItem(
      WidgetTester tester,
      String label,
    ) => tester.widget<CheckedPopupMenuItem<ItemSortOrder>>(
      find.widgetWithText(CheckedPopupMenuItem<ItemSortOrder>, label),
    );

    testWidgets('項目があると並び順ボタンが出て空のときは出ない', (tester) async {
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      expect(find.byTooltip('並び順'), findsNothing);
      await pumpOrderedItems(tester);
      expect(find.byTooltip('並び順'), findsOneWidget);
    });
    testWidgets('メニューに4つの並び順が出て経年順にチェックが付いている', (tester) async {
      await pumpOrderedItems(tester);
      await tester.tap(find.byTooltip('並び順'));
      await tester.pumpAndSettle();
      for (final label in ['経年順', '経過日数順', '名前順', '登録順']) {
        expect(find.text(label), findsOneWidget);
        expect(menuItem(tester, label).checked, label == '経年順');
      }
    });
    testWidgets('登録順を選ぶと登録した順に並ぶ', (tester) async {
      await pumpOrderedItems(tester);
      await selectOrder(tester, '登録順');
      expect(top(tester, '車の点検'), lessThan(top(tester, '美容院')));
      expect(top(tester, '美容院'), lessThan(top(tester, '風呂掃除')));
    });
    testWidgets('経過日数順で記録してもカードの位置が変わらない', (tester) async {
      await pumpOrderedItems(tester);
      await selectOrder(tester, '経過日数順');
      final before = top(tester, '風呂掃除');
      await recordBath(tester);
      expect(top(tester, '風呂掃除'), before);
      expect(find.text('今日'), findsOneWidget);
    });
    testWidgets('絞り込みと併用しても選んだ並びを保つ', (tester) async {
      final categories = FakeCategoryRepository(items: repository);
      addTearDown(categories.dispose);
      final category = await categories.add('家のこと');
      final car = await repository.add(
        '車の点検',
        categoryId: category.id,
        now: now,
      );
      await repository.add('美容院', now: now);
      final bath = await repository.add(
        '風呂掃除',
        categoryId: category.id,
        now: now,
      );
      for (final days in [540, 360, 180]) {
        await repository.markDone(car.id, now.subtract(Duration(days: days)));
      }
      for (final days in [28, 21, 14]) {
        await repository.markDone(bath.id, now.subtract(Duration(days: days)));
      }
      await tester.pumpWidget(
        _app(repository, FakeClock(now), categoryRepository: categories),
      );
      await tester.pumpAndSettle();
      expect(top(tester, '風呂掃除'), lessThan(top(tester, '車の点検')));
      await selectOrder(tester, '登録順');
      await tester.tap(find.text('家のこと'));
      await tester.pumpAndSettle();
      expect(find.text('美容院'), findsNothing);
      expect(top(tester, '車の点検'), lessThan(top(tester, '風呂掃除')));
    });
    testWidgets('選び直した並び順にチェックが移る', (tester) async {
      await pumpOrderedItems(tester);
      await selectOrder(tester, '名前順');
      await tester.tap(find.byTooltip('並び順'));
      await tester.pumpAndSettle();
      expect(menuItem(tester, '名前順').checked, isTrue);
      expect(menuItem(tester, '経年順').checked, isFalse);
    });
  });
}
