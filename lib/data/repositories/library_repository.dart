import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_writer.dart';
import '../db/database.dart';
import '../import/pgn_import_service.dart';

class CollectionSummary {
  const CollectionSummary(this.row, this.gameCount);
  final CollectionRow row;
  final int gameCount;
}

class GameFilter {
  const GameFilter({this.query = '', this.result, this.eco});
  final String query;
  final String? result;
  final String? eco;

  bool get isEmpty => query.trim().isEmpty && result == null && (eco == null || eco!.isEmpty);
}

class LibraryRepository {
  LibraryRepository(this.db);
  final AppDatabase db;

  Stream<List<CollectionSummary>> watchCollections() {
    final count = db.games.id.count();
    final q =
        db.select(db.collections).join([
            leftOuterJoin(db.games, db.games.collectionId.equalsExp(db.collections.id), useColumns: false),
          ])
          ..addColumns([count])
          ..groupBy([db.collections.id])
          ..orderBy([OrderingTerm.desc(db.collections.updatedAt)]);
    return q.watch().map(
      (rows) => [for (final r in rows) CollectionSummary(r.readTable(db.collections), r.read(count) ?? 0)],
    );
  }

  Future<CollectionRow?> collection(int id) =>
      (db.select(db.collections)..where((c) => c.id.equals(id))).getSingleOrNull();

  Stream<CollectionRow?> watchCollection(int id) =>
      (db.select(db.collections)..where((c) => c.id.equals(id))).watchSingleOrNull();

  Future<int> createCollection(String name, {String source = 'manual', String? sourceRef}) {
    final now = DateTime.now();
    return db
        .into(db.collections)
        .insert(
          CollectionsCompanion.insert(
            name: name,
            source: Value(source),
            sourceRef: Value(sourceRef),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> renameCollection(int id, String name) => (db.update(
    db.collections,
  )..where((c) => c.id.equals(id))).write(CollectionsCompanion(name: Value(name), updatedAt: Value(DateTime.now())));

  /// Older versions found "My analyses" by its name, so changing the app
  /// language made a second one. Folds them into the oldest (once, at
  /// start-up; harmless when there is nothing to fold).
  Future<void> mergeAnalysisCollections() => db.transaction(() async {
    final all =
        await (db.select(db.collections)
              ..where((c) => c.source.equals('analysis') | c.name.isIn(const ['My analyses', 'Мої аналізи']))
              ..orderBy([(c) => OrderingTerm.asc(c.id)]))
            .get();
    if (all.isEmpty) return;
    final keep = all.first;
    if (keep.source != 'analysis') {
      await (db.update(
        db.collections,
      )..where((c) => c.id.equals(keep.id))).write(const CollectionsCompanion(source: Value('analysis')));
    }
    for (final other in all.skip(1)) {
      await (db.update(
        db.games,
      )..where((g) => g.collectionId.equals(other.id))).write(GamesCompanion(collectionId: Value(keep.id)));
      await (db.delete(db.collections)..where((c) => c.id.equals(other.id))).go();
    }
  });

  Future<void> deleteCollection(int id) => db.transaction(() async {
    await (db.delete(db.games)..where((g) => g.collectionId.equals(id))).go();
    await (db.delete(db.collections)..where((c) => c.id.equals(id))).go();
  });

  /// Stores parsed games in one transaction (F-IMP / 9.2).
  Future<int> addGames(int collectionId, List<GameImportData> games, {void Function(double)? onProgress}) async {
    final now = DateTime.now();
    final maxOrder = await _maxOrder(collectionId);
    const chunk = 500;
    await db.transaction(() async {
      for (var i = 0; i < games.length; i += chunk) {
        final part = games.sublist(i, i + chunk > games.length ? games.length : i + chunk);
        await db.batch((b) {
          b.insertAll(db.games, [
            for (var j = 0; j < part.length; j++) _companion(collectionId, part[j], maxOrder + i + j + 1, now),
          ]);
        });
        onProgress?.call((i + part.length) / games.length);
      }
      await _touch(collectionId);
    });
    return games.length;
  }

  GamesCompanion _companion(int collectionId, GameImportData g, int order, DateTime now) {
    final h = g.headers;
    return GamesCompanion.insert(
      collectionId: collectionId,
      orderIdx: Value(order),
      pgn: g.pgn,
      headersJson: Value(headersToJson(h)),
      white: Value(h['White'] ?? ''),
      black: Value(h['Black'] ?? ''),
      event: Value(h['Event'] ?? ''),
      date: Value(h['Date'] ?? ''),
      result: Value(h['Result'] ?? '*'),
      eco: Value(g.eco),
      opening: Value(g.opening),
      rootFen: Value(g.rootFen),
      plyCount: Value(g.plyCount),
      issuesJson: Value(g.issues.isEmpty ? '' : jsonEncode(g.issues)),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> _maxOrder(int collectionId) async {
    final max = db.games.orderIdx.max();
    final q = db.selectOnly(db.games)
      ..addColumns([max])
      ..where(db.games.collectionId.equals(collectionId));
    return (await q.getSingle()).read(max) ?? 0;
  }

  Future<void> _touch(int collectionId) => (db.update(
    db.collections,
  )..where((c) => c.id.equals(collectionId))).write(CollectionsCompanion(updatedAt: Value(DateTime.now())));

  Stream<List<GameRow>> watchGames(int collectionId, {GameFilter filter = const GameFilter()}) {
    final q = db.select(db.games)..where((g) => g.collectionId.equals(collectionId));
    final text = filter.query.trim();
    if (text.isNotEmpty) {
      for (final word in text.split(RegExp(r'\s+'))) {
        final like = '%$word%';
        q.where(
          (g) =>
              g.white.like(like) |
              g.black.like(like) |
              g.event.like(like) |
              g.eco.like(like) |
              g.opening.like(like) |
              g.date.like(like) |
              g.headersJson.like(like),
        );
      }
    }
    if (filter.result != null) q.where((g) => g.result.equals(filter.result!));
    if (filter.eco != null && filter.eco!.isNotEmpty) q.where((g) => g.eco.like('${filter.eco}%'));
    q.orderBy([(g) => OrderingTerm.asc(g.orderIdx)]);
    return q.watch();
  }

  /// A game's text without layout differences, to tell the same game
  /// imported twice.
  static String pgnKey(String pgn) => pgn.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// [pgnKey]s of the games already in a collection.
  Future<Set<String>> pgnKeys(int collectionId) async {
    final q = db.selectOnly(db.games)
      ..addColumns([db.games.pgn])
      ..where(db.games.collectionId.equals(collectionId));
    return {for (final r in await q.get()) pgnKey(r.read(db.games.pgn)!)};
  }

  Future<CollectionRow?> collectionNamed(String name) =>
      (db.select(db.collections)
            ..where((c) => c.name.equals(name))
            ..limit(1))
          .getSingleOrNull();

  Future<List<GameRow>> gamesOf(int collectionId) =>
      (db.select(db.games)
            ..where((g) => g.collectionId.equals(collectionId))
            ..orderBy([(g) => OrderingTerm.asc(g.orderIdx)]))
          .get();

  Future<GameRow?> game(int id) => (db.select(db.games)..where((g) => g.id.equals(id))).getSingleOrNull();

  Future<List<GameRow>> gamesByIds(List<int> ids) => (db.select(db.games)..where((g) => g.id.isIn(ids))).get();

  /// Saves an edited game (re-serialized from the tree).
  Future<void> saveGame(int id, ChessGame game) async {
    final pgn = gameToPgn(game);
    final h = game.headers;
    await (db.update(db.games)..where((g) => g.id.equals(id))).write(
      GamesCompanion(
        pgn: Value(pgn),
        headersJson: Value(headersToJson(h)),
        white: Value(h['White'] ?? ''),
        black: Value(h['Black'] ?? ''),
        event: Value(h['Event'] ?? ''),
        date: Value(h['Date'] ?? ''),
        result: Value(h['Result'] ?? '*'),
        eco: Value(h['ECO'] ?? ''),
        opening: Value(h['Opening'] ?? ''),
        plyCount: Value(game.mainline.length),
        // The warning stays while unread moves are kept in a comment.
        issuesJson: Value(game.hasUnparsedTail ? jsonEncode(const ['Unread moves are kept in a comment']) : ''),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int> createGame(int collectionId, ChessGame game) async {
    final data = GameImportData(
      pgn: gameToPgn(game),
      headers: Map.of(game.headers),
      plyCount: game.mainline.length,
      issues: const [],
      startLine: 1,
      rootFen: game.headers['FEN'],
    );
    final order = await _maxOrder(collectionId);
    final id = await db.into(db.games).insert(_companion(collectionId, data, order + 1, DateTime.now()));
    await _touch(collectionId);
    return id;
  }

  /// Deletes games and returns them, so the deletion can be undone with
  /// [restoreGames].
  Future<List<GameRow>> deleteGames(List<int> ids) => db.transaction(() async {
    final rows = await (db.select(db.games)..where((g) => g.id.isIn(ids))).get();
    await (db.delete(db.games)..where((g) => g.id.isIn(ids))).go();
    return rows;
  });

  Future<void> restoreGames(List<GameRow> rows) =>
      db.batch((b) => b.insertAll(db.games, rows, mode: InsertMode.insertOrReplace));

  Future<void> moveGames(List<int> ids, int toCollection) =>
      (db.update(db.games)..where((g) => g.id.isIn(ids))).write(GamesCompanion(collectionId: Value(toCollection)));

  /// PGN of several games (stored text, lossless) for export (F-EDIT-06).
  Future<String> exportPgn({int? collectionId, List<int>? gameIds}) async {
    List<GameRow> rows;
    if (gameIds != null) {
      rows = await gamesByIds(gameIds);
      rows.sort((a, b) => gameIds.indexOf(a.id).compareTo(gameIds.indexOf(b.id)));
    } else {
      rows = await gamesOf(collectionId!);
    }
    return rows.map((r) => r.pgn.trim()).join('\n\n') + (rows.isEmpty ? '' : '\n');
  }

  Future<int> totalGames() async {
    final c = db.games.id.count();
    return (await (db.selectOnly(db.games)..addColumns([c])).getSingle()).read(c) ?? 0;
  }
}
