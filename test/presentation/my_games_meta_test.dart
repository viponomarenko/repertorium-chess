import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/openings/opening_book.dart';
import 'package:tabiya/presentation/accounts/game_meta.dart';
import 'package:tabiya/presentation/gap/gap_report_screen.dart';

/// D-099: what a row of My games and a card of the report show.
void main() {
  const pgn =
      '[White "Opp"]\n[Black "Me"]\n[WhiteElo "1512"]\n[BlackElo "1480"]\n\n'
      '1. e4 {[%clk 0:05:00]} Nc6 2. d4 d5 3. e5 Bf5 *';

  test('the line up to a move, numbered', () {
    expect(lineUpTo(pgn, 2), '1. e4 Nc6');
    expect(lineUpTo(pgn, 5), '1. e4 Nc6 2. d4 d5 3. e5');
    expect(lineUpTo('[SetUp "1"]\n[FEN "8/8/8/8/8/8/8/K6k w - - 0 1"]\n\n1. Kb1 *', 1, fallback: 'Kb1'), 'Kb1');
  });

  test("the opponent's rating and the deepest named opening", () {
    Position pos = Chess.initial;
    final keys = <String>[];
    for (final san in ['e4', 'Nc6']) {
      pos = pos.play(pos.parseSan(san)!);
      keys.add(positionKeyOf(pos));
    }
    final book = OpeningBook([
      OpeningInfo(key: keys[0], eco: 'B00', name: "King's Pawn Game", moves: const ['e4']),
      OpeningInfo(key: keys[1], eco: 'B00', name: 'Nimzowitsch Defense', moves: const ['e4', 'Nc6']),
    ]);
    final meta = gameMeta([(1, 'black', pgn), (2, 'white', pgn)], book);
    expect(meta[1]!.opening, 'Nimzowitsch Defense');
    expect(meta[1]!.opponentElo, 1512);
    expect(meta[2]!.opponentElo, 1480);
  });
}
