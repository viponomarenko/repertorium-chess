import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';

void main() {
  test('parseTypedMove accepts English, Ukrainian and lowercase input', () {
    final pos = Chess.initial;
    String? uci(String t) {
      final m = parseTypedMove(pos, t);
      return m == null ? null : standardUci(pos, m);
    }

    expect(uci('Nf3'), 'g1f3');
    expect(uci('Кf3'), 'g1f3');
    expect(uci('nf3'), 'g1f3');
    expect(uci('e4'), 'e2e4');
    expect(uci('b3'), 'b2b3');
    expect(uci('e2e4'), 'e2e4');
    expect(uci('Ke2'), isNull);
    expect(uci(''), isNull);
  });

  test('parseTypedMove handles castling variants', () {
    final pos = Chess.fromSetup(Setup.parseFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'));
    for (final t in ['O-O', '0-0', 'o-o']) {
      final m = parseTypedMove(pos, t);
      expect(m, isNotNull, reason: t);
    }
    expect(parseTypedMove(pos, '0-0-0'), isNotNull);
    final bishop = Chess.fromSetup(Setup.parseFen('4k3/8/8/8/8/8/8/2B1K3 w - - 0 1'));
    expect(parseTypedMove(bishop, 'bd2'), isNotNull);
    expect(parseTypedMove(bishop, 'Сd2'), isNotNull);
  });
}
