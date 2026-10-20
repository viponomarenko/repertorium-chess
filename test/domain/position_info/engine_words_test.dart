import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/position_info/engine_words.dart';

ScoredLine line(List<String> moves, {int? cp, int? mate}) => ScoredLine(moves: moves, cp: cp, mate: mate);

void main() {
  group('verdict', () {
    test('thresholds match 0.3 / 0.8 / 2.0 pawns', () {
      expect(verdictOf(line([], cp: 0)).advantage, Advantage.equal);
      expect(verdictOf(line([], cp: 29)).advantage, Advantage.equal);
      expect(verdictOf(line([], cp: 30)).advantage, Advantage.slight);
      expect(verdictOf(line([], cp: 79)).advantage, Advantage.slight);
      expect(verdictOf(line([], cp: 80)).advantage, Advantage.clear);
      expect(verdictOf(line([], cp: 199)).advantage, Advantage.clear);
      expect(verdictOf(line([], cp: 200)).advantage, Advantage.decisive);
    });

    test('side follows the sign; equal has no side', () {
      expect(verdictOf(line([], cp: 120)).side, Side.white);
      expect(verdictOf(line([], cp: -120)).side, Side.black);
      expect(verdictOf(line([], cp: -10)).side, isNull);
    });

    test('mate', () {
      final v = verdictOf(line([], mate: -3));
      expect(v.advantage, Advantage.decisive);
      expect(v.side, Side.black);
      expect(v.mateIn, 3);
    });

    test('winning chances are symmetric and bounded', () {
      expect(winChance(cp: 0), 50);
      expect(winChance(cp: 300) + winChance(cp: -300), closeTo(100, 1e-9));
      expect(winChance(cp: 100000), winChance(cp: 1000));
      expect(winChanceFor(Side.black, line([], cp: 300)), closeTo(100 - winChance(cp: 300), 1e-9));
    });
  });

  group('move kind', () {
    Position at(String fen) => positionFromFen(fen);

    test('capture, check, castling, quiet', () {
      // 1.e4 d5: exd5 is a capture that only trades back.
      final scandi = at('rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2');
      expect(moveKindOf(scandi, line(['e4d5', 'd8d5', 'b1c3'], cp: 30)), MoveKind.capture);
      expect(moveKindOf(Chess.initial, line(['e2e4'], cp: 30)), MoveKind.quiet);
      final castle = at('r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4');
      expect(moveKindOf(castle, line(['e1g1'], cp: 30)), MoveKind.castling);
      final check = at('rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2');
      expect(moveKindOf(check, line(['d1h5', 'g8f6'], cp: -50)), MoveKind.quiet);
      final bishopCheck = at('rnbqkbnr/ppp2ppp/3p4/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 3');
      expect(moveKindOf(bishopCheck, line(['f1b5', 'c7c6'], cp: 20)), MoveKind.check);
    });

    test('mate and promotion', () {
      final mated = at('r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4');
      expect(moveKindOf(mated, line(['h5f7'], mate: 1)), MoveKind.mate);
      final promo = at('8/P6k/8/8/8/8/6K1/8 w - - 0 1');
      expect(moveKindOf(promo, line(['a7a8q'], cp: 900)), MoveKind.promotion);
    });

    test('a hanging piece taken wins material; an exchange does not', () {
      // Black's knight on e5 is attacked by the d4 pawn and not defended.
      final hanging = at('rnbqkb1r/pppp1ppp/8/4n3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4');
      expect(moveKindOf(hanging, line(['d4e5', 'd7d6', 'e5d6'], cp: 350)), MoveKind.winsMaterial);
      // Bxf6 Qxf6 is an even trade.
      final trade = at('rnbqkb1r/pppp1ppp/5n2/4p1B1/4P3/8/PPPP1PPP/RN1QKBNR w KQkq - 2 3');
      expect(materialGain(trade, ['g5f6', 'd8f6', 'b1c3'], Side.white), 0);
      expect(moveKindOf(trade, line(['g5f6', 'd8f6', 'b1c3'], cp: 0)), MoveKind.capture);
    });

    test('material won but the evaluation disagrees is not "wins material"', () {
      final hanging = at('rnbqkb1r/pppp1ppp/8/4n3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4');
      expect(moveKindOf(hanging, line(['d4e5', 'd7d6', 'e5d6'], cp: 0)), MoveKind.capture);
    });
  });

  group('threat', () {
    test('flips the side to move and drops en passant', () {
      final fen = threatFen('rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3');
      expect(fen, 'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR b KQkq - 0 3');
    });

    test('none when in check or the game is over', () {
      expect(threatFen('rnbqkbnr/ppppp2p/5p2/6pQ/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 1 3'), isNull);
      expect(threatFen('rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3'), isNull);
    });

    test('works with a four-field key', () {
      expect(threatFen(keyFromFen(kInitialFen)), isNotNull);
    });

    test('named only when it gains enough', () {
      // White to move; with a free move Black would mate with Qxf2.
      const fen = 'r1b1k1nr/pppp1ppp/2n5/2b1p3/2B1P2q/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 5';
      final pos = positionFromFen(fen);
      final tf = threatFen(fen)!;
      final t = threatOf(pos: pos, current: line([], cp: 0), threatPositionFen: tf, best: line(['h4f2'], mate: -1));
      expect(t, isNotNull);
      expect(t!.san, 'Qxf2#');
      expect(t.mateIn, 1);
      expect(t.kind, MoveKind.mate);
      final none = threatOf(pos: pos, current: line([], cp: 0), threatPositionFen: tf, best: line(['a7a6'], cp: -20));
      expect(none, isNull);
    });
  });

  group('only move', () {
    final pos = positionFromFen(kInitialFen);

    test('gap over the threshold', () {
      expect(isOnlyMove(pos, [line(['e2e4'], cp: 0), line(['d2d4'], cp: -300)]), isTrue);
      expect(isOnlyMove(pos, [line(['e2e4'], cp: 0), line(['d2d4'], cp: -20)]), isFalse);
    });

    test('needs two lines and a position that is not lost anyway', () {
      expect(isOnlyMove(pos, [line(['e2e4'], cp: 0)]), isFalse);
      expect(isOnlyMove(pos, [line(['e2e4'], cp: -600), line(['d2d4'], mate: -2)]), isFalse);
    });

    test('a single legal move is not "the only move"', () {
      // White king in check along the first rank; taking the rook on b2 is
      // the one legal move.
      final forced = positionFromFen('k7/8/8/8/8/8/1r6/K6r w - - 0 1');
      expect(forced.legalMoves.values.fold(0, (a, s) => a + s.size), 1);
      expect(isOnlyMove(forced, [line(['a1b2'], cp: 0), line(['a1b2'], cp: -900)]), isFalse);
    });

    test('black to move counts from Black', () {
      final b = positionFromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      expect(isOnlyMove(b, [line(['c7c5'], cp: 0), line(['g7g5'], cp: 300)]), isTrue);
    });
  });

  test('explain puts it together', () {
    final e = explain(kInitialFen, [line(['e2e4', 'e7e5'], cp: 25), line(['d2d4'], cp: 20)])!;
    expect(e.bestSan, 'e4');
    expect(e.bestKind, MoveKind.quiet);
    expect(e.verdict.advantage, Advantage.equal);
    expect(e.onlyMove, isFalse);
    expect(e.threat, isNull);
  });
}
