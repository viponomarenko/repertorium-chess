/// Backup to a single `.tabiya` file (zip with JSON and PGN) and restore
/// with "replace" or "merge" (ТЗ 9.2). Tokens are never included.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../db/database.dart';

enum RestoreMode { replace, merge }

class BackupInfo {
  const BackupInfo({required this.createdAt, required this.appVersion, required this.schema, required this.counts});
  final DateTime createdAt;
  final String appVersion;
  final int schema;
  final Map<String, int> counts;
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What a restore brought in and what it found already on the device.
class RestoreSummary {
  const RestoreSummary({
    required this.repertoiresAdded,
    required this.repertoiresSkipped,
    required this.collectionsAdded,
    required this.collectionsSkipped,
  });
  final int repertoiresAdded;
  final int repertoiresSkipped;
  final int collectionsAdded;
  final int collectionsSkipped;

  int get added => repertoiresAdded + collectionsAdded;
  int get skipped => repertoiresSkipped + collectionsSkipped;
}

class BackupService {
  BackupService(this.db, {required this.appVersion});
  final AppDatabase db;
  final String appVersion;

  static const format = 'tabiya-backup';
  static const formatVersion = 1;

  Future<List<int>> export() => db.transaction(_exportSnapshot);

  Future<List<int>> _exportSnapshot() async {
    final collections = await db.select(db.collections).get();
    final games = await db.select(db.games).get();
    final repertoires = await db.select(db.repertoires).get();
    final positions = await db.select(db.repPositions).get();
    final moves = await db.select(db.repMoves).get();
    final cards = await db.select(db.cards).get();
    final logs = await db.select(db.reviewLogs).get();
    final accounts = await db.select(db.linkedAccounts).get();
    final imported = await db.select(db.importedGames).get();
    final settings = await db.select(db.settings).get();
    // The report itself is recomputed from the games; what the user chose
    // to hide in it is not, and would come back after a restore.
    final hiddenGaps = await (db.select(db.gapEvents)..where((e) => e.dismissed.equals(true))).get();

    final archive = Archive();
    void addJson(String name, Object data) {
      final bytes = utf8.encode(const JsonEncoder.withIndent(' ').convert(data));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final counts = {
      'collections': collections.length,
      'games': games.length,
      'repertoires': repertoires.length,
      'positions': positions.length,
      'moves': moves.length,
      'cards': cards.length,
      'reviewLogs': logs.length,
      'importedGames': imported.length,
    };
    addJson('manifest.json', {
      'format': format,
      'formatVersion': formatVersion,
      'schema': db.schemaVersion,
      'app': appVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'counts': counts,
    });
    // Games: JSON (used for restore) + one readable PGN file per collection.
    addJson('collections.json', [for (final c in collections) c.toJson()]);
    addJson('games.json', [for (final g in games) g.toJson()]);
    final byCollection = <int, List<GameRow>>{};
    for (final g in games) {
      (byCollection[g.collectionId] ??= []).add(g);
    }
    for (final e in byCollection.entries) {
      e.value.sort((a, b) => a.orderIdx.compareTo(b.orderIdx));
      final text = e.value.map((g) => g.pgn.trim()).join('\n\n');
      final bytes = utf8.encode('$text\n');
      archive.addFile(ArchiveFile('pgn/collection_${e.key}.pgn', bytes.length, bytes));
    }
    addJson('repertoires.json', [for (final r in repertoires) r.toJson()]);
    addJson('rep_positions.json', [for (final p in positions) p.toJson()]);
    addJson('rep_moves.json', [for (final m in moves) m.toJson()]);
    addJson('cards.json', [for (final c in cards) c.toJson()]);
    addJson('review_logs.json', [for (final l in logs) l.toJson()]);
    addJson('linked_accounts.json', [
      for (final a in accounts) {...a.toJson(), 'tokenRef': null},
    ]);
    addJson('imported_games.json', [for (final g in imported) g.toJson()]);
    addJson('settings.json', [for (final s in settings) s.toJson()]);
    addJson('gap_events.json', [for (final e in hiddenGaps) e.toJson()]);
    return ZipEncoder().encode(archive);
  }

  Archive _open(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException('Not a Repertorium chess backup');
    }
  }

  Object? _json(Archive a, String name) {
    final f = a.findFile(name);
    if (f == null) return null;
    return jsonDecode(utf8.decode(f.content));
  }

  List<Map<String, Object?>> _list(Archive a, String name) {
    final data = _json(a, name);
    if (data is! List) throw const BackupException('Not a Repertorium chess backup');
    return [for (final e in data) (e as Map).cast<String, Object?>()];
  }

  BackupInfo inspect(List<int> bytes) {
    try {
      final a = _open(bytes);
      final m = (_json(a, 'manifest.json') as Map?)?.cast<String, Object?>();
      if (m == null ||
          m['format'] != format ||
          m['formatVersion'] != formatVersion ||
          m['schema'] is! int ||
          (m['schema']! as int) < 1) {
        throw const BackupException('Not a Repertorium chess backup');
      }
      if ((m['schema']! as int) > db.schemaVersion) {
        throw const BackupException('Backup is from a newer app version');
      }
      final counts = (m['counts'] as Map).map((k, v) => MapEntry(k as String, v as int));
      if (counts.values.any((v) => v < 0)) throw const BackupException('Not a Repertorium chess backup');
      final info = BackupInfo(
        createdAt: DateTime.parse(m['createdAt'] as String),
        appVersion: m['app'] as String? ?? '',
        schema: m['schema']! as int,
        counts: counts,
      );
      _validatePayload(a, counts);
      return info;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException('Not a Repertorium chess backup');
    }
  }

  /// Decode every required table and validate references before any deletion.
  /// Missing tables are corruption, even when their expected count is zero.
  void _validatePayload(Archive a, Map<String, int> counts) {
    void require(bool condition) {
      if (!condition) throw const BackupException('Not a Repertorium chess backup');
    }

    final names = <String>{};
    for (final file in a.files) {
      require(names.add(file.name));
    }
    List<T> rows<T>(String file, T Function(Map<String, dynamic>) parse, [String? count]) {
      final raw = _list(a, file);
      if (count != null) require(counts[count] == raw.length);
      return [for (final row in raw) parse(row)];
    }

    Set<T> unique<T>(Iterable<T> values) {
      final result = <T>{};
      for (final value in values) {
        require(result.add(value));
      }
      return result;
    }

    final collections = rows('collections.json', CollectionRow.fromJson, 'collections');
    final games = rows('games.json', GameRow.fromJson, 'games');
    final reps = rows('repertoires.json', RepertoireRow.fromJson, 'repertoires');
    final positions = rows('rep_positions.json', RepPositionRow.fromJson, 'positions');
    final moves = rows('rep_moves.json', RepMoveRow.fromJson, 'moves');
    final cards = rows('cards.json', CardRow.fromJson, 'cards');
    final logs = rows('review_logs.json', ReviewLogRow.fromJson, 'reviewLogs');
    final imported = rows('imported_games.json', ImportedGameRow.fromJson, 'importedGames');
    final accounts = rows('linked_accounts.json', LinkedAccountRow.fromJson);
    final settings = rows('settings.json', SettingRow.fromJson);
    final colIds = unique(collections.map((r) => r.id));
    final repIds = unique(reps.map((r) => r.id));
    final positionIds = unique(positions.map((r) => (r.repertoireId, r.positionKey)));
    unique(games.map((r) => r.id));
    unique(moves.map((r) => (r.repertoireId, r.fromKey, r.uci)));
    unique(cards.map((r) => (r.repertoireId, r.positionKey)));
    unique(logs.map((r) => r.id));
    unique(imported.map((r) => r.id));
    unique(imported.map((r) => (r.provider, r.externalId)));
    unique(accounts.map((r) => r.provider));
    unique(settings.map((r) => r.key));
    require(games.every((r) => colIds.contains(r.collectionId)));
    require(positions.every((r) => repIds.contains(r.repertoireId)));
    require(reps.every((r) => positionIds.contains((r.id, r.rootKey))));
    require(
      moves.every(
        (r) => positionIds.contains((r.repertoireId, r.fromKey)) && positionIds.contains((r.repertoireId, r.toKey)),
      ),
    );
    require(cards.every((r) => positionIds.contains((r.repertoireId, r.positionKey))));
    // Historical reviews may refer to a position that has since been removed.
    require(logs.every((r) => repIds.contains(r.repertoireId)));
  }

  static String _pgnKey(String pgn) => pgn.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Restores a backup. In [RestoreMode.merge] what is not on the device
  /// yet is added with new ids; a repertoire or a collection that is
  /// already here with the same content is left alone, with its training
  /// history (D-056). Settings are kept.
  Future<RestoreSummary> restore(List<int> bytes, RestoreMode mode) async {
    final info = inspect(bytes);
    if (info.schema > db.schemaVersion) {
      throw const BackupException('Backup is from a newer app version');
    }
    final a = _open(bytes);
    final collections = _list(a, 'collections.json');
    final games = _list(a, 'games.json');
    final repertoires = _list(a, 'repertoires.json');
    final positions = _list(a, 'rep_positions.json');
    final moves = _list(a, 'rep_moves.json');
    final cards = _list(a, 'cards.json');
    final logs = _list(a, 'review_logs.json');
    final accounts = _list(a, 'linked_accounts.json');
    final imported = _list(a, 'imported_games.json');
    final settings = _list(a, 'settings.json');
    // Absent in backups made before 1.0.2.
    final hiddenGaps = a.findFile('gap_events.json') == null
        ? const <Map<String, Object?>>[]
        : _list(a, 'gap_events.json');

    // Merge: find what the device already has.
    final skipCols = <int>{};
    final skipReps = <int>{};
    if (mode == RestoreMode.merge) {
      final have = <String, List<Set<String>>>{};
      for (final c in await db.select(db.collections).get()) {
        final q = db.selectOnly(db.games)
          ..addColumns([db.games.pgn])
          ..where(db.games.collectionId.equals(c.id));
        (have[c.name] ??= []).add({for (final r in await q.get()) _pgnKey(r.read(db.games.pgn)!)});
      }
      final incoming = <int, Set<String>>{};
      for (final g in games) {
        final row = GameRow.fromJson(g);
        (incoming[row.collectionId] ??= {}).add(_pgnKey(row.pgn));
      }
      for (final c in collections) {
        final row = CollectionRow.fromJson(c);
        final mine = incoming[row.id] ?? const <String>{};
        if ((have[row.name] ?? const []).any((set) => set.containsAll(mine))) skipCols.add(row.id);
      }
      String sig(String name, String color, String rootKey) => '$name|$color|$rootKey';
      final haveReps = <String, List<Set<String>>>{};
      for (final r in await db.select(db.repertoires).get()) {
        final ms = await (db.select(db.repMoves)..where((m) => m.repertoireId.equals(r.id))).get();
        (haveReps[sig(r.name, r.color, r.rootKey)] ??= []).add({for (final m in ms) '${m.fromKey}|${m.uci}'});
      }
      final incomingMoves = <int, Set<String>>{};
      for (final m in moves) {
        final row = RepMoveRow.fromJson(m);
        (incomingMoves[row.repertoireId] ??= {}).add('${row.fromKey}|${row.uci}');
      }
      for (final r in repertoires) {
        final row = RepertoireRow.fromJson(r);
        final mine = incomingMoves[row.id] ?? const <String>{};
        if ((haveReps[sig(row.name, row.color, row.rootKey)] ?? const []).any((set) => set.containsAll(mine))) {
          skipReps.add(row.id);
        }
      }
    }
    final summary = RestoreSummary(
      repertoiresAdded: repertoires.length - skipReps.length,
      repertoiresSkipped: skipReps.length,
      collectionsAdded: collections.length - skipCols.length,
      collectionsSkipped: skipCols.length,
    );

    await db.transaction(() async {
      if (mode == RestoreMode.replace) {
        for (final t in <TableInfo<Table, Object?>>[
          db.gapEvents,
          db.reviewLogs,
          db.cards,
          db.repMoves,
          db.repPositions,
          db.repertoires,
          db.games,
          db.collections,
          db.importedGames,
          db.httpCache,
          db.explorerCache,
          db.linkedAccounts,
          db.settings,
        ]) {
          await db.delete(t).go();
        }
      }
      final colMap = <int, int>{};
      for (final c in collections) {
        final row = CollectionRow.fromJson(c);
        if (skipCols.contains(row.id)) continue;
        final id = mode == RestoreMode.replace
            ? await db.into(db.collections).insert(row)
            : await db.into(db.collections).insert(row.toCompanion(false).copyWith(id: const Value.absent()));
        colMap[row.id] = id;
      }
      await db.batch((b) {
        for (final g in games) {
          final row = GameRow.fromJson(g);
          if (skipCols.contains(row.collectionId)) continue;
          final comp = row
              .toCompanion(false)
              .copyWith(
                collectionId: Value(colMap[row.collectionId] ?? row.collectionId),
                id: mode == RestoreMode.replace ? Value(row.id) : const Value.absent(),
              );
          b.insert(db.games, comp);
        }
      });
      final repMap = <int, int>{};
      for (final r in repertoires) {
        final row = RepertoireRow.fromJson(r);
        if (skipReps.contains(row.id)) continue;
        final id = mode == RestoreMode.replace
            ? await db.into(db.repertoires).insert(row)
            : await db.into(db.repertoires).insert(row.toCompanion(false).copyWith(id: const Value.absent()));
        repMap[row.id] = id;
      }
      int rid(int old) => repMap[old] ?? old;
      await db.batch((b) {
        for (final p in positions) {
          final row = RepPositionRow.fromJson(p);
          if (skipReps.contains(row.repertoireId)) continue;
          b.insert(
            db.repPositions,
            row.copyWith(repertoireId: rid(row.repertoireId)),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final m in moves) {
          final row = RepMoveRow.fromJson(m);
          if (skipReps.contains(row.repertoireId)) continue;
          b.insert(db.repMoves, row.copyWith(repertoireId: rid(row.repertoireId)), mode: InsertMode.insertOrReplace);
        }
        for (final c in cards) {
          final row = CardRow.fromJson(c);
          if (skipReps.contains(row.repertoireId)) continue;
          b.insert(db.cards, row.copyWith(repertoireId: rid(row.repertoireId)), mode: InsertMode.insertOrReplace);
        }
        for (final l in logs) {
          final row = ReviewLogRow.fromJson(l);
          if (skipReps.contains(row.repertoireId)) continue;
          b.insert(
            db.reviewLogs,
            row
                .toCompanion(false)
                .copyWith(
                  repertoireId: Value(rid(row.repertoireId)),
                  id: mode == RestoreMode.replace ? Value(row.id) : const Value.absent(),
                ),
          );
        }
        for (final g in imported) {
          final row = ImportedGameRow.fromJson(g);
          b.insert(
            db.importedGames,
            row.toCompanion(false).copyWith(id: mode == RestoreMode.replace ? Value(row.id) : const Value.absent()),
            mode: InsertMode.insertOrIgnore,
          );
        }
        for (final acc in accounts) {
          final row = LinkedAccountRow.fromJson(acc);
          // Lichess needs a new login: the token is not in the backup.
          b.insert(
            db.linkedAccounts,
            row.copyWith(tokenRef: const Value(null), scopes: row.provider == 'lichess' ? '' : row.scopes),
            mode: mode == RestoreMode.replace ? InsertMode.insertOrReplace : InsertMode.insertOrIgnore,
          );
        }
        if (mode == RestoreMode.replace) {
          for (final s in settings) {
            b.insert(db.settings, SettingRow.fromJson(s), mode: InsertMode.insertOrReplace);
          }
          // Ids are kept in this mode, so the hidden events still point
          // at their game and repertoire.
          for (final e in hiddenGaps) {
            b.insert(db.gapEvents, GapEventRow.fromJson(e), mode: InsertMode.insertOrIgnore);
          }
        }
      });
    });
    return summary;
  }
}
