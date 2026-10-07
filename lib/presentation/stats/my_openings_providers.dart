import 'dart:isolate';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../domain/stats/opening_tree.dart';
import '../accounts/accounts_providers.dart';

/// Which of the user's games the statistics cover.
class MyGamesFilter {
  const MyGamesFilter({this.color, this.provider, this.days});

  /// The user's colour; null: both (the explorer panel).
  final Side? color;

  /// lichess | chesscom; null: all.
  final String? provider;

  /// Only the last [days] days; null: all time.
  final int? days;

  MyGamesFilter copyWith({
    Side? color,
    String? provider,
    bool clearProvider = false,
    int? days,
    bool clearDays = false,
  }) => MyGamesFilter(
    color: color ?? this.color,
    provider: clearProvider ? null : (provider ?? this.provider),
    days: clearDays ? null : (days ?? this.days),
  );

  bool accepts(ImportedGameRow g, DateTime now) =>
      (color == null || g.userColor == color!.name) &&
      (provider == null || g.provider == provider) &&
      (days == null || now.difference(g.playedAt).inDays <= days!);

  @override
  bool operator ==(Object other) =>
      other is MyGamesFilter && other.color == color && other.provider == provider && other.days == days;

  @override
  int get hashCode => Object.hash(color, provider, days);
}

final importedGamesProvider = StreamProvider<List<ImportedGameRow>>(
  (ref) => ref.watch(accountsServiceProvider).watchImportedGames(),
);

/// The opening tree of the user's games; rebuilt when games are downloaded.
/// Many games are parsed off the UI thread.
final myOpeningTreeProvider = FutureProvider.autoDispose.family<OpeningTree, MyGamesFilter>((ref, f) async {
  final rows = await ref.watch(importedGamesProvider.future);
  final now = DateTime.now();
  final input = [
    for (final g in rows)
      if (f.accepts(g, now)) (g.id, g.userColor, g.result, g.pgn),
  ];
  return input.length < 300 ? _buildTree(input) : _buildTreeInIsolate(input);
});

typedef _TreeInput = List<(int, String, String, String)>;

OpeningTree _buildTree(_TreeInput input) => OpeningTree.build([
  for (final (id, color, result, pgn) in input)
    // Variants and games from a set-up position have no plies here and
    // are left out (they used to count at the root as normal games).
    if (firstPlies(pgn) case final plies when plies.isNotEmpty)
      TreeGame(
        id: id,
        userColor: color == 'black' ? Side.black : Side.white,
        outcome: outcomeFor(result, color == 'black' ? Side.black : Side.white),
        plies: plies,
      ),
]);

/// Top-level, so the closure sent to the isolate holds only the games,
/// never the provider's ref.
Future<OpeningTree> _buildTreeInIsolate(_TreeInput input) => Isolate.run(() => _buildTree(input));
