import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/gap/gap_analysis.dart';
import 'package:tabiya/domain/openings/opening_book.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

RepertoireGraph rep(Side color, List<List<String>> lines) {
  final g = RepertoireGraph(color: color, rootKey: kInitialKey, rootFen: kInitialFen);
  for (final l in lines) {
    addSanLine(g, Chess.initial, l);
  }
  return g;
}

GapEvent? run(RepertoireGraph g, String moves) => analyzeGame(g, PgnParser.parseOne('$moves *'));

void main() {
  group('F-GAP-01 reference games', () {
    final white = rep(Side.white, [
      ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
      ['e4', 'c5', 'Nf3', 'd6', 'd4'],
    ]);

    test('user deviation', () {
      final ev = run(white, '1. e4 e5 2. Bc4 Nf6');
      expect(ev!.type, GapType.userDeviation);
      expect(ev.ply, 3);
      expect(ev.playedSan, 'Bc4');
      expect(ev.expectedSan, 'Nf3');
    });

    test('opponent novelty (gap)', () {
      final ev = run(white, '1. e4 e6 2. d4 d5');
      expect(ev!.type, GapType.opponentNovelty);
      expect(ev.ply, 2);
      expect(ev.playedSan, 'e6');
    });

    test('end of book', () {
      final ev = run(white, '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4');
      expect(ev!.type, GapType.endOfBook);
      expect(ev.ply, 6);
    });

    test('game finished inside the book: no event', () {
      expect(run(white, '1. e4 c5 2. Nf3'), isNull);
    });

    test('transposition into the repertoire is not an error', () {
      final black = rep(Side.black, [
        ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'd5'],
      ]);
      // 1. Nf3 is not in the repertoire, but the game transposes back.
      expect(run(black, '1. Nf3 Nf6 2. c4 e6 3. d4 d5'), isNull);
      final ev = run(black, '1. Nf3 Nf6 2. c4 e6 3. g3 d5');
      expect(ev!.type, GapType.opponentNovelty);
      expect(ev.ply, 1);
    });

    test('user color detection', () {
      final g = PgnParser.parseOne('[White "Tabiya"]\n[Black "Other"]\n\n1. e4 *');
      expect(userColorIn(g, 'tabiya'), Side.white);
      expect(userColorIn(g, 'nobody'), isNull);
    });
  });

  group('F-THEORY-01 opening book', () {
    const tsv =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -\tB00\tKing\'s Pawn Game\te4\n'
        'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -\tB20\tSicilian Defense\te4 c5\n';
    final book = OpeningBook.parseTsv(tsv);

    test('lookup and deepest', () {
      Position p = Chess.initial;
      final keys = [positionKeyOf(p)];
      for (final s in ['e4', 'c5', 'Nf3']) {
        p = p.play(p.parseSan(s)!);
        keys.add(positionKeyOf(p));
      }
      expect(book.deepest(keys)!.name, 'Sicilian Defense');
      expect(book.lookup(keys[1])!.eco, 'B00');
      expect(book.search('b2').single.eco, 'B20');
      expect(book.search('sicil').single.family, 'Sicilian Defense');
    });
  });
}
