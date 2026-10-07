/// Import of documents (PGN games, study chapters) into a repertoire,
/// with merge by position key, conflicts and preview (F-REP-03..06).
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';
import '../pgn/pgn_model.dart';
import 'repertoire_graph.dart';

class RepImportOptions {
  const RepImportOptions({
    this.ownAllVariations = false,
    this.opponentAllVariations = true,
    this.maxPly,
    this.includeComments = true,
    this.includeShapes = true,
    this.source = 'pgn',
    this.commentPolicy = CommentPolicy.merge,
  });

  /// Own moves: all variations (true) or only the main line (false).
  final bool ownAllVariations;

  /// Opponent moves: all variations (true, default) or only the main line.
  final bool opponentAllVariations;

  /// Maximum depth in plies counted from the game's starting position.
  final int? maxPly;
  final bool includeComments;
  final bool includeShapes;
  final String source;
  final CommentPolicy commentPolicy;

  RepImportOptions copyWith({
    bool? ownAllVariations,
    bool? opponentAllVariations,
    int? maxPly,
    bool clearMaxPly = false,
    bool? includeComments,
    bool? includeShapes,
    String? source,
    CommentPolicy? commentPolicy,
  }) => RepImportOptions(
    ownAllVariations: ownAllVariations ?? this.ownAllVariations,
    opponentAllVariations: opponentAllVariations ?? this.opponentAllVariations,
    maxPly: clearMaxPly ? null : (maxPly ?? this.maxPly),
    includeComments: includeComments ?? this.includeComments,
    includeShapes: includeShapes ?? this.includeShapes,
    source: source ?? this.source,
    commentPolicy: commentPolicy ?? this.commentPolicy,
  );
}

/// What to do when an imported comment differs from an existing one.
enum CommentPolicy { keepOld, replace, merge }

/// A document part to import: the subtree starting at [start] (the path
/// from the game root to [start] is imported as a single line).
class ImportSource {
  const ImportSource(this.start, {this.label = ''});
  ImportSource.game(ChessGame game, {String label = ''}) : this(game.root, label: label);

  final GameNode start;
  final String label;
}

class ImportConflict {
  ImportConflict({required this.key, required this.fen});

  final PositionKey key;
  final String fen;

  /// Moves proposed as `main` (uci -> san). The first is the current main.
  final Map<String, String> candidates = {};

  @override
  String toString() => 'Conflict($key: ${candidates.values.join(' vs ')})';
}

class ImportStats {
  int newPositions = 0;
  int newMoves = 0;
  int matchedMoves = 0;
  int commentCollisions = 0;

  /// Moves that could not be connected to the repertoire start position.
  int outsideMoves = 0;
  int sources = 0;

  @override
  String toString() =>
      'ImportStats(newPos=$newPositions, newMoves=$newMoves, matched=$matchedMoves, '
      'comments=$commentCollisions, outside=$outsideMoves)';
}

class ImportResult {
  ImportResult(this.stats, this.conflicts);
  final ImportStats stats;
  final List<ImportConflict> conflicts;

  bool get reachedRepertoire => stats.newMoves + stats.matchedMoves > 0;
}

/// Runs the import on [graph] (mutating it). For a preview, pass a clone
/// (`graph.clone()`): the result is identical to the real run.
ImportResult importIntoRepertoire(RepertoireGraph graph, List<ImportSource> sources, RepImportOptions options) {
  final stats = ImportStats()..sources = sources.length;
  final conflicts = <PositionKey, ImportConflict>{};
  final positionsBefore = graph.positions.length;

  void addComment(RepMove m, GameNode node) {
    if (!options.includeComments) return;
    final incoming = [node.startCommentText, node.commentText].where((t) => t.isNotEmpty).join(' ');
    if (incoming.isEmpty) return;
    final old = m.comment;
    if (old.isEmpty) {
      graph.setMoveComment(m, incoming);
      return;
    }
    if (old == incoming || old.contains(incoming)) return;
    stats.commentCollisions++;
    switch (options.commentPolicy) {
      case CommentPolicy.keepOld:
        break;
      case CommentPolicy.replace:
        graph.setMoveComment(m, incoming);
      case CommentPolicy.merge:
        graph.setMoveComment(m, '$old\n$incoming');
    }
  }

  void addShapes(RepMove m, GameNode node) {
    if (!options.includeShapes) return;
    final shapes = node.shapes;
    if (shapes.isEmpty) return;
    final p = graph.positions[m.toKey];
    if (p == null) return;
    final merged = {...p.shapes, ...shapes}.toList();
    if (merged.length != p.shapes.length) graph.setPositionShapes(m.toKey, merged);
  }

  /// Adds the move of [node] (played from its parent). Returns false if the
  /// move could not be connected.
  bool addNode(GameNode node, {required bool asMain}) {
    final parent = node.parent!;
    final fromKey = parent.key;
    if (!graph.positions.containsKey(fromKey)) {
      stats.outsideMoves++;
      return false;
    }
    final pos = parent.position;
    final move = parseUciMove(pos, node.uci!);
    if (move == null) return false;
    final own = pos.turn == graph.color;
    final existing = graph.move(fromKey, standardUci(pos, move));
    RepMove m;
    if (existing != null) {
      stats.matchedMoves++;
      m = existing;
      if (own && asMain && existing.role != MoveRole.main) {
        final currentMain = graph.mainMove(fromKey);
        if (currentMain == null) {
          graph.setRole(existing, MoveRole.main);
        } else {
          _recordConflict(conflicts, graph, fromKey, currentMain, existing);
        }
      }
    } else {
      final currentMain = own ? graph.mainMove(fromKey) : null;
      final role = !own
          ? MoveRole.opponent
          : (asMain && currentMain == null)
          ? MoveRole.main
          : MoveRole.alternative;
      final r = graph.addMove(pos, move, source: options.source, forceRole: role);
      m = r.move!;
      stats.newMoves++;
      if (own && asMain && currentMain != null) {
        _recordConflict(conflicts, graph, fromKey, currentMain, m);
      }
    }
    addComment(m, node);
    addShapes(m, node);
    return true;
  }

  void walk(GameNode node) {
    // Iterative DFS to support very deep trees.
    final stack = <GameNode>[node];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      if (n.children.isEmpty) continue;
      if (options.maxPly != null && n.depth >= options.maxPly!) continue;
      final own = n.position.turn == graph.color;
      final all = own ? options.ownAllVariations : options.opponentAllVariations;
      final candidates = n.children.where((c) => !c.isNullMove).toList();
      if (candidates.isEmpty) continue;
      final selected = all ? candidates : [candidates.first];
      final inGraph = graph.positions.containsKey(n.key);
      // Add in document order (keeps the variation order), then visit the
      // first child first.
      final next = <GameNode>[];
      for (var i = 0; i < selected.length; i++) {
        final child = selected[i];
        if (!inGraph) {
          // Not yet at the repertoire start position: keep searching.
          next.add(child);
        } else if (addNode(child, asMain: i == 0)) {
          next.add(child);
        }
      }
      stack.addAll(next.reversed);
    }
  }

  for (final src in sources) {
    // Path from the game root to the start node: a single line.
    final line = src.start.line;
    var ok = true;
    for (final n in line) {
      if (n.isNullMove) {
        ok = false;
        break;
      }
      if (options.maxPly != null && n.depth > options.maxPly!) break;
      final parentInGraph = graph.positions.containsKey(n.parent!.key);
      if (!parentInGraph) continue; // before the repertoire start
      if (!addNode(n, asMain: true)) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    walk(src.start);
  }

  stats.newPositions = graph.positions.length - positionsBefore;
  return ImportResult(stats, conflicts.values.toList());
}

void _recordConflict(
  Map<PositionKey, ImportConflict> conflicts,
  RepertoireGraph graph,
  PositionKey key,
  RepMove currentMain,
  RepMove incoming,
) {
  if (currentMain.uci == incoming.uci) return;
  final c = conflicts.putIfAbsent(key, () => ImportConflict(key: key, fen: graph.positions[key]!.fen));
  c.candidates.putIfAbsent(currentMain.uci, () => currentMain.san);
  c.candidates.putIfAbsent(incoming.uci, () => incoming.san);
}

/// How the other candidates of a conflict are treated.
enum ConflictOthers { alternative, delete }

class ConflictResolution {
  const ConflictResolution.choose(this.key, this.mainUci, {this.others = ConflictOthers.alternative}) : defer = false;
  const ConflictResolution.defer(this.key) : mainUci = null, others = ConflictOthers.alternative, defer = true;

  final PositionKey key;
  final String? mainUci;
  final ConflictOthers others;
  final bool defer;
}

/// Applies a conflict resolution (F-REP-06).
void resolveConflict(RepertoireGraph graph, ImportConflict conflict, ConflictResolution r) {
  if (r.defer) {
    graph.setDeferred(conflict.key, true);
    return;
  }
  final main = graph.move(conflict.key, r.mainUci!);
  if (main == null) return;
  graph.setRole(main, MoveRole.main);
  graph.setDeferred(conflict.key, false);
  if (r.others == ConflictOthers.delete) {
    for (final uci in conflict.candidates.keys) {
      if (uci == r.mainUci) continue;
      final m = graph.move(conflict.key, uci);
      if (m != null) graph.deleteMove(m);
    }
  }
}

/// Plays a SAN line (e.g. "e4 c5 Nf3") from [start] into [graph] with
/// default roles. Convenience for the builder and tests.
void addSanLine(RepertoireGraph graph, Position start, List<String> sans, {String source = 'manual'}) {
  var pos = start;
  for (final san in sans) {
    final move = pos.parseSan(san);
    if (move == null) throw ArgumentError('Illegal move $san in ${pos.fen}');
    graph.addMove(pos, move, policy: OwnMovePolicy.asAlternative, source: source);
    pos = pos.play(move);
  }
}
