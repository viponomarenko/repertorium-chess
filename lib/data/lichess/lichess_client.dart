/// Lichess API client (F-LI). Endpoints verified against the official
/// OpenAPI spec (lichess-org/api, v2.0.174); see docs/DECISIONS.md.
///
/// Rules (ТЗ 6.1): only one request at a time (queue); on 429 wait at
/// least 60 s and retry, notifying the UI; User-Agent with a link to the
/// repository.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LichessException implements Exception {
  const LichessException(this.status, this.message);
  final int? status;
  final String message;

  bool get isUnauthorized => status == 401;
  bool get isNotFound => status == 404;
  bool get isRateLimited => status == 429;

  @override
  String toString() => 'LichessException($status): $message';
}

class LichessAccount {
  const LichessAccount({required this.id, required this.username});
  final String id;
  final String username;
}

class StudyMeta {
  const StudyMeta({required this.id, required this.name, required this.createdAt, required this.updatedAt});
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class LichessGame {
  const LichessGame({
    required this.id,
    required this.pgn,
    required this.createdAt,
    required this.speed,
    required this.rated,
    required this.white,
    required this.black,
    required this.winner,
    required this.status,
    this.clockInitial,
    this.clockIncrement,
  });

  final String id;
  final String pgn;
  final DateTime createdAt;
  final String speed;
  final bool rated;

  /// User names (lowercase ids); empty for AI opponents.
  final String white;
  final String black;
  final String? winner;
  final String status;
  final int? clockInitial;
  final int? clockIncrement;

  String get result => switch (winner) {
    'white' => '1-0',
    'black' => '0-1',
    _ => status == 'started' ? '*' : '1/2-1/2',
  };

  String get timeControl => clockInitial == null ? speed : '${clockInitial! ~/ 60}+${clockIncrement ?? 0}';

  static LichessGame fromJson(Map<String, Object?> j) {
    final players = (j['players'] as Map?)?.cast<String, Object?>() ?? {};
    String name(String side) {
      final p = (players[side] as Map?)?.cast<String, Object?>();
      final user = (p?['user'] as Map?)?.cast<String, Object?>();
      return (user?['id'] as String?) ?? '';
    }

    final clock = (j['clock'] as Map?)?.cast<String, Object?>();
    return LichessGame(
      id: j['id']! as String,
      pgn: (j['pgn'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
      speed: (j['speed'] as String?) ?? '',
      rated: (j['rated'] as bool?) ?? false,
      white: name('white'),
      black: name('black'),
      winner: j['winner'] as String?,
      status: (j['status'] as String?) ?? '',
      clockInitial: (clock?['initial'] as num?)?.toInt(),
      clockIncrement: (clock?['increment'] as num?)?.toInt(),
    );
  }
}

class ExplorerMove {
  const ExplorerMove({
    required this.uci,
    required this.san,
    required this.white,
    required this.draws,
    required this.black,
    this.averageRating,
  });

  final String uci;
  final String san;
  final int white;
  final int draws;
  final int black;
  final int? averageRating;

  int get total => white + draws + black;
}

class ExplorerResult {
  const ExplorerResult({
    required this.white,
    required this.draws,
    required this.black,
    required this.moves,
    this.openingName,
    this.eco,
  });

  final int white;
  final int draws;
  final int black;
  final List<ExplorerMove> moves;
  final String? openingName;
  final String? eco;

  int get total => white + draws + black;

  static ExplorerResult fromJson(Map<String, Object?> j) {
    final opening = (j['opening'] as Map?)?.cast<String, Object?>();
    return ExplorerResult(
      white: (j['white'] as num?)?.toInt() ?? 0,
      draws: (j['draws'] as num?)?.toInt() ?? 0,
      black: (j['black'] as num?)?.toInt() ?? 0,
      openingName: opening?['name'] as String?,
      eco: opening?['eco'] as String?,
      moves: [
        for (final m in (j['moves'] as List?) ?? const [])
          ExplorerMove(
            uci: (m as Map)['uci'] as String,
            san: m['san'] as String,
            white: (m['white'] as num?)?.toInt() ?? 0,
            draws: (m['draws'] as num?)?.toInt() ?? 0,
            black: (m['black'] as num?)?.toInt() ?? 0,
            averageRating: (m['averageRating'] as num?)?.toInt(),
          ),
      ],
    );
  }
}

class CloudEvalLine {
  const CloudEvalLine({required this.moves, this.cp, this.mate});

  /// UCI moves; castling in king-takes-rook form (e1h1) as returned.
  final List<String> moves;
  final int? cp;
  final int? mate;
}

class CloudEval {
  const CloudEval({required this.depth, required this.knodes, required this.lines});
  final int depth;
  final int knodes;
  final List<CloudEvalLine> lines;
}

class StudyImportResult {
  const StudyImportResult({required this.chapters, this.error});
  final int chapters;
  final String? error;
}

enum LichessUrlKind { study, chapter, game }

class LichessUrl {
  const LichessUrl(this.kind, this.id, [this.chapterId]);
  final LichessUrlKind kind;
  final String id;
  final String? chapterId;

  /// Recognizes study, chapter and game links (F-LI-06).
  static LichessUrl? parse(String text) {
    final t = text.trim();
    final study = RegExp(r'lichess\.org/study/([A-Za-z0-9]{8})(?:/([A-Za-z0-9]{8}))?').firstMatch(t);
    if (study != null) {
      final ch = study.group(2);
      return ch == null
          ? LichessUrl(LichessUrlKind.study, study.group(1)!)
          : LichessUrl(LichessUrlKind.chapter, study.group(1)!, ch);
    }
    final game = RegExp(
      r'lichess\.org/(?:game/export/)?([A-Za-z0-9]{8})(?:[A-Za-z0-9]{4})?(?:/(?:white|black))?(?:[#?/].*)?$',
    ).firstMatch(t);
    if (game != null) {
      const reserved = {
        'training',
        'practice',
        'analysis',
        'streamer',
        'tutorial',
        'features',
        'broadcast',
        'coordinate',
      };
      if (!reserved.contains(game.group(1)!.toLowerCase())) {
        return LichessUrl(LichessUrlKind.game, game.group(1)!);
      }
    }
    return null;
  }
}

class LichessClient {
  LichessClient({
    http.Client? client,
    required this.userAgent,
    this.tokenProvider,
    this.host = 'https://lichess.org',
    this.explorerHost = 'https://explorer.lichess.org',
    this.rateLimitPause = const Duration(seconds: 60),
    Future<void> Function(Duration)? sleep,
    this.maxRateLimitRetries = 2,
    this.idleTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _sleep = sleep ?? Future<void>.delayed;

  final http.Client _client;
  final String userAgent;
  final Future<String?> Function()? tokenProvider;
  final String host;
  final String explorerHost;
  final Duration rateLimitPause;
  final Future<void> Function(Duration) _sleep;
  final int maxRateLimitRetries;

  /// How long a streamed download may stay silent before it is given up.
  final Duration idleTimeout;

  final _rateLimited = StreamController<Duration>.broadcast();

  /// Emits the pause every time Lichess answers 429 (UI shows a notice).
  Stream<Duration> get rateLimitEvents => _rateLimited.stream;

  Future<void> _tail = Future.value();
  int _pending = 0;
  bool _closed = false;
  Future<void>? _cooldown;
  final _cloudRequests = <Completer<void>>{};
  final _cloudCache = <String, (DateTime, CloudEval?)>{};

  Future<T> _withAbort<T>(Future<T> operation, Future<void>? abort, Uri url) => abort == null
      ? operation
      : Future.any([operation, abort.then<T>((_) => throw http.RequestAbortedException(url))]);

  /// Number of queued or running requests.
  int get pending => _pending;

  /// Runs [task] after all previously queued requests (one at a time).
  Future<T> _queued<T>(Future<T> Function() task) {
    final c = Completer<T>();
    _pending++;
    _tail = _tail.then((_) async {
      try {
        if (_closed) throw const LichessException(null, 'Client closed');
        c.complete(await task());
      } catch (e, st) {
        c.completeError(e, st);
      } finally {
        _pending--;
      }
    });
    return c.future;
  }

  Uri _uri(String base, String path, [Map<String, String>? query]) =>
      Uri.parse('$base$path').replace(queryParameters: query == null || query.isEmpty ? null : query);

  Future<http.StreamedResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? headers,
    Map<String, String>? form,
    String? body,
    bool auth = true,
    Future<void>? abort,
    Duration? requestTimeout,
  }) async {
    for (var attempt = 0; ; attempt++) {
      final cooldown = _cooldown;
      if (cooldown != null) await _withAbort(cooldown, abort, url);
      final req = http.AbortableRequest(method, url, abortTrigger: abort);
      req.headers['User-Agent'] = userAgent;
      if (headers != null) req.headers.addAll(headers);
      if (auth) {
        final t = await tokenProvider?.call();
        if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
      }
      if (form != null) req.bodyFields = form;
      if (body != null) req.body = body;
      // The limit covers one attempt, not the pause after a 429: waiting
      // out the pause inside a 30 s timeout made the retry impossible.
      final sending = requestTimeout == null ? _client.send(req) : _client.send(req).timeout(requestTimeout);
      final res = await _withAbort(sending, abort, url);
      if (res.statusCode == 429) {
        if (!_closed) _rateLimited.add(rateLimitPause);
        // The pause belongs to the client, even if this request is cancelled.
        _cooldown ??= _sleep(rateLimitPause).whenComplete(() => _cooldown = null);
        if (attempt < maxRateLimitRetries) {
          await _withAbort(res.stream.drain<void>(), abort, url);
          continue;
        }
      }
      return res;
    }
  }

  Future<String> _text(
    String method,
    Uri url, {
    String accept = 'application/json',
    Map<String, String>? form,
    bool auth = true,
    Set<int> ok = const {200},
  }) => _queued(() async {
    final abort = Completer<void>();
    try {
      final res = await _send(
        method,
        url,
        headers: {'Accept': accept},
        form: form,
        auth: auth,
        abort: abort.future,
        requestTimeout: const Duration(seconds: 30),
      );
      final text = await res.stream.bytesToString().timeout(const Duration(seconds: 60));
      if (!ok.contains(res.statusCode)) throw LichessException(res.statusCode, _errorMessage(text));
      return text;
    } finally {
      // A timeout must also stop the underlying request/retry before another
      // queued operation starts. The shared 429 cooldown remains in force.
      abort.complete();
    }
  });

  String _errorMessage(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['error'] != null) return j['error'].toString();
    } catch (_) {}
    return body.length > 200 ? body.substring(0, 200) : body;
  }

  Future<Map<String, Object?>> _json(String method, Uri url, {Map<String, String>? form, bool auth = true}) async {
    final text = await _text(method, url, form: form, auth: auth);
    return (jsonDecode(text) as Map).cast<String, Object?>();
  }

  /// Streams NDJSON objects. The request holds the queue until the stream
  /// is done or cancelled. Connection drops surface as stream errors.
  Stream<Map<String, Object?>> _ndjson(Uri url, {bool auth = true}) {
    late StreamController<Map<String, Object?>> controller;
    final abort = Completer<void>();
    controller = StreamController(
      onListen: () {
        unawaited(
          _queued(() async {
            try {
              final res = await _send(
                'GET',
                url,
                headers: {'Accept': 'application/x-ndjson'},
                auth: auth,
                abort: abort.future,
                requestTimeout: const Duration(seconds: 30),
              );
              if (res.statusCode != 200) {
                final text = await res.stream.bytesToString();
                controller.addError(LichessException(res.statusCode, _errorMessage(text)));
                return;
              }
              // A download that stalls (a half-open socket after a network
              // switch) ends with an error instead of blocking the queue.
              final lines = res.stream.timeout(idleTimeout).transform(utf8.decoder).transform(const LineSplitter());
              await for (final line in lines) {
                if (abort.isCompleted) break;
                if (line.trim().isEmpty) continue;
                try {
                  controller.add((jsonDecode(line) as Map).cast<String, Object?>());
                } catch (_) {
                  // Skip malformed line.
                }
              }
            } on http.RequestAbortedException {
              // Cancelled by the user.
            } catch (e, st) {
              if (!abort.isCompleted) controller.addError(e, st);
            } finally {
              await controller.close();
            }
          }),
        );
      },
      onCancel: () {
        if (!abort.isCompleted) abort.complete();
      },
    );
    return controller.stream;
  }

  // ------------------------------------------------------------ account

  Future<LichessAccount> account() async {
    final j = await _json('GET', _uri(host, '/api/account'));
    return LichessAccount(id: j['id']! as String, username: j['username']! as String);
  }

  /// Revokes the current token (F-LI-04).
  Future<void> revokeToken() async {
    await _text('DELETE', _uri(host, '/api/token'), ok: const {200, 204});
  }

  // ------------------------------------------------------------ studies

  Future<String> studyPgn(String studyId, {String? chapterId}) => _text(
    'GET',
    _uri(host, chapterId == null ? '/api/study/$studyId.pgn' : '/api/study/$studyId/$chapterId.pgn', {
      'comments': 'true',
      'variations': 'true',
      'clocks': 'true',
      'orientation': 'true',
    }),
    accept: 'application/x-chess-pgn',
  );

  Stream<StudyMeta> studiesByUser(String username) => _ndjson(_uri(host, '/api/study/by/$username')).map(
    (j) => StudyMeta(
      id: j['id']! as String,
      name: (j['name'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch((j['updatedAt'] as num?)?.toInt() ?? 0),
    ),
  );

  /// Imports PGN games as chapters (scope study:write, F-LI-12).
  Future<StudyImportResult> importPgnToStudy(String studyId, String pgn, {String? name, String? orientation}) async {
    final j = await _json(
      'POST',
      _uri(host, '/api/study/$studyId/import-pgn'),
      form: {'pgn': pgn, 'name': ?name, 'orientation': ?orientation},
    );
    return StudyImportResult(chapters: ((j['chapters'] as List?) ?? const []).length, error: j['error'] as String?);
  }

  /// Creates a private study (scope study:write). Returns its id.
  Future<String> createStudy(String name, {String visibility = 'private'}) async {
    final j = await _json(
      'POST',
      _uri(host, '/api/study'),
      form: {
        'name': name.length < 2 ? '$name  ' : (name.length > 100 ? name.substring(0, 100) : name),
        'visibility': visibility,
        'computer': 'everyone',
        'explorer': 'everyone',
        'cloneable': 'everyone',
        'shareable': 'everyone',
        'chat': 'member',
      },
    );
    return j['id']! as String;
  }

  /// Counts chapters by exporting the study.
  Future<int> studyChapterCount(String studyId) async {
    final pgn = await studyPgn(studyId);
    return RegExp(r'^\[Event ', multiLine: true).allMatches(pgn).length;
  }

  // ------------------------------------------------------------ games

  Future<String> gamePgn(String gameId) => _text(
    'GET',
    _uri(host, '/game/export/$gameId', {'clocks': 'true', 'evals': 'true', 'opening': 'true'}),
    accept: 'application/x-chess-pgn',
    auth: false,
  );

  /// Streams a user's games, newest first (F-LI-08).
  Stream<LichessGame> userGames(
    String username, {
    DateTime? since,
    DateTime? until,
    int? max,
    List<String>? perfTypes,
    bool? rated,
    String? color,
  }) {
    final q = <String, String>{
      'pgnInJson': 'true',
      'clocks': 'false',
      'evals': 'false',
      'opening': 'true',
      'moves': 'true',
      'finished': 'true',
      if (since != null) 'since': '${since.millisecondsSinceEpoch}',
      if (until != null) 'until': '${until.millisecondsSinceEpoch}',
      if (max != null) 'max': '$max',
      if (perfTypes != null && perfTypes.isNotEmpty) 'perfType': perfTypes.join(','),
      if (rated != null) 'rated': '$rated',
      'color': ?color,
    };
    return _ndjson(_uri(host, '/api/games/user/$username', q)).map(LichessGame.fromJson);
  }

  // ------------------------------------------------------------ explorer

  /// Opening explorer (requires a token since March 2026, F-LI-09).
  Future<ExplorerResult> explorer(
    String fen, {
    String db = 'masters',
    List<String> speeds = const [],
    List<int> ratings = const [],
    int moves = 15,
  }) async {
    final q = <String, String>{
      'fen': fen,
      'moves': '$moves',
      'topGames': '0',
      if (db == 'lichess') ...{
        'variant': 'standard',
        'recentGames': '0',
        if (speeds.isNotEmpty) 'speeds': speeds.join(','),
        if (ratings.isNotEmpty) 'ratings': ratings.join(','),
      },
    };
    final text = await _text('GET', _uri(explorerHost, db == 'lichess' ? '/lichess' : '/masters', q));
    return ExplorerResult.fromJson((jsonDecode(text) as Map).cast<String, Object?>());
  }

  /// Cached cloud evaluation, with a budget that includes queue waiting.
  /// Cancellation aborts HTTP and prevents obsolete queued requests from starting.
  Future<CloudEval?> cloudEval(
    String fen, {
    int multiPv = 1,
    Future<void>? abort,
    Duration budget = const Duration(seconds: 3),
  }) async {
    final key = '$multiPv/$fen';
    final cached = _cloudCache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < const Duration(minutes: 10)) {
      return cached.$2;
    }
    final url = _uri(host, '/api/cloud-eval', {'fen': fen, 'multiPv': '$multiPv'});
    final cancelled = Completer<void>();
    void cancel() {
      if (!cancelled.isCompleted) cancelled.complete();
    }

    _cloudRequests.add(cancelled);
    unawaited(abort?.then((_) => cancel()));
    final timer = Timer(budget, cancel);
    try {
      final result = await _withAbort(
        _queued(() async {
          if (cancelled.isCompleted) throw http.RequestAbortedException(url);
          final res = await _send(
            'GET',
            url,
            auth: false,
            headers: {'Accept': 'application/json'},
            abort: cancelled.future,
          );
          final text = await _withAbort(res.stream.bytesToString(), cancelled.future, url);
          if (res.statusCode == 404) return null;
          if (res.statusCode != 200) throw LichessException(res.statusCode, _errorMessage(text));
          final j = (jsonDecode(text) as Map).cast<String, Object?>();
          return CloudEval(
            depth: (j['depth'] as num?)?.toInt() ?? 0,
            knodes: (j['knodes'] as num?)?.toInt() ?? 0,
            lines: [
              for (final p in (j['pvs'] as List?) ?? const [])
                CloudEvalLine(
                  moves: ((p as Map)['moves'] as String? ?? '').split(' ').where((s) => s.isNotEmpty).toList(),
                  cp: (p['cp'] as num?)?.toInt(),
                  mate: (p['mate'] as num?)?.toInt(),
                ),
            ],
          );
        }),
        cancelled.future,
        url,
      );
      if (_cloudCache.length >= 256) _cloudCache.remove(_cloudCache.keys.first);
      _cloudCache[key] = (DateTime.now(), result);
      return result;
    } finally {
      timer.cancel();
      _cloudRequests.remove(cancelled);
    }
  }

  void close() {
    _closed = true;
    for (final request in _cloudRequests) {
      if (!request.isCompleted) request.complete();
    }
    _cloudCache.clear();
    _client.close();
    _rateLimited.close();
  }
}
