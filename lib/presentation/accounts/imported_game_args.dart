import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/widgets.dart';

import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../game/game_screen.dart';
import 'game_meta.dart';
import 'my_games_screen.dart';

/// "1... Nc6" for the move at [ply] (1 – White's first move).
String plyMoveText(int ply, String san) => ply.isOdd ? '${(ply + 1) ~/ 2}. $san' : '${ply ~/ 2}... $san';

/// How a downloaded game opens: from the user's side, at the position where
/// it left the repertoire (the user sees the choice they had), with the
/// opponent and the result in the title, a link to the site and the
/// neighbouring games of [order] (D-099).
GameScreenArgs importedGameArgs(
  BuildContext context,
  ImportedGameRow g, {
  GameMeta? meta,
  (int, String)? exit,
  List<int> order = const [],
}) {
  final l = context.l10n;
  final outcome = switch (userOutcome(g)) {
    '+' => l.outcomeWin,
    '−' => l.outcomeLoss,
    '=' => l.outcomeDraw,
    _ => l.outcomeUnknown,
  };
  final elo = meta?.opponentElo;
  final opponent = g.opponent.isEmpty ? '?' : g.opponent;
  final facts = [
    outcome,
    if (exit != null) l.leftRepertoireAt(plyMoveText(exit.$1, exit.$2)) else timeControlText(g.timeControl, l),
  ].where((t) => t.isNotEmpty).join(' · ');
  return GameScreenArgs(
    pgn: g.pgn,
    orientation: g.userColor == 'black' ? Side.black : Side.white,
    initialPath: exit == null ? null : List.filled(exit.$1 - 1, 0),
    title: elo == null ? opponent : '$opponent $elo',
    subtitle: facts,
    sourceUrl: g.url.isEmpty ? null : g.url,
    sourceName: g.provider == 'lichess' ? 'Lichess' : 'Chess.com',
    importedId: g.id,
    importedOrder: order,
  );
}
