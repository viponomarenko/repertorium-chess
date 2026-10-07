/// Repertoire as a graph of positions and moves (ТЗ 3.1-3.3, F-REP).
///
/// The graph is a DAG keyed by [PositionKey]; several paths may lead to the
/// same position (transpositions), so code never assumes a tree (INV-3).
library;

import 'dart:collection';

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';
import '../pgn/pgn_model.dart';
import '../srs/fsrs.dart';

enum MoveRole {
  main,
  alternative,

  /// Opponent move (role is not applicable).
  opponent;

  String get dbValue => this == MoveRole.opponent ? '' : name;

  static MoveRole fromDb(String v) => switch (v) {
    'main' => MoveRole.main,
    'alternative' => MoveRole.alternative,
    _ => MoveRole.opponent,
  };
}

class RepMove {
  RepMove({
    required this.fromKey,
    required this.uci,
    required this.toKey,
    required this.san,
    required this.role,
    this.weight = 50,
    this.comment = '',
    this.source = 'manual',
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final PositionKey fromKey;

  /// Standard UCI (castling e1g1).
  final String uci;
  final PositionKey toKey;
  final String san;
  MoveRole role;
  int weight;
  String comment;
  String source;
  int sortOrder;
  final DateTime createdAt;

  String get id => '$fromKey|$uci';

  RepMove copy() => RepMove(
    fromKey: fromKey,
    uci: uci,
    toKey: toKey,
    san: san,
    role: role,
    weight: weight,
    comment: comment,
    source: source,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );

  @override
  String toString() => 'RepMove($san ${role.name} w=$weight)';
}

class RepPosition {
  RepPosition({
    required this.key,
    required this.fen,
    this.comment = '',
    List<BoardShape>? shapes,
    this.conflictDeferred = false,
    this.engineFlag = '',
  }) : shapes = shapes ?? [];

  final PositionKey key;

  /// A full FEN of the position (counters from the first path that reached it).
  final String fen;
  String comment;
  List<BoardShape> shapes;
  bool conflictDeferred;
  String engineFlag;

  RepPosition copy() => RepPosition(
    key: key,
    fen: fen,
    comment: comment,
    shapes: [...shapes],
    conflictDeferred: conflictDeferred,
    engineFlag: engineFlag,
  );

  Position get position => positionFromFen(fen);
}

class CardInfo {
  CardInfo({required this.srs, this.suspended = false, DateTime? createdAt}) : createdAt = createdAt ?? DateTime.now();

  SrsState srs;
  bool suspended;
  final DateTime createdAt;

  CardInfo copy() => CardInfo(srs: srs, suspended: suspended, createdAt: createdAt);
}

/// Pending changes to persist (so that edits of a 20k-position repertoire
/// do not rewrite everything).
class GraphChanges {
  final Set<PositionKey> upsertPositions = {};
  final Set<PositionKey> deletePositions = {};
  final Set<String> upsertMoves = {};
  final Set<String> deleteMoves = {};
  final Set<PositionKey> upsertCards = {};
  final Set<PositionKey> deleteCards = {};

  bool get isEmpty =>
      upsertPositions.isEmpty &&
      deletePositions.isEmpty &&
      upsertMoves.isEmpty &&
      deleteMoves.isEmpty &&
      upsertCards.isEmpty &&
      deleteCards.isEmpty;

  void clear() {
    upsertPositions.clear();
    deletePositions.clear();
    upsertMoves.clear();
    deleteMoves.clear();
    upsertCards.clear();
    deleteCards.clear();
  }

  /// Moves all pending changes into a new object and clears this one, so
  /// changes made while they are being written are not lost.
  GraphChanges take() {
    final out = GraphChanges()
      ..upsertPositions.addAll(upsertPositions)
      ..deletePositions.addAll(deletePositions)
      ..upsertMoves.addAll(upsertMoves)
      ..deleteMoves.addAll(deleteMoves)
      ..upsertCards.addAll(upsertCards)
      ..deleteCards.addAll(deleteCards);
    clear();
    return out;
  }

  /// Puts back changes that could not be written.
  void restore(GraphChanges other) {
    upsertPositions.addAll(other.upsertPositions);
    deletePositions.addAll(other.deletePositions);
    upsertMoves.addAll(other.upsertMoves);
    deleteMoves.addAll(other.deleteMoves);
    upsertCards.addAll(other.upsertCards);
    deleteCards.addAll(other.deleteCards);
  }
}

/// What to do when adding an own move where a different main move exists
/// (F-REP-02).
enum OwnMovePolicy {
  /// Do nothing, report [AddMoveOutcome.needsDecision].
  ask,

  /// The new move becomes main, the old main becomes an alternative.
  replaceMain,

  /// Add as an alternative.
  asAlternative,
}

enum AddMoveOutcome { added, existed, needsDecision, promotedToMain }

class AddMoveResult {
  const AddMoveResult(this.outcome, this.move, {this.currentMain});
  final AddMoveOutcome outcome;
  final RepMove? move;
  final RepMove? currentMain;
}

class DeletionPlan {
  const DeletionPlan({required this.moves, required this.positions, required this.cards, this.promotedAlternative});

  /// Move ids that will be removed (the edge itself + orphaned subtrees).
  final Set<String> moves;
  final Set<PositionKey> positions;
  final Set<PositionKey> cards;

  /// Alternative that becomes main if the deleted move was main.
  final String? promotedAlternative;
}

class RepertoireGraph {
  RepertoireGraph({required this.color, required this.rootKey, required String rootFen}) {
    positions[rootKey] = RepPosition(key: rootKey, fen: rootFen);
  }

  RepertoireGraph._empty({required this.color, required this.rootKey});

  /// The user's color.
  final Side color;
  final PositionKey rootKey;

  final Map<PositionKey, RepPosition> positions = {};
  final Map<PositionKey, List<RepMove>> _out = {};
  final Map<PositionKey, List<RepMove>> _in = {};
  final Map<PositionKey, CardInfo> cards = {};
  final GraphChanges changes = GraphChanges();

  /// Builds a graph from persisted rows (no change tracking).
  factory RepertoireGraph.load({
    required Side color,
    required PositionKey rootKey,
    required Iterable<RepPosition> positions,
    required Iterable<RepMove> moves,
    required Map<PositionKey, CardInfo> cards,
  }) {
    final g = RepertoireGraph._empty(color: color, rootKey: rootKey);
    for (final p in positions) {
      g.positions[p.key] = p;
    }
    for (final m in moves) {
      g._link(m);
    }
    g.cards.addAll(cards);
    for (final list in g._out.values) {
      list.sort(_moveOrder);
    }
    return g;
  }

  RepertoireGraph clone() {
    final g = RepertoireGraph._empty(color: color, rootKey: rootKey);
    positions.forEach((k, v) => g.positions[k] = v.copy());
    for (final list in _out.values) {
      for (final m in list) {
        g._link(m.copy());
      }
    }
    cards.forEach((k, v) => g.cards[k] = v.copy());
    return g;
  }

  static int _moveOrder(RepMove a, RepMove b) {
    int rank(RepMove m) => switch (m.role) {
      MoveRole.main => 0,
      MoveRole.alternative => 1,
      MoveRole.opponent => 2,
    };
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    if (a.role == MoveRole.opponent) {
      final w = b.weight.compareTo(a.weight);
      if (w != 0) return w;
    }
    return a.sortOrder.compareTo(b.sortOrder);
  }

  void _link(RepMove m) {
    (_out[m.fromKey] ??= []).add(m);
    (_in[m.toKey] ??= []).add(m);
  }

  void _unlink(RepMove m) {
    _out[m.fromKey]?.remove(m);
    if (_out[m.fromKey]?.isEmpty ?? false) _out.remove(m.fromKey);
    _in[m.toKey]?.remove(m);
    if (_in[m.toKey]?.isEmpty ?? false) _in.remove(m.toKey);
  }

  // ------------------------------------------------------------- queries

  RepPosition get root => positions[rootKey]!;

  bool isUserTurn(PositionKey key) => sideToMoveOfKey(key) == color;

  List<RepMove> movesFrom(PositionKey key) => _out[key] ?? const [];

  List<RepMove> movesTo(PositionKey key) => _in[key] ?? const [];

  RepMove? move(PositionKey from, String uci) {
    for (final m in movesFrom(from)) {
      if (m.uci == uci) return m;
    }
    return null;
  }

  RepMove? moveById(String id) {
    final i = id.lastIndexOf('|');
    return move(id.substring(0, i), id.substring(i + 1));
  }

  RepMove? mainMove(PositionKey key) {
    for (final m in movesFrom(key)) {
      if (m.role == MoveRole.main) return m;
    }
    return null;
  }

  List<RepMove> alternatives(PositionKey key) => movesFrom(key).where((m) => m.role == MoveRole.alternative).toList();

  int get moveCount => _out.values.fold(0, (a, l) => a + l.length);

  Iterable<RepMove> get allMoves sync* {
    for (final l in _out.values) {
      yield* l;
    }
  }

  /// Whether training of [key] is possible (a card exists, not deferred).
  bool isTrainable(PositionKey key) {
    final c = cards[key];
    final p = positions[key];
    return c != null && !c.suspended && p != null && !p.conflictDeferred;
  }

  /// Positions reachable from [from] following moves (BFS).
  Set<PositionKey> reachableFrom(PositionKey from, {String? skipMoveId}) {
    final seen = <PositionKey>{from};
    final queue = Queue<PositionKey>()..add(from);
    while (queue.isNotEmpty) {
      final k = queue.removeFirst();
      for (final m in movesFrom(k)) {
        if (m.id == skipMoveId) continue;
        if (seen.add(m.toKey)) queue.add(m.toKey);
      }
    }
    return seen;
  }

  /// Shortest move path from the root to [target] (null if unreachable).
  List<RepMove>? pathFromRoot(PositionKey target, {PositionKey? from}) {
    final start = from ?? rootKey;
    if (target == start) return [];
    final prev = <PositionKey, RepMove>{};
    final queue = Queue<PositionKey>()..add(start);
    final seen = {start};
    while (queue.isNotEmpty) {
      final k = queue.removeFirst();
      for (final m in movesFrom(k)) {
        if (!seen.add(m.toKey)) continue;
        prev[m.toKey] = m;
        if (m.toKey == target) {
          final path = <RepMove>[];
          var cur = target;
          while (cur != start) {
            final pm = prev[cur]!;
            path.add(pm);
            cur = pm.fromKey;
          }
          return path.reversed.toList();
        }
        queue.add(m.toKey);
      }
    }
    return null;
  }

  // ------------------------------------------------------------- mutation

  RepPosition _ensurePosition(PositionKey key, String fen) {
    final existing = positions[key];
    if (existing != null) return existing;
    final p = RepPosition(key: key, fen: fen);
    positions[key] = p;
    changes.upsertPositions.add(key);
    changes.deletePositions.remove(key);
    return p;
  }

  void touchPosition(PositionKey key) => changes.upsertPositions.add(key);

  void touchMove(RepMove m) => changes.upsertMoves.add(m.id);

  void _addMoveRaw(RepMove m) {
    m.sortOrder = movesFrom(m.fromKey).length;
    _link(m);
    _out[m.fromKey]!.sort(_moveOrder);
    changes.upsertMoves.add(m.id);
    changes.deleteMoves.remove(m.id);
  }

  /// Adds [move] played in [from] (F-REP-02).
  AddMoveResult addMove(
    Position from,
    Move move, {
    OwnMovePolicy policy = OwnMovePolicy.ask,
    String source = 'manual',
    String comment = '',
    int weight = 50,
    MoveRole? forceRole,
  }) {
    final fromKey = positionKeyOf(from);
    final norm = normalizeMove(from, move);
    final uci = standardUci(from, norm);
    final existing = this.move(fromKey, uci);
    final own = from.turn == color;
    if (existing != null) {
      if (own && forceRole == MoveRole.main && existing.role != MoveRole.main) {
        _setMain(existing);
        return AddMoveResult(AddMoveOutcome.promotedToMain, existing);
      }
      return AddMoveResult(AddMoveOutcome.existed, existing);
    }
    final currentMain = own ? mainMove(fromKey) : null;
    MoveRole role;
    if (!own) {
      role = MoveRole.opponent;
    } else if (forceRole != null) {
      role = forceRole;
    } else if (currentMain == null) {
      role = MoveRole.main;
    } else {
      switch (policy) {
        case OwnMovePolicy.ask:
          return AddMoveResult(AddMoveOutcome.needsDecision, null, currentMain: currentMain);
        case OwnMovePolicy.replaceMain:
          role = MoveRole.main;
        case OwnMovePolicy.asAlternative:
          role = MoveRole.alternative;
      }
    }
    _ensurePosition(fromKey, from.fen);
    final (next, san) = from.makeSan(norm);
    final toKey = positionKeyOf(next);
    _ensurePosition(toKey, next.fen);
    final m = RepMove(
      fromKey: fromKey,
      uci: uci,
      toKey: toKey,
      san: san,
      role: role == MoveRole.main ? MoveRole.alternative : role,
      weight: weight,
      comment: comment,
      source: source,
    );
    _addMoveRaw(m);
    if (role == MoveRole.main) _setMain(m);
    _ensureCard(fromKey);
    return AddMoveResult(AddMoveOutcome.added, m, currentMain: currentMain);
  }

  /// Makes [m] the main move (INV-1): the previous main becomes alternative.
  void _setMain(RepMove m) {
    for (final other in movesFrom(m.fromKey)) {
      if (other.role == MoveRole.main && other != m) {
        other.role = MoveRole.alternative;
        changes.upsertMoves.add(other.id);
      }
    }
    m.role = MoveRole.main;
    changes.upsertMoves.add(m.id);
    _out[m.fromKey]!.sort(_moveOrder);
    _ensureCard(m.fromKey);
  }

  /// Changes the role of an own move (F-REP-08).
  void setRole(RepMove m, MoveRole role) {
    if (!isUserTurn(m.fromKey)) return;
    if (role == MoveRole.main) {
      _setMain(m);
    } else if (role == MoveRole.alternative) {
      m.role = MoveRole.alternative;
      changes.upsertMoves.add(m.id);
      // Keep INV-4: a position without main has no card.
      if (mainMove(m.fromKey) == null) _dropCard(m.fromKey);
      _out[m.fromKey]!.sort(_moveOrder);
    }
  }

  void setWeight(RepMove m, int weight) {
    m.weight = weight.clamp(0, 100);
    changes.upsertMoves.add(m.id);
    _out[m.fromKey]?.sort(_moveOrder);
  }

  void setMoveComment(RepMove m, String comment) {
    m.comment = comment;
    changes.upsertMoves.add(m.id);
  }

  void setPositionComment(PositionKey key, String comment) {
    final p = positions[key];
    if (p == null) return;
    p.comment = comment;
    changes.upsertPositions.add(key);
  }

  void setPositionShapes(PositionKey key, List<BoardShape> shapes) {
    final p = positions[key];
    if (p == null) return;
    p.shapes = shapes;
    changes.upsertPositions.add(key);
  }

  void setDeferred(PositionKey key, bool deferred) {
    final p = positions[key];
    if (p == null) return;
    p.conflictDeferred = deferred;
    changes.upsertPositions.add(key);
  }

  void _ensureCard(PositionKey key) {
    if (!isUserTurn(key)) return;
    if (mainMove(key) == null) return;
    if (cards.containsKey(key)) return;
    cards[key] = CardInfo(srs: const SrsState());
    changes.upsertCards.add(key);
    changes.deleteCards.remove(key);
  }

  void _dropCard(PositionKey key) {
    if (cards.remove(key) != null) {
      changes.deleteCards.add(key);
      changes.upsertCards.remove(key);
    }
  }

  void updateCard(PositionKey key, SrsState srs) {
    final c = cards[key];
    if (c == null) return;
    c.srs = srs;
    changes.upsertCards.add(key);
  }

  /// How much of the subtree reachable from [from] is suspended: no card
  /// at all, some of them, or every one.
  ({bool any, bool all}) suspension(PositionKey from) {
    var any = false;
    var all = true;
    var cardsSeen = false;
    for (final k in reachableFrom(from)) {
      final c = cards[k];
      if (c == null) continue;
      cardsSeen = true;
      if (c.suspended) {
        any = true;
      } else {
        all = false;
      }
    }
    return (any: any, all: cardsSeen && all);
  }

  /// Marks everything as changed, so that the next save writes the whole
  /// graph (used to bring back a snapshot taken before a deletion).
  void markAllChanged() {
    changes.upsertPositions.addAll(positions.keys);
    changes.upsertMoves.addAll(allMoves.map((m) => m.id));
    changes.upsertCards.addAll(cards.keys);
  }

  /// Suspends / resumes all cards in the subtree reachable from [from]
  /// (F-REP-08). Returns the number of affected cards.
  int setSuspendedSubtree(PositionKey from, bool suspended) {
    var n = 0;
    for (final k in reachableFrom(from)) {
      final c = cards[k];
      if (c != null && c.suspended != suspended) {
        c.suspended = suspended;
        changes.upsertCards.add(k);
        n++;
      }
    }
    return n;
  }

  /// Computes what deleting a move removes (INV-5).
  DeletionPlan planDeleteMove(RepMove m) {
    final reachable = reachableFrom(rootKey, skipMoveId: m.id);
    final orphanPositions = positions.keys.where((k) => !reachable.contains(k)).toSet();
    final moves = <String>{m.id};
    for (final k in orphanPositions) {
      for (final om in movesFrom(k)) {
        moves.add(om.id);
      }
    }
    final orphanCards = orphanPositions.where(cards.containsKey).toSet();
    String? promoted;
    if (m.role == MoveRole.main) {
      final alts = alternatives(m.fromKey);
      if (alts.isNotEmpty) promoted = alts.first.id;
    }
    // The origin loses its card if no main remains.
    if (m.role == MoveRole.main && promoted == null && cards.containsKey(m.fromKey)) {
      orphanCards.add(m.fromKey);
    }
    return DeletionPlan(moves: moves, positions: orphanPositions, cards: orphanCards, promotedAlternative: promoted);
  }

  void applyDeletion(DeletionPlan plan) {
    for (final id in plan.moves) {
      final mv = moveById(id);
      if (mv == null) continue;
      _unlink(mv);
      changes.deleteMoves.add(id);
      changes.upsertMoves.remove(id);
    }
    for (final k in plan.positions) {
      positions.remove(k);
      changes.deletePositions.add(k);
      changes.upsertPositions.remove(k);
    }
    for (final k in plan.cards) {
      _dropCard(k);
    }
    if (plan.promotedAlternative != null) {
      final alt = moveById(plan.promotedAlternative!);
      if (alt != null) _setMain(alt);
    }
  }

  void deleteMove(RepMove m) => applyDeletion(planDeleteMove(m));

  /// Positions where two or more own moves compete for `main`: never
  /// possible in a consistent graph (INV-1) — used by [checkInvariants].
  List<String> checkInvariants() {
    final errors = <String>[];
    for (final k in positions.keys) {
      final out = movesFrom(k);
      final mains = out.where((m) => m.role == MoveRole.main).length;
      if (isUserTurn(k)) {
        if (mains > 1) errors.add('INV-1: $k has $mains main moves');
        if (out.any((m) => m.role == MoveRole.opponent)) {
          errors.add('INV-1: $k has opponent-role moves on the user side');
        }
        final hasCard = cards.containsKey(k);
        if (mains == 1 && !hasCard) errors.add('INV-4: $k has main but no card');
        if (mains == 0 && hasCard) errors.add('INV-4: $k has a card without main');
      } else {
        if (out.any((m) => m.role != MoveRole.opponent)) {
          errors.add('INV-2: $k has own-role moves on the opponent side');
        }
        if (cards.containsKey(k)) errors.add('INV-4: opponent position $k has a card');
      }
      for (final m in out) {
        if (!positions.containsKey(m.toKey)) errors.add('dangling move ${m.id}');
      }
    }
    final reachable = reachableFrom(rootKey);
    for (final k in positions.keys) {
      if (!reachable.contains(k)) errors.add('INV-5: $k unreachable');
    }
    for (final k in cards.keys) {
      if (!positions.containsKey(k)) errors.add('card without position $k');
    }
    return errors;
  }

  /// Positions that are reached by more than one move (transpositions).
  List<RepMove> transpositionsInto(PositionKey key) => movesTo(key);

  /// Own-move positions of the user without any continuation although the
  /// opponent position before has moves: "gaps" (F-REP-07 filter).
  bool isGap(PositionKey key) => isUserTurn(key) && movesFrom(key).isEmpty && key != rootKey;

  /// Leaf positions (no continuation) — ends of lines.
  bool isLeaf(PositionKey key) => movesFrom(key).isEmpty;
}
