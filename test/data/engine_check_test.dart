import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/engine/engine_check.dart';
import 'package:tabiya/data/engine/engine_service.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/srs/fsrs.dart';

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

/// Prefers [best] at the start (+1.0) and judges every other position at
/// -1.0 for White: 1. e4 then loses two pawns' worth against [best].
class ScriptedEngine implements EngineService {
  ScriptedEngine(this.best);
  String best;
  @override
  String get name => 'scripted';
  @override
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1}) async => fen == kInitialFen
      ? EngineEval(
          fen: fen,
          depth: 14,
          lines: [
            PvLine(multipv: 1, moves: [best], cp: 100),
          ],
        )
      : EngineEval(
          fen: fen,
          depth: 13,
          lines: const [
            PvLine(multipv: 1, moves: ['e7e5'], cp: -100),
          ],
        );

  @override
  Stream<EngineEval> analyze(String fen, EngineOptions options) => throw UnimplementedError();
  @override
  Future<void> stop() async {}
  @override
  Future<void> shutdown() async {}
}

/// White repertoire 1. e4 e5, checked once: 1. e4 is flagged (D-090).
Future<RepertoireGraph> flaggedE4(ScriptedEngine engine) async {
  final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
  final e4 = Chess.initial.play(Chess.initial.parseSan('e4')!);
  g.addMove(Chess.initial, Chess.initial.parseSan('e4')!);
  g.addMove(e4, e4.parseSan('e5')!);
  g.cards[g.rootKey]!.srs = SrsState(reps: 3, state: CardState.review, due: DateTime(2030), stability: 9);
  await checkRepertoire(g, engine).toList();
  return g;
}

void main() {
  group('engine flags: the ways out (D-090)', () {
    test('the check flags the main move and remembers which move it judged', () async {
      final g = await flaggedE4(ScriptedEngine('d2d4'));
      final f = EngineFlag.decode(g.positions[g.rootKey]!.engineFlag)!;
      expect(f.active, isTrue);
      expect(f.bestSan, 'd4');
      expect(f.mainUci, 'e2e4');
    });

    test('keeping my move answers the flag; a new check does not raise it again', () async {
      final engine = ScriptedEngine('d2d4');
      final g = await flaggedE4(engine);
      final root = g.positions[g.rootKey]!;
      g.setEngineFlag(g.rootKey, EngineFlag.decode(root.engineFlag)!.dismiss().encode());
      expect(EngineFlag.isActive(root.engineFlag), isFalse);
      final last = (await checkRepertoire(g, engine).toList()).last;
      expect(last.flagged, 0);
      expect(EngineFlag.isActive(root.engineFlag), isFalse);
    });

    test('a kept move is flagged again when the engine finds a different move', () async {
      final engine = ScriptedEngine('d2d4');
      final g = await flaggedE4(engine);
      final root = g.positions[g.rootKey]!;
      g.setEngineFlag(g.rootKey, EngineFlag.decode(root.engineFlag)!.dismiss().encode());
      engine.best = 'c2c4';
      final last = (await checkRepertoire(g, engine).toList()).last;
      expect(last.flagged, 1);
      expect(EngineFlag.decode(root.engineFlag)!.bestSan, 'c4');
      expect(EngineFlag.isActive(root.engineFlag), isTrue);
    });

    test('taking the suggestion: the new move is main, the old one an alternative, the card starts over', () async {
      final g = await flaggedE4(ScriptedEngine('d2d4'));
      final r = g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.replaceMain);
      expect(g.mainMove(g.rootKey), r.move);
      final e4 = g.move(g.rootKey, 'e2e4')!;
      expect(e4.role, MoveRole.alternative);
      expect(g.movesFrom(e4.toKey), isNotEmpty, reason: 'the old line stays');
      expect(g.positions[g.rootKey]!.engineFlag, isEmpty);
      expect(g.cards[g.rootKey]!.srs.state, CardState.newCard);
      expect(g.checkInvariants(), isEmpty);
    });

    test('making another move main or deleting the judged move clears the flag', () async {
      final g = await flaggedE4(ScriptedEngine('d2d4'));
      final d4 = g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.asAlternative).move!;
      expect(g.positions[g.rootKey]!.engineFlag, isNotEmpty, reason: 'an alternative changes nothing');
      g.setRole(d4, MoveRole.main);
      expect(g.positions[g.rootKey]!.engineFlag, isEmpty);

      final g2 = await flaggedE4(ScriptedEngine('d2d4'));
      g2.deleteMove(g2.mainMove(g2.rootKey)!);
      expect(g2.positions[g2.rootKey]!.engineFlag, isEmpty);
    });
  });

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
