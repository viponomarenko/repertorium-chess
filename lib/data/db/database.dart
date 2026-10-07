import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Collections,
    Games,
    Repertoires,
    RepPositions,
    RepMoves,
    Cards,
    ReviewLogs,
    LinkedAccounts,
    ImportedGames,
    GapEvents,
    ExplorerCache,
    HttpCache,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Increment on every schema change and add a step to [migration].
  /// Schema snapshots live in `drift_schemas/` (see README).
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (m, from, to) async {
      // Future migrations go here, step by step:
      // if (from < 2) { await m.addColumn(...); }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement('CREATE INDEX IF NOT EXISTS idx_games_collection ON games (collection_id, order_idx)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_rep_moves_to ON rep_moves (repertoire_id, to_key)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_cards_due ON cards (repertoire_id, due)');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_review_logs_pos ON review_logs (repertoire_id, position_key, timestamp)',
    );
    await customStatement('CREATE INDEX IF NOT EXISTS idx_review_logs_time ON review_logs (timestamp)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_imported_played ON imported_games (provider, played_at)');
    await customStatement('CREATE INDEX IF NOT EXISTS idx_gap_rep ON gap_events (repertoire_id, position_key)');
  }

  static QueryExecutor _openConnection() => driftDatabase(name: 'tabiya');
}
