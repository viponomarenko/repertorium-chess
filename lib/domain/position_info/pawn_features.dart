/// Small positional features of a position for "About this position"
/// (D-107): passed, isolated, doubled and backward pawns, open and
/// half-open files, kings on opposite wings, a weakened pawn shelter.
/// Each has a weight; the panel shows the most important few.
library;

import 'package:dartchess/dartchess.dart';

enum PawnFeatureKind { passed, isolated, doubled, backward, openFile, halfOpenFile, oppositeCastling, weakShelter }

class PawnFeature {
  const PawnFeature(this.kind, {this.side, this.squares = const [], this.file, required this.weight});

  final PawnFeatureKind kind;

  /// The side the feature belongs to (whose pawns, whose king, for whom a
  /// file is half-open); null for open files and opposite castling.
  final Side? side;

  /// The pawns concerned (passed, isolated, backward, doubled).
  final List<Square> squares;
  final File? file;

  /// Higher first.
  final int weight;
}

/// The most features shown at once.
const int kMaxFeatures = 4;

SquareSet _fileMask(int f) => SquareSet.fromFile(File(f));

SquareSet _adjacentFiles(int f) =>
    (f > 0 ? _fileMask(f - 1) : SquareSet.empty) | (f < 7 ? _fileMask(f + 1) : SquareSet.empty);

/// Squares ahead of [sq] for [side] on files [mask] (its own file and/or the
/// adjacent ones).
SquareSet _ahead(Square sq, Side side, SquareSet mask) {
  var out = SquareSet.empty;
  for (final s in mask.squares) {
    if (side == Side.white ? s.rank > sq.rank : s.rank < sq.rank) out = out.withSquare(s);
  }
  return out;
}

/// Squares level with or behind [sq] for [side] on [mask].
SquareSet _levelOrBehind(Square sq, Side side, SquareSet mask) {
  var out = SquareSet.empty;
  for (final s in mask.squares) {
    if (side == Side.white ? s.rank <= sq.rank : s.rank >= sq.rank) out = out.withSquare(s);
  }
  return out;
}

bool _hasHeavyPieces(Board b) => (b.rooks | b.queens).isNotEmpty;

List<PawnFeature> _pawnFeatures(Board b, Side side) {
  final own = b.piecesOf(side, Role.pawn);
  final opp = b.piecesOf(side.opposite, Role.pawn);
  final passed = <Square>[], isolated = <Square>[], backward = <Square>[];
  final out = <PawnFeature>[];
  for (final sq in own.squares) {
    final f = sq.file;
    final front = _ahead(sq, side, _fileMask(f) | _adjacentFiles(f));
    // No own pawn in front on the same file either (the rear of doubled
    // pawns is not passed).
    if ((front & opp).isEmpty && (_ahead(sq, side, _fileMask(f)) & own).isEmpty) passed.add(sq);
    final neighbours = _adjacentFiles(f) & own;
    if (neighbours.isEmpty) {
      isolated.add(sq);
      continue;
    }
    // Backward: no neighbour level or behind to support its advance, and
    // the square in front is controlled by an enemy pawn.
    if ((_levelOrBehind(sq, side, _adjacentFiles(f)) & own).isEmpty) {
      final rank = side == Side.white ? sq.rank + 1 : sq.rank - 1;
      if (rank >= 0 && rank <= 7) {
        final stop = Square.fromCoords(File(f), Rank(rank));
        if ((pawnAttacks(side, stop) & opp).isNotEmpty && !own.has(stop)) backward.add(sq);
      }
    }
  }
  if (passed.isNotEmpty) {
    // The further advanced, the more it matters.
    final advance = passed
        .map((s) => side == Side.white ? s.rank : 7 - s.rank)
        .reduce((a, b) => a > b ? a : b);
    out.add(PawnFeature(PawnFeatureKind.passed, side: side, squares: passed, weight: 80 + advance * 2));
  }
  if (isolated.isNotEmpty) out.add(PawnFeature(PawnFeatureKind.isolated, side: side, squares: isolated, weight: 60));
  if (backward.isNotEmpty) out.add(PawnFeature(PawnFeatureKind.backward, side: side, squares: backward, weight: 45));
  for (var f = 0; f < 8; f++) {
    final onFile = own & _fileMask(f);
    if (onFile.moreThanOne) {
      out.add(PawnFeature(PawnFeatureKind.doubled, side: side, squares: onFile.squares.toList(), weight: 50));
    }
  }
  return out;
}

/// Kings on opposite wings (a-c against g-h files), each still on its own
/// first two ranks: usually a race of pawn storms.
bool _oppositeWings(Board b) {
  final wk = b.kingOf(Side.white), bk = b.kingOf(Side.black);
  if (wk == null || bk == null) return false;
  if (wk.rank > 1 || bk.rank < 6) return false;
  bool queenside(Square s) => s.file <= 2;
  bool kingside(Square s) => s.file >= 6;
  return (queenside(wk) && kingside(bk)) || (kingside(wk) && queenside(bk));
}

/// A king tucked in a corner (files a-c or f-h, its first rank) with fewer
/// than two of its own pawns on the three files in front, one or two ranks
/// up.
bool _weakShelter(Board b, Side side) {
  final k = b.kingOf(side);
  if (k == null || k.rank != (side == Side.white ? 0 : 7)) return false;
  if (k.file >= 3 && k.file <= 4) return false;
  if (b.piecesOf(side.opposite, Role.queen).isEmpty) return false;
  var files = _fileMask(k.file) | _adjacentFiles(k.file);
  var shield = SquareSet.empty;
  for (final s in files.squares) {
    final up = side == Side.white ? s.rank - k.rank : k.rank - s.rank;
    if (up == 1 || up == 2) shield = shield.withSquare(s);
  }
  files = shield;
  return (files & b.piecesOf(side, Role.pawn)).size < 2;
}

/// All features of [b], most important first, at most [kMaxFeatures].
List<PawnFeature> pawnFeatures(Board b) {
  final out = <PawnFeature>[
    for (final side in Side.values) ..._pawnFeatures(b, side),
    if (_oppositeWings(b)) const PawnFeature(PawnFeatureKind.oppositeCastling, weight: 70),
    for (final side in Side.values)
      if (_weakShelter(b, side)) PawnFeature(PawnFeatureKind.weakShelter, side: side, weight: 55),
  ];
  if (_hasHeavyPieces(b)) {
    for (var f = 0; f < 8; f++) {
      final w = b.piecesOf(Side.white, Role.pawn) & _fileMask(f);
      final k = b.piecesOf(Side.black, Role.pawn) & _fileMask(f);
      if (w.isEmpty && k.isEmpty) {
        out.add(PawnFeature(PawnFeatureKind.openFile, file: File(f), weight: 40));
      } else if (w.isEmpty != k.isEmpty) {
        // Half-open for the side without a pawn there.
        out.add(
          PawnFeature(PawnFeatureKind.halfOpenFile, side: w.isEmpty ? Side.white : Side.black, file: File(f), weight: 30),
        );
      }
    }
  }
  // Stable: equal weights keep the order above (white before black, files
  // from a to h).
  final indexed = out.indexed.toList()
    ..sort((a, b) => b.$2.weight != a.$2.weight ? b.$2.weight.compareTo(a.$2.weight) : a.$1.compareTo(b.$1));
  return [for (final (_, f) in indexed.take(kMaxFeatures)) f];
}
