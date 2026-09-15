import 'package:lastwhen/domain/clock.dart';

/// 任意の時刻を返す [Clock]。
///
/// テスト内で `DateTime.now()` を呼ぶと、実行した瞬間によって結果が変わるテストになる。
final class FakeClock implements Clock {
  FakeClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// 返す時刻を差し替える。
  void advanceTo(DateTime value) => _now = value;
}
