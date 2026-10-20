/// Puzzle themes of Lichess, grouped as on lichess.org/training/themes
/// (lila `PuzzleTheme.categorized`), D-123.
library;

enum PuzzleCategory { recommended, phases, motifs, advanced, mates, mateThemes, specialMoves, goals, lengths, origin }

/// The whole mix of themes: the angle of "all puzzles".
const kPuzzleMix = 'mix';

/// Theme keys in the order of the Lichess themes page. `mate` stands only
/// under the mates, not again under the goals.
const Map<PuzzleCategory, List<String>> kPuzzleThemes = {
  PuzzleCategory.recommended: [kPuzzleMix],
  PuzzleCategory.phases: [
    'opening',
    'middlegame',
    'endgame',
    'rookEndgame',
    'bishopEndgame',
    'pawnEndgame',
    'knightEndgame',
    'queenEndgame',
    'queenRookEndgame',
  ],
  PuzzleCategory.motifs: [
    'advancedPawn',
    'attackingF2F7',
    'capturingDefender',
    'discoveredAttack',
    'doubleCheck',
    'exposedKing',
    'fork',
    'hangingPiece',
    'kingsideAttack',
    'pin',
    'queensideAttack',
    'sacrifice',
    'skewer',
    'trappedPiece',
  ],
  PuzzleCategory.advanced: [
    'attraction',
    'clearance',
    'collinearMove',
    'discoveredCheck',
    'defensiveMove',
    'deflection',
    'interference',
    'intermezzo',
    'quietMove',
    'xRayAttack',
    'zugzwang',
  ],
  PuzzleCategory.mates: ['mate', 'mateIn1', 'mateIn2', 'mateIn3', 'mateIn4', 'mateIn5'],
  PuzzleCategory.mateThemes: [
    'anastasiaMate',
    'arabianMate',
    'backRankMate',
    'balestraMate',
    'blindSwineMate',
    'bodenMate',
    'cornerMate',
    'doubleBishopMate',
    'dovetailMate',
    'epauletteMate',
    'hookMate',
    'killBoxMate',
    'pillsburysMate',
    'morphysMate',
    'operaMate',
    'swallowstailMate',
    'triangleMate',
    'vukovicMate',
    'smotheredMate',
  ],
  PuzzleCategory.specialMoves: ['castling', 'enPassant', 'promotion', 'underPromotion'],
  PuzzleCategory.goals: ['equality', 'advantage', 'crushing'],
  PuzzleCategory.lengths: ['oneMove', 'short', 'long', 'veryLong'],
  PuzzleCategory.origin: ['master', 'masterVsMaster', 'superGM'],
};

final Set<String> kAllPuzzleThemes = {for (final l in kPuzzleThemes.values) ...l};

/// Themes that say nothing about the solution (lila `PuzzleFinisher`).
const _neutralThemes = {
  'opening',
  'middlegame',
  'endgame',
  'rookEndgame',
  'bishopEndgame',
  'pawnEndgame',
  'knightEndgame',
  'queenEndgame',
  'queenRookEndgame',
  'master',
  'masterVsMaster',
  'superGM',
};

/// Themes that all but give the solution away.
const _obviousThemes = {'enPassant', 'attackingF2F7', 'doubleCheck', 'mateIn1', 'castling'};

/// How much one result in [angle] moves the rating, as on Lichess: a
/// theme that hints at the solution counts less, a loss more than a win.
double puzzleRatingWeight(String angle, {required bool win}) {
  if (angle == kPuzzleMix) return 1;
  if (_obviousThemes.contains(angle) || angle.endsWith('Mate')) return win ? 0.1 : 0.4;
  if (_neutralThemes.contains(angle)) return win ? 0.7 : 0.8;
  return win ? 0.2 : 0.7;
}
