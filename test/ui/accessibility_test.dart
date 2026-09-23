import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderObject, RenderParagraph;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/app.dart';
import 'package:lastwhen/domain/clock.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/domain/item_repository.dart';
import 'package:lastwhen/state/providers.dart';
import 'package:lastwhen/ui/screens/item_add_screen.dart';
import 'package:lastwhen/ui/screens/item_edit_screen.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/item_card.dart';

import '../support/fake_clock.dart';
import '../support/fake_item_repository.dart';

Widget _app(
  FakeItemRepository repository,
  Clock clock, {
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) => MediaQuery(
  data: MediaQueryData(
    textScaler: TextScaler.linear(textScale),
    platformBrightness: brightness,
  ),
  child: ProviderScope(
    overrides: [
      itemRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(clock),
    ],
    child: const App(),
  ),
);

/// 親ノードへマージされたラベルも、配信されるツリーから検査する。
List<String> _semanticsLabels(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) {
      labels.add(node.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return labels;
}

/// 省略された文字列を描画結果から集め、レイアウトの退行を検出する。
List<String> _ellipsizedTexts(WidgetTester tester) {
  final found = <String>[];
  void visit(RenderObject object) {
    if (object is RenderParagraph && object.didExceedMaxLines) {
      found.add(object.text.toPlainText());
    }
    object.visitChildren(visit);
  }

  visit(tester.binding.renderViews.first);
  return found;
}

void _setScreenSize(WidgetTester tester, {double height = 640}) {
  tester.view.physicalSize = Size(360 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// 読み込み中を維持し、インジケータの意味情報を検査する。
final class _NeverEmittingRepository implements ItemRepository {
  @override
  Stream<List<Item>> watchAll() =>
      Stream<List<Item>>.fromFuture(Completer<List<Item>>().future);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailingRepository implements ItemRepository {
  @override
  Stream<List<Item>> watchAll() =>
      Stream<List<Item>>.error(StateError('DB オープン失敗'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // ローカルの暦日を固定するため、UTC の時差に依存させない。
  final now = DateTime(2026, 9, 16, 12);
  late FakeItemRepository repository;
  setUp(() {
    repository = FakeItemRepository();
    addTearDown(repository.dispose);
  });

  Future<void> seedItems() async {
    final item = await repository.add('美容院', now: now);
    await repository.markDone(item.id, DateTime(2026, 9, 12, 12));
    await repository.add('歯ブラシ交換', now: now);
  }

  group('アクセシビリティ', () {
    test('コントラスト比が light / dark の全ペアで WCAG AA を満たす', () {
      double linear(double channel) => channel <= 0.04045
          ? channel / 12.92
          : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
      double luminance(Color color) =>
          0.2126 * linear(color.r) +
          0.7152 * linear(color.g) +
          0.0722 * linear(color.b);
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final colors = theme.colorScheme;
        final pairs = <String, (Color, Color)>{
          '本文': (colors.onSurface, colors.surface),
          '補助文字': (colors.onSurfaceVariant, colors.surface),
          'やった': (colors.onSecondaryContainer, colors.secondaryContainer),
          '保存': (colors.onPrimary, colors.primary),
          'FAB': (colors.onPrimaryContainer, colors.primaryContainer),
          '削除': (colors.error, colors.surface),
          'ダイアログ': (colors.onSurface, colors.surfaceContainerHigh),
          'SnackBar': (colors.onInverseSurface, colors.inverseSurface),
          'SnackBar アクション': (colors.inversePrimary, colors.inverseSurface),
        };
        for (final entry in pairs.entries) {
          final a = luminance(entry.value.$1);
          final b = luminance(entry.value.$2);
          expect(
            (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05),
            greaterThanOrEqualTo(4.5),
            reason: '${theme.brightness}: ${entry.key}',
          );
        }
      }
    });

    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('文字サイズ ${scale * 100}% で一覧の文字が省略されない', (tester) async {
        _setScreenSize(tester);
        await seedItems();
        await tester.pumpWidget(
          _app(repository, FakeClock(now), textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(find.text('美容院'), findsOneWidget);
        expect(find.text('歯ブラシ交換'), findsOneWidget);
        expect(find.text('4日前'), findsOneWidget);
        expect(find.text('未実施'), findsOneWidget);
        expect(_ellipsizedTexts(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('項目名が長い場合だけ 2 行まで表示して省略する', (tester) async {
      _setScreenSize(tester);
      final name = List.filled(40, 'あ').join();
      final item = await repository.add(name, now: now);
      await repository.markDone(item.id, DateTime(2026, 9, 12, 12));
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(name)).maxLines, 2);
      expect(_ellipsizedTexts(tester), [name]);
      expect(tester.takeException(), isNull);
    });

    for (final isEditing in [false, true]) {
      testWidgets('文字サイズ 200% で${isEditing ? '編集' : '登録'}画面が破綻しない', (
        tester,
      ) async {
        _setScreenSize(tester, height: 320);
        final item = await repository.add('美容院', now: now);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ProviderScope(
              overrides: [
                itemRepositoryProvider.overrideWithValue(repository),
                clockProvider.overrideWithValue(FakeClock(now)),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                home: isEditing
                    ? ItemEditScreen(itemId: item.id, initialName: item.name)
                    : const ItemAddScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(_ellipsizedTexts(tester), isEmpty);
        expect(tester.takeException(), isNull);
        // 短い画面でも末尾の操作まで到達できることを確認する。
        final action = find.text(isEditing ? '削除' : '保存');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('文字サイズ ${scale * 100}% でやったは56dp以上、カードは48dp以上', (
        tester,
      ) async {
        _setScreenSize(tester);
        await seedItems();
        await tester.pumpWidget(
          _app(repository, FakeClock(now), textScale: scale),
        );
        await tester.pumpAndSettle();
        final size = tester.getSize(find.byType(DoneButton).first);
        expect(size.width, greaterThanOrEqualTo(56));
        expect(size.height, greaterThanOrEqualTo(56));
        expect(
          tester.getSize(find.byType(ItemCard).first).height,
          greaterThanOrEqualTo(48),
        );
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('文字サイズ ${scale * 100}% でやったボタンと項目追加ボタンが画面の右半分にある', (
        tester,
      ) async {
        _setScreenSize(tester);
        await seedItems();
        await tester.pumpWidget(
          _app(repository, FakeClock(now), textScale: scale),
        );
        await tester.pumpAndSettle();
        final midpoint = tester.getSize(find.byType(Scaffold)).width / 2;
        expect(
          tester.getCenter(find.byType(DoneButton).first).dx,
          greaterThan(midpoint),
        );
        expect(
          tester.getCenter(find.byType(FloatingActionButton)).dx,
          greaterThan(midpoint),
        );
      });
    }

    testWidgets('dark テーマでも一覧が破綻しない', (tester) async {
      _setScreenSize(tester);
      await seedItems();
      await tester.pumpWidget(
        _app(repository, FakeClock(now), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(ItemCard).first)).brightness,
        Brightness.dark,
      );
      expect(_ellipsizedTexts(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('文字サイズ ${scale * 100}% でカードに項目名と最終実施日と経過日数を含む読み上げラベルがある', (
        tester,
      ) async {
        _setScreenSize(tester);
        final handle = tester.ensureSemantics();
        await seedItems();
        await tester.pumpWidget(
          _app(repository, FakeClock(now), textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(_semanticsLabels(tester), contains('美容院、最終実施日は2026年9月12日、4日経過'));
        expect(_semanticsLabels(tester), contains('歯ブラシ交換、未実施'));
        handle.dispose();
      });

      testWidgets('文字サイズ ${scale * 100}% でやったボタンの読み上げラベルに項目名が含まれる', (
        tester,
      ) async {
        _setScreenSize(tester);
        final handle = tester.ensureSemantics();
        await seedItems();
        await tester.pumpWidget(
          _app(repository, FakeClock(now), textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(_semanticsLabels(tester), contains('美容院をやったと記録'));
        expect(_semanticsLabels(tester), contains('歯ブラシ交換をやったと記録'));
        handle.dispose();
      });
    }

    testWidgets('読み込み中のインジケータにラベルがある', (tester) async {
      _setScreenSize(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itemRepositoryProvider.overrideWithValue(
              _NeverEmittingRepository(),
            ),
            clockProvider.overrideWithValue(FakeClock(now)),
          ],
          child: const App(),
        ),
      );
      expect(_semanticsLabels(tester), contains('読み込み中'));
      handle.dispose();
    });

    testWidgets('空状態の装飾アイコンは読み上げ対象から外れている', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(_app(repository, FakeClock(now)));
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byIcon(Icons.inbox_outlined),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });

    testWidgets('読み込みエラーの装飾アイコンは読み上げ対象から外れている', (tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itemRepositoryProvider.overrideWithValue(_FailingRepository()),
            clockProvider.overrideWithValue(FakeClock(now)),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.byIcon(Icons.error_outline),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}
