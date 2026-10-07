import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/engine/engine_check.dart';
import 'package:tabiya/data/engine/engine_service.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';

class CheckEngine implements EngineService {
  final calls = <Completer<EngineEval>>[];
  @override
  String get name => 'test';
  @override
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1}) {
    final c = Completer<EngineEval>();
    calls.add(c);
    return c.future;
  }

  @override
  Stream<EngineEval> analyze(String fen, EngineOptions options) => throw UnimplementedError();
  @override
  Future<void> stop() async {}
  @override
  Future<void> shutdown() async {}
}

void main() {
  for (final cancelAfter in [1, 2]) {
    test('cancellation after evaluation $cancelAfter preserves existing flags', () async {
      final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
      g.addMove(Chess.initial, Chess.initial.parseSan('e4')!);
      g.positions[g.rootKey]!.engineFlag = 'existing';
      var cancelled = false;
      final engine = CheckEngine();
      final result = checkRepertoire(g, engine, cancelled: () => cancelled).toList();
      final assertion = expectLater(result, throwsA(isA<EngineCancelled>()));
      await Future<void>.delayed(Duration.zero);
      cancelled = cancelAfter == 1;
      engine.calls.first.complete(
        const EngineEval(
          fen: kInitialFen,
          depth: 14,
          lines: [
            PvLine(multipv: 1, moves: ['d2d4'], cp: 100),
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      if (cancelAfter == 2) {
        cancelled = true;
        engine.calls.last.complete(
          const EngineEval(
            fen: kInitialFen,
            depth: 13,
            lines: [
              PvLine(multipv: 1, moves: ['e7e5'], cp: -100),
            ],
          ),
        );
      }
      await assertion;
      expect(engine.calls, hasLength(cancelAfter));
      expect(g.positions[g.rootKey]!.engineFlag, 'existing');
    });
  }
}
