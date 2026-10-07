/// Opponent move selection (ТЗ 5.3) and subtree aggregates over the DAG.
library;

import 'dart:math' as math;

import '../chess/chess_utils.dart';
import '../repertoire/repertoire_graph.dart';
import '../srs/fsrs.dart';

enum OpponentStrategy {
  /// Toward the most overdue card (default in Review).
  dueFirst,

  /// Random, proportional to the move weight.
  weighted,

  /// Uniformly random.
  uniform,

  /// Toward the least learned subtree.
  leastLearned;

  static OpponentStrategy fromName(String? n) =>
      OpponentStrategy.values.firstWhere((s) => s.name == n, orElse: () => OpponentStrategy.dueFirst);
}

/// Aggregated information about everything reachable from a position.
class SubtreeInfo {
  const SubtreeInfo({
    this.maxOverdueDays,
    this.hasDue = false,
    this.hasNew = false,
    this.minStability = double.infinity,
    this.trainableCount = 0,
  });

  /// Largest overdue amount (days) among due cards; null if none is due.
  final double? maxOverdueDays;
  final bool hasDue;
  final bool hasNew;

  /// Weakest (lowest) stability of a card; new cards count as 0.
  final double minStability;

  /// Approximate count (shared subtrees may be counted more than once).
  final int trainableCount;
}

/// Computes [SubtreeInfo] for every position reachable from [from].
///
/// [isDue] and [isNew] decide per position; positions in [exclude] are
/// treated as not due / not new (e.g. already reviewed in this session).
Map<PositionKey, SubtreeInfo> computeSubtreeInfo(
  RepertoireGraph graph,
  Fsrs fsrs,
  DateTime now, {
  required PositionKey from,
  bool Function(PositionKey key)? isDue,
  bool Function(PositionKey key)? isNew,
}) {
  final memo = <PositionKey, SubtreeInfo>{};
  bool due(PositionKey k) {
    if (isDue != null) return isDue(k);
    final c = graph.cards[k];
    return c != null && graph.isTrainable(k) && fsrs.isDue(c.srs, now);
  }

  bool fresh(PositionKey k) {
    if (isNew != null) return isNew(k);
    final c = graph.cards[k];
    return c != null && graph.isTrainable(k) && c.srs.isNew;
  }

  // Iterative post-order DFS (repertoires can be deep).
  final stack = <(PositionKey, bool)>[(from, false)];
  final onStack = <PositionKey>{};
  while (stack.isNotEmpty) {
    final (k, expanded) = stack.removeLast();
    if (memo.containsKey(k)) continue;
    if (!expanded) {
      if (!onStack.add(k)) continue; // defensive: cycle
      stack.add((k, true));
      for (final m in graph.movesFrom(k)) {
        if (!memo.containsKey(m.toKey)) stack.add((m.toKey, false));
      }
      continue;
    }
    onStack.remove(k);
    double? maxOver;
    var hasDue = false;
    var hasNew = false;
    var minStab = double.infinity;
    var count = 0;
    final c = graph.cards[k];
    if (c != null && graph.isTrainable(k)) {
      count = 1;
      if (due(k)) {
        hasDue = true;
        maxOver = fsrs.overdueDays(c.srs, now) ?? 0;
      }
      if (fresh(k)) hasNew = true;
      minStab = c.srs.isNew ? 0 : c.srs.stability;
    }
    for (final m in graph.movesFrom(k)) {
      final child = memo[m.toKey];
      if (child == null) continue;
      if (child.hasDue) {
        hasDue = true;
        maxOver = math.max(maxOver ?? double.negativeInfinity, child.maxOverdueDays ?? 0);
      }
      hasNew = hasNew || child.hasNew;
      minStab = math.min(minStab, child.minStability);
      count += child.trainableCount;
    }
    memo[k] = SubtreeInfo(
      maxOverdueDays: maxOver,
      hasDue: hasDue,
      hasNew: hasNew,
      minStability: minStab,
      trainableCount: count,
    );
  }
  return memo;
}

/// Picks one of [candidates] (opponent moves) according to [strategy].
RepMove? chooseOpponentMove(
  List<RepMove> candidates,
  OpponentStrategy strategy,
  Map<PositionKey, SubtreeInfo> info,
  math.Random random,
) {
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first;
  switch (strategy) {
    case OpponentStrategy.dueFirst:
      RepMove? best;
      double? bestOver;
      var tie = <RepMove>[];
      for (final m in candidates) {
        final o = info[m.toKey]?.maxOverdueDays;
        if (o == null) continue;
        if (bestOver == null || o > bestOver + 1e-9) {
          bestOver = o;
          best = m;
          tie = [m];
        } else if ((o - bestOver).abs() <= 1e-9) {
          tie.add(m);
        }
      }
      if (best == null) return _weighted(candidates, random);
      return tie.length > 1 ? _weighted(tie, random) : best;
    case OpponentStrategy.weighted:
      return _weighted(candidates, random);
    case OpponentStrategy.uniform:
      return candidates[random.nextInt(candidates.length)];
    case OpponentStrategy.leastLearned:
      var best = <RepMove>[];
      var bestStab = double.infinity;
      for (final m in candidates) {
        final s = info[m.toKey]?.minStability ?? double.infinity;
        if (s < bestStab - 1e-9) {
          bestStab = s;
          best = [m];
        } else if ((s - bestStab).abs() <= 1e-9) {
          best.add(m);
        }
      }
      if (best.isEmpty) return _weighted(candidates, random);
      return best.length == 1 ? best.first : _weighted(best, random);
  }
}

RepMove _weighted(List<RepMove> moves, math.Random random) {
  final total = moves.fold<int>(0, (a, m) => a + math.max(0, m.weight));
  if (total <= 0) return moves[random.nextInt(moves.length)];
  var r = random.nextInt(total);
  for (final m in moves) {
    r -= math.max(0, m.weight);
    if (r < 0) return m;
  }
  return moves.last;
}
