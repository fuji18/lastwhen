/// 現在時刻を返す唯一の口。
///
/// 経過日数はこのプロダクトの中心機能で、境界(日またぎ・月末・うるう年・夏時間)の
/// 検証が要る。`DateTime.now()` を直に呼ぶとテストが書けない。
abstract interface class Clock {
  /// 現在時刻(UTC)。
  DateTime now();
}

/// 端末の時計を使う [Clock]。
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
