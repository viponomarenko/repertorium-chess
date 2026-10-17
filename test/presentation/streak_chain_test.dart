import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/home/today_screen.dart';

/// The warm capsule under the week covers the days of the streak (D-093).
void main() {
  test('the chain ends today when today has practice', () {
    expect(streakChain([0, 9, 20, 26, 20, 14, 12]), (1, 6));
  });
  test('the chain ends yesterday while today has none yet', () {
    expect(streakChain([0, 0, 5, 3, 8, 2, 0]), (2, 5));
  });
  test('no chain without practice today or yesterday', () {
    expect(streakChain([4, 5, 6, 0, 0, 0, 0]), isNull);
    expect(streakChain(const []), isNull);
  });
  test('a single day is a chain of one', () {
    expect(streakChain([0, 0, 0, 0, 0, 0, 3]), (6, 6));
  });
}
