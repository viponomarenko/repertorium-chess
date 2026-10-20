import 'dart:async';

import 'package:drift/drift.dart';

import '../chesscom/chesscom_client.dart';
import '../db/database.dart';
import '../lichess/lichess_auth.dart';
import '../lichess/lichess_client.dart';

class SyncProgress {
  const SyncProgress({
    required this.downloaded,
    required this.added,
    this.month,
    this.done = false,
    this.error,
    this.more = false,
  });

  /// Games looked at (already downloaded ones included).
  final int downloaded;

  /// Games new to the app.
  final int added;

  /// The Chess.com month being read.
  final DateTime? month;
  final bool done;
  final Object? error;

  /// The limit was reached: there are games left to download.
  final bool more;
}

/// Filters for downloading the user's games (F-LI-08, F-CC-02).
class GamesFilter {
  const GamesFilter({
    this.since,
    this.max,
    this.speeds = const {},
    this.ratedOnly = false,
    this.color,
    this.newOnly = false,
  });

  final DateTime? since;

  /// At most this many games new to the app: games downloaded before do
  /// not count, so a second download continues where the first stopped.
  final int? max;

  /// bullet | blitz | rapid | classical | correspondence(daily)
  final Set<String> speeds;
  final bool ratedOnly;

  /// white | black
  final String? color;

  /// Only games played after the latest downloaded one (the whole history
  /// when nothing is downloaded yet).
  final bool newOnly;
}

class AccountsService {
  AccountsService({
    required this.db,
    required this.lichess,
    required this.chessCom,
    required this.tokens,
    LichessOAuth? oauth,
  }) : oauth = oauth ?? LichessOAuth();

  final AppDatabase db;
  final LichessClient lichess;
  final ChessComClient chessCom;
  final TokenStore tokens;
  final LichessOAuth oauth;

  Stream<List<LinkedAccountRow>> watchAccounts() => db.select(db.linkedAccounts).watch();

  Future<LinkedAccountRow?> account(String provider) =>
      (db.select(db.linkedAccounts)..where((a) => a.provider.equals(provider))).getSingleOrNull();

  // ------------------------------------------------------------ Lichess

  Future<LinkedAccountRow> connectLichess({bool withWrite = false}) async {
    final scopes = withWrite ? LichessOAuth.writeScopes : LichessOAuth.readScopes;
    final token = await oauth.login(scopes: scopes);
    await tokens.write(token);
    final acc = await lichess.account();
    final row = LinkedAccountsCompanion.insert(
      provider: 'lichess',
      username: acc.username,
      tokenRef: const Value(SecureTokenStore.key),
      scopes: Value(scopes.join(' ')),
      connectedAt: DateTime.now(),
    );
    await db.into(db.linkedAccounts).insertOnConflictUpdate(row);
    return (await account('lichess'))!;
  }

  /// Asks for `study:write` only when first needed (F-LI-03).
  Future<void> ensureLichessWrite() async {
    final acc = await account('lichess');
    if (acc != null && acc.scopes.split(' ').contains('study:write')) return;
    await connectLichess(withWrite: true);
  }

  Future<void> disconnectLichess() async {
    try {
      await lichess.revokeToken();
    } catch (_) {
      // Token may already be invalid; remove locally anyway.
    }
    await tokens.delete();
    await (db.delete(db.linkedAccounts)..where((a) => a.provider.equals('lichess'))).go();
  }

  /// Called on 401: the token is no longer valid (F-LI-02).
  Future<void> markLichessExpired() async {
    await tokens.delete();
    await (db.update(
      db.linkedAccounts,
    )..where((a) => a.provider.equals('lichess'))).write(const LinkedAccountsCompanion(scopes: Value('')));
  }

  Future<bool> hasLichessToken() async => (await tokens.read())?.isNotEmpty ?? false;

  // ------------------------------------------------------------ Chess.com

  Future<ChessComPlayer?> connectChessCom(String username) async {
    final p = await chessCom.player(username);
    if (p == null) return null;
    await db
        .into(db.linkedAccounts)
        .insertOnConflictUpdate(
          LinkedAccountsCompanion.insert(provider: 'chesscom', username: p.username, connectedAt: DateTime.now()),
        );
    return p;
  }

  Future<void> disconnectChessCom() async {
    await (db.delete(db.linkedAccounts)..where((a) => a.provider.equals('chesscom'))).go();
    await _forgetChessComMonths();
  }

  /// Drops the "not modified" marks of the monthly archives: with them a
  /// later download would skip every month already seen, although its
  /// games may have been deleted since.
  Future<void> _forgetChessComMonths() => (db.delete(db.httpCache)..where((c) => c.url.like('%chess.com%'))).go();

  /// Lichess variants (Atomic, Chess960...) are not openings of standard
  /// chess: they do not belong in the statistics or the gap report.
  static bool isVariantPgn(String pgn) {
    final v = RegExp(r'\[Variant "([^"]*)"\]').firstMatch(pgn)?.group(1)?.toLowerCase();
    return v != null && v != 'standard' && v != 'chess' && v != 'normal';
  }

  // ------------------------------------------------------------ games

  Future<DateTime?> _latestGame(String provider) => _playedAt(provider, db.importedGames.playedAt.max());

  Future<DateTime?> _oldestGame(String provider) => _playedAt(provider, db.importedGames.playedAt.min());

  Future<DateTime?> _playedAt(String provider, Expression<DateTime> aggregate) async {
    final q = db.selectOnly(db.importedGames)
      ..addColumns([aggregate])
      ..where(db.importedGames.provider.equals(provider));
    return (await q.getSingle()).read(aggregate);
  }

  Future<bool> _insertGame(ImportedGamesCompanion c) async {
    final row = await db.into(db.importedGames).insertReturningOrNull(c, mode: InsertMode.insertOrIgnore);
    return row != null;
  }

  /// Downloads Lichess games (F-LI-08). Only what is not here yet is
  /// asked for: games newer than the latest downloaded one, oldest first so
  /// that a limit leaves no hole, then (unless [GamesFilter.newOnly]) games
  /// older than the earliest one.
  Stream<SyncProgress> syncLichess(GamesFilter f, {bool Function()? cancelled}) async* {
    final acc = await account('lichess');
    if (acc == null) return;
    final latest = await _latestGame('lichess');
    final oldest = await _oldestGame('lichess');
    const ms = Duration(milliseconds: 1);
    final windows = <({DateTime? since, DateTime? until, bool oldestFirst})>[
      if (latest == null || oldest == null)
        (since: f.since, until: null, oldestFirst: false)
      else ...[
        (since: f.since != null && f.since!.isAfter(latest) ? f.since : latest.add(ms), until: null, oldestFirst: true),
        if (!f.newOnly && (f.since == null || oldest.isAfter(f.since!)))
          (since: f.since, until: oldest.subtract(ms), oldestFirst: false),
      ],
    ];
    var downloaded = 0;
    var added = 0;
    var more = false;
    final perf = f.speeds.map((s) => s == 'daily' ? 'correspondence' : s).toList();
    try {
      for (final w in windows) {
        if (cancelled?.call() ?? false) break;
        final left = f.max == null ? null : f.max! - added;
        if (left != null && left <= 0) {
          more = true;
          break;
        }
        var seen = 0;
        await for (final g in lichess.userGames(
          acc.username,
          since: w.since,
          until: w.until,
          max: left,
          perfTypes: perf.isEmpty ? null : perf,
          rated: f.ratedOnly ? true : null,
          color: f.color,
          oldestFirst: w.oldestFirst,
        )) {
          if (cancelled?.call() ?? false) break;
          downloaded++;
          seen++;
          if (isVariantPgn(g.pgn)) continue;
          final userColor = g.white == acc.username.toLowerCase() ? 'white' : 'black';
          if (await _insertGame(
            ImportedGamesCompanion.insert(
              provider: 'lichess',
              externalId: g.id,
              pgn: g.pgn,
              playedAt: g.createdAt,
              userColor: userColor,
              timeControl: Value(g.timeControl),
              speed: Value(g.speed),
              result: Value(g.result),
              opponent: Value(userColor == 'white' ? g.black : g.white),
              url: Value('https://lichess.org/${g.id}'),
              rated: Value(g.rated),
            ),
          )) {
            added++;
          }
          if (downloaded % 10 == 0) yield SyncProgress(downloaded: downloaded, added: added);
        }
        // The server stopped at the limit: there may be more.
        if (left != null && seen >= left) more = true;
      }
      await _touchSync('lichess');
      yield SyncProgress(downloaded: downloaded, added: added, done: true, more: more);
    } catch (e) {
      yield SyncProgress(downloaded: downloaded, added: added, done: true, error: e);
    }
  }

  /// Year and month of a Chess.com archive URL (`.../games/2026/10`).
  static DateTime? archiveMonth(Uri url) {
    final parts = url.pathSegments;
    if (parts.length < 2) return null;
    final y = int.tryParse(parts[parts.length - 2]);
    final m = int.tryParse(parts.last);
    return y == null || m == null ? null : DateTime(y, m);
  }

  /// Downloads Chess.com games month by month (F-CC-02, F-CC-03). A month
  /// read through without skipping a game is remembered by its ETag and
  /// later costs one 304 answer. Games already here do not count towards
  /// the limit, so the next download goes on where this one stopped:
  /// newest first for a period or the whole history, oldest first for new
  /// games only.
  Stream<SyncProgress> syncChessCom(GamesFilter f, {bool Function()? cancelled}) async* {
    final acc = await account('chesscom');
    if (acc == null) return;
    var downloaded = 0;
    var added = 0;
    var more = false;
    try {
      final archives = await chessCom.archives(acc.username);
      final latest = f.newOnly ? await _latestGame('chesscom') : null;
      final newOnly = latest != null;
      final from = newOnly ? latest : f.since;
      final months = [
        for (final u in archives)
          if (archiveMonth(u) case final m?)
            if (from == null || !m.isBefore(DateTime(from.year, from.month))) (u, m),
      ];
      final me = acc.username.toLowerCase();
      final ordered = (newOnly ? months : months.reversed).toList();
      for (final (k, (url, month)) in ordered.indexed) {
        if (cancelled?.call() ?? false) break;
        if (f.max != null && added >= f.max!) {
          // More to come only if a month left is not read through yet.
          more = await _anyUnread([for (final (u, _) in ordered.skip(k)) u]);
          break;
        }
        final cache = await (db.select(db.httpCache)..where((c) => c.url.equals(url.toString()))).getSingleOrNull();
        final r = await chessCom.month(url, etag: cache?.etag, lastModified: cache?.lastModified);
        if (r.notModified) {
          yield SyncProgress(downloaded: downloaded, added: added, month: month);
          continue;
        }
        // A month's games come oldest first.
        final games = newOnly ? r.games : r.games.reversed.toList();
        var complete = true;
        for (final (i, g) in games.indexed) {
          if (cancelled?.call() ?? false) {
            complete = false;
            break;
          }
          // Variants are never downloaded: skipping them leaves the month whole.
          if (g.rules != 'chess') continue;
          final color = g.white.toLowerCase() == me ? 'white' : 'black';
          if ((f.color != null && f.color != color) ||
              (f.ratedOnly && !g.rated) ||
              (f.speeds.isNotEmpty && !f.speeds.contains(g.timeClass)) ||
              (!newOnly && f.since != null && g.endTime.isBefore(f.since!))) {
            complete = false;
            continue;
          }
          downloaded++;
          if (await _insertGame(
            ImportedGamesCompanion.insert(
              provider: 'chesscom',
              externalId: g.id,
              pgn: g.pgn,
              playedAt: g.endTime,
              userColor: color,
              timeControl: Value(g.timeControl),
              speed: Value(g.timeClass),
              result: Value(g.result),
              opponent: Value(color == 'white' ? g.black : g.white),
              url: Value(g.url),
              rated: Value(g.rated),
            ),
          )) {
            added++;
          }
          if (f.max != null && added >= f.max! && i < games.length - 1) {
            complete = false;
            more = true;
            break;
          }
        }
        if (complete) {
          await db
              .into(db.httpCache)
              .insertOnConflictUpdate(
                HttpCacheCompanion.insert(
                  url: url.toString(),
                  etag: Value(r.etag),
                  lastModified: Value(r.lastModified),
                  fetchedAt: DateTime.now(),
                ),
              );
        }
        yield SyncProgress(downloaded: downloaded, added: added, month: month);
      }
      await _touchSync('chesscom');
      yield SyncProgress(downloaded: downloaded, added: added, done: true, more: more);
    } catch (e) {
      yield SyncProgress(downloaded: downloaded, added: added, done: true, error: e);
    }
  }

  /// Whether any of [months] was never read through (no remembered ETag).
  Future<bool> _anyUnread(List<Uri> months) async {
    final known = {
      for (final c in await (db.select(db.httpCache)..where((c) => c.url.isIn([for (final u in months) '$u']))).get())
        c.url,
    };
    return months.any((u) => !known.contains('$u'));
  }

  Future<void> _touchSync(String provider) => (db.update(
    db.linkedAccounts,
  )..where((a) => a.provider.equals(provider))).write(LinkedAccountsCompanion(lastSyncAt: Value(DateTime.now())));

  Stream<List<ImportedGameRow>> watchImportedGames({String? provider}) {
    final q = db.select(db.importedGames)..orderBy([(g) => OrderingTerm.desc(g.playedAt)]);
    if (provider != null) q.where((g) => g.provider.equals(provider));
    return q.watch();
  }

  Future<void> deleteImportedGames({String? provider}) async {
    final q = db.delete(db.importedGames);
    if (provider != null) q.where((g) => g.provider.equals(provider));
    await q.go();
    if (provider == null || provider == 'chesscom') await _forgetChessComMonths();
  }
}
