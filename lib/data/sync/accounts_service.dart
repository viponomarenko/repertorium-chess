import 'dart:async';

import 'package:drift/drift.dart';

import '../chesscom/chesscom_client.dart';
import '../db/database.dart';
import '../lichess/lichess_auth.dart';
import '../lichess/lichess_client.dart';

class SyncProgress {
  const SyncProgress({required this.downloaded, required this.added, this.message, this.done = false, this.error});
  final int downloaded;
  final int added;
  final String? message;
  final bool done;
  final Object? error;
}

/// Filters for downloading the user's games (F-LI-08, F-CC-02).
class GamesFilter {
  const GamesFilter({this.since, this.max, this.speeds = const {}, this.ratedOnly = false, this.color});

  final DateTime? since;
  final int? max;

  /// bullet | blitz | rapid | classical | correspondence(daily)
  final Set<String> speeds;
  final bool ratedOnly;

  /// white | black
  final String? color;
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

  Future<DateTime?> _latestGame(String provider) async {
    final max = db.importedGames.playedAt.max();
    final q = db.selectOnly(db.importedGames)
      ..addColumns([max])
      ..where(db.importedGames.provider.equals(provider));
    return (await q.getSingle()).read(max);
  }

  Future<bool> _insertGame(ImportedGamesCompanion c) async {
    final row = await db.into(db.importedGames).insertReturningOrNull(c, mode: InsertMode.insertOrIgnore);
    return row != null;
  }

  /// Downloads Lichess games; incremental by default (F-LI-08).
  Stream<SyncProgress> syncLichess(GamesFilter f, {bool Function()? cancelled}) async* {
    final acc = await account('lichess');
    if (acc == null) return;
    final since = f.since ?? (await _latestGame('lichess'))?.add(const Duration(milliseconds: 1));
    var downloaded = 0;
    var added = 0;
    final perf = f.speeds.map((s) => s == 'daily' ? 'correspondence' : s).toList();
    try {
      await for (final g in lichess.userGames(
        acc.username,
        since: since,
        max: f.max,
        perfTypes: perf.isEmpty ? null : perf,
        rated: f.ratedOnly ? true : null,
        color: f.color,
      )) {
        if (cancelled?.call() ?? false) break;
        downloaded++;
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
      await _touchSync('lichess');
      yield SyncProgress(downloaded: downloaded, added: added, done: true);
    } catch (e) {
      yield SyncProgress(downloaded: downloaded, added: added, done: true, error: e);
    }
  }

  /// Downloads Chess.com games month by month; only new and current months
  /// are fetched again, with ETag (F-CC-02, F-CC-03).
  Stream<SyncProgress> syncChessCom(GamesFilter f, {bool Function()? cancelled}) async* {
    final acc = await account('chesscom');
    if (acc == null) return;
    var downloaded = 0;
    var added = 0;
    try {
      final archives = await chessCom.archives(acc.username);
      final latest = await _latestGame('chesscom');
      final from = f.since ?? latest;
      final months = archives.where((u) {
        if (from == null) return true;
        final parts = u.pathSegments;
        final y = int.tryParse(parts[parts.length - 2]) ?? 0;
        final m = int.tryParse(parts.last) ?? 0;
        return y > from.year || (y == from.year && m >= from.month);
      }).toList();
      // Newest first, so a limit keeps recent games.
      for (final url in months.reversed) {
        if (cancelled?.call() ?? false) break;
        if (f.max != null && downloaded >= f.max!) break;
        final cache = await (db.select(db.httpCache)..where((c) => c.url.equals(url.toString()))).getSingleOrNull();
        final r = await chessCom.month(url, etag: cache?.etag, lastModified: cache?.lastModified);
        if (r.notModified) {
          yield SyncProgress(downloaded: downloaded, added: added, message: url.pathSegments.skip(5).join('/'));
          continue;
        }
        final me = acc.username.toLowerCase();
        // The month may be cached (ETag) only when every game of it was
        // looked at without filters; otherwise a later sync with other
        // settings would get 304 and never see the skipped games.
        final unfiltered = f.color == null && !f.ratedOnly && f.speeds.isEmpty && f.since == null;
        var complete = true;
        for (final g in r.games.reversed) {
          if (g.rules != 'chess') continue;
          final color = g.white.toLowerCase() == me ? 'white' : 'black';
          if (f.color != null && f.color != color) continue;
          if (f.ratedOnly && !g.rated) continue;
          if (f.speeds.isNotEmpty && !f.speeds.contains(g.timeClass == 'daily' ? 'daily' : g.timeClass)) continue;
          if (f.since != null && g.endTime.isBefore(f.since!)) continue;
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
          if (f.max != null && downloaded >= f.max!) {
            complete = g == r.games.first;
            break;
          }
        }
        if (unfiltered && complete) {
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
        yield SyncProgress(downloaded: downloaded, added: added, message: url.pathSegments.skip(5).join('/'));
      }
      await _touchSync('chesscom');
      yield SyncProgress(downloaded: downloaded, added: added, done: true);
    } catch (e) {
      yield SyncProgress(downloaded: downloaded, added: added, done: true, error: e);
    }
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
