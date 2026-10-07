/// Repertoire -> PGN tree of variations (F-REP-09).
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../../core/constants.dart';
import '../chess/chess_utils.dart';
import '../pgn/pgn_model.dart';
import 'repertoire_graph.dart';

enum TranspositionMode {
  /// Transposed subtrees are written again in full.
  expand,

  /// Only the first occurrence is expanded; others get a comment.
  comment,
}

/// Formats a line of nodes as "1. e4 c5 2. Nf3".
String formatLine(List<GameNode> line) {
  final sb = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final n = line[i];
    final p = n.parent!.position;
    if (p.turn == Side.white) {
      if (sb.isNotEmpty) sb.write(' ');
      sb.write('${p.fullmoves}. ');
    } else if (i == 0) {
      sb.write('${p.fullmoves}... ');
    } else {
      sb.write(' ');
    }
    sb.write(n.san);
  }
  return sb.toString();
}

ChessGame repertoireToGame(
  RepertoireGraph graph, {
  String name = 'Repertoire',
  TranspositionMode mode = TranspositionMode.comment,
  String transpositionLabel = 'Transposes to',
  PositionKey? from,
  int maxNodes = 20000,
}) {
  final startKey = from ?? graph.rootKey;
  final startPos = graph.positions[startKey]!;
  final rootPosition = positionFromFen(startPos.fen);
  final game = ChessGame(root: GameNode.root(rootPosition));
  game.headers.addAll(ChessGame.defaultHeaders());
  game.headers['Event'] = name;
  game.headers['Annotator'] = AppInfo.name;
  if (keyFromFen(rootPosition.fen) != kInitialKey) {
    game.headers['SetUp'] = '1';
    game.headers['FEN'] = rootPosition.fen;
  }
  if (startPos.comment.isNotEmpty || startPos.shapes.isNotEmpty) {
    game.root.comments.add(PgnComment(text: startPos.comment, shapes: startPos.shapes));
  }

  final firstOccurrence = <PositionKey, GameNode>{startKey: game.root};
  var nodes = 0;

  List<RepMove> ordered(PositionKey key) {
    final list = [...graph.movesFrom(key)];
    list.sort((a, b) {
      int rank(RepMove m) => m.role == MoveRole.main ? 0 : (m.role == MoveRole.alternative ? 1 : 2);
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return b.weight.compareTo(a.weight);
    });
    return list;
  }

  // Iterative DFS: (game node, position key).
  final stack = <(GameNode, PositionKey)>[(game.root, startKey)];
  while (stack.isNotEmpty) {
    final (node, key) = stack.removeLast();
    final children = <(GameNode, PositionKey)>[];
    for (final m in ordered(key)) {
      final move = parseUciMove(node.position, m.uci);
      if (move == null) continue;
      final child = node.addMove(move);
      nodes++;
      final pos = graph.positions[m.toKey];
      final texts = [m.comment, pos?.comment ?? ''].where((t) => t.isNotEmpty).join('\n');
      final shapes = pos?.shapes ?? const <BoardShape>[];
      if (texts.isNotEmpty || shapes.isNotEmpty) {
        child.comments.add(PgnComment(text: texts, shapes: shapes));
      }
      final seen = firstOccurrence[m.toKey];
      final overBudget = nodes > maxNodes;
      if (seen != null && (mode == TranspositionMode.comment || overBudget)) {
        if (graph.movesFrom(m.toKey).isNotEmpty) {
          child.comments.add(PgnComment(text: '$transpositionLabel: ${formatLine(seen.line)}'));
        }
        continue;
      }
      firstOccurrence.putIfAbsent(m.toKey, () => child);
      if (!overBudget) children.add((child, m.toKey));
    }
    stack.addAll(children.reversed);
  }
  return game;
}
