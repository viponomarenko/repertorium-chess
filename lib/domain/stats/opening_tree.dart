/// Opening statistics of the user's own games (Lichess, Chess.com): which
/// moves and variations occur how often and how they score (D-048).
library;

import 'package:dartchess/dartchess.dart';

import '../chess/chess_utils.dart';
import '../repertoire/repertoire_graph.dart';

/// GameOutcome of a game for the user.
enum GameOutcome { win, draw, loss, unknown }

GameOutcome outcomeFor(String result, Side userColor) => switch (result) {
  '1-0' => userColor == Side.white ? GameOutcome.win : GameOutcome.loss,
  '0-1' => userColor == Side.black ? GameOutcome.win : GameOutcome.loss,
  '1/2-1/2' => GameOutcome.draw,
  _ => GameOutcome.unknown,
};

/// One game reduced to what the statistics need.
class TreeGame {
  const TreeGame({required this.id, required this.userColor, required this.outcome, required this.plies});
  final int id;
  final Side userColor;
  final GameOutcome outcome;

  /// The first moves as standard UCI, from the initial position.
  final List<String> plies;
}

/// Games, wins, draws and losses (the user's point of view).
class Score {
  int games = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;

  void add(GameOutcome o) {
    games++;
    switch (o) {
      case GameOutcome.win:
        wins++;
      case GameOutcome.draw:
        draws++;
      case GameOutcome.loss:
        losses++;
      case GameOutcome.unknown:
        break;
    }
  }

  /// Points per game (1 a win, ½ a draw), 0..1; null without results.
  double? get points {
    final n = wins + draws + losses;
    return n == 0 ? null : (wins + draws / 2) / n;
  }
}

class MoveStat {
  MoveStat(this.uci, this.san, this.toKey);
  final String uci;
  final String san;
  final PositionKey toKey;
  final Score score = Score();

  /// Games (ids) that played this move here.
  final List<int> gameIds = [];
}

class PositionStat {
  PositionStat(this.fen);
  final String fen;
  final Score score = Score();
  final Map<String, MoveStat> moves = {};

  /// Moves by how often they were played.
  List<MoveStat> get sortedMoves => moves.values.toList()..sort((a, b) => b.score.games.compareTo(a.score.games));
}

/// A frequent variation: the first moves shared by a group of games.
class VariationStat {
  VariationStat(this.ucis, this.sans, this.endKey, this.endFen);
  final List<String> ucis;
  final List<String> sans;
  final PositionKey endKey;
  final String endFen;
  final Score score = Score();
  final List<int> gameIds = [];
}

/// Where a line leaves a repertoire.
class RepertoireFit {
  const RepertoireFit({required this.inBook, this.leftAtPly, this.userLeft = false});

  /// The whole line is in the repertoire.
  final bool inBook;

  /// 1-based ply of the first move not in the repertoire.
  final int? leftAtPly;

  /// The user (not the opponent) left the repertoire.
  final bool userLeft;
}

/// The tree of positions the games went through (transpositions merge: a
/// position is counted once per game however it was reached).
class OpeningTree {
  OpeningTree._(this.games, this.positions, this.rootKey);

  /// Builds the tree over the first [maxPlies] moves of [games].
  factory OpeningTree.build(List<TreeGame> games, {int maxPlies = 30}) {
    final positions = <PositionKey, PositionStat>{};
    final rootKey = positionKeyOf(Chess.initial);
    for (final g in games) {
      Position pos = Chess.initial;
      var key = rootKey;
      final seen = <PositionKey>{};
      for (var i = 0; i <= g.plies.length && i <= maxPlies; i++) {
        final stat = positions.putIfAbsent(key, () => PositionStat(pos.fen));
        if (!seen.add(key)) break; // a repetition: counted once
        stat.score.add(g.outcome);
        if (i == g.plies.length || i == maxPlies) break;
        final m = parseUciMove(pos, g.plies[i]);
        if (m == null) break;
        final (next, san) = pos.makeSan(m);
        final nextKey = positionKeyOf(next);
        final ms = stat.moves.putIfAbsent(g.plies[i], () => MoveStat(g.plies[i], san, nextKey));
        ms.score.add(g.outcome);
        ms.gameIds.add(g.id);
        pos = next;
        key = nextKey;
      }
    }
    return OpeningTree._(games, positions, rootKey);
  }

  final List<TreeGame> games;
  final Map<PositionKey, PositionStat> positions;
  final PositionKey rootKey;

  int get totalGames => games.length;

  PositionStat? at(PositionKey key) => positions[key];

  /// The most frequent variations: games grouped by their first [plies]
  /// moves (shorter games by all their moves), most common first.
  List<VariationStat> topVariations({required int plies, int limit = 40}) {
    final groups = <String, VariationStat>{};
    for (final g in games) {
      final line = g.plies.take(plies).toList();
      if (line.isEmpty) continue;
      final id = line.join(' ');
      var v = groups[id];
      if (v == null) {
        Position pos = Chess.initial;
        final sans = <String>[];
        final ucis = <String>[];
        for (final u in line) {
          final m = parseUciMove(pos, u);
          if (m == null) break;
          final (next, san) = pos.makeSan(m);
          sans.add(san);
          ucis.add(u);
          pos = next;
        }
        v = groups[id] = VariationStat(ucis, sans, positionKeyOf(pos), pos.fen);
      }
      v.score.add(g.outcome);
      v.gameIds.add(g.id);
    }
    final list = groups.values.toList()..sort((a, b) => b.score.games.compareTo(a.score.games));
    return list.take(limit).toList();
  }
}

/// How [ucis] (from the initial position) follows [graph]: where it leaves
/// it and who left it. Transpositions into known positions count as in.
RepertoireFit fitRepertoire(RepertoireGraph graph, List<String> ucis) {
  Position pos = Chess.initial;
  var key = positionKeyOf(pos);
  // A repertoire from a later position: follow the line until it starts.
  var i = 0;
  while (key != graph.rootKey && i < ucis.length) {
    final m = parseUciMove(pos, ucis[i]);
    if (m == null) return const RepertoireFit(inBook: false);
    pos = pos.play(m);
    key = positionKeyOf(pos);
    i++;
  }
  if (key != graph.rootKey) return const RepertoireFit(inBook: false);
  for (; i < ucis.length; i++) {
    final m = parseUciMove(pos, ucis[i]);
    if (m == null) break;
    final userTurn = pos.turn == graph.color;
    final next = pos.play(m);
    final nextKey = positionKeyOf(next);
    final inGraph = graph.move(key, standardUci(pos, m)) != null || graph.positions.containsKey(nextKey);
    if (!inGraph) return RepertoireFit(inBook: false, leftAtPly: i + 1, userLeft: userTurn);
    pos = next;
    key = nextKey;
  }
  return const RepertoireFit(inBook: true);
}

/// The first moves of a PGN's main line as standard UCI, without a full
/// parse (comments, clocks, NAGs and variations skipped): fast enough for
/// thousands of downloaded games.
List<String> firstPlies(String pgn, {int max = 30}) {
  // Not standard chess from the usual start: no opening to speak of.
  if (_notStandardRe.hasMatch(pgn)) return const [];
  // Movetext only: drop the header lines.
  final body = pgn.split('\n').where((l) => !l.trimLeft().startsWith('[')).join(' ');
  final out = <String>[];
  Position pos = Chess.initial;
  var depthComment = 0, depthVariation = 0;
  for (final raw
      in body
          .replaceAll('{', ' { ')
          .replaceAll('}', ' } ')
          .replaceAll('(', ' ( ')
          .replaceAll(')', ' ) ')
          .split(RegExp(r'\s+'))) {
    if (raw.isEmpty) continue;
    if (raw == '{') {
      depthComment++;
      continue;
    }
    if (raw == '}') {
      depthComment = depthComment > 0 ? depthComment - 1 : 0;
      continue;
    }
    if (depthComment > 0) continue;
    if (raw == '(') {
      depthVariation++;
      continue;
    }
    if (raw == ')') {
      depthVariation = depthVariation > 0 ? depthVariation - 1 : 0;
      continue;
    }
    if (depthVariation > 0 || raw.startsWith(r'$')) continue;
    if (raw == '1-0' || raw == '0-1' || raw == '1/2-1/2' || raw == '*') break;
    final san = raw.replaceFirst(RegExp(r'^\d+\.+'), '').replaceAll(RegExp(r'[!?]+$'), '');
    if (san.isEmpty) continue;
    final m = pos.parseSan(san);
    if (m == null) break;
    out.add(standardUci(pos, m));
    pos = pos.play(m);
    if (out.length >= max) break;
  }
  return out;
}

/// A variant other than standard chess, or a game from a set-up position.
final _notStandardRe = RegExp(r'\[Variant "(?!Standard"|Chess"|Normal")[^"]*"\]|\[FEN "', caseSensitive: false);
