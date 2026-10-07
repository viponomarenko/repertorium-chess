import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/foundation.dart';

import '../../data/db/database.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';

/// Loaded repertoire + navigation state of the position browser/builder.
class RepertoireController extends ChangeNotifier {
  RepertoireController(this.id, this.repo);

  final int id;
  final RepertoireRepository repo;

  RepertoireRow? row;
  RepertoireGraph? graph;
  Object? error;
  int revision = 0;

  /// Moves from the root to the current position.
  List<RepMove> path = [];

  /// Positions not in the repertoire yet (builder: exploring new moves).
  final List<(Move, String, Position)> pending = [];

  bool get loaded => graph != null;
  Side get color => graph!.color;

  PositionKey get key {
    if (pending.isNotEmpty) return positionKeyOf(pending.last.$3);
    return path.isEmpty ? graph!.rootKey : path.last.toKey;
  }

  Position get position {
    if (pending.isNotEmpty) return pending.last.$3;
    return positionFromFen(graph!.positions[key]!.fen);
  }

  bool get inRepertoire => pending.isEmpty;

  Move? get lastMove {
    if (pending.isNotEmpty) return pending.last.$1;
    if (path.isEmpty) return null;
    return Move.parse(path.last.uci);
  }

  Future<void> load({PositionKey? at}) async {
    // A failure of an earlier load must not outlive a successful one.
    error = null;
    try {
      row = await repo.repertoire(id);
      if (row == null) {
        error = 'not found';
      } else {
        final previous = graph == null ? null : key;
        graph = await repo.loadGraph(id);
        final target = at ?? previous;
        final keepPath = at == null && _pathValid() && (path.isEmpty ? graph!.rootKey : path.last.toKey) == target;
        if (keepPath) {
          // Same line as before (not the shortest transposition to it).
        } else if (target != null && graph!.positions.containsKey(target)) {
          path = graph!.pathFromRoot(target) ?? [];
        } else if (!_pathValid()) {
          path = [];
        }
        pending.clear();
      }
    } catch (e) {
      error = e;
    }
    revision++;
    notifyListeners();
  }

  bool _pathValid() {
    if (graph == null) return false;
    var k = graph!.rootKey;
    for (final m in path) {
      if (m.fromKey != k || graph!.move(m.fromKey, m.uci) == null) return false;
      k = m.toKey;
    }
    return true;
  }

  Future<void> _saving = Future.value();

  /// Counts writes to the database (unlike [revision], which also grows on
  /// every reload). Other screens are told about these only: two screens of
  /// one repertoire telling each other about their reloads would never stop.
  int saves = 0;

  /// Saves one after another (quick moves in the line editor call this
  /// while the previous save is still running).
  Future<void> save() {
    final g = graph;
    if (g == null) return Future.value();
    final next = _saving.catchError((Object _) {}).then((_) => repo.saveGraph(id, g));
    _saving = next;
    return next.then((_) {
      revision++;
      saves++;
      notifyListeners();
    });
  }

  // ------------------------------------------------------------ navigation

  void go(RepMove m) {
    pending.clear();
    path = [...path, m];
    notifyListeners();
  }

  void back() {
    if (pending.isNotEmpty) {
      pending.removeLast();
    } else if (path.isNotEmpty) {
      path = path.sublist(0, path.length - 1);
    }
    notifyListeners();
  }

  void toRoot() {
    pending.clear();
    path = [];
    notifyListeners();
  }

  void truncate(int length) {
    pending.clear();
    path = path.sublist(0, length);
    notifyListeners();
  }

  void jumpTo(PositionKey k) {
    final p = graph?.pathFromRoot(k);
    if (p == null) return;
    pending.clear();
    path = p;
    notifyListeners();
  }

  /// Plays a move on the board: follows the repertoire if the move exists,
  /// otherwise explores it (not yet added).
  void playOnBoard(Move move) {
    final pos = position;
    final norm = normalizeMove(pos, move);
    final uci = standardUci(pos, norm);
    if (inRepertoire) {
      final m = graph!.move(key, uci);
      if (m != null) return go(m);
    }
    final (next, san) = pos.makeSan(norm);
    pending.add((norm, san, next));
    notifyListeners();
  }

  // ------------------------------------------------------------ editing

  /// Adds the explored moves (pending) to the repertoire. For an own move
  /// where a different main exists, [policy] decides (F-REP-02).
  Future<AddMoveOutcome> commitPending({OwnMovePolicy policy = OwnMovePolicy.ask}) async {
    final g = graph!;
    var pos = positionFromFen(g.positions[path.isEmpty ? g.rootKey : path.last.toKey]!.fen);
    final newPath = [...path];
    for (var i = 0; i < pending.length; i++) {
      final (move, _, next) = pending[i];
      // The user's decision covers only the conflict it was asked for;
      // a later conflicting move is asked about again.
      final r = g.addMove(pos, move, policy: i == 0 ? policy : OwnMovePolicy.ask);
      if (r.outcome == AddMoveOutcome.needsDecision) {
        // Keep what was added so far; the caller asks the user.
        path = newPath;
        pending.removeRange(0, i);
        await save();
        return AddMoveOutcome.needsDecision;
      }
      newPath.add(r.move!);
      pos = next;
    }
    pending.clear();
    path = newPath;
    await save();
    return AddMoveOutcome.added;
  }

  /// The main move that conflicts with the first pending own move, if any.
  RepMove? get pendingConflict {
    if (pending.isEmpty || graph == null) return null;
    final fromKey = path.isEmpty ? graph!.rootKey : path.last.toKey;
    if (!graph!.isUserTurn(fromKey)) return null;
    final main = graph!.mainMove(fromKey);
    if (main == null) return null;
    final first = pending.first;
    final pos = positionFromFen(graph!.positions[fromKey]!.fen);
    return standardUci(pos, first.$1) == main.uci ? null : main;
  }

  Future<void> setRole(RepMove m, MoveRole role) async {
    graph!.setRole(m, role);
    await save();
  }

  Future<void> setWeight(RepMove m, int w) async {
    graph!.setWeight(m, w);
    await save();
  }

  Future<void> setMoveComment(RepMove m, String c) async {
    graph!.setMoveComment(m, c);
    await save();
  }

  Future<void> setPositionComment(PositionKey k, String c) async {
    graph!.setPositionComment(k, c);
    await save();
  }

  Future<void> delete(DeletionPlan plan) async {
    graph!.applyDeletion(plan);
    // Navigate back if the current position was removed.
    final idx = path.indexWhere((m) => plan.moves.contains(m.id) || plan.positions.contains(m.toKey));
    if (idx >= 0) path = path.sublist(0, idx);
    pending.clear();
    await save();
  }

  /// Brings back [snapshot] (a clone taken before a deletion) and the path
  /// the user was on.
  Future<void> restore(RepertoireGraph snapshot, List<RepMove> oldPath) async {
    snapshot.markAllChanged();
    // What exists now but not in the snapshot (a move added since) goes.
    final current = graph;
    if (current != null) {
      snapshot.changes.deleteMoves.addAll([
        for (final m in current.allMoves)
          if (snapshot.moveById(m.id) == null) m.id,
      ]);
      snapshot.changes.deletePositions.addAll(current.positions.keys.where((k) => !snapshot.positions.containsKey(k)));
      snapshot.changes.deleteCards.addAll(current.cards.keys.where((k) => !snapshot.cards.containsKey(k)));
    }
    graph = snapshot;
    path = [
      for (final m in oldPath)
        if (snapshot.move(m.fromKey, m.uci) != null) snapshot.move(m.fromKey, m.uci)!,
    ];
    if (!_pathValid()) path = [];
    pending.clear();
    await save();
  }

  Future<int> setSuspended(PositionKey from, bool suspended) async {
    final n = graph!.setSuspendedSubtree(from, suspended);
    await save();
    return n;
  }

  Future<void> setDeferred(PositionKey k, bool deferred) async {
    graph!.setDeferred(k, deferred);
    await save();
  }
}
