/// Tolerant PGN parser (F-IMP-04, F-IMP-05).
///
/// * nested variations of any depth, `{}` and `;` comments, `%` escape lines;
/// * NAGs (`$n`) and suffix annotations (`!`, `?!`, ...), evaluation symbols;
/// * `[%cal]`/`[%csl]` shapes and other `[%...]` commands (kept verbatim);
/// * `[FEN]`/`[SetUp]` headers, arbitrary headers;
/// * null moves (`--`, `Z0`);
/// * errors never abort the whole file: a game is imported up to the
///   problem, an error inside a variation only drops the rest of that
///   variation. Every problem is reported with its line number.
library;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';
import 'pgn_model.dart';

/// One game of a multi-game file together with its raw source text.
class ParsedGame {
  ParsedGame({required this.game, required this.raw, required this.startLine, required this.index});

  final ChessGame game;

  /// Raw source text of the game (headers + movetext).
  final String raw;
  final int startLine;
  final int index;

  bool get hasErrors => game.issues.isNotEmpty;
}

/// Symbolic annotations mapped to NAG codes.
const Map<String, int> kSymbolNags = {
  '!': 1,
  '?': 2,
  '!!': 3,
  '??': 4,
  '!?': 5,
  '?!': 6,
  '□': 7,
  '=': 10,
  '∞': 13,
  '⩲': 14,
  '+=': 14,
  '+/=': 14,
  '⩱': 15,
  '=+': 15,
  '=/+': 15,
  '±': 16,
  '+/-': 16,
  '∓': 17,
  '-/+': 17,
  '+-': 18,
  '-+': 19,
  '=/∞': 44,
  '⨀': 22,
  '○': 32,
  '⟳': 32,
  '↑': 36,
  '→': 40,
  '⇆': 132,
  'N': 146,
};

const _results = {'1-0', '0-1', '1/2-1/2', '½-½', '*'};

class PgnParser {
  PgnParser(this.text, {this.onProgress, this.isCancelled});

  final String text;

  /// Called periodically with the number of characters processed.
  final void Function(int done, int total)? onProgress;
  final bool Function()? isCancelled;

  int _i = 0;
  int _line = 1;
  int _lastProgress = 0;

  static List<ParsedGame> parseAll(String text) => PgnParser(text).parse();

  /// Parses a single game (the first one found). Returns an empty game if
  /// the text contains none.
  static ChessGame parseOne(String text) {
    final games = PgnParser(text).parse();
    return games.isEmpty ? ChessGame(headers: ChessGame.defaultHeaders()) : games.first.game;
  }

  List<ParsedGame> parse() {
    final out = <ParsedGame>[];
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) _i = 1;
    while (true) {
      if (isCancelled?.call() ?? false) break;
      _skipBetweenGames();
      if (_i >= text.length) break;
      final start = _i;
      final startLine = _line;
      final game = _parseGame(out.length);
      if (game == null) continue;
      out.add(ParsedGame(game: game, raw: text.substring(start, _i).trim(), startLine: startLine, index: out.length));
      if (onProgress != null && _i - _lastProgress > 32768) {
        _lastProgress = _i;
        onProgress!(_i, text.length);
      }
    }
    onProgress?.call(text.length, text.length);
    return out;
  }

  // ---------------------------------------------------------------- scanner

  bool get _eof => _i >= text.length;
  String get _c => text[_i];

  void _advance() {
    if (_i >= text.length) return;
    if (text.codeUnitAt(_i) == 0x0A) _line++;
    _i++;
  }

  // U+FEFF too: a byte-order mark in the middle of a file (files joined
  // with `copy /b`) is not a move.
  bool _isWs(int c) =>
      c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0B || c == 0x0C || c == 0xA0 || c == 0xFEFF;

  bool _atLineStart() {
    var j = _i - 1;
    while (j >= 0) {
      final c = text.codeUnitAt(j);
      if (c == 0x0A) return true;
      if (c != 0x20 && c != 0x09 && c != 0x0D) return false;
      j--;
    }
    return true;
  }

  void _skipWs() {
    while (!_eof && _isWs(text.codeUnitAt(_i))) {
      _advance();
    }
  }

  void _skipLine() {
    while (!_eof && text.codeUnitAt(_i) != 0x0A) {
      _i++;
    }
  }

  /// Skips whitespace, `%` escape lines and `;` comments between games.
  void _skipBetweenGames() {
    while (!_eof) {
      _skipWs();
      if (_eof) return;
      final c = _c;
      if (c == '%' && _atLineStart()) {
        _skipLine();
      } else if (c == ';') {
        _skipLine();
      } else {
        return;
      }
    }
  }

  // ---------------------------------------------------------------- headers

  /// Returns false if the header was malformed (skipped).
  bool _parseHeader(Map<String, String> headers, List<ParseIssue> issues, int gameIndex) {
    final line = _line;
    _advance(); // [
    _skipWs();
    final nameStart = _i;
    while (!_eof && !_isWs(text.codeUnitAt(_i)) && _c != '"' && _c != ']') {
      _i++;
    }
    final name = text.substring(nameStart, _i);
    _skipWs();
    if (_eof || _c != '"') {
      issues.add(ParseIssue(line: line, message: 'Malformed header', token: name, gameIndex: gameIndex));
      _skipTo(']');
      return false;
    }
    _advance(); // "
    final sb = StringBuffer();
    while (!_eof && _c != '"') {
      if (_c == '\\' && _i + 1 < text.length) {
        _advance();
      }
      if (_c == '\n') {
        break;
      }
      sb.write(_c);
      _advance();
    }
    if (!_eof && _c == '"') _advance();
    _skipWs();
    if (!_eof && _c == ']') {
      _advance();
    } else {
      issues.add(ParseIssue(line: line, message: 'Unterminated header', token: name, gameIndex: gameIndex));
    }
    if (name.isNotEmpty) headers[name] = sb.toString();
    return true;
  }

  void _skipTo(String ch) {
    while (!_eof && _c != ch && _c != '\n') {
      _advance();
    }
    if (!_eof && _c == ch) _advance();
  }

  // ---------------------------------------------------------------- game

  ChessGame? _parseGame(int gameIndex) {
    final headers = <String, String>{};
    final issues = <ParseIssue>[];

    // Headers.
    while (!_eof) {
      _skipWs();
      if (_eof) break;
      if (_c == '[') {
        // A repeated header name means a new game without movetext.
        final save = _i;
        final saveLine = _line;
        final m = _headerNameRe.matchAsPrefix(text, _i);
        if (m != null && headers.containsKey(m.group(1))) {
          _i = save;
          _line = saveLine;
          break;
        }
        _parseHeader(headers, issues, gameIndex);
      } else if (_c == '%' && _atLineStart()) {
        _skipLine();
      } else if (_c == ';') {
        _skipLine();
      } else {
        break;
      }
    }

    // Starting position.
    Position start = Chess.initial;
    var skipMoves = false;
    final fen = headers['FEN'];
    if (fen != null && fen.trim().isNotEmpty) {
      try {
        start = positionFromFen(fen);
      } catch (_) {
        issues.add(ParseIssue(line: _line, message: 'Invalid FEN header', token: fen, gameIndex: gameIndex));
        skipMoves = true;
      }
    }
    final variant = headers['Variant']?.toLowerCase();
    if (variant != null &&
        !const {
          'standard',
          'chess',
          'from position',
          'fromposition',
          'normal',
          'chess960',
          'freestyle',
        }.contains(variant)) {
      issues.add(
        ParseIssue(line: _line, message: 'Unsupported variant', token: headers['Variant'], gameIndex: gameIndex),
      );
      skipMoves = true;
    }

    final root = GameNode.root(start);
    final game = ChessGame(headers: headers, root: root, issues: issues);

    // Movetext.
    final stack = <_Frame>[];
    var frame = _Frame(parent: root, last: null);
    var pending = <PgnComment>[];
    var sawMovetext = false;
    var mainlineBroken = skipMoves;
    // Where the part of the main line that could not be read begins and
    // ends: it is kept as a comment instead of being dropped (D-055).
    int? tailStart;
    int? tailEnd;
    int? numberStart;
    var tailKept = false;

    void attachPendingToRoot() {
      if (pending.isNotEmpty) {
        root.comments.addAll(pending);
        pending = [];
      }
    }

    while (!_eof) {
      if (isCancelled?.call() ?? false) break;
      final cu = text.codeUnitAt(_i);
      if (_isWs(cu)) {
        _advance();
        continue;
      }
      final c = _c;
      final tokLine = _line;

      if (c == '[') {
        if (sawMovetext || headers.isNotEmpty) {
          // Start of next game.
          break;
        }
        _parseHeader(headers, issues, gameIndex);
        continue;
      }
      if (c == '%' && _atLineStart()) {
        _skipLine();
        continue;
      }
      if (skipMoves && !tailKept) tailStart ??= _i;
      if (c == '{') {
        sawMovetext = true;
        final commentStart = _i;
        final raw = _readBraceComment(issues, gameIndex);
        if (skipMoves && tailStart == commentStart && raw.trimLeft().startsWith(kUnparsedMarker)) {
          // The tail kept by an earlier export of this unreadable game.
          root.comments.add(PgnComment.parse(raw));
          issues.add(ParseIssue(line: tokLine, message: 'Unread moves are kept in a comment', gameIndex: gameIndex));
          tailStart = null;
          tailKept = true;
          continue;
        }
        if (frame.skipping || (mainlineBroken && stack.isEmpty)) continue;
        final comment = PgnComment.parse(raw);
        if (comment.text.startsWith(kUnparsedMarker)) {
          // A tail kept by an earlier import: the game is still incomplete.
          issues.add(ParseIssue(line: tokLine, message: 'Unread moves are kept in a comment', gameIndex: gameIndex));
        }
        if (frame.last == null) {
          pending.add(comment);
        } else {
          frame.last!.comments.add(comment);
        }
        continue;
      }
      if (c == ';') {
        sawMovetext = true;
        _advance();
        final s = _i;
        _skipLine();
        if (frame.skipping || (mainlineBroken && stack.isEmpty)) continue;
        final comment = PgnComment.parse(text.substring(s, _i).trimRight());
        if (frame.last == null) {
          pending.add(comment);
        } else {
          frame.last!.comments.add(comment);
        }
        continue;
      }
      if (c == '(') {
        sawMovetext = true;
        _advance();
        if (frame.last == null || frame.skipping || (mainlineBroken && stack.isEmpty)) {
          if (!frame.skipping && !mainlineBroken) {
            issues.add(ParseIssue(line: tokLine, message: 'Variation without a preceding move', gameIndex: gameIndex));
          }
          _skipVariation();
          continue;
        }
        stack.add(frame);
        frame = _Frame(parent: frame.last!.parent!, last: null);
        if (pending.isNotEmpty) {
          // Comments right before '(' belong to the previous move.
          stack.last.last!.comments.addAll(pending);
          pending = [];
        }
        continue;
      }
      if (c == ')') {
        _advance();
        if (stack.isEmpty) {
          issues.add(ParseIssue(line: tokLine, message: 'Unbalanced ")"', gameIndex: gameIndex));
          continue;
        }
        if (pending.isNotEmpty && frame.last != null) {
          frame.last!.comments.addAll(pending);
        }
        pending = [];
        frame = stack.removeLast();
        continue;
      }
      if (c == '\$') {
        sawMovetext = true;
        _advance();
        final s = _i;
        while (!_eof && _isDigit(text.codeUnitAt(_i))) {
          _i++;
        }
        final n = int.tryParse(text.substring(s, _i));
        if (n != null && frame.last != null && !frame.skipping && !(mainlineBroken && stack.isEmpty)) {
          frame.last!.nags.add(n);
        }
        continue;
      }

      // Word token.
      final s = _i;
      while (!_eof) {
        final ch = text.codeUnitAt(_i);
        if (_isWs(ch) || ch == 0x7B /*{*/ || ch == 0x28 || ch == 0x29 || ch == 0x3B || ch == 0x5B || ch == 0x24) {
          break;
        }
        _i++;
      }
      var token = text.substring(s, _i);
      if (token.isEmpty) {
        _advance();
        continue;
      }
      sawMovetext = true;

      if (_results.contains(token)) {
        if (stack.isEmpty) {
          // End of game.
          headers.putIfAbsent('Result', () => token == '½-½' ? '1/2-1/2' : token);
          tailEnd = s;
          break;
        }
        continue;
      }

      // Move numbers: "12." "12..." "12…" and also "12.e4".
      final numMatch = _moveNumberRe.matchAsPrefix(token);
      if (numMatch != null) {
        token = token.substring(numMatch.end);
        if (token.isEmpty) {
          if (stack.isEmpty && !mainlineBroken) numberStart = s;
          continue;
        }
      } else if (_isDigit(token.codeUnitAt(0)) && !token.startsWith('0-0')) {
        // "0000" is a null move, not a stray number.
        if (token != '0000' && RegExp(r'^\d+$').hasMatch(token)) continue;
      }
      // Leading dots ("...Nf6").
      while (token.startsWith('.') || token.startsWith('…')) {
        token = token.substring(1);
      }
      if (token.isEmpty) continue;

      // Standalone annotation symbols.
      final symNag = kSymbolNags[token];
      if (symNag != null && token != 'N') {
        if (frame.last != null && !frame.skipping) frame.last!.nags.add(symNag);
        continue;
      }
      if (token == 'N' && frame.last != null) {
        if (!frame.skipping) frame.last!.nags.add(146);
        continue;
      }

      if (mainlineBroken && stack.isEmpty) continue;
      if (frame.skipping) continue;

      // Split trailing annotations: e4!? Nf3?!
      var nags = <int>[];
      final annMatch = _suffixRe.firstMatch(token);
      if (annMatch != null) {
        final sym = annMatch.group(0)!;
        final code = kSymbolNags[sym];
        if (code != null) nags = [code];
        token = token.substring(0, annMatch.start);
      }

      final parentNode = frame.last ?? frame.parent;
      GameNode? node;
      if (token == '--' || token == 'Z0' || token == '0000' || token == '@@@@') {
        node = parentNode.addNullMove();
      } else {
        final move = parseSanLenient(parentNode.position, token);
        if (move != null) {
          node = parentNode.addMove(move);
        }
      }
      if (node == null) {
        issues.add(
          ParseIssue(line: tokLine, message: 'Illegal or unreadable move', token: token, gameIndex: gameIndex),
        );
        if (stack.isEmpty) {
          mainlineBroken = true;
          tailStart ??= numberStart ?? s;
        } else {
          frame.skipping = true;
        }
        continue;
      }
      if (pending.isNotEmpty) {
        if (frame.last == null && stack.isEmpty && identical(parentNode, root)) {
          attachPendingToRoot();
        } else {
          node.startComments.addAll(pending);
          pending = [];
        }
      }
      node.nags.addAll(nags);
      frame.last = node;
      if (stack.isEmpty) numberStart = null;
    }

    if (tailStart != null) {
      final tail = text
          .substring(tailStart, tailEnd ?? _i)
          .replaceAll('{', '(')
          .replaceAll('}', ')')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (tail.isNotEmpty) {
        final mainFrame = stack.isEmpty ? frame : stack.first;
        (mainFrame.last ?? root).comments.add(PgnComment(text: '$kUnparsedMarker $tail'));
      }
    }

    if (stack.isNotEmpty) {
      issues.add(ParseIssue(line: _line, message: 'Unclosed variation', gameIndex: gameIndex));
    }
    // A comment right after the result ("1-0 {White wins}") still belongs
    // to this game; it used to become a game of its own.
    if (tailEnd != null) {
      while (true) {
        final save = _i;
        final saveLine = _line;
        _skipWs();
        if (_eof || _c != '{') {
          _i = save;
          _line = saveLine;
          break;
        }
        final comment = PgnComment.parse(_readBraceComment(issues, gameIndex));
        if (comment.isEmpty) continue;
        final mainFrame = stack.isEmpty ? frame : stack.first;
        (mainFrame.last ?? root).comments.add(comment);
      }
    }
    attachPendingToRoot();

    if (headers.isEmpty && !sawMovetext) return null;
    // Move numbers and punctuation alone are not a game. Keep malformed
    // games with diagnostics, and valid empty games with headers/comments.
    if (headers.isEmpty && root.children.isEmpty && root.comments.isEmpty && issues.isEmpty) return null;
    // Text without a single header or readable move is not a game at all
    // ("Found 1 game" for a pasted sentence).
    if (headers.isEmpty && root.children.isEmpty && issues.any((i) => i.message == 'Illegal or unreadable move')) {
      return null;
    }
    if (headers.isEmpty) {
      headers.addAll(ChessGame.defaultHeaders());
    }
    return game;
  }

  static final _headerNameRe = RegExp(r'\[\s*([A-Za-z0-9_]+)');
  static final _moveNumberRe = RegExp(r'^\d+\s*(\.+|…)');
  static final _suffixRe = RegExp(r'[!?□]+$');

  bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

  String _readBraceComment(List<ParseIssue> issues, int gameIndex) {
    final line = _line;
    _advance(); // {
    final s = _i;
    while (!_eof && _c != '}') {
      _advance();
    }
    final raw = text.substring(s, _i);
    if (_eof) {
      issues.add(ParseIssue(line: line, message: 'Unterminated comment', gameIndex: gameIndex));
    } else {
      _advance(); // }
    }
    return raw;
  }

  /// Skips to the matching `)` (the opening `(` already consumed).
  void _skipVariation() {
    var depth = 1;
    while (!_eof && depth > 0) {
      final c = _c;
      if (c == '{') {
        while (!_eof && _c != '}') {
          _advance();
        }
      } else if (c == ';') {
        _skipLine();
        continue;
      } else if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      }
      _advance();
    }
  }
}

class _Frame {
  _Frame({required this.parent, required this.last});

  /// Node from which the first move of this line is played.
  final GameNode parent;

  /// Last move node in this line.
  GameNode? last;

  /// After an error in a variation, the rest of it is ignored.
  bool skipping = false;
}
