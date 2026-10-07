import 'dart:convert';

import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import 'engine_service.dart';

class EngineFlag {
  const EngineFlag({required this.lossCp, required this.bestUci, required this.bestSan, required this.depth});
  final int lossCp;
  final String bestUci;
  final String bestSan;
  final int depth;

  String encode() => jsonEncode({'loss': lossCp, 'best': bestUci, 'bestSan': bestSan, 'depth': depth});

  static EngineFlag? decode(String s) {
    if (s.isEmpty) return null;
    try {
      final j = (jsonDecode(s) as Map).cast<String, Object?>();
      return EngineFlag(
        lossCp: (j['loss'] as num).toInt(),
        bestUci: j['best'] as String? ?? '',
        bestSan: j['bestSan'] as String? ?? '',
        depth: (j['depth'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class EngineCheckProgress {
  const EngineCheckProgress(this.done, this.total, this.flagged, {this.finished = false});
  final int done;
  final int total;
  final int flagged;
  final bool finished;
}

/// Checks the `main` moves of a repertoire with a limited depth; a move that
/// loses more than [thresholdCp] is flagged for review. Nothing else is
/// changed automatically (F-ENG-04).
Stream<EngineCheckProgress> checkRepertoire(
  RepertoireGraph g,
  EngineService engine, {
  int depth = 14,
  int thresholdCp = 80,
  bool Function()? cancelled,
}) async* {
  final positions = g.reachableFrom(g.rootKey).where((k) => g.isUserTurn(k) && g.mainMove(k) != null).toList();
  var flagged = 0;
  final userIsWhite = g.color.name == 'white';
  for (var i = 0; i < positions.length; i++) {
    if (cancelled?.call() ?? false) throw const EngineCancelled();
    final key = positions[i];
    final pos = g.positions[key]!;
    final main = g.mainMove(key)!;
    final before = await engine.evaluate(pos.fen, depth: depth);
    if (cancelled?.call() ?? false) throw const EngineCancelled();
    final best = before.best;
    String flag = '';
    if (best != null && best.moves.isNotEmpty) {
      final position = positionFromFen(pos.fen);
      final bestMove = parseUciMove(position, best.moves.first);
      final bestUci = bestMove == null ? best.moves.first : standardUci(position, bestMove);
      if (bestUci != main.uci) {
        final after = await engine.evaluate(g.positions[main.toKey]!.fen, depth: depth - 1);
        if (cancelled?.call() ?? false) throw const EngineCancelled();
        final afterScore = after.best?.score;
        if (afterScore != null) {
          final sign = userIsWhite ? 1 : -1;
          final loss = (best.score - afterScore) * sign;
          if (loss > thresholdCp) {
            final san = bestMove == null ? bestUci : position.makeSan(bestMove).$2;
            flag = EngineFlag(lossCp: loss, bestUci: bestUci, bestSan: san, depth: before.depth).encode();
            flagged++;
          }
        }
      }
    }
    if (pos.engineFlag != flag) {
      pos.engineFlag = flag;
      g.touchPosition(key);
    }
    yield EngineCheckProgress(i + 1, positions.length, flagged);
  }
  yield EngineCheckProgress(positions.length, positions.length, flagged, finished: true);
}
