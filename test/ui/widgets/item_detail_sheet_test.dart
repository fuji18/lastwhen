import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';
import 'package:lastwhen/domain/elapsed_days.dart';
import 'package:lastwhen/domain/item.dart';
import 'package:lastwhen/state/item_view.dart';
import 'package:lastwhen/ui/theme/app_theme.dart';
import 'package:lastwhen/ui/widgets/done_button.dart';
import 'package:lastwhen/ui/widgets/item_detail_sheet.dart';

ItemView _view({
  ElapsedLabel elapsed = const DaysAgo(14),
  String? lastDoneText = '2026年9月9日',
  int? previousIntervalDays = 7,
  double? baselineIntervalDays = 7,
  double? relativeElapsed = 2,
  AgingStage stage = AgingStage.heavilyAged,
}) => ItemView(
  id: const ItemId('item-1'),
  name: '美容院',
  elapsed: elapsed,
  lastDoneText: lastDoneText,
  previousIntervalDays: previousIntervalDays,
  baselineIntervalDays: baselineIntervalDays,
  relativeElapsed: relativeElapsed,
  agingStage: stage,
);

Widget _app(ItemView item, {VoidCallback? onEditPressed}) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: ItemDetailSheet(item: item, onEditPressed: onEditPressed ?? () {}),
  ),
);

void main() {
  group('文言', () {
    for (final (elapsed, expected) in <(ElapsedLabel, String)>[
      (const NeverDone(), 'まだ記録がありません'),
      (const Today(), '最後：今日'),
      (const Yesterday(), '最後：昨日'),
      (const DaysAgo(14), '最後：14日前'),
    ]) {
      test(expected, () => expect(detailLastDoneLine(elapsed), expected));
    }
    test('前回間隔がないときは行を出さない', () {
      expect(detailPreviousIntervalLine(null), isNull);
    });
    test('前回間隔を日単位で示す', () {
      expect(detailPreviousIntervalLine(7), '前回：7日間隔');
    });
    const hints = {
      AgingStage.fresh: null,
      AgingStage.slightlyAged: null,
      AgingStage.dueSoon: 'そろそろかも。',
      AgingStage.aged: 'いつもより間が空いているかも。',
      AgingStage.heavilyAged: 'だいぶ間が空いているかも。',
    };
    for (final entry in hints.entries) {
      test('${entry.key} の一言', () {
        expect(agingStageHintText(entry.key), entry.value);
      });
    }
  });

  testWidgets('通常の3行を表示する', (tester) async {
    await tester.pumpWidget(_app(_view()));
    expect(find.text('最後：14日前'), findsOneWidget);
    expect(find.text('前回：7日間隔'), findsOneWidget);
    expect(find.text('だいぶ間が空いているかも。'), findsOneWidget);
  });

  testWidgets('そろそろの一言を表示する', (tester) async {
    await tester.pumpWidget(
      _app(_view(relativeElapsed: 1.2, stage: AgingStage.dueSoon)),
    );
    expect(find.text('そろそろかも。'), findsOneWidget);
  });

  testWidgets('未実施では記録がないことだけを表示する', (tester) async {
    await tester.pumpWidget(
      _app(
        const ItemView(
          id: ItemId('never'),
          name: '美容院',
          elapsed: NeverDone(),
          lastDoneText: null,
        ),
      ),
    );
    expect(find.text('まだ記録がありません'), findsOneWidget);
    expect(find.textContaining('最後：'), findsNothing);
    expect(find.textContaining('前回：'), findsNothing);
    expect(find.textContaining('かも。'), findsNothing);
  });

  testWidgets('未実施なら間隔とステージがあっても追加の行を出さない', (tester) async {
    await tester.pumpWidget(
      _app(_view(elapsed: const NeverDone(), lastDoneText: null)),
    );
    expect(find.text('まだ記録がありません'), findsOneWidget);
    expect(find.textContaining('前回：'), findsNothing);
    expect(find.textContaining('かも。'), findsNothing);
  });

  testWidgets('記録1件のみなら最後の行だけを表示する', (tester) async {
    await tester.pumpWidget(
      _app(
        _view(
          elapsed: const DaysAgo(3),
          previousIntervalDays: null,
          baselineIntervalDays: null,
          relativeElapsed: null,
          stage: AgingStage.fresh,
        ),
      ),
    );
    expect(find.text('最後：3日前'), findsOneWidget);
    expect(find.textContaining('前回：'), findsNothing);
    expect(find.textContaining('かも。'), findsNothing);
  });

  testWidgets('相対経過度1.0未満なら一言を出さない', (tester) async {
    await tester.pumpWidget(
      _app(
        _view(
          elapsed: const DaysAgo(5),
          relativeElapsed: 5 / 7,
          stage: AgingStage.slightlyAged,
        ),
      ),
    );
    expect(find.text('最後：5日前'), findsOneWidget);
    expect(find.text('前回：7日間隔'), findsOneWidget);
    expect(find.textContaining('かも。'), findsNothing);
  });

  testWidgets('情報は3行までで基準間隔を出さない', (tester) async {
    await tester.pumpWidget(_app(_view()));
    expect(
      find.descendant(
        of: find.byType(ItemDetailSheet),
        matching: find.byType(Text),
      ),
      findsNWidgets(5),
    );
    expect(find.textContaining('7.0'), findsNothing);
    expect(find.textContaining('平均'), findsNothing);
  });

  testWidgets('削除とやったの入口を置かない', (tester) async {
    await tester.pumpWidget(_app(_view()));
    expect(find.text('削除'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byType(DoneButton), findsNothing);
  });

  testWidgets('編集ボタンはコールバックを1回呼ぶ', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(_view(), onEditPressed: () => calls++));
    await tester.tap(find.text('編集'));
    expect(calls, 1);
  });

  testWidgets('各行を独立して読み上げ、項目名を見出しにする', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    await tester.pumpWidget(_app(_view()));
    for (final line in ['最後：14日前', '前回：7日間隔', 'だいぶ間が空いているかも。']) {
      expect(find.bySemanticsLabel(line), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.text('美容院')).flagsCollection.isHeader,
      isTrue,
    );
  });
}
