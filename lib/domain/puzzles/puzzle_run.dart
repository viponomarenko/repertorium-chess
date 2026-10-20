/// One attempt at a puzzle (D-123): checks the solver's moves against the
/// solution and plays the replies, as on Lichess.
library;

import 'package:dartchess/dartchess.dart';

import '../chess/chess_utils.dart';
import 'puzzle.dart';

enum PuzzleVerdict {
  /// The right move; the reply follows ([PuzzleRun.playReply]).
  correct,

  /// The right move, and the last one.
  solved,

  /// Not the move; the position stays as it was.
  wrong,
}

class PuzzleRun {
  PuzzleRun(this.puzzle) : setup = puzzle.setup() {
    position = setup.start;
    lastMove = setup.lastMove;
  }

  final Puzzle puzzle;
  final PuzzleSetup setup;

  late Position position;
  Move? lastMove;

  /// Index of the next move of the solution.
  int step = 0;

  /// A wrong move or a shown solution: the result is a loss, whatever
  /// happens after.
  bool failed = false;

  bool get done => step >= puzzle.solution.length;

  /// The solver is to move (not the scripted reply).
  bool get solverToMove => !done && step.isEven;

  /// The expected move now, normalized for [Position.play].
  Move? get expected => done ? null : parseUciMove(position, puzzle.solution[step]);

  /// Checks the solver's [move]. A different move that mates also solves
  /// the puzzle, as on Lichess.
  PuzzleVerdict submit(Move move) {
    assert(solverToMove);
    final norm = normalizeMove(position, move);
    final want = expected;
    if (!position.isLegal(norm)) return _wrong();
    final next = position.play(norm);
    final same = want != null && standardUci(position, norm) == standardUci(position, want);
    if (!same && !next.isCheckmate) return _wrong();
    position = next;
    lastMove = norm;
    step = same ? step + 1 : puzzle.solution.length;
    return done ? PuzzleVerdict.solved : PuzzleVerdict.correct;
  }

  PuzzleVerdict _wrong() {
    failed = true;
    return PuzzleVerdict.wrong;
  }

  /// Plays the scripted move of the solution (the reply, or the solver's
  /// own move when the solution is shown). Returns it, or null when done.
  Move? playScripted() {
    final m = expected;
    if (m == null) {
      step = puzzle.solution.length;
      return null;
    }
    position = position.play(m);
    lastMove = m;
    step++;
    return m;
  }

  /// Gives up: the rest is played by [playScripted].
  void reveal() => failed = true;
}
