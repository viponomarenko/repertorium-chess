/// Analysis of the user's games against a repertoire (F-GAP-01).
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';
import '../pgn/pgn_model.dart';
import '../repertoire/repertoire_graph.dart';

enum GapType {
  /// The user played something else where the repertoire knew the answer.
  userDeviation,

  /// The opponent played a move the repertoire does not cover.
  opponentNovelty,

  /// The repertoire line ended (not an error).
  endOfBook;

  static GapType fromName(String n) => GapType.values.firstWhere((t) => t.name == n, orElse: () => GapType.endOfBook);
}

class GapEvent {
  const GapEvent({
    required this.type,
    required this.key,
    required this.fen,
    required this.ply,
    required this.playedSan,
    required this.playedUci,
    this.expectedSan = '',
  });

  final GapType type;
  final PositionKey key;
  final String fen;

  /// Ply of the move in the game (1 = White's first move).
  final int ply;
  final String playedSan;
  final String playedUci;
  final String expectedSan;

  @override
  String toString() => 'GapEvent(${type.name} at ply $ply: $playedSan, expected $expectedSan)';
}

/// Whether [game] ever reaches the repertoire's start position.
bool reachesRepertoire(RepertoireGraph graph, ChessGame game) =>
    game.root.key == graph.rootKey || game.mainline.any((n) => n.key == graph.rootKey);

/// Finds the first event where [game] leaves [graph]. Returns null if the
/// game never reaches the repertoire, or stays in book until its end.
///
/// Transpositions are recognized: a move that is not in the repertoire but
/// leads to a known position (or returns to one within [lookahead] plies)
/// is not reported.
GapEvent? analyzeGame(RepertoireGraph graph, ChessGame game, {int lookahead = 8}) {
  final nodes = game.mainline;
  final keys = [game.root.key, for (final n in nodes) n.key];
  // Find where the game enters the repertoire (its start position).
  var i = keys.indexOf(graph.rootKey);
  if (i < 0) return null;
  while (i < nodes.length) {
    final key = keys[i];
    final node = nodes[i];
    final before = i == 0 ? game.root.position : nodes[i - 1].position;
    final userTurn = before.turn == graph.color;
    final nextKey = keys[i + 1];
    final edge = node.isNullMove ? null : graph.move(key, node.uci!);
    if (edge != null) {
      if (userTurn && edge.role == MoveRole.alternative) {
        // Alternatives are part of the repertoire: fine.
      }
      i++;
      continue;
    }
    // Direct transposition: the resulting position is known.
    if (graph.positions.containsKey(nextKey)) {
      i++;
      continue;
    }
    final out = graph.movesFrom(key);
    if (out.isEmpty) {
      return GapEvent(
        type: GapType.endOfBook,
        key: key,
        fen: before.fen,
        ply: i + 1,
        playedSan: node.san ?? '',
        playedUci: node.uci ?? '',
      );
    }
    // Later transposition back into the repertoire.
    var back = -1;
    for (var j = i + 2; j < keys.length && j <= i + 1 + lookahead; j++) {
      if (graph.positions.containsKey(keys[j])) {
        back = j;
        break;
      }
    }
    if (back > 0) {
      i = back;
      continue;
    }
    if (userTurn) {
      final main = graph.mainMove(key);
      return GapEvent(
        type: GapType.userDeviation,
        key: key,
        fen: before.fen,
        ply: i + 1,
        playedSan: node.san ?? '',
        playedUci: node.uci ?? '',
        expectedSan: main?.san ?? out.first.san,
      );
    }
    return GapEvent(
      type: GapType.opponentNovelty,
      key: key,
      fen: before.fen,
      ply: i + 1,
      playedSan: node.san ?? '',
      playedUci: node.uci ?? '',
    );
  }
  return null;
}

/// The user's color in a game given their username (case-insensitive).
Side? userColorIn(ChessGame game, String username) {
  final u = username.toLowerCase();
  if ((game.headers['White'] ?? '').toLowerCase() == u) return Side.white;
  if ((game.headers['Black'] ?? '').toLowerCase() == u) return Side.black;
  return null;
}
