/// Chess.com Published-Data API client (F-CC). Read-only public data, no
/// OAuth: "connecting" means remembering a username.
///
/// Requests are strictly sequential (parallel requests get 429); on 429 we
/// back off exponentially. Conditional requests use ETag / Last-Modified
/// (304 = unchanged, F-CC-03).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChessComException implements Exception {
  const ChessComException(this.status, this.message);
  final int? status;
  final String message;

  @override
  String toString() => 'ChessComException($status): $message';
}

class ChessComPlayer {
  const ChessComPlayer({required this.username, this.name, this.avatar});
  final String username;
  final String? name;
  final String? avatar;
}

class ChessComGame {
  const ChessComGame({
    required this.url,
    required this.pgn,
    required this.endTime,
    required this.timeControl,
    required this.timeClass,
    required this.rated,
    required this.rules,
    required this.white,
    required this.black,
    required this.whiteResult,
    required this.blackResult,
  });

  final String url;
  final String pgn;
  final DateTime endTime;
  final String timeControl;

  /// bullet | blitz | rapid | daily
  final String timeClass;
  final bool rated;
  final String rules;
  final String white;
  final String black;
  final String whiteResult;
  final String blackResult;

  String get id => url.split('/').last;

  String get result {
    if (whiteResult == 'win') return '1-0';
    if (blackResult == 'win') return '0-1';
    return '1/2-1/2';
  }

  static ChessComGame fromJson(Map<String, Object?> j) {
    final w = (j['white'] as Map?)?.cast<String, Object?>() ?? {};
    final b = (j['black'] as Map?)?.cast<String, Object?>() ?? {};
    return ChessComGame(
      url: (j['url'] as String?) ?? '',
      pgn: (j['pgn'] as String?) ?? '',
      endTime: DateTime.fromMillisecondsSinceEpoch(((j['end_time'] as num?)?.toInt() ?? 0) * 1000),
      timeControl: (j['time_control'] as String?) ?? '',
      timeClass: (j['time_class'] as String?) ?? '',
      rated: (j['rated'] as bool?) ?? false,
      rules: (j['rules'] as String?) ?? 'chess',
      white: (w['username'] as String?) ?? '',
      black: (b['username'] as String?) ?? '',
      whiteResult: (w['result'] as String?) ?? '',
      blackResult: (b['result'] as String?) ?? '',
    );
  }
}

class MonthResult {
  const MonthResult({required this.notModified, this.games = const [], this.etag, this.lastModified});
  final bool notModified;
  final List<ChessComGame> games;
  final String? etag;
  final String? lastModified;
}

class ChessComClient {
  ChessComClient({
    http.Client? client,
    required this.userAgent,
    this.host = 'https://api.chess.com',
    Future<void> Function(Duration)? sleep,
    this.maxRetries = 5,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _client;
  final String userAgent;
  final String host;
  final Future<void> Function(Duration) _sleep;
  final int maxRetries;

  /// How long one request may take before it is given up.
  final Duration requestTimeout;

  Future<void> _tail = Future.value();

  Future<T> _queued<T>(Future<T> Function() task) {
    final c = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        c.complete(await task());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<http.Response> _get(Uri url, {Map<String, String>? headers}) => _queued(() async {
    var delay = const Duration(seconds: 2);
    for (var attempt = 0; ; attempt++) {
      // A stalled connection must not hold the request queue forever.
      final res = await _client
          .get(url, headers: {'User-Agent': userAgent, 'Accept': 'application/json', ...?headers})
          .timeout(requestTimeout);
      if (res.statusCode == 429 && attempt < maxRetries) {
        await _sleep(delay);
        delay *= 2;
        continue;
      }
      return res;
    }
  });

  Uri _u(String path) => Uri.parse('$host$path');

  /// Usernames are case-insensitive; canonical URLs are lowercase.
  static String canonical(String username) => username.trim().toLowerCase();

  /// Returns null if the player does not exist (F-CC-01).
  Future<ChessComPlayer?> player(String username) async {
    final res = await _get(_u('/pub/player/${canonical(username)}'));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw ChessComException(res.statusCode, res.body);
    final j = (jsonDecode(res.body) as Map).cast<String, Object?>();
    return ChessComPlayer(
      username: (j['username'] as String?) ?? username,
      name: j['name'] as String?,
      avatar: j['avatar'] as String?,
    );
  }

  /// Monthly archive URLs, oldest first (F-CC-02).
  Future<List<Uri>> archives(String username) async {
    final res = await _get(_u('/pub/player/${canonical(username)}/games/archives'));
    if (res.statusCode == 404) return const [];
    if (res.statusCode != 200) throw ChessComException(res.statusCode, res.body);
    final j = (jsonDecode(res.body) as Map).cast<String, Object?>();
    return [for (final a in (j['archives'] as List?) ?? const []) Uri.parse(a as String)];
  }

  /// Games of one month. Pass the previous [etag]/[lastModified] for a
  /// conditional request; `notModified` is true on 304.
  Future<MonthResult> month(Uri archiveUrl, {String? etag, String? lastModified}) async {
    final res = await _get(archiveUrl, headers: {'If-None-Match': ?etag, 'If-Modified-Since': ?lastModified});
    if (res.statusCode == 304) {
      return MonthResult(notModified: true, etag: etag, lastModified: lastModified);
    }
    if (res.statusCode == 410 || res.statusCode == 404) return const MonthResult(notModified: false);
    if (res.statusCode != 200) throw ChessComException(res.statusCode, res.body);
    final j = (jsonDecode(res.body) as Map).cast<String, Object?>();
    return MonthResult(
      notModified: false,
      games: [
        for (final g in (j['games'] as List?) ?? const []) ChessComGame.fromJson((g as Map).cast<String, Object?>()),
      ],
      etag: res.headers['etag'],
      lastModified: res.headers['last-modified'],
    );
  }

  void close() => _client.close();
}
