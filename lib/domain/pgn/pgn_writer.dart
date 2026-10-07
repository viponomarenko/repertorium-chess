/// PGN serialization (F-EDIT-06, F-EDIT-07).
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import 'pgn_model.dart';

const _strOrder = ['Event', 'Site', 'Date', 'Round', 'White', 'Black', 'Result'];

class PgnWriter {
  PgnWriter({this.lineWidth = 80, this.includeComments = true, this.includeVariations = true});

  final int lineWidth;
  final bool includeComments;
  final bool includeVariations;

  String write(ChessGame game) {
    final sb = StringBuffer();
    _writeHeaders(sb, game);
    sb.write('\n');
    final tokens = <String>[];
    _writeMovetext(game, tokens);
    tokens.add(game.headers['Result'] ?? '*');
    sb.write(_wrap(tokens));
    sb.write('\n');
    return sb.toString();
  }

  String writeAll(Iterable<ChessGame> games) => games.map(write).join('\n');

  void _writeHeaders(StringBuffer sb, ChessGame game) {
    final h = game.headers;
    final written = <String>{};
    // Seven Tag Roster first when present, then the rest in original order.
    final strPresent = _strOrder.where(h.containsKey).length;
    if (strPresent >= 3) {
      for (final k in _strOrder) {
        final v = h[k];
        if (v != null) {
          sb.write('[$k "${_escape(v)}"]\n');
          written.add(k);
        }
      }
    }
    for (final e in h.entries) {
      if (written.contains(e.key)) continue;
      sb.write('[${e.key} "${_escape(e.value)}"]\n');
    }
  }

  String _escape(String v) => v.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  void _writeMovetext(ChessGame game, List<String> out) {
    if (includeComments) {
      for (final c in game.root.comments) {
        if (!c.isEmpty) out.add('{${c.encode()}}');
      }
    }
    _writeLine(game.root, out, forceNumber: true);
  }

  String _moveNumberPrefix(GameNode node, bool force) {
    final parentPos = node.parent!.position;
    if (parentPos.turn == Side.white) return '${parentPos.fullmoves}. ';
    return force ? '${parentPos.fullmoves}... ' : '';
  }

  String _moveToken(GameNode node, bool force) {
    final sb = StringBuffer(_moveNumberPrefix(node, force));
    sb.write(node.san);
    return sb.toString();
  }

  void _writeNodeAnnotations(GameNode node, List<String> out) {
    for (final n in node.nags) {
      out.add('\$$n');
    }
    if (includeComments) {
      for (final c in node.comments) {
        if (!c.isEmpty) out.add('{${c.encode()}}');
      }
    }
  }

  bool _hasComments(GameNode n) => includeComments && n.comments.any((c) => !c.isEmpty);

  void _writeStartComments(GameNode node, List<String> out) {
    if (!includeComments) return;
    for (final c in node.startComments) {
      if (!c.isEmpty) out.add('{${c.encode()}}');
    }
  }

  /// Writes the continuation from [from] (iteratively on the main line,
  /// recursively on side variations).
  void _writeLine(GameNode from, List<String> out, {required bool forceNumber}) {
    var node = from;
    var force = forceNumber;
    while (node.children.isNotEmpty) {
      final main = node.children.first;
      _writeStartComments(main, out);
      final hadStart = includeComments && main.startComments.any((c) => !c.isEmpty);
      out.add(_moveToken(main, force || hadStart));
      _writeNodeAnnotations(main, out);
      var hadVariations = false;
      if (includeVariations) {
        for (final variation in node.children.skip(1)) {
          hadVariations = true;
          out.add('(');
          _writeStartComments(variation, out);
          out.add(_moveToken(variation, true));
          _writeNodeAnnotations(variation, out);
          _writeLine(variation, out, forceNumber: _hasComments(variation));
          out.add(')');
        }
      }
      force = hadVariations || _hasComments(main);
      node = main;
    }
  }

  String _wrap(List<String> tokens) {
    final sb = StringBuffer();
    var lineLen = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      final noSpaceBefore = i == 0 || t == ')' || tokens[i - 1] == '(';
      final add = (noSpaceBefore ? 0 : 1) + t.length;
      if (lineLen > 0 && lineLen + add > lineWidth && !noSpaceBefore) {
        sb.write('\n');
        lineLen = 0;
      } else if (!noSpaceBefore) {
        sb.write(' ');
        lineLen++;
      }
      sb.write(t);
      final nl = t.lastIndexOf('\n');
      lineLen = nl >= 0 ? t.length - nl - 1 : lineLen + t.length;
    }
    return sb.toString();
  }
}

/// Convenience: serialize a single game.
String gameToPgn(ChessGame game) => PgnWriter().write(game);
