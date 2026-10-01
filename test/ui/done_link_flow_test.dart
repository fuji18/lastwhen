import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/done_link.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/item_detail_screen.dart';
import 'package:lastwhen/ui/done_link_receiver.dart';

import '../support/fake_category_repository.dart';
import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

void main() {
  final now = DateTime.utc(2026, 9, 16, 3);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Widget app(DoneLinkReceiver receiver) => ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(FakeCategoryRepository()),
      clockProvider.overrideWithValue(FakeClock(now)),
    ],
    child: App(doneLinks: receiver),
  );

  Future<void> push(WidgetTester tester, DoneLinkReceiver r, String url) async {
    await r.didPushRouteInformation(RouteInformation(uri: Uri.parse(url)));
    await tester.pumpAndSettle();
  }

  Future<DateTime?> lastDoneAt() async =>
      (await repository.watchAll().first).single.lastDoneAt;

  testWidgets('コールドスタートのリンクで記録し、確認は出さない', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver(
      initialRoute: doneLinkFor(item.id).toString(),
    );
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();

    expect(find.text('「美容院」を記録しました'), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await lastDoneAt(), now);
  });

  testWidgets('起動中に届いたリンクで記録する', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await push(tester, receiver, doneLinkFor(item.id).toString());

    expect(find.text('「美容院」を記録しました'), findsOneWidget);
    expect(find.text('取り消す'), findsOneWidget);
    expect(await lastDoneAt(), now);
  });

  testWidgets('取り消すと未実施に戻る', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver(
      initialRoute: doneLinkFor(item.id).toString(),
    );
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取り消す'));
    await tester.pumpAndSettle();

    expect(await lastDoneAt(), isNull);
  });

  testWidgets('今日すでに記録済みなら書き込まない', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    final url = doneLinkFor(item.id).toString();
    await push(tester, receiver, url);
    await push(tester, receiver, url);

    expect(find.text('「美容院」は今日すでに記録しています'), findsOneWidget);
    expect(await lastDoneAt(), now);
  });

  testWidgets('存在しない項目は見つからない', (tester) async {
    await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await push(tester, receiver, 'lastwhen://done/unknown');

    expect(find.text('この項目は見つかりませんでした'), findsOneWidget);
    expect(await lastDoneAt(), isNull);
  });

  testWidgets('形式が不正なリンクは見つからない', (tester) async {
    await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await push(tester, receiver, 'lastwhen://other/x');

    expect(find.text('この項目は見つかりませんでした'), findsOneWidget);
    expect(await lastDoneAt(), isNull);
  });

  testWidgets('図鑑タブ表示中でもホームへ戻りスナックバーが見える', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('図鑑'),
      ),
    );
    await tester.pumpAndSettle();
    await push(tester, receiver, doneLinkFor(item.id).toString());

    expect(find.text('「美容院」を記録しました'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('詳細画面を開いたままでも記録し、詳細画面に留まる', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    await tester.tap(find.text('美容院'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemDetailScreen), findsOneWidget);
    await push(tester, receiver, doneLinkFor(item.id).toString());

    expect(find.byType(ItemDetailScreen), findsOneWidget);
    expect(find.text('「美容院」を記録しました'), findsOneWidget);
  });

  testWidgets('書き込みに失敗したら保存できなかったと出す', (tester) async {
    final item = await repository.add('美容院', now: now);
    final receiver = DoneLinkReceiver();
    await tester.pumpWidget(app(receiver));
    await tester.pumpAndSettle();
    repository.writeError = StateError('boom');
    await push(tester, receiver, doneLinkFor(item.id).toString());

    expect(find.text('保存できませんでした。もう一度お試しください'), findsOneWidget);
  });
}
