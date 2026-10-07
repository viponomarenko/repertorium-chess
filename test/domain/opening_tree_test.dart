import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/domain/stats/opening_tree.dart';

List<String> ucisOf(List<String> sans) {
  Position p = Chess.initial;
  final out = <String>[];
  for (final s in sans) {
    final m = p.parseSan(s)!;
    out.add(standardUci(p, m));
    p = p.play(m);
  }
  return out;
}

TreeGame game(int id, List<String> sans, GameOutcome o, {Side color = Side.white}) =>
    TreeGame(id: id, userColor: color, outcome: o, plies: ucisOf(sans));

void main() {
  final games = [
    game(1, ['e4', 'c5', 'Nf3', 'd6', 'd4'], GameOutcome.win),
    game(2, ['e4', 'c5', 'Nf3', 'd6', 'd4'], GameOutcome.loss),
    game(3, ['e4', 'c5', 'Nf3', 'Nc6', 'd4'], GameOutcome.draw),
    game(4, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'], GameOutcome.win),
    // Transposes to the Sicilian position after 2...d6 via 1. Nf3.
    game(5, ['Nf3', 'c5', 'e4', 'd6'], GameOutcome.win),
  ];

  test('counts moves and results from the user side', () {
    final t = OpeningTree.build(games);
    final root = t.at(t.rootKey)!;
    expect(root.score.games, 5);
    expect(root.sortedMoves.map((m) => (m.san, m.score.games)).toList(), [('e4', 4), ('Nf3', 1)]);
    final e4 = root.moves[ucisOf(['e4']).single]!;
    expect((e4.score.wins, e4.score.draws, e4.score.losses), (2, 1, 1));
    final afterE4 = t.at(e4.toKey)!;
    expect(afterE4.sortedMoves.first.san, 'c5');
    expect(afterE4.sortedMoves.first.score.games, 3);
  });

  test('transpositions merge: a position counts every game that reached it', () {
    final t = OpeningTree.build(games);
    Position p = Chess.initial;
    for (final s in ['e4', 'c5', 'Nf3', 'd6']) {
      p = p.play(p.parseSan(s)!);
    }
    expect(t.at(positionKeyOf(p))!.score.games, 3, reason: 'games 1, 2 and the 1. Nf3 game 5');
  });

  test('most frequent variations, most common first', () {
    final t = OpeningTree.build(games);
    final v = t.topVariations(plies: 4);
    expect(v.first.sans, ['e4', 'c5', 'Nf3', 'd6']);
    expect(v.first.score.games, 2);
    expect(v.first.gameIds, [1, 2]);
    expect(v.map((x) => x.score.games).fold<int>(0, (a, b) => a + b), 5);
  });

  test('where a line leaves the repertoire, and who left it', () {
    final g = RepertoireGraph(color: Side.white, rootKey: positionKeyOf(Chess.initial), rootFen: Chess.initial.fen);
    addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
    expect(fitRepertoire(g, ucisOf(['e4', 'c5', 'Nf3', 'd6', 'd4'])).inBook, isTrue);
    final opp = fitRepertoire(g, ucisOf(['e4', 'e5', 'Nf3']));
    expect((opp.inBook, opp.leftAtPly, opp.userLeft), (false, 2, false));
    final mine = fitRepertoire(g, ucisOf(['e4', 'c5', 'Nc3']));
    expect((mine.inBook, mine.leftAtPly, mine.userLeft), (false, 3, true));
  });

  test('first plies of a downloaded PGN with clocks and results', () {
    const pgn = r'''[Event "Rated Blitz game"]
[White "me"]
[Black "you"]
[Result "1-0"]

1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } 2. Nf3?! $6 d6 (2... Nc6 3. d4) 3. d4 cxd4 4. O-O-O?? 1-0''';
    // 4. O-O-O is illegal here: parsing stops before it.
    expect(firstPlies(pgn), ucisOf(['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4']));
    expect(firstPlies(pgn, max: 3), ucisOf(['e4', 'c5', 'Nf3']));
  });

  test('outcome from the user side', () {
    expect(outcomeFor('1-0', Side.white), GameOutcome.win);
    expect(outcomeFor('1-0', Side.black), GameOutcome.loss);
    expect(outcomeFor('1/2-1/2', Side.black), GameOutcome.draw);
    expect(outcomeFor('*', Side.white), GameOutcome.unknown);
  });
}
