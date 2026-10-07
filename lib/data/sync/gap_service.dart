import 'dart:isolate';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:drift/drift.dart';

import '../../domain/gap/gap_analysis.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../db/database.dart';
import '../repositories/repertoire_repository.dart';

class GapRow {
  const GapRow(this.event, this.game, this.repertoireId);
  final GapEventRow event;
  final ImportedGameRow game;
  final int repertoireId;
}

/// What one run of the analysis saw: games compared, games that reached a
/// repertoire of their colour, events found.
class GapSummary {
  const GapSummary({required this.games, required this.reached, required this.events});
  final int games;
  final int reached;
  final int events;
}

/// Runs the games-vs-repertoire analysis and stores the events (F-GAP).
class GapService {
  GapService(this.db, this.repertoires);
  final AppDatabase db;
  final RepertoireRepository repertoires;

  /// Re-analyzes all imported games. A game is judged against one
  /// repertoire of its colour only: the one it follows the longest (D-057).
  /// With a 1.e4 and a 1.d4 repertoire, a 1.e4 game is not a deviation
  /// from the 1.d4 one.
  Future<GapSummary> analyzeAll() async {
    final reps = await db.select(db.repertoires).get();
    final games = await db.select(db.importedGames).get();
    var total = 0;
    final reached = <int>{};
    final graphs = <int, RepertoireGraph>{for (final r in reps) r.id: await repertoires.loadGraph(r.id)};
    final eventsByRep = <int, List<(int, GapEvent)>>{for (final r in reps) r.id: []};
    for (final side in Side.values) {
      final ids = [
        for (final r in reps)
          if (graphs[r.id]!.color == side) r.id,
      ];
      if (ids.isEmpty) continue;
      final color = side == Side.white ? 'white' : 'black';
      final relevant = games.where((g) => g.userColor == color).map((g) => (g.id, g.pgn)).toList();
      final (events, reachedIds) = await _analyzeInIsolate([for (final id in ids) graphs[id]!], relevant);
      reached.addAll(reachedIds);
      for (final (gameId, index, e) in events) {
        eventsByRep[ids[index]]!.add((gameId, e));
      }
    }
    for (final r in reps) {
      final events = eventsByRep[r.id]!;
      await db.transaction(() async {
        // What the user hid stays hidden after a re-analysis.
        final hidden = {
          for (final e in await (db.select(
            db.gapEvents,
          )..where((e) => e.repertoireId.equals(r.id) & e.dismissed.equals(true))).get())
            _dismissKey(e.importedGameId, e.positionKey, e.playedUci),
        };
        await (db.delete(db.gapEvents)..where((e) => e.repertoireId.equals(r.id))).go();
        await db.batch((b) {
          b.insertAll(db.gapEvents, [
            for (final (gameId, e) in events)
              GapEventsCompanion.insert(
                importedGameId: gameId,
                repertoireId: r.id,
                type: e.type.name,
                positionKey: e.key,
                fen: e.fen,
                ply: e.ply,
                playedSan: Value(e.playedSan),
                playedUci: Value(e.playedUci),
                expectedSan: Value(e.expectedSan),
                dismissed: Value(hidden.contains(_dismissKey(gameId, e.key, e.playedUci))),
              ),
          ]);
        });
      });
      total += events.length;
    }
    final now = DateTime.now();
    await db.update(db.importedGames).write(ImportedGamesCompanion(analyzedAt: Value(now)));
    lastSummary = GapSummary(games: games.length, reached: reached.length, events: total);
    return lastSummary!;
  }

  /// The result of the latest run in this session (the report explains an
  /// empty result with it).
  GapSummary? lastSummary;

  static String _dismissKey(int gameId, String positionKey, String playedUci) => '$gameId|$positionKey|$playedUci';

  /// Runs [_analyze] off the UI thread. A static function, so the closure
  /// sent to the isolate holds only its arguments: a closure made inside
  /// [analyzeAll] would also capture this service and its database, which
  /// cannot cross isolates ("Something went wrong" on My games).
  static Future<(List<(int, int, GapEvent)>, List<int>)> _analyzeInIsolate(
    List<RepertoireGraph> graphs,
    List<(int, String)> games,
  ) => Isolate.run(() => _analyze(graphs, games));

  /// For every game: the event in the repertoire it follows the longest
  /// (game id, index of that repertoire in [graphs], event), and the games
  /// that reached any of the repertoires at all. A game that stays inside
  /// one of them to its end has no event.
  static (List<(int, int, GapEvent)>, List<int>) _analyze(List<RepertoireGraph> graphs, List<(int, String)> games) {
    final out = <(int, int, GapEvent)>[];
    final reached = <int>[];
    for (final (id, pgn) in games) {
      final g = PgnParser.parseOne(pgn);
      var anyReached = false;
      var inBook = false;
      (int, GapEvent)? best;
      for (var i = 0; i < graphs.length; i++) {
        if (!reachesRepertoire(graphs[i], g)) continue;
        anyReached = true;
        final e = analyzeGame(graphs[i], g);
        if (e == null) {
          inBook = true;
          break;
        }
        if (best == null || e.ply > best.$2.ply) best = (i, e);
      }
      if (anyReached) reached.add(id);
      if (!inBook && best != null) out.add((id, best.$1, best.$2));
    }
    return (out, reached);
  }

  Stream<List<GapRow>> watchEvents() {
    final q =
        db.select(db.gapEvents).join([
            innerJoin(db.importedGames, db.importedGames.id.equalsExp(db.gapEvents.importedGameId)),
          ])
          ..where(db.gapEvents.dismissed.equals(false))
          ..orderBy([OrderingTerm.desc(db.importedGames.playedAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          GapRow(r.readTable(db.gapEvents), r.readTable(db.importedGames), r.readTable(db.gapEvents).repertoireId),
      ],
    );
  }

  Future<void> dismiss(Iterable<int> ids, {bool dismissed = true}) =>
      (db.update(db.gapEvents)..where((e) => e.id.isIn(ids))).write(GapEventsCompanion(dismissed: Value(dismissed)));
}
