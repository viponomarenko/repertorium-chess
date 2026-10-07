import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/haptics.dart';
import '../../core/now.dart';
import '../../core/sound_service.dart';
import '../../data/db/database.dart';
import '../../data/import/pgn_import_service.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/openings/opening_book.dart';
import '../../domain/srs/fsrs.dart';

/// Overridden in main() with the opened database.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('databaseProvider'));

/// Overridden in main() with the settings loaded before the first frame.
final initialSettingsProvider = Provider<AppSettings>((ref) => const AppSettings());

final soundServiceProvider = Provider<SoundService>((ref) {
  final s = SoundService();
  ref.onDispose(s.dispose);
  return s;
});

class SettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'app';

  @override
  AppSettings build() {
    final s = ref.read(initialSettingsProvider);
    _apply(s);
    return s;
  }

  void _apply(AppSettings s) {
    final sound = ref.read(soundServiceProvider);
    sound.enabled = s.sound;
    sound.haptics = s.haptics;
    Haptics.enabled = s.haptics;
  }

  Future<void> update(AppSettings Function(AppSettings) f) async {
    final next = f(state);
    state = next;
    _apply(next);
    final db = ref.read(databaseProvider);
    await db
        .into(db.settings)
        .insertOnConflictUpdate(SettingsCompanion(key: const Value(_key), value: Value(next.encode())));
  }

  /// Replaces all settings (backup restore).
  Future<void> replace(AppSettings s) => update((_) => s);

  /// Re-reads settings from the database (after a restore).
  Future<void> reloadFromDb() async {
    final s = await load(ref.read(databaseProvider));
    state = s;
    _apply(s);
  }

  static Future<AppSettings> load(AppDatabase db) async {
    final row = await (db.select(db.settings)..where((t) => t.key.equals(_key))).getSingleOrNull();
    return row == null ? const AppSettings() : AppSettings.decode(row.value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

final fsrsProvider = Provider<Fsrs>((ref) {
  final retention = ref.watch(settingsProvider.select((s) => s.desiredRetention));
  return Fsrs(FsrsParams(desiredRetention: retention));
});

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) => LibraryRepository(ref.watch(databaseProvider)));

final repertoireRepositoryProvider = Provider<RepertoireRepository>(
  (ref) => RepertoireRepository(ref.watch(databaseProvider), fsrs: ref.watch(fsrsProvider)),
);

final openingBookProvider = FutureProvider<OpeningBook>((ref) async {
  final tsv = await rootBundle.loadString('assets/openings/openings.tsv');
  return OpeningBook.parseTsv(tsv);
});

/// Opening book as a sendable map for background parsing (ECO detection).
final openingMapProvider = Provider<Map<String, List<String>>>((ref) {
  final book = ref.watch(openingBookProvider).value;
  if (book == null) return const {};
  return {
    for (final o in book.all) o.key: [o.eco, o.name],
  };
});

final pgnImportServiceProvider = Provider<PgnImportService>(
  (ref) => PgnImportService(bookProvider: () => ref.read(openingMapProvider)),
);

final collectionsProvider = StreamProvider<List<CollectionSummary>>(
  (ref) => ref.watch(libraryRepositoryProvider).watchCollections(),
);

/// Bumped when the app resumes / after training to refresh due counts.
class RefreshTick extends Notifier<int> {
  @override
  int build() => 0;

  /// Safe to call late (after async work), even when the app is closing.
  void bump() {
    if (ref.mounted) state++;
  }
}

final refreshTickProvider = NotifierProvider<RefreshTick, int>(RefreshTick.new);

/// The repertoire lines were last added to (this session): adding several
/// lines from one file goes to the same place without choosing again.
class LastImportTarget extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int id) => state = id;
}

final lastImportTargetProvider = NotifierProvider<LastImportTarget, int?>(LastImportTarget.new);

final repertoiresProvider = StreamProvider<List<RepertoireSummary>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(repertoireRepositoryProvider).watchSummaries();
});

final streakProvider = FutureProvider<int>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(repertoireRepositoryProvider).streak();
});

/// Answers per day this week (oldest first, today last) for the goal chart.
final weekActivityProvider = FutureProvider<List<int>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(repertoireRepositoryProvider).answersPerDay();
});

/// Answers given today, every one of them in any mode: the daily goal
/// (F-STAT-04, D-058).
final todayCountProvider = FutureProvider<int>((ref) async {
  ref.watch(refreshTickProvider);
  final fsrs = ref.watch(fsrsProvider);
  final repo = ref.watch(repertoireRepositoryProvider);
  return repo.answersSince(fsrs.dayStart(appNow()));
});
