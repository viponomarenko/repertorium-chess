/// In-memory model of a PGN game: a tree of moves with variations,
/// comments, NAGs, shapes and unknown `[%...]` commands (ТЗ 3.2, MoveNode).
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';

enum ShapeColor {
  green('G'),
  red('R'),
  blue('B'),
  yellow('Y');

  const ShapeColor(this.letter);
  final String letter;

  static ShapeColor? fromLetter(String l) {
    switch (l.toUpperCase()) {
      case 'G':
        return ShapeColor.green;
      case 'R':
        return ShapeColor.red;
      case 'B':
        return ShapeColor.blue;
      case 'Y':
        return ShapeColor.yellow;
    }
    return null;
  }
}

/// An arrow (orig != dest) or a highlighted square (dest == null).
class BoardShape {
  const BoardShape(this.color, this.orig, [this.dest]);

  final ShapeColor color;
  final Square orig;
  final Square? dest;

  bool get isArrow => dest != null && dest != orig;

  String get encoded => '${color.letter}${orig.name}${isArrow ? dest!.name : ''}';

  static BoardShape? parse(String s) {
    final t = s.trim();
    if (t.length != 3 && t.length != 5) return null;
    final color = ShapeColor.fromLetter(t[0]);
    final orig = Square.parse(t.substring(1, 3));
    if (color == null || orig == null) return null;
    if (t.length == 3) return BoardShape(color, orig);
    final dest = Square.parse(t.substring(3, 5));
    if (dest == null) return null;
    return BoardShape(color, orig, dest);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardShape && other.color == color && other.orig == orig && other.dest == (isArrow ? dest : null);

  @override
  int get hashCode => Object.hash(color, orig, isArrow ? dest : null);

  @override
  String toString() => encoded;
}

/// A PGN comment `{...}` split into free text, shapes and other commands.
class PgnComment {
  const PgnComment({this.text = '', this.shapes = const [], this.commands = const []});

  /// Free text without embedded commands (trimmed).
  final String text;
  final List<BoardShape> shapes;

  /// Unknown or non-shape commands, raw, without brackets, e.g.
  /// `%clk 0:03:00`, `%eval 0.25`, `%emt 0:00:05`.
  final List<String> commands;

  bool get isEmpty => text.isEmpty && shapes.isEmpty && commands.isEmpty;

  String? command(String name) {
    for (final c in commands) {
      if (c.startsWith('%$name ') || c == '%$name') {
        return c.substring(name.length + 1).trim();
      }
    }
    return null;
  }

  PgnComment copyWith({String? text, List<BoardShape>? shapes, List<String>? commands}) =>
      PgnComment(text: text ?? this.text, shapes: shapes ?? this.shapes, commands: commands ?? this.commands);

  static final _cmdRe = RegExp(r'\[%([A-Za-z_][A-Za-z0-9_]*)\s*([^\]]*)\]');

  /// Parses the raw inside of `{...}`.
  factory PgnComment.parse(String raw) {
    final shapes = <BoardShape>[];
    final commands = <String>[];
    final text = raw.replaceAllMapped(_cmdRe, (m) {
      final name = m.group(1)!;
      final args = m.group(2)!.trim();
      if (name == 'cal' || name == 'csl') {
        for (final part in args.split(',')) {
          final s = BoardShape.parse(part);
          if (s != null) shapes.add(s);
        }
      } else {
        commands.add(args.isEmpty ? '%$name' : '%$name $args');
      }
      return ' ';
    });
    return PgnComment(text: text.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim(), shapes: shapes, commands: commands);
  }

  /// Serializes back to the inside of `{...}`.
  String encode() {
    final parts = <String>[];
    for (final c in commands) {
      parts.add('[$c]');
    }
    final circles = shapes.where((s) => !s.isArrow).map((s) => s.encoded);
    final arrows = shapes.where((s) => s.isArrow).map((s) => s.encoded);
    if (circles.isNotEmpty) parts.add('[%csl ${circles.join(',')}]');
    if (arrows.isNotEmpty) parts.add('[%cal ${arrows.join(',')}]');
    final t = text.replaceAll('}', ')');
    if (t.isNotEmpty) parts.add(t);
    return parts.join(' ');
  }

  @override
  bool operator ==(Object other) =>
      other is PgnComment && other.text == text && _setEq(other.shapes, shapes) && _listEq(other.commands, commands);

  @override
  int get hashCode => Object.hash(text, Object.hashAllUnordered(shapes));

  @override
  String toString() => '{${encode()}}';
}

bool _setEq<T>(List<T> a, List<T> b) => a.length == b.length && a.toSet().containsAll(b) && b.toSet().containsAll(a);

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A node of the move tree. The root has no move; its [position] is the
/// starting position and its [comments] are the game comment.
class GameNode {
  GameNode.root(this.position) : parent = null, san = null, uci = null, isNullMove = false;

  GameNode._child({
    required GameNode this.parent,
    required this.position,
    required String this.san,
    required String this.uci,
    this.isNullMove = false,
  });

  GameNode? parent;
  final Position position;

  /// SAN as produced by the move generator (normalized), null for root.
  final String? san;

  /// Standard UCI (castling e1g1). `0000` for a null move.
  final String? uci;
  final bool isNullMove;

  /// Comments before the move (e.g. at the start of a variation).
  List<PgnComment> startComments = [];

  /// Comments after the move.
  List<PgnComment> comments = [];
  List<int> nags = [];
  final List<GameNode> children = [];

  bool get isRoot => parent == null;
  String get fen => position.fen;
  PositionKey get key => positionKeyOf(position);

  /// Ply counted from the root (root = 0).
  int get depth {
    var d = 0;
    GameNode? n = parent;
    while (n != null) {
      d++;
      n = n.parent;
    }
    return d;
  }

  /// Side that made the move of this node.
  Side get moverSide => position.turn.opposite;

  /// Move number of this node's move (as printed in PGN).
  int get moveNumber {
    final p = parent!.position;
    return p.fullmoves;
  }

  /// True if this node is on the main line from the root.
  bool get isMainline {
    GameNode node = this;
    while (node.parent != null) {
      if (node.parent!.children.first != node) return false;
      node = node.parent!;
    }
    return true;
  }

  int get indexInParent => parent == null ? 0 : parent!.children.indexOf(this);

  GameNode? get mainChild => children.isEmpty ? null : children.first;

  /// All shapes from the comments after this move.
  List<BoardShape> get shapes => [for (final c in comments) ...c.shapes];

  String get commentText => comments.map((c) => c.text).where((t) => t.isNotEmpty).join(' ');

  String get startCommentText => startComments.map((c) => c.text).where((t) => t.isNotEmpty).join(' ');

  /// Adds (or finds) a child for [move] played from this node.
  GameNode addMove(Move move) {
    final norm = normalizeMove(position, move);
    for (final c in children) {
      if (!c.isNullMove && parseUciMove(position, c.uci!) == norm) return c;
    }
    final (next, san) = position.makeSan(norm);
    final child = GameNode._child(parent: this, position: next, san: san, uci: standardUci(position, norm));
    children.add(child);
    return child;
  }

  /// Finds the existing child for [move], if any.
  GameNode? findChild(Move move) {
    final norm = normalizeMove(position, move);
    for (final c in children) {
      if (!c.isNullMove && parseUciMove(position, c.uci!) == norm) return c;
    }
    return null;
  }

  GameNode addNullMove() {
    for (final c in children) {
      if (c.isNullMove) return c;
    }
    final child = GameNode._child(
      parent: this,
      position: playNullMove(position),
      san: '--',
      uci: '0000',
      isNullMove: true,
    );
    children.add(child);
    return child;
  }

  /// Path of child indices from the root to this node.
  List<int> get path {
    final p = <int>[];
    GameNode node = this;
    while (node.parent != null) {
      p.add(node.parent!.children.indexOf(node));
      node = node.parent!;
    }
    return p.reversed.toList();
  }

  /// Nodes from the first move to this node (root excluded).
  List<GameNode> get line {
    final l = <GameNode>[];
    GameNode? node = this;
    while (node != null && node.parent != null) {
      l.add(node);
      node = node.parent;
    }
    return l.reversed.toList();
  }

  /// Number of nodes in this subtree (excluding this node).
  int get subtreeSize {
    var n = 0;
    final stack = [...children];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      n++;
      stack.addAll(c.children);
    }
    return n;
  }

  /// Iterates over all descendants depth-first (pre-order).
  Iterable<GameNode> descendants() sync* {
    final stack = <GameNode>[...children.reversed];
    while (stack.isNotEmpty) {
      final n = stack.removeLast();
      yield n;
      stack.addAll(n.children.reversed);
    }
  }

  @override
  String toString() => 'GameNode(${san ?? 'root'}, ${children.length} children)';
}

/// Problem found while parsing a PGN file (F-IMP-05).
/// Starts the comment that keeps the moves the parser could not read
/// (an illegal move breaks the main line; an unsupported variant has no
/// readable moves at all). Nothing of the original text is lost.
const kUnparsedMarker = '[?]';

class ParseIssue {
  const ParseIssue({required this.line, required this.message, this.token, this.gameIndex = 0});

  final int line;
  final String message;
  final String? token;
  final int gameIndex;

  @override
  String toString() => 'Game ${gameIndex + 1}, line $line: $message${token != null ? ' ($token)' : ''}';
}

/// "White - Black" from PGN headers; an unknown ("?") or empty side is
/// left out, so there is no dangling dash; '' when both are unknown.
String playersLine(String? white, String? black) {
  String clean(String? s) => s == null || s.trim() == '?' ? '' : s.trim();
  return [clean(white), clean(black)].where((s) => s.isNotEmpty).join(' - ');
}

class ChessGame {
  ChessGame({Map<String, String>? headers, GameNode? root, List<ParseIssue>? issues})
    : headers = headers ?? <String, String>{},
      root = root ?? GameNode.root(Chess.initial),
      issues = issues ?? [];

  factory ChessGame.fromFen(String fen) {
    final pos = positionFromFen(fen);
    final g = ChessGame(root: GameNode.root(pos));
    g.headers.addAll(defaultHeaders());
    if (pos.fen != Chess.initial.fen) {
      g.headers['SetUp'] = '1';
      g.headers['FEN'] = pos.fen;
    }
    return g;
  }

  final Map<String, String> headers;
  GameNode root;
  final List<ParseIssue> issues;

  static Map<String, String> defaultHeaders() => Map.of({
    'Event': '?',
    'Site': '?',
    'Date': '????.??.??',
    'Round': '?',
    'White': '?',
    'Black': '?',
    'Result': '*',
  });

  String get startFen => root.fen;

  /// A game holding only the line through [node]: the moves from the start
  /// to it and on along its main continuation, with their comments and
  /// annotations; side variations are left out (to learn one line of a
  /// lecture at a time).
  ChessGame lineThrough(GameNode node) {
    final g = ChessGame(headers: Map.of(headers), root: GameNode.root(root.position));
    g.root.comments = [...root.comments];
    final src = [...node.line];
    for (var n = node.mainChild; n != null; n = n.mainChild) {
      src.add(n);
    }
    var dst = g.root;
    for (final s in src) {
      if (s.isNullMove) break;
      final m = parseUciMove(dst.position, s.uci!);
      if (m == null) break;
      dst = dst.addMove(m)
        ..comments = [...s.comments]
        ..startComments = [...s.startComments]
        ..nags = [...s.nags];
    }
    return g;
  }

  GameNode? nodeAt(List<int> path) {
    GameNode node = root;
    for (final i in path) {
      if (i < 0 || i >= node.children.length) return null;
      node = node.children[i];
    }
    return node;
  }

  /// Whether a comment still holds moves the parser could not read.
  bool get hasUnparsedTail {
    bool marked(GameNode n) => n.comments.any((c) => c.text.startsWith(kUnparsedMarker));
    return marked(root) || root.descendants().any(marked);
  }

  List<GameNode> get mainline {
    final l = <GameNode>[];
    var n = root.mainChild;
    while (n != null) {
      l.add(n);
      n = n.mainChild;
    }
    return l;
  }

  int get nodeCount => root.subtreeSize;

  String? header(String name) {
    final v = headers[name];
    if (v == null || v.isEmpty || v == '?' || v == '????.??.??') return null;
    return v;
  }
}
