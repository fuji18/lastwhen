import 'package:intl/intl.dart';

// 別名を付ける: `baselineIntervalDays` / `previousIntervalDays` / `relativeElapsed`
// はこのファイルのフィールド名(`ItemView` 判断7)と同じ名前(design.md の用語に揃えた結果)。
// 衝突を避けるため常に `baseline.` を付けて呼ぶ。
import '../domain/baseline_interval.dart' as baseline;
import '../domain/elapsed_days.dart';
import '../domain/item.dart';

/// 最終実施日の表示フォーマット(`2026年9月12日`)。
///
/// **ロケールを渡さない。** `年` `月` `日` は ASCII 英字ではないためパターン文字にならず、
/// リテラルとして出力される。整形されるのは数値フィールドだけなので、ロケール依存の
/// シンボル(曜日名・月名)を引かず、`initializeDateFormatting` も要らない。
final DateFormat _lastDoneFormat = DateFormat('y年M月d日');

/// UI が描画に必要とするものだけを持つ表示モデル。
///
/// **`DateTime` を持たない。** 「UTC で保存された日時をローカルの暦日として読む」という
/// 解釈を状態管理層に閉じ、UI に漏らさない(`docs/functional-design.md`「コンポーネント設計」)。
final class ItemView {
  /// 表示モデルを組み立てる。通常は [ItemView.from] を使う。
  const ItemView({
    required this.id,
    required this.name,
    required this.elapsed,
    required this.lastDoneText,
    this.previousIntervalDays,
    this.baselineIntervalDays,
    this.relativeElapsed,
  });

  /// ドメインの [Item] を [now] 時点の表示モデルへ変換する。
  factory ItemView.from(Item item, {required DateTime now}) {
    final lastDoneAt = item.lastDoneAt;
    final baselineDays = baseline.baselineIntervalDays(item.recentDoneAts);
    return ItemView(
      id: item.id,
      name: item.name,
      elapsed: elapsedLabel(lastDoneAt: lastDoneAt, now: now),
      // UTC のまま整形すると、ローカルの暦日で数える経過日数と別の日を指す行が出る。
      lastDoneText: lastDoneAt == null
          ? null
          : _lastDoneFormat.format(lastDoneAt.toLocal()),
      previousIntervalDays: baseline.previousIntervalDays(item.recentDoneAts),
      baselineIntervalDays: baselineDays,
      relativeElapsed: baseline.relativeElapsed(
        elapsedDays: lastDoneAt == null
            ? null
            : elapsedDays(lastDoneAt: lastDoneAt, now: now),
        baselineIntervalDays: baselineDays,
      ),
    );
  }

  /// 対象の項目 ID。
  final ItemId id;

  /// 項目名。
  final String name;

  /// 経過日数の表示ラベル。**文字列への変換は UI 層が行う。**
  final ElapsedLabel elapsed;

  /// 最後にやった日(`2026年9月12日`)。**未実施なら null**。
  final String? lastDoneText;

  /// 前回間隔(日)。記録 1 件以下なら null。
  final int? previousIntervalDays;

  /// 基準間隔(日)。記録 1 件以下なら null。画面上の呼び名は「平均」。
  final double? baselineIntervalDays;

  /// 相対経過度(経過日数 ÷ 基準間隔)。基準間隔が null・未実施なら null。
  final double? relativeElapsed;

  @override
  bool operator ==(Object other) =>
      other is ItemView &&
      other.id == id &&
      other.name == name &&
      other.elapsed == elapsed &&
      other.lastDoneText == lastDoneText &&
      other.previousIntervalDays == previousIntervalDays &&
      other.baselineIntervalDays == baselineIntervalDays &&
      other.relativeElapsed == relativeElapsed;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    elapsed,
    lastDoneText,
    previousIntervalDays,
    baselineIntervalDays,
    relativeElapsed,
  );
}

/// 一覧をまとめて表示モデルへ変換する。
///
/// **[now] を引数で受け取り、1 回の変換につき 1 つに固定する。** 行ごとに `Clock.now()` を
/// 呼ぶと、描画中に日付をまたいだとき行間で基準時刻が食い違う
/// (`docs/functional-design.md`「パフォーマンス最適化」)。
List<ItemView> toItemViews(List<Item> items, {required DateTime now}) =>
    items.map((item) => ItemView.from(item, now: now)).toList(growable: false);
