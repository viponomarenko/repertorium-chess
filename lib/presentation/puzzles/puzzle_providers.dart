/// State shared by the puzzle screens (D-123, D-126).
library;

import 'dart:io' show gzip;
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/lichess/lichess_auth.dart';
import '../../data/puzzles/puzzle_repository.dart';
import '../../domain/puzzles/glicko2.dart';
import '../../domain/puzzles/puzzle_pack.dart';
import '../../domain/puzzles/puzzle_profile.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';

final puzzleRepositoryProvider = Provider<PuzzleRepository>((ref) => PuzzleRepository(ref.watch(databaseProvider)));

/// Read again whenever a screen opens: a restored backup brings its own.
final puzzleProfileProvider = FutureProvider.autoDispose<PuzzleProfile>(
  (ref) => ref.watch(puzzleRepositoryProvider).load(),
);

/// Sends results to Lichess; one for the app, so two screens never send
/// the same result twice.
final puzzleSyncProvider = Provider<PuzzleSync>(
  (ref) => PuzzleSync(ref.watch(lichessClientProvider), ref.watch(puzzleRepositoryProvider)),
);

/// Whether Lichess may be asked for puzzles, for every theme at once.
final puzzleNetworkProvider = Provider<PuzzleNetwork>((ref) => PuzzleNetwork());

/// The offline pack, unpacked off the UI thread once; null when missing.
final puzzlePackProvider = FutureProvider<PuzzlePack?>((ref) async {
  final ByteData data;
  try {
    data = await rootBundle.load('assets/puzzles/puzzles.tsv.gz');
  } catch (_) {
    return null;
  }
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  return Isolate.run(() {
    final text = String.fromCharCodes(gzip.decode(bytes));
    return PuzzlePack(text.split('\n').where((l) => l.isNotEmpty).toList());
  });
});

/// The connected Lichess account and whether its token may count puzzles
/// (`puzzle:write`); null without an account.
final puzzleAccountProvider = FutureProvider<PuzzleAccount?>((ref) async {
  // Rebuilt when the accounts change; read from the database itself, as a
  // provider nobody listens to is paused (Riverpod 3) and its stream would
  // never come when the puzzle screen only reads this once.
  ref.watch(linkedAccountsProvider);
  final acc = await ref.watch(accountsServiceProvider).account('lichess');
  if (acc == null || acc.scopes.isEmpty) return null;
  final scopes = acc.scopes.split(' ');
  return (user: acc.username.toLowerCase(), canWrite: LichessOAuth.puzzleScopes.every(scopes.contains));
});

/// The Lichess user puzzles count for, when the token allows it.
String? puzzleUser(PuzzleAccount? a) => a != null && a.canWrite ? a.user : null;

/// "1500?" while the rating is provisional; no thousands separator, as
/// ratings are written everywhere.
String puzzleRatingText(Glicko g) => '${g.rating.round()}${g.provisional ? '?' : ''}';

/// Asks Lichess again for `puzzle:read` and `puzzle:write` (and keeps
/// `study:write` when the account had it).
Future<void> reconnectForPuzzles(WidgetRef ref) async {
  final service = ref.read(accountsServiceProvider);
  final LinkedAccountRow? acc = await service.account('lichess');
  await service.connectLichess(withWrite: acc?.scopes.split(' ').contains('study:write') ?? false);
}
