import 'package:flutter_test/flutter_test.dart';
import 'package:lastwhen/domain/aging_stage.dart';

void main() {
  final cases = <double?, AgingStage>{
    0: AgingStage.fresh,
    0.49: AgingStage.fresh,
    0.5: AgingStage.slightlyAged,
    0.99: AgingStage.slightlyAged,
    1.0: AgingStage.dueSoon,
    1.49: AgingStage.dueSoon,
    1.5: AgingStage.aged,
    1.99: AgingStage.aged,
    2.0: AgingStage.heavilyAged,
    5.0: AgingStage.heavilyAged,
    null: AgingStage.fresh,
  };
  for (final entry in cases.entries) {
    test('相対経過度 ${entry.key} は ${entry.value.name}', () {
      expect(agingStageOf(entry.key), entry.value);
    });
  }
}
