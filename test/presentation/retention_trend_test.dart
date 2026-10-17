import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/stats/stats_view.dart';

/// The note under the retention gauges (D-094): this week against the
/// 90-day average, only with 20+ answers this week and 3+ points apart.
void main() {
  test('better by enough: the difference in points', () {
    expect(retentionTrend((20, 18), (100, 84)), 6); // 90 % vs 84 %
  });
  test('worse by enough: a negative difference', () {
    expect(retentionTrend((40, 30), (200, 160)), -5); // 75 % vs 80 %
  });
  test('exactly 3 points counts, 2 does not', () {
    expect(retentionTrend((100, 83), (100, 80)), 3);
    expect(retentionTrend((100, 82), (100, 80)), isNull);
    expect(retentionTrend((100, 77), (100, 80)), -3);
  });
  test('fewer than 20 answers this week says nothing', () {
    expect(retentionTrend((19, 19), (100, 50)), isNull);
    expect(retentionTrend((20, 20), (100, 50)), 50);
  });
  test('no history says nothing', () {
    expect(retentionTrend((30, 25), (0, 0)), isNull);
  });
}
