import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/clock.dart';

import '../support/fake_clock.dart';

void main() {
  group('SystemClock', () {
    test('SystemClock は UTC の現在時刻を返す', () {
      const clock = SystemClock();
      final before = DateTime.now().toUtc();
      final result = clock.now();
      final after = DateTime.now().toUtc();

      expect(result.isUtc, isTrue);
      expect(result.isAfter(before) || result.isAtSameMomentAs(before), isTrue);
      expect(result.isBefore(after) || result.isAtSameMomentAs(after), isTrue);
    });
  });

  group('FakeClock', () {
    test('FakeClock は与えた時刻を返し続ける', () {
      final fixed = DateTime.utc(2026, 1, 10, 3, 0);
      final clock = FakeClock(fixed);

      expect(clock.now(), fixed);
      expect(clock.now(), fixed);
    });

    test('FakeClock は時刻を差し替えられる', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 10, 3, 0));
      final next = DateTime.utc(2026, 1, 11, 3, 0);

      clock.advanceTo(next);

      expect(clock.now(), next);
    });
  });
}
