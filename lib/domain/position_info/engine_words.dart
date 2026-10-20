/// The engine's verdict in words for the "About this position" panel
/// (D-105): who stands better and how much, what kind of move the best one
/// is, what the opponent threatens, and whether only one move holds.
///
/// Scores are compared as winning chances (the Lichess formula), not raw
/// centipawns: a pawn matters at 0.00 and means little at +6.
library;

import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';

import '../chess/chess_utils.dart';

/// One engine line: UCI moves and a score from White's point of view.
class ScoredLine {
  const ScoredLine({required this.moves, this.cp, this.mate});
  final List<String> moves;
  final int? cp;
  final int? mate;
}

/// White's winning chances in percent (0..100), as on Lichess.
double winChance({int? cp, int? mate}) {
  if (mate != null) return mate > 0 ? 100 : 0;
  final c = (cp ?? 0).clamp(-1000, 1000);
  return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * c)) - 1);
}

/// [side]'s winning chances for a line scored from White's point of view.
double winChanceFor(Side side, ScoredLine l) {
  final w = winChance(cp: l.cp, mate: l.mate);
  return side == Side.white ? w : 100 - w;
}

enum Advantage { equal, slight, clear, decisive }

/// The thresholds, in White's winning chances above 50: the equivalents of
/// 0.3, 0.8 and 2.0 pawns.
final double kSlightFrom = winChance(cp: 30) - 50;
final double kClearFrom = winChance(cp: 80) - 50;
final double kDecisiveFrom = winChance(cp: 200) - 50;

/// A drop in winning chances (percentage points) from the best move to the
/// second that makes the best one "the only move".
const double kOnlyMoveGap = 20;

/// A gain in the opponent's winning chances (percentage points) that makes
/// what they would play with a free move a threat worth naming.
const double kThreatGap = 10;

class EvalVerdict {
  const EvalVerdict(this.advantage, {this.side, this.mateIn});

  final Advantage advantage;

  /// The side that stands better; null when equal.
  final Side? side;

  /// Moves to mate for [side], when the engine sees one.
  final int? mateIn;
}

EvalVerdict verdictOf(ScoredLine l) {
  final mate = l.mate;
  if (mate != null && mate != 0) {
    return EvalVerdict(Advantage.decisive, side: mate > 0 ? Side.white : Side.black, mateIn: mate.abs());
  }
  final d = winChance(cp: l.cp) - 50;
  final side = d > 0 ? Side.white : Side.black;
  final a = d.abs();
  if (a < kSlightFrom) return const EvalVerdict(Advantage.equal);
  if (a < kClearFrom) return EvalVerdict(Advantage.slight, side: side);
  if (a < kDecisiveFrom) return EvalVerdict(Advantage.clear, side: side);
  return EvalVerdict(Advantage.decisive, side: side);
}

enum MoveKind { mate, promotion, winsMaterial, castling, check, capture, quiet }

const _values = {Role.pawn: 1, Role.knight: 3, Role.bishop: 3, Role.rook: 5, Role.queen: 9, Role.king: 0};

int _material(Board b, Side side) => _values.entries.fold(0, (a, e) => a + b.piecesOf(side, e.key).size * e.value);

/// [side]'s material minus the opponent's, in pawns.
int materialBalance(Board b, Side side) => _material(b, side) - _material(b, side.opposite);

bool _isCapture(Position pos, Move m) {
  if (m is! NormalMove) return false;
  if (isCastling(pos, m)) return false;
  final target = pos.board.pieceAt(m.to);
  if (target != null) return true;
  // En passant: a pawn moving diagonally to an empty square.
  final piece = pos.board.pieceAt(m.from);
  return piece?.role == Role.pawn && m.from.file != m.to.file;
}

/// The material [side] gains along [uci] from [pos], counted where the line
/// calms down: before the first move (after the first one) that is not a
/// capture or a promotion and is not made out of check. Counting at the end
/// of the line instead would catch exchanges half done.
int materialGain(Position pos, List<String> uci, Side side) {
  final start = materialBalance(pos.board, side);
  var p = pos;
  for (var i = 0; i < uci.length; i++) {
    final m = parseUciMove(p, uci[i]);
    if (m == null) break;
    final noisy = _isCapture(p, m) || (m is NormalMove && m.promotion != null) || p.isCheck;
    if (i > 0 && !noisy) break;
    p = p.play(m);
  }
  return materialBalance(p.board, side) - start;
}

/// What kind of move the first move of [line] is, the most telling first.
MoveKind moveKindOf(Position pos, ScoredLine line) {
  if (line.moves.isEmpty) return MoveKind.quiet;
  final m = parseUciMove(pos, line.moves.first);
  if (m == null) return MoveKind.quiet;
  final after = pos.play(m);
  final side = pos.turn;
  if (after.isCheckmate) return MoveKind.mate;
  if (m is NormalMove && m.promotion != null) return MoveKind.promotion;
  // Material won only counts when the evaluation agrees.
  if (materialGain(pos, line.moves, side) >= 1 && winChanceFor(side, line) - 50 >= kSlightFrom) {
    return MoveKind.winsMaterial;
  }
  if (isCastling(pos, m)) return MoveKind.castling;
  if (after.isCheck) return MoveKind.check;
  if (_isCapture(pos, m)) return MoveKind.capture;
  return MoveKind.quiet;
}

/// The same position with the other side to move (a "null move"), to ask
/// the engine what the opponent would do with a free move. Null when the
/// side to move is in check (the opponent cannot then move) or when the
/// result would not be a legal position.
String? threatFen(String fen) {
  final pos = tryPositionFromFen(fen);
  if (pos == null || pos.isCheck || pos.isGameOver) return null;
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 4) return null;
  parts[1] = parts[1] == 'w' ? 'b' : 'w';
  parts[3] = '-';
  while (parts.length < 6) {
    parts.add(parts.length == 4 ? '0' : '1');
  }
  final out = parts.join(' ');
  final flipped = tryPositionFromFen(out);
  if (flipped == null || flipped.isGameOver) return null;
  return out;
}

/// Whether the best move is the only good one: the second best loses at
/// least [kOnlyMoveGap] points of winning chances, and the best one is not
/// lost anyway. Needs at least two lines and more than one legal move.
bool isOnlyMove(Position pos, List<ScoredLine> lines) {
  if (lines.length < 2) return false;
  final legal = pos.legalMoves.values.fold(0, (a, s) => a + s.size);
  if (legal < 2) return false;
  final side = pos.turn;
  final first = winChanceFor(side, lines[0]);
  final second = winChanceFor(side, lines[1]);
  return first >= 30 && first - second >= kOnlyMoveGap;
}

class Threat {
  const Threat({required this.san, required this.kind, this.mateIn});

  /// The opponent's move, SAN (English).
  final String san;
  final MoveKind kind;

  /// Moves to mate when the threat is a mate.
  final int? mateIn;
}

/// The opponent's threat: their best move in the [threatFen] position,
/// named only when it gains them at least [kThreatGap] points over the
/// real evaluation [current].
Threat? threatOf({required Position pos, required ScoredLine current, required String threatPositionFen, ScoredLine? best}) {
  if (best == null || best.moves.isEmpty) return null;
  final tp = tryPositionFromFen(threatPositionFen);
  if (tp == null) return null;
  final opp = pos.turn.opposite;
  if (winChanceFor(opp, best) - winChanceFor(opp, current) < kThreatGap) return null;
  final m = parseUciMove(tp, best.moves.first);
  if (m == null) return null;
  final (_, san) = tp.makeSan(m);
  final mate = best.mate;
  final oppMates = mate != null && (opp == Side.white ? mate > 0 : mate < 0);
  return Threat(san: san, kind: moveKindOf(tp, best), mateIn: oppMates ? mate.abs() : null);
}

/// Everything the engine block says about a position.
class EngineExplanation {
  const EngineExplanation({
    required this.verdict,
    required this.bestSan,
    required this.bestKind,
    required this.onlyMove,
    this.threat,
  });

  final EvalVerdict verdict;
  final String? bestSan;
  final MoveKind? bestKind;
  final bool onlyMove;
  final Threat? threat;
}

/// Puts the pieces together for [fen] from the engine's [lines] (best
/// first) and, when it was asked, its answer in the [threatFen] position.
EngineExplanation? explain(String fen, List<ScoredLine> lines, {String? threatPositionFen, ScoredLine? threatBest}) {
  final pos = tryPositionFromFen(fen);
  if (pos == null || lines.isEmpty) return null;
  final best = lines.first;
  String? san;
  final m = best.moves.isEmpty ? null : parseUciMove(pos, best.moves.first);
  if (m != null) san = pos.makeSan(m).$2;
  return EngineExplanation(
    verdict: verdictOf(best),
    bestSan: san,
    bestKind: m == null ? null : moveKindOf(pos, best),
    onlyMove: isOnlyMove(pos, lines),
    threat: threatPositionFen == null
        ? null
        : threatOf(pos: pos, current: best, threatPositionFen: threatPositionFen, best: threatBest),
  );
}
