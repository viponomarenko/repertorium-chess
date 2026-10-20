/// A Lichess puzzle (D-123): the game it comes from and the solution line.
library;

import 'package:dartchess/dartchess.dart';

import '../chess/chess_utils.dart';

class PuzzleFormatException implements Exception {
  const PuzzleFormatException(this.message);
  final String message;

  @override
  String toString() => 'PuzzleFormatException: $message';
}

/// Where a puzzle came from (D-126).
enum PuzzleSource { lichess, pack }

class Puzzle {
  const Puzzle({
    required this.id,
    required this.rating,
    required this.plays,
    required this.solution,
    required this.themes,
    required this.gameId,
    required this.gameMoves,
    this.fen,
    this.setupMove,
    this.deviation,
    this.source = PuzzleSource.lichess,
  });

  final String id;
  final int rating;
  final int plays;

  /// The rating deviation, when known (the pack has it, the API not).
  final double? deviation;
  final PuzzleSource source;

  /// A puzzle of the pack: the position before the opponent's move, and
  /// that move (UCI); [gameMoves] is then empty.
  final String? fen;
  final String? setupMove;

  /// UCI moves: the solver's moves at even indexes, the replies between.
  final List<String> solution;
  final List<String> themes;
  final String gameId;

  /// SAN moves of the game up to and including the opponent's move that
  /// sets the puzzle.
  final List<String> gameMoves;

  /// The `PuzzleAndGame` object of the Lichess API.
  static Puzzle fromLichessJson(Map<String, Object?> j) {
    final p = (j['puzzle'] as Map?)?.cast<String, Object?>();
    final g = (j['game'] as Map?)?.cast<String, Object?>();
    if (p == null || g == null) throw const PuzzleFormatException('no puzzle or game');
    final solution = [for (final m in (p['solution'] as List?) ?? const []) m.toString()];
    if (solution.isEmpty) throw const PuzzleFormatException('empty solution');
    return Puzzle(
      id: p['id']?.toString() ?? '',
      rating: (p['rating'] as num?)?.toInt() ?? 1500,
      plays: (p['plays'] as num?)?.toInt() ?? 0,
      solution: solution,
      themes: [for (final t in (p['themes'] as List?) ?? const []) t.toString()],
      gameId: g['id']?.toString() ?? '',
      gameMoves: (g['pgn'] as String? ?? '').split(' ').where((s) => s.isNotEmpty).toList(),
    );
  }

  /// A line of the offline pack (`tool/puzzles/build_puzzles.py`):
  /// id, FEN, moves (the opponent's first), rating, deviation, themes.
  static Puzzle fromPackLine(String line) {
    final f = line.split('\t');
    if (f.length < 6) throw PuzzleFormatException('bad pack line: $line');
    final moves = f[2].split(' ').where((s) => s.isNotEmpty).toList();
    if (moves.length < 2) throw PuzzleFormatException('${f[0]}: no solution');
    return Puzzle(
      id: f[0],
      fen: f[1],
      setupMove: moves.first,
      solution: moves.sublist(1),
      rating: int.tryParse(f[3]) ?? 1500,
      deviation: double.tryParse(f[4]),
      themes: f[5].split(' ').where((s) => s.isNotEmpty).toList(),
      plays: 0,
      gameId: '',
      gameMoves: const [],
      source: PuzzleSource.pack,
    );
  }

  /// The position before the opponent's last move, that move, and the
  /// position the solver starts from. Throws [PuzzleFormatException] when
  /// the game does not lead to a position where the solution is legal.
  PuzzleSetup setup() {
    final fen = this.fen;
    if (fen != null) {
      final before = tryPositionFromFen(fen);
      final last = before == null ? null : parseUciMove(before, setupMove ?? '');
      if (before == null || last == null) throw PuzzleFormatException('$id: bad position or move');
      final start = before.play(last);
      if (parseUciMove(start, solution.first) == null) throw PuzzleFormatException('$id: solution does not fit');
      return PuzzleSetup(before: before, lastMove: last, start: start);
    }
    if (gameMoves.isEmpty) throw PuzzleFormatException('$id: no game moves');
    Position pos = Chess.initial;
    Position before = pos;
    Move? last;
    for (final san in gameMoves) {
      final m = parseSanLenient(pos, san);
      if (m == null) throw PuzzleFormatException('$id: illegal move $san');
      before = pos;
      last = m;
      pos = pos.play(m);
    }
    if (parseUciMove(pos, solution.first) == null) {
      throw PuzzleFormatException('$id: solution does not fit the game');
    }
    return PuzzleSetup(before: before, lastMove: last!, start: pos);
  }
}

class PuzzleSetup {
  const PuzzleSetup({required this.before, required this.lastMove, required this.start});
  final Position before;
  final Move lastMove;
  final Position start;

  /// The side the solver plays.
  Side get solver => start.turn;
}
