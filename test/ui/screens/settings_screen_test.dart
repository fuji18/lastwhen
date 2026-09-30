import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/app_info.dart';
import 'package:lastwhen/ui/screens/category_manage_screen.dart';
import 'package:lastwhen/ui/screens/item_list_screen.dart';
import 'package:lastwhen/ui/screens/settings_screen.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';

import '../../support/fake_category_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_item_repository.dart';

Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  FakeCategoryRepository? categoryRepository,
  double textScale = 1,
}) => MediaQuery(
  data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
  child: ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(
        categoryRepository ?? FakeCategoryRepository(),
      ),
      clockProvider.overrideWithValue(clock),
    ],
    child: const App(),
  ),
);

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text('設定')),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

/// `Clipboard.setData` を受け止めるモックを入れ、写された文字列を返す関数を返す。
String? Function() _mockClipboard(WidgetTester tester) {
  String? copiedText;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText =
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
  return () => copiedText;
}

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

  testWidgets('起動直後はホームで下部ナビにホーム・図鑑・設定がある', (tester) async {
    await pumpItems(tester);
    expect(find.byType(ItemListScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    for (final label in ['ホーム', '図鑑', '設定']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('設定にカテゴリ管理・注意事項・アプリ情報が表示される', (tester) async {
    await pumpItems(tester);
    await _openSettings(tester);
    for (final label in [
      'カテゴリの管理',
      '注意事項',
      '項目と記録は、この端末の中にだけ保存されます。アプリがインターネットへ送信することはありません。',
      'アプリを削除すると、項目と記録もすべて消えます。',
      '端末のバックアップ(Android の自動バックアップなど)が有効な場合は、機種変更で引き継げるように、項目と記録の複製が OS の提供元のクラウドに保存されます。',
      'このアプリについて',
      'プライバシーポリシー',
      AppInfo.privacyPolicyUrl,
      'バージョン',
      AppInfo.versionName,
      'ライセンス',
    ]) {
      await _scrollTo(tester, find.text(label));
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('カテゴリの管理から管理画面が開く', (tester) async {
    await pumpItems(tester);
    await _openSettings(tester);
    await tester.tap(find.text('カテゴリの管理'));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryManageScreen), findsOneWidget);
  });

  testWidgets('URL をコピーするとクリップボードに入り完了を知らせる', (tester) async {
    await pumpItems(tester);
    await _openSettings(tester);
    final copied = _mockClipboard(tester);
    await _scrollTo(tester, find.byTooltip('URL をコピー'));
    await tester.tap(find.byTooltip('URL をコピー'));
    await tester.pumpAndSettle();
    expect(copied(), AppInfo.privacyPolicyUrl);
    expect(find.widgetWithText(SnackBar, 'URL をコピーしました'), findsOneWidget);
  });

  testWidgets('コピー後にホームへ移って設定に戻ると SnackBar が無い', (tester) async {
    await pumpItems(tester);
    await _openSettings(tester);
    _mockClipboard(tester);
    await _scrollTo(tester, find.byTooltip('URL をコピー'));
    await tester.tap(find.byTooltip('URL をコピー'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('ホーム'),
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ライセンスをタップすると LicensePage が開く', (tester) async {
    await pumpItems(tester);
    await _openSettings(tester);
    await _scrollTo(tester, find.text('ライセンス'));
    await tester.tap(find.text('ライセンス'));
    // ライセンスの読み込み中はインジケータが回るため settle を待たない。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('ホームで記録した直後に設定を開くと取り消し導線が消え例外が出ない', (tester) async {
    await pumpItems(tester);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ItemCard, '歯ブラシ交換'),
        matching: find.byType(DoneButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    await _openSettings(tester);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一覧の AppBar にカテゴリを管理のボタンが無い', (tester) async {
    await pumpItems(tester);
    expect(find.byTooltip('カテゴリを管理'), findsNothing);
  });
}
