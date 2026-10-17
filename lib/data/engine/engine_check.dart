import 'dart:convert';

import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import 'engine_service.dart';

/// The engine's verdict on the main move of a position (F-ENG-04): the
/// move it would play instead, how much the main move loses, and whether
/// the user decided to keep their own move (D-090).
class EngineFlag {
  const EngineFlag({
    required this.lossCp,
    required this.bestUci,
    required this.bestSan,
    required this.depth,
    this.mainUci = '',
    this.dismissed = false,
  });
  final int lossCp;
  final String bestUci;
  final String bestSan;
  final int depth;

  /// The main move the verdict is about (empty in flags saved before D-090).
  final String mainUci;

  /// The user kept their move: no longer a problem, and a new check does
  /// not raise it again while the main move and the engine's choice stay.
  final bool dismissed;

  bool get active => !dismissed;

  EngineFlag dismiss() =>
      EngineFlag(lossCp: lossCp, bestUci: bestUci, bestSan: bestSan, depth: depth, mainUci: mainUci, dismissed: true);

  String encode() => jsonEncode({
    'loss': lossCp,
    'best': bestUci,
    'bestSan': bestSan,
    'depth': depth,
    if (mainUci.isNotEmpty) 'main': mainUci,
    if (dismissed) 'dismissed': true,
  });

  static EngineFlag? decode(String s) {
    if (s.isEmpty) return null;
    try {
      final j = (jsonDecode(s) as Map).cast<String, Object?>();
      return EngineFlag(
        lossCp: (j['loss'] as num).toInt(),
        bestUci: j['best'] as String? ?? '',
        bestSan: j['bestSan'] as String? ?? '',
        depth: (j['depth'] as num?)?.toInt() ?? 0,
        mainUci: j['main'] as String? ?? '',
        dismissed: j['dismissed'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// An engine flag the user still has to decide about.
  static bool isActive(String s) => decode(s)?.active ?? false;
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
            final previous = EngineFlag.decode(pos.engineFlag);
            if (previous != null && previous.dismissed && previous.mainUci == main.uci && previous.bestUci == bestUci) {
              // Already answered "keep my move": stays answered.
              flag = pos.engineFlag;
            } else {
              flag = EngineFlag(
                lossCp: loss,
                bestUci: bestUci,
                bestSan: san,
                depth: before.depth,
                mainUci: main.uci,
              ).encode();
              flagged++;
            }
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
