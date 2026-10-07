/// Parsing of chess files in a background isolate with progress and
/// cancellation (F-IMP-01, F-IMP-05, F-IMP-06).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../../domain/pgn/text_encoding.dart';

/// Plain, sendable summary of a parsed game ready to be stored.
class GameImportData {
  const GameImportData({
    required this.pgn,
    required this.headers,
    required this.plyCount,
    required this.issues,
    required this.startLine,
    this.eco = '',
    this.opening = '',
    this.rootFen,
  });

  final String pgn;
  final Map<String, String> headers;
  final int plyCount;
  final List<String> issues;
  final int startLine;
  final String eco;
  final String opening;
  final String? rootFen;

  String get white => headers['White'] ?? '';
  String get black => headers['Black'] ?? '';
  String get event => headers['Event'] ?? '';
  String get title {
    final players = playersLine(white, black);
    return players.isNotEmpty ? players : event;
  }
}

class ParseReport {
  const ParseReport({required this.games, required this.encoding, this.cancelled = false});
  final List<GameImportData> games;
  final TextEncodingKind encoding;
  final bool cancelled;

  int get errorCount => games.where((g) => g.issues.isNotEmpty).length;
}

/// Detected kind of pasted / shared text (F-IMP-02).
enum ChessTextKind { pgn, fen, epd, lichessUrl, url, unknown }

ChessTextKind detectChessText(String text) {
  final t = text.trim();
  if (t.isEmpty) return ChessTextKind.unknown;
  if (RegExp(r'^https?://(www\.)?lichess\.org/', caseSensitive: false).hasMatch(t)) return ChessTextKind.lichessUrl;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(t)) return ChessTextKind.url;
  final firstLine = t.split('\n').first.trim();
  if (!t.contains('\n') || t.split('\n').where((l) => l.trim().isNotEmpty).length == 1) {
    final parts = firstLine.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts[0].split('/').length == 8) {
      if (tryPositionFromFen(parts.take(6).join(' ')) != null) {
        return parts.length >= 6 && int.tryParse(parts[4]) != null ? ChessTextKind.fen : ChessTextKind.epd;
      }
    }
  }
  if (t.contains('[') ||
      RegExp(r'\b1\.\s*[a-hNBRQKO]').hasMatch(t) ||
      RegExp(r'^\s*[a-hNBRQKO][a-h1-8x]').hasMatch(t)) {
    return ChessTextKind.pgn;
  }
  return ChessTextKind.unknown;
}

/// Converts FEN / EPD lines into minimal PGN games (F-IMP-01).
String fenLinesToPgn(String text) {
  final sb = StringBuffer();
  var n = 0;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 4) continue;
    final fenCore = parts.take(4).join(' ');
    final hasCounters = parts.length >= 6 && int.tryParse(parts[4]) != null && int.tryParse(parts[5]) != null;
    final fen = hasCounters ? parts.take(6).join(' ') : '$fenCore 0 1';
    final pos = tryPositionFromFen(fen);
    if (pos == null) continue;
    n++;
    // EPD operations such as id "..."; become the event name.
    final idMatch = RegExp(r'id\s+"([^"]*)"').firstMatch(line);
    final commentMatch = RegExp(r'c0\s+"([^"]*)"').firstMatch(line);
    sb
      ..writeln('[Event "${idMatch?.group(1) ?? 'Position $n'}"]')
      ..writeln('[Site "?"]')
      ..writeln('[Date "????.??.??"]')
      ..writeln('[Round "?"]')
      ..writeln('[White "?"]')
      ..writeln('[Black "?"]')
      ..writeln('[Result "*"]')
      ..writeln('[SetUp "1"]')
      ..writeln('[FEN "${pos.fen}"]')
      ..writeln();
    if (commentMatch != null) sb.write('{${commentMatch.group(1)}} ');
    sb
      ..writeln('*')
      ..writeln();
  }
  return sb.toString();
}

GameImportData summarizeParsed(ParsedGame p, Map<String, List<String>> book) {
  final g = p.game;
  var eco = g.headers['ECO'] ?? '';
  var opening = g.headers['Opening'] ?? '';
  if ((eco.isEmpty || opening.isEmpty) && book.isNotEmpty) {
    final keys = [g.root.key, for (final n in g.mainline.take(40)) n.key];
    for (var i = keys.length - 1; i >= 0; i--) {
      final e = book[keys[i]];
      if (e != null) {
        if (eco.isEmpty) eco = e[0];
        if (opening.isEmpty) opening = e[1];
        break;
      }
    }
  }
  final fen = g.headers['FEN'];
  return GameImportData(
    pgn: p.raw,
    headers: Map.of(g.headers),
    plyCount: g.mainline.length,
    issues: [for (final i in g.issues) '${i.line}: ${i.message}${i.token != null ? ' (${i.token})' : ''}'],
    startLine: p.startLine,
    eco: eco,
    opening: opening,
    rootFen: fen != null && fen.isNotEmpty ? g.root.fen : null,
  );
}

class _IsolateArgs {
  _IsolateArgs(this.port, this.bytes, this.text, this.forced, this.book);
  final SendPort port;
  final List<int>? bytes;
  final String? text;
  final TextEncodingKind? forced;
  final Map<String, List<String>> book;
}

void _parseEntry(_IsolateArgs a) {
  String text;
  var enc = TextEncodingKind.utf8;
  if (a.text != null) {
    text = a.text!;
  } else {
    final d = decodeChessText(a.bytes!, forced: a.forced);
    text = d.text;
    enc = d.encoding;
  }
  final kind = detectChessText(text);
  if (kind == ChessTextKind.fen || kind == ChessTextKind.epd || (kind == ChessTextKind.unknown && text.contains('/'))) {
    final asPgn = fenLinesToPgn(text);
    if (asPgn.isNotEmpty) text = asPgn;
  }
  final parser = PgnParser(text, onProgress: (done, total) => a.port.send(['p', done / (total == 0 ? 1 : total)]));
  final games = parser.parse();
  final out = [for (final g in games) summarizeParsed(g, a.book)];
  a.port.send(['done', out, enc.name]);
}

/// Handle for a running parse; call [cancel] to stop it.
class ParseJob {
  ParseJob._(this.progress, this.result, this._cancel);
  final Stream<double> progress;
  final Future<ParseReport> result;
  final void Function() _cancel;
  void cancel() => _cancel();
}

class PgnImportService {
  PgnImportService({this.bookProvider});

  /// Returns the opening book map (key -> [eco, name]) for ECO detection.
  final Map<String, List<String>> Function()? bookProvider;

  /// Parses [bytes] (or [text]) in a background isolate.
  ParseJob parse({List<int>? bytes, String? text, TextEncodingKind? forcedEncoding}) {
    final progress = StreamController<double>.broadcast();
    final completer = Completer<ParseReport>();
    final port = ReceivePort();
    Isolate? isolate;
    var cancelled = false;

    // Closed on every path: it used to stay open after a successful parse.
    final errorPort = ReceivePort();
    port.listen((msg) {
      final list = msg as List<Object?>;
      if (list[0] == 'p') {
        progress.add(list[1]! as double);
      } else if (list[0] == 'done') {
        final enc = TextEncodingKind.values.byName(list[2]! as String);
        completer.complete(ParseReport(games: (list[1]! as List).cast<GameImportData>(), encoding: enc));
        port.close();
        errorPort.close();
        unawaited(progress.close());
      } else if (list[0] == 'error') {
        completer.completeError(Exception(list[1]));
        port.close();
        unawaited(progress.close());
      }
    });

    errorPort.listen((e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception((e as List).first.toString()));
      }
      errorPort.close();
      port.close();
      if (!progress.isClosed) unawaited(progress.close());
    });

    Isolate.spawn(
      _parseEntry,
      _IsolateArgs(port.sendPort, bytes, text, forcedEncoding, bookProvider?.call() ?? const {}),
      onError: errorPort.sendPort,
    ).then((iso) {
      isolate = iso;
      if (cancelled) iso.kill(priority: Isolate.immediate);
    });

    void cancel() {
      cancelled = true;
      isolate?.kill(priority: Isolate.immediate);
      if (!completer.isCompleted) {
        completer.complete(const ParseReport(games: [], encoding: TextEncodingKind.utf8, cancelled: true));
      }
      port.close();
      errorPort.close();
      if (!progress.isClosed) unawaited(progress.close());
    }

    return ParseJob._(progress.stream, completer.future, cancel);
  }

  /// Synchronous parse (small inputs, tests).
  static List<GameImportData> parseTextSync(String text, {Map<String, List<String>> book = const {}}) {
    var t = text;
    final kind = detectChessText(t);
    if (kind == ChessTextKind.fen || kind == ChessTextKind.epd) t = fenLinesToPgn(t);
    return [for (final g in PgnParser.parseAll(t)) summarizeParsed(g, book)];
  }
}

String headersToJson(Map<String, String> headers) => jsonEncode(headers);

Map<String, String> headersFromJson(String s) {
  try {
    return (jsonDecode(s) as Map).map((k, v) => MapEntry(k as String, v as String));
  } catch (_) {
    return {};
  }
}

/// Re-parses a stored game.
ChessGame parseStoredGame(String pgn) => PgnParser.parseOne(pgn);
