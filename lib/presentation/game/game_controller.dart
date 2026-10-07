import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/foundation.dart';

import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../../domain/pgn/pgn_writer.dart';
import '../theme/tokens.dart';

class _Snapshot {
  const _Snapshot(this.pgn, this.path);
  final String pgn;
  final List<int> path;
}

/// State of the game viewer/editor (F-VIEW, F-EDIT).
///
/// Edits are snapshot-based (PGN + current path), which gives undo/redo
/// for every operation (F-EDIT-04). Persisted games are auto-saved with a
/// short debounce.
class GameController extends ChangeNotifier {
  GameController({required ChessGame game, this.onSave, this.autosaveDelay = AppTiming.autosave})
    : _game = game,
      _current = game.root;

  ChessGame _game;
  GameNode _current;

  /// Set later when an analysis is saved into the library.
  Future<void> Function(ChessGame game)? onSave;
  final Duration autosaveDelay;

  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];
  Timer? _saveTimer;
  bool _dirty = false;
  int _revision = 0;
  Future<void>? _saveInFlight;
  Object? _saveError;
  bool _disposed = false;

  ChessGame get game => _game;
  GameNode get current => _current;
  Position get position => _current.position;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get dirty => _dirty;
  bool get saving => _saveInFlight != null;
  Object? get saveError => _saveError;

  /// Changes whenever the tree changes (not on navigation).
  int get revision => _revision;

  Move? get lastMove {
    final uci = _current.uci;
    if (uci == null || _current.isNullMove) return null;
    return Move.parse(uci);
  }

  // ------------------------------------------------------------ navigation

  void goTo(GameNode n) {
    if (identical(n, _current)) return;
    _current = n;
    notifyListeners();
  }

  bool get canBack => _current.parent != null;
  bool get canForward => _current.children.isNotEmpty;

  void back() {
    if (_current.parent != null) goTo(_current.parent!);
  }

  void forward([int index = 0]) {
    if (index < _current.children.length) goTo(_current.children[index]);
  }

  void toStart() => goTo(_game.root);

  void toEnd() {
    var n = _current;
    while (n.children.isNotEmpty) {
      n = n.children.first;
    }
    goTo(n);
  }

  void goToPath(List<int> path) {
    final n = _game.nodeAt(path);
    if (n != null) goTo(n);
  }

  // ------------------------------------------------------------ editing

  _Snapshot _snap() => _Snapshot(gameToPgn(_game), _current.path);

  void _restore(_Snapshot s) {
    final g = PgnParser.parseOne(s.pgn);
    _game = g;
    _current = g.nodeAt(s.path) ?? g.root;
  }

  void _beginEdit() {
    _undo.add(_snap());
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
  }

  void _endEdit() {
    _revision++;
    _dirty = true;
    notifyListeners();
    _scheduleSave();
  }

  void _scheduleSave() {
    if (onSave == null) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(autosaveDelay, () => unawaited(_autoFlush()));
  }

  Future<void> _autoFlush() async {
    try {
      await flush();
    } catch (_) {
      // The controller keeps the pending revision and exposes the error to UI.
    }
  }

  /// Serializes writes and drains edits made while a write is in flight.
  Future<void> flush() {
    _saveTimer?.cancel();
    if (_saveInFlight != null) return _saveInFlight!;
    if (!_dirty || onSave == null) return Future.value();
    final completer = Completer<void>();
    _saveInFlight = completer.future;
    _saveError = null;
    if (!_disposed) notifyListeners();
    unawaited(_drainSaves(completer));
    return completer.future;
  }

  Future<void> _drainSaves(Completer<void> completer) async {
    Object? failure;
    StackTrace? trace;
    try {
      while (_dirty && onSave != null) {
        final revision = _revision;
        // The repository must see an immutable snapshot while awaiting I/O.
        final snapshot = PgnParser.parseOne(gameToPgn(_game));
        await onSave!(snapshot);
        if (_revision == revision) _dirty = false;
      }
    } catch (e, st) {
      _saveError = failure = e;
      trace = st;
    } finally {
      _saveInFlight = null;
      if (!_disposed) notifyListeners();
    }
    if (failure == null) {
      completer.complete();
    } else {
      completer.completeError(failure, trace);
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snap());
    _restore(_undo.removeLast());
    _endEdit();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snap());
    _restore(_redo.removeLast());
    _endEdit();
  }

  /// Plays a move from the current position: goes to an existing child or
  /// creates a new variation (F-EDIT-01). Returns the node.
  GameNode playMove(Move move) {
    final existing = _current.findChild(move);
    if (existing != null) {
      goTo(existing);
      return existing;
    }
    _beginEdit();
    final n = _current.addMove(move);
    _current = n;
    _endEdit();
    return n;
  }

  /// Adds a sequence of UCI moves as a variation from [from] (engine line).
  void addLine(GameNode from, List<String> uciMoves) {
    _beginEdit();
    var n = from;
    for (final u in uciMoves) {
      final m = parseUciMove(n.position, u);
      if (m == null) break;
      n = n.addMove(m);
    }
    // The cursor stays where the user is studying: the line appears in the
    // notation as a variation and can be opened from there.
    _endEdit();
  }

  /// Moves a variation one step up among its siblings (F-EDIT-02).
  void promote(GameNode n) {
    final p = n.parent;
    if (p == null) return;
    final i = p.children.indexOf(n);
    if (i <= 0) return;
    _beginEdit();
    p.children
      ..removeAt(i)
      ..insert(i - 1, n);
    _endEdit();
  }

  /// Makes the line through [n] the main line.
  void makeMainline(GameNode n) {
    _beginEdit();
    GameNode node = n;
    while (node.parent != null) {
      final p = node.parent!;
      p.children
        ..remove(node)
        ..insert(0, node);
      node = p;
    }
    _endEdit();
  }

  /// Deletes [n] and everything after it.
  void deleteNode(GameNode n) {
    final p = n.parent;
    if (p == null) return;
    _beginEdit();
    p.children.remove(n);
    if (_isDescendantOrSelf(_current, n)) _current = p;
    _endEdit();
  }

  /// Deletes all moves after [n].
  void deleteAfter(GameNode n) {
    if (n.children.isEmpty) return;
    _beginEdit();
    if (!identical(_current, n) && _isDescendantOrSelf(_current, n)) _current = n;
    n.children.clear();
    _endEdit();
  }

  bool _isDescendantOrSelf(GameNode x, GameNode ancestor) {
    GameNode? c = x;
    while (c != null) {
      if (identical(c, ancestor)) return true;
      c = c.parent;
    }
    return false;
  }

  /// Sets the comment text of [n], keeping shapes and `[%...]` commands.
  void setComment(GameNode n, String text, {bool before = false}) {
    _beginEdit();
    final list = before ? n.startComments : (n.isRoot ? _game.root.comments : n.comments);
    final shapes = [for (final c in list) ...c.shapes];
    final commands = [for (final c in list) ...c.commands];
    list
      ..clear()
      ..add(PgnComment(text: text.trim(), shapes: shapes, commands: commands));
    list.removeWhere((c) => c.isEmpty);
    _endEdit();
  }

  /// Toggles a NAG. Move-quality NAGs (1..6) and evaluation NAGs (10..19)
  /// are mutually exclusive within their group.
  void toggleNag(GameNode n, int nag) {
    if (n.isRoot) return;
    _beginEdit();
    if (n.nags.contains(nag)) {
      n.nags.remove(nag);
    } else {
      bool sameGroup(int x) => (nag <= 6 && x <= 6) || (nag >= 10 && nag <= 19 && x >= 10 && x <= 19);
      n.nags.removeWhere(sameGroup);
      n.nags.add(nag);
      n.nags.sort();
    }
    _endEdit();
  }

  void clearNags(GameNode n) {
    if (n.nags.isEmpty) return;
    _beginEdit();
    n.nags.clear();
    _endEdit();
  }

  /// Adds / removes / recolors a shape on the current node (F-EDIT-03).
  void toggleShape(BoardShape s) {
    final n = _current;
    _beginEdit();
    final list = n.isRoot ? _game.root.comments : n.comments;
    final all = [for (final c in list) ...c.shapes];
    final sameSquares = all
        .where((x) => x.orig == s.orig && (x.isArrow ? x.dest : null) == (s.isArrow ? s.dest : null))
        .toList();
    if (sameSquares.any((x) => x.color == s.color)) {
      all.removeWhere(sameSquares.contains);
    } else {
      all
        ..removeWhere(sameSquares.contains)
        ..add(s);
    }
    _setShapes(list, all);
    _endEdit();
  }

  void clearShapes() {
    final list = _current.isRoot ? _game.root.comments : _current.comments;
    if (!list.any((c) => c.shapes.isNotEmpty)) return;
    _beginEdit();
    _setShapes(list, const []);
    _endEdit();
  }

  void _setShapes(List<PgnComment> list, List<BoardShape> shapes) {
    if (list.isEmpty) {
      list.add(PgnComment(shapes: shapes));
    } else {
      for (var i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(shapes: i == 0 ? shapes : const []);
      }
    }
    list.removeWhere((c) => c.isEmpty);
  }

  List<BoardShape> get currentShapes {
    final list = _current.isRoot ? _game.root.comments : _current.comments;
    return [for (final c in list) ...c.shapes];
  }

  void setHeaders(Map<String, String> headers) {
    _beginEdit();
    _game.headers
      ..clear()
      ..addAll(headers);
    _endEdit();
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    if (_dirty) unawaited(_autoFlush());
    super.dispose();
  }
}
