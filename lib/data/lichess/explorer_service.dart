import 'dart:async';
import 'dart:convert';

import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../db/database.dart';
import 'lichess_client.dart';

class ExplorerQuery {
  const ExplorerQuery({this.db = 'masters', this.speeds = const [], this.ratings = const []});

  /// masters | lichess
  final String db;
  final List<String> speeds;
  final List<int> ratings;

  String cacheKey(PositionKey key) =>
      db == 'masters' ? 'masters|$key' : 'lichess|$key|${speeds.join(',')}|${ratings.join(',')}';
}

/// Opening explorer with a local cache (key = FEN + filters, TTL 30 days,
/// F-LI-09) and client-side throttling for batch jobs (25 req/min limit).
class ExplorerService {
  ExplorerService(this.db, this.client, {this.ttl = const Duration(days: 30)});
  final AppDatabase db;
  final LichessClient client;
  final Duration ttl;

  Future<ExplorerResult> lookup(String fen, ExplorerQuery q, {bool refresh = false}) async {
    final key = q.cacheKey(keyFromFen(fen));
    if (!refresh) {
      final row = await (db.select(db.explorerCache)..where((c) => c.cacheKey.equals(key))).getSingleOrNull();
      if (row != null && DateTime.now().difference(row.fetchedAt) < ttl) {
        return ExplorerResult.fromJson((jsonDecode(row.json) as Map).cast<String, Object?>());
      }
    }
    final r = await client.explorer(fen, db: q.db, speeds: q.speeds, ratings: q.ratings);
    await db
        .into(db.explorerCache)
        .insertOnConflictUpdate(
          ExplorerCacheCompanion.insert(cacheKey: key, json: jsonEncode(_toJson(r)), fetchedAt: DateTime.now()),
        );
    return r;
  }

  Future<bool> isCached(String fen, ExplorerQuery q) async {
    final row = await (db.select(
      db.explorerCache,
    )..where((c) => c.cacheKey.equals(q.cacheKey(keyFromFen(fen))))).getSingleOrNull();
    return row != null && DateTime.now().difference(row.fetchedAt) < ttl;
  }

  Future<void> clearCache() => db.delete(db.explorerCache).go();

  static Map<String, Object?> _toJson(ExplorerResult r) => {
    'white': r.white,
    'draws': r.draws,
    'black': r.black,
    'opening': r.openingName == null ? null : {'name': r.openingName, 'eco': r.eco},
    'moves': [
      for (final m in r.moves)
        {
          'uci': m.uci,
          'san': m.san,
          'white': m.white,
          'draws': m.draws,
          'black': m.black,
          'averageRating': m.averageRating,
        },
    ],
  };
}

class BatchProgress {
  const BatchProgress(this.done, this.total, {this.finished = false, this.error});
  final int done;
  final int total;
  final bool finished;
  final Object? error;
}

class CoverageGap {
  const CoverageGap({
    required this.key,
    required this.fen,
    required this.san,
    required this.uci,
    required this.share,
    required this.games,
  });
  final PositionKey key;
  final String fen;
  final String san;
  final String uci;

  /// Share of games in this position (0..1).
  final double share;
  final int games;
}

/// Batch explorer jobs over a repertoire: fill opponent weights (F-LI-10)
/// and find popular uncovered opponent moves (F-GAP-04).
class ExplorerBatch {
  ExplorerBatch(this.explorer, {this.minInterval = const Duration(milliseconds: 2500)});
  final ExplorerService explorer;

  /// Lichess allows about 25 explorer requests per minute per user.
  final Duration minInterval;

  List<PositionKey> _opponentPositions(RepertoireGraph g, {int maxPositions = 2000}) {
    final reachable = g.reachableFrom(g.rootKey).where((k) => !g.isUserTurn(k)).toList();
    // Shallow positions first (they matter most).
    final depth = <PositionKey, int>{g.rootKey: 0};
    final order = <PositionKey>[g.rootKey];
    for (var i = 0; i < order.length; i++) {
      for (final m in g.movesFrom(order[i])) {
        if (!depth.containsKey(m.toKey)) {
          depth[m.toKey] = depth[order[i]]! + 1;
          order.add(m.toKey);
        }
      }
    }
    final set = reachable.toSet();
    return order.where(set.contains).take(maxPositions).toList();
  }

  Future<void> _throttle(bool cached, DateTime last) async {
    if (cached) return;
    final wait = minInterval - DateTime.now().difference(last);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }

  /// Normalizes opponent move frequencies into weights 0..100.
  Stream<BatchProgress> fillWeights(RepertoireGraph g, ExplorerQuery q, {bool Function()? cancelled}) async* {
    final positions = _opponentPositions(g).where((k) => g.movesFrom(k).isNotEmpty).toList();
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    for (var i = 0; i < positions.length; i++) {
      if (cancelled?.call() ?? false) break;
      final k = positions[i];
      final fen = g.positions[k]!.fen;
      final cached = await explorer.isCached(fen, q);
      await _throttle(cached, last);
      try {
        final r = await explorer.lookup(fen, q);
        if (!cached) last = DateTime.now();
        final counts = {for (final m in r.moves) m.uci: m.total};
        final moves = g.movesFrom(k);
        final total = moves.fold<int>(0, (a, m) => a + (counts[_std(m.uci)] ?? counts[m.uci] ?? 0));
        for (final m in moves) {
          final c = counts[_std(m.uci)] ?? counts[m.uci] ?? 0;
          final w = total == 0 ? 50 : (c * 100 / total).round().clamp(total > 0 && c > 0 ? 1 : 0, 100);
          if (w != m.weight) g.setWeight(m, w);
        }
      } catch (e) {
        // Lichess errors, timeouts and a lost connection alike.
        yield BatchProgress(i, positions.length, finished: true, error: e);
        return;
      }
      yield BatchProgress(i + 1, positions.length);
    }
    yield BatchProgress(positions.length, positions.length, finished: true);
  }

  /// Opponent moves played in more than [minShare] of games but missing in
  /// the repertoire (F-GAP-04).
  Stream<(BatchProgress, List<CoverageGap>)> coverage(
    RepertoireGraph g,
    ExplorerQuery q, {
    double minShare = 0.05,
    int minGames = 20,
    bool Function()? cancelled,
  }) async* {
    final positions = _opponentPositions(g);
    final gaps = <CoverageGap>[];
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    for (var i = 0; i < positions.length; i++) {
      if (cancelled?.call() ?? false) break;
      final k = positions[i];
      final fen = g.positions[k]!.fen;
      final cached = await explorer.isCached(fen, q);
      await _throttle(cached, last);
      try {
        final r = await explorer.lookup(fen, q);
        if (!cached) last = DateTime.now();
        final total = r.total;
        if (total >= minGames) {
          final known = g.movesFrom(k).map((m) => m.uci).toSet();
          for (final m in r.moves) {
            final share = m.total / total;
            if (share >= minShare && !known.contains(_std(m.uci)) && !known.contains(m.uci)) {
              final pos = positionFromFen(fen);
              final mv = parseUciMove(pos, m.uci);
              gaps.add(
                CoverageGap(
                  key: k,
                  fen: fen,
                  san: m.san,
                  uci: mv == null ? m.uci : standardUci(pos, mv),
                  share: share,
                  games: m.total,
                ),
              );
            }
          }
        }
      } catch (e) {
        yield (BatchProgress(i, positions.length, finished: true, error: e), gaps);
        return;
      }
      yield (BatchProgress(i + 1, positions.length), List.of(gaps));
    }
    gaps.sort((a, b) => b.share.compareTo(a.share));
    yield (BatchProgress(positions.length, positions.length, finished: true), gaps);
  }

  /// Explorer uses king-takes-rook castling in some responses; accept both.
  static String _std(String uci) => switch (uci) {
    'e1h1' => 'e1g1',
    'e1a1' => 'e1c1',
    'e8h8' => 'e8g8',
    'e8a8' => 'e8c8',
    _ => uci,
  };
}
