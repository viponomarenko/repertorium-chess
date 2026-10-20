import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/position_info/pawn_features.dart';

import 'structures_test.dart' show pawns;

/// Small positional features (D-107).
void main() {
  List<PawnFeatureKind> kinds(Board b) => [for (final f in pawnFeatures(b)) f.kind];
  PawnFeature first(Board b, PawnFeatureKind k) => pawnFeatures(b).firstWhere((f) => f.kind == k);
  List<String> names(PawnFeature f) => [for (final s in f.squares) s.name];

  test('the initial position has none', () {
    expect(pawnFeatures(Chess.initial.board), isEmpty);
  });

  test('a passed pawn, and only the one that is passed', () {
    // c7 in front of d6 on a neighbouring file would stop it being passed.
    expect(pawnFeatures(pawns(['a2', 'b2', 'c2', 'd6'], ['a7', 'b7', 'c7'])).map((f) => f.kind), isNot(contains(PawnFeatureKind.passed)));
    final b = pawns(['a2', 'b2', 'c2', 'd6', 'g2'], ['a7', 'b7', 'g7']);
    final f = first(b, PawnFeatureKind.passed);
    expect(f.side, Side.white);
    expect(names(f), ['d6']);
    expect(pawnFeatures(b).where((f) => f.kind == PawnFeatureKind.passed), hasLength(1));
  });

  test('isolated and doubled pawns', () {
    final b = pawns(['a2', 'c2', 'c3', 'h2'], ['a7', 'b7', 'g7', 'h7']);
    final iso = first(b, PawnFeatureKind.isolated);
    expect(iso.side, Side.white);
    expect(names(iso), containsAll(['a2', 'c2', 'c3', 'h2']));
    expect(names(first(b, PawnFeatureKind.doubled)), ['c2', 'c3']);
    // The rear doubled pawn is not passed even with nothing in front.
    for (final f in pawnFeatures(b).where((f) => f.kind == PawnFeatureKind.passed)) {
      expect(names(f), isNot(contains('c2')));
    }
  });

  test('a backward pawn: no support and its stop square under a pawn', () {
    final b = pawns(['c4', 'e4', 'g2'], ['d6', 'e5', 'f7', 'g7']);
    final f = first(b, PawnFeatureKind.backward);
    expect(f.side, Side.black);
    expect(names(f), ['d6']);
  });

  test('open and half-open files only with rooks or queens on the board', () {
    final open = Board.parseFen('r3k3/pp3ppp/8/8/8/8/PP3PPP/R3K3');
    expect([for (final f in pawnFeatures(open)) if (f.kind == PawnFeatureKind.openFile) f.file!.name], ['c', 'd', 'e']);
    final noRooks = Board.parseFen('4k3/pp3ppp/8/8/8/8/PP3PPP/4K3');
    expect(kinds(noRooks), isNot(contains(PawnFeatureKind.openFile)));
    final half = Board.parseFen('r3k3/pp1p1ppp/8/8/8/8/PP2PPPP/R3K3');
    final h = pawnFeatures(half).where((f) => f.kind == PawnFeatureKind.halfOpenFile).toList();
    expect([for (final f in h) (f.file!.name, f.side)], [('d', Side.white), ('e', Side.black)]);
  });

  test('kings on opposite wings', () {
    final b = Board.parseFen('2kr3r/ppp2ppp/8/8/8/8/PPP2PPP/R4RK1');
    expect(kinds(b), contains(PawnFeatureKind.oppositeCastling));
    expect(kinds(Board.parseFen('r4rk1/ppp2ppp/8/8/8/8/PPP2PPP/R4RK1')), isNot(contains(PawnFeatureKind.oppositeCastling)));
  });

  test('a weakened shelter, only while the opponent has a queen', () {
    final b = Board.parseFen('q3k3/8/8/8/8/8/5P2/6K1');
    final f = first(b, PawnFeatureKind.weakShelter);
    expect(f.side, Side.white);
    expect(kinds(Board.parseFen('4k3/8/8/8/8/8/5P2/6K1')), isNot(contains(PawnFeatureKind.weakShelter)));
    expect(kinds(Board.parseFen('q3k3/8/8/8/8/8/5PPP/6K1')), isNot(contains(PawnFeatureKind.weakShelter)));
  });

  test('at most four, the weightiest first', () {
    final b = Board.parseFen('2kr3r/p6p/8/3P4/8/8/P1P2P1P/R4RK1');
    final f = pawnFeatures(b);
    expect(f.length, lessThanOrEqualTo(kMaxFeatures));
    for (var i = 1; i < f.length; i++) {
      expect(f[i - 1].weight, greaterThanOrEqualTo(f[i].weight));
    }
    expect(f.first.kind, PawnFeatureKind.passed);
  });
}
