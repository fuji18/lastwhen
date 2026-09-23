/// 経年ステージ。相対経過度から判定する。
enum AgingStage {
  /// 真新しい。相対経過度が null のときもこれ。
  fresh,

  /// 少し経過(0.5 以上 1.0 未満)。
  slightlyAged,

  /// そろそろ(1.0 以上 1.5 未満)。
  dueSoon,

  /// 経過(1.5 以上 2.0 未満)。
  aged,

  /// かなり経過(2.0 以上)。
  heavilyAged,
}

/// 相対経過度から判定する。境界は下側を含む。
///
/// 基準間隔が分からない null は fresh。絶対日数で代用しない。
AgingStage agingStageOf(double? relativeElapsed) => switch (relativeElapsed) {
  null => AgingStage.fresh,
  < 0.5 => AgingStage.fresh,
  < 1.0 => AgingStage.slightlyAged,
  < 1.5 => AgingStage.dueSoon,
  < 2.0 => AgingStage.aged,
  _ => AgingStage.heavilyAged,
};
