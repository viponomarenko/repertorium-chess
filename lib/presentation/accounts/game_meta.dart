import 'dart:isolate';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/chess/chess_utils.dart';
import '../../domain/openings/opening_book.dart';
import '../../domain/stats/opening_tree.dart';
import '../app/providers.dart';
import '../stats/my_openings_providers.dart';
import 'accounts_providers.dart';

/// What a row of "My games" shows besides the stored columns: the opening
/// (from the catalogue, by position, so transpositions are named right)
/// and the opponent's rating (from the PGN headers).
class GameMeta {
  const GameMeta({this.opening, this.opponentElo});
  final String? opening;
  final int? opponentElo;
}

/// Meta of every downloaded game by its id. Only games not seen before are
/// parsed (a comparison or a download re-emits the whole list), many of
/// them off the UI thread.
final gameMetaProvider = FutureProvider<Map<int, GameMeta>>((ref) async {
  final rows = await ref.watch(importedGamesProvider.future);
  // Ratings do not wait for the catalogue: the openings follow when it is read.
  final book = ref.watch(openingBookProvider).value;
  final cache = book == null ? <int, GameMeta>{} : _metaCache;
  final input = [
    for (final g in rows)
      if (!cache.containsKey(g.id)) (g.id, g.userColor, g.pgn),
  ];
  final fresh = input.length < 100
      ? gameMeta(input, book ?? OpeningBook.empty)
      : await _gameMetaInIsolate(input, book ?? OpeningBook.empty);
  cache.addAll(fresh);
  return {for (final g in rows) g.id: ?cache[g.id]};
});

/// Meta computed with the catalogue, kept for the life of the app.
final _metaCache = <int, GameMeta>{};

/// Where each compared game left the repertoire: game id -> (ply, move).
final gameExitsProvider = StreamProvider<Map<int, (int, String)>>(
  (ref) => ref.watch(gapServiceProvider).watchGameExits(),
);

/// Top-level, so the closure sent to the isolate holds only the games and
/// the catalogue, never the provider's ref.
Future<Map<int, GameMeta>> _gameMetaInIsolate(List<(int, String, String)> games, OpeningBook book) =>
    Isolate.run(() => gameMeta(games, book));

final _eloRe = RegExp(r'\[(White|Black)Elo "(\d+)"\]');

/// The meta of [games] (id, the user's colour, PGN).
Map<int, GameMeta> gameMeta(List<(int, String, String)> games, OpeningBook book) {
  final out = <int, GameMeta>{};
  for (final (id, userColor, pgn) in games) {
    int? elo;
    final opponent = userColor == 'white' ? 'Black' : 'White';
    for (final m in _eloRe.allMatches(pgn)) {
      if (m.group(1) == opponent) elo = int.tryParse(m.group(2)!);
    }
    Position pos = Chess.initial;
    final keys = <PositionKey>[];
    for (final uci in firstPlies(pgn)) {
      final move = parseUciMove(pos, uci);
      if (move == null) break;
      pos = pos.play(move);
      keys.add(positionKeyOf(pos));
    }
    out[id] = GameMeta(opening: book.deepest(keys)?.name, opponentElo: elo);
  }
  return out;
}
