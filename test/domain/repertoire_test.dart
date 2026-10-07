import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_export.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

RepertoireGraph newRep(Side color) => RepertoireGraph(color: color, rootKey: kInitialKey, rootFen: kInitialFen);

Position play(List<String> sans, [Position? from]) {
  var pos = from ?? Chess.initial;
  for (final s in sans) {
    pos = pos.play(pos.parseSan(s)!);
  }
  return pos;
}

PositionKey keyAfter(List<String> sans) => positionKeyOf(play(sans));

void expectConsistent(RepertoireGraph g) => expect(g.checkInvariants(), isEmpty);

void main() {
  group('F-REP-02 builder', () {
    test('own moves default to main, cards created (INV-4)', () {
      final g = newRep(Side.white);
      addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      expect(g.mainMove(kInitialKey)!.san, 'e4');
      expect(g.movesFrom(keyAfter(['e4'])).single.role, MoveRole.opponent);
      expect(g.cards.keys.toSet(), {
        kInitialKey,
        keyAfter(['e4', 'e5']),
        keyAfter(['e4', 'e5', 'Nf3', 'Nc6']),
      });
      expectConsistent(g);
    });

    test('second own move asks, then replace or alternative', () {
      final g = newRep(Side.white);
      addSanLine(g, Chess.initial, ['e4']);
      final r = g.addMove(Chess.initial, Chess.initial.parseSan('d4')!);
      expect(r.outcome, AddMoveOutcome.needsDecision);
      expect(r.currentMain!.san, 'e4');
      expect(g.movesFrom(kInitialKey), hasLength(1));

      g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.asAlternative);
      expect(g.mainMove(kInitialKey)!.san, 'e4');
      g.addMove(Chess.initial, Chess.initial.parseSan('c4')!, policy: OwnMovePolicy.replaceMain);
      expect(g.mainMove(kInitialKey)!.san, 'c4');
      expect(g.alternatives(kInitialKey).map((m) => m.san).toSet(), {'e4', 'd4'});
      expectConsistent(g);
    });

    test('existing move is not duplicated', () {
      final g = newRep(Side.black);
      addSanLine(g, Chess.initial, ['e4', 'c5']);
      addSanLine(g, Chess.initial, ['e4', 'c5']);
      expect(g.moveCount, 2);
      expectConsistent(g);
    });
  });

  group('INV-3 transpositions (F-TRN-11)', () {
    test('two paths lead to one position and one card', () {
      final g = newRep(Side.black);
      addSanLine(g, Chess.initial, ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'd5']);
      addSanLine(g, Chess.initial, ['Nf3', 'Nf6', 'c4', 'e6', 'd4', 'd5']);
      final target = keyAfter(['d4', 'Nf6', 'c4', 'e6', 'Nf3']);
      expect(keyAfter(['Nf3', 'Nf6', 'c4', 'e6', 'd4']), target);
      expect(g.movesTo(target), hasLength(2));
      expect(g.movesFrom(target).single.san, 'd5');
      expect(g.cards.containsKey(target), isTrue);
      expectConsistent(g);
    });
  });

  group('INV-5 deletion', () {
    test('deleting a move removes unreachable positions and their cards', () {
      final g = newRep(Side.white);
      addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
      addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
      final e5 = g.move(keyAfter(['e4']), play(['e4']).parseSan('e5')!.uci)!;
      final plan = g.planDeleteMove(e5);
      expect(plan.positions, hasLength(4)); // after e5, Nf3, Nc6, Bb5
      expect(plan.cards, hasLength(2));
      g.applyDeletion(plan);
      expect(g.positions.containsKey(keyAfter(['e4', 'e5'])), isFalse);
      expect(g.positions.containsKey(keyAfter(['e4', 'c5'])), isTrue);
      expectConsistent(g);
    });

    test('transposed position survives if still reachable', () {
      final g = newRep(Side.black);
      addSanLine(g, Chess.initial, ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'd5']);
      addSanLine(g, Chess.initial, ['Nf3', 'Nf6', 'c4', 'e6', 'd4', 'd5']);
      final nf3 = g.move(kInitialKey, 'g1f3')!;
      final plan = g.planDeleteMove(nf3);
      // Only the positions unique to the 1.Nf3 path are removed.
      expect(plan.positions.contains(keyAfter(['d4', 'Nf6', 'c4', 'e6', 'Nf3'])), isFalse);
      g.applyDeletion(plan);
      expect(g.movesTo(keyAfter(['d4', 'Nf6', 'c4', 'e6', 'Nf3'])), hasLength(1));
      expectConsistent(g);
    });

    test('deleting main promotes an alternative (INV-1/INV-4)', () {
      final g = newRep(Side.white);
      addSanLine(g, Chess.initial, ['e4']);
      g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.asAlternative);
      g.deleteMove(g.mainMove(kInitialKey)!);
      expect(g.mainMove(kInitialKey)!.san, 'd4');
      expect(g.cards.containsKey(kInitialKey), isTrue);
      expectConsistent(g);
    });

    test('deleting the only move drops the card', () {
      final g = newRep(Side.white);
      addSanLine(g, Chess.initial, ['e4']);
      g.deleteMove(g.mainMove(kInitialKey)!);
      expect(g.cards, isEmpty);
      expectConsistent(g);
    });
  });

  group('F-REP-03/05/06 import', () {
    const pgn = '''
[Event "Sicilian for Black"]
[Result "*"]

1. e4 c5 {Sicilian} 2. Nf3 (2. c3 d5 {Best vs Alapin} 3. exd5 Qxd5) (2. Nc3 Nc6) 2... d6
(2... Nc6 3. d4) 3. d4 cxd4 4. Nxd4 Nf6 5. Nc3 a6 {[%cal Ga6b5] Najdorf} *
''';

    test('all opponent variations, own main line only', () {
      final g = newRep(Side.black);
      final game = PgnParser.parseOne(pgn);
      final preview = importIntoRepertoire(g.clone(), [ImportSource.game(game)], const RepImportOptions());
      final r = importIntoRepertoire(g, [ImportSource.game(game)], const RepImportOptions());
      expect(preview.stats.newMoves, r.stats.newMoves);
      expect(preview.stats.newPositions, r.stats.newPositions);
      // e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6 + c3 d5 exd5 Qxd5 + Nc3 Nc6 = 16
      expect(r.stats.newMoves, 16);
      expect(r.conflicts, isEmpty);
      expect(g.move(keyAfter(['e4', 'c5', 'Nf3']), 'b8c6'), isNull, reason: 'own variation skipped');
      expect(g.move(keyAfter(['e4']), 'c7c5')!.comment, 'Sicilian');
      expect(
        g.positions[keyAfter(['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'a6'])]!.shapes,
        hasLength(1),
      );
      expectConsistent(g);
    });

    test('variation order of the document is kept', () {
      final g = newRep(Side.white);
      importIntoRepertoire(g, [
        ImportSource.game(PgnParser.parseOne('1. e4 e5 (1... c5) (1... e6) (1... c6) *')),
      ], const RepImportOptions());
      expect(g.movesFrom(keyAfter(['e4'])).map((m) => m.san).toList(), ['e5', 'c5', 'e6', 'c6']);
    });

    test('own variations as alternatives', () {
      final g = newRep(Side.black);
      final game = PgnParser.parseOne(pgn);
      importIntoRepertoire(g, [ImportSource.game(game)], const RepImportOptions(ownAllVariations: true));
      final pos = keyAfter(['e4', 'c5', 'Nf3']);
      expect(g.mainMove(pos)!.san, 'd6');
      expect(g.alternatives(pos).single.san, 'Nc6');
      expectConsistent(g);
    });

    test('opponent main line only and max depth', () {
      final g = newRep(Side.black);
      final game = PgnParser.parseOne(pgn);
      final r = importIntoRepertoire(g, [
        ImportSource.game(game),
      ], const RepImportOptions(opponentAllVariations: false, maxPly: 4));
      expect(r.stats.newMoves, 4);
      expectConsistent(g);
    });

    test('merge: same moves not duplicated, conflicts detected and resolved', () {
      final g = newRep(Side.black);
      importIntoRepertoire(g, [ImportSource.game(PgnParser.parseOne(pgn))], const RepImportOptions());
      final other = PgnParser.parseOne('1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 *');
      final preview = importIntoRepertoire(g.clone(), [ImportSource.game(other)], const RepImportOptions());
      expect(preview.stats.matchedMoves, 3);
      expect(preview.stats.newMoves, 3);
      expect(preview.conflicts, hasLength(1));
      final r = importIntoRepertoire(g, [ImportSource.game(other)], const RepImportOptions());
      final conflict = r.conflicts.single;
      expect(conflict.candidates.values.toList(), ['d6', 'Nc6']);
      // Before resolution the old main stays main (INV-1 holds).
      expectConsistent(g);
      resolveConflict(g, conflict, ConflictResolution.choose(conflict.key, 'b8c6'));
      expect(g.mainMove(conflict.key)!.san, 'Nc6');
      expect(g.alternatives(conflict.key).single.san, 'd6');
      expectConsistent(g);
      // Delete the others.
      resolveConflict(g, conflict, ConflictResolution.choose(conflict.key, 'b8c6', others: ConflictOthers.delete));
      expect(g.alternatives(conflict.key), isEmpty);
      expect(g.positions.containsKey(keyAfter(['e4', 'c5', 'Nf3', 'd6'])), isFalse);
      expectConsistent(g);
    });

    test('deferred conflict disables training of the position', () {
      final g = newRep(Side.black);
      importIntoRepertoire(g, [ImportSource.game(PgnParser.parseOne('1. e4 c5 *'))], const RepImportOptions());
      final r = importIntoRepertoire(g, [
        ImportSource.game(PgnParser.parseOne('1. e4 e5 *')),
      ], const RepImportOptions());
      resolveConflict(g, r.conflicts.single, ConflictResolution.defer(r.conflicts.single.key));
      expect(g.isTrainable(keyAfter(['e4'])), isFalse);
      expectConsistent(g);
    });

    test('comment policies', () {
      for (final (policy, expected) in [
        (CommentPolicy.keepOld, 'old'),
        (CommentPolicy.replace, 'new'),
        (CommentPolicy.merge, 'old\nnew'),
      ]) {
        final g = newRep(Side.white);
        importIntoRepertoire(g, [ImportSource.game(PgnParser.parseOne('1. e4 {old} *'))], const RepImportOptions());
        final r = importIntoRepertoire(g, [
          ImportSource.game(PgnParser.parseOne('1. e4 {new} *')),
        ], RepImportOptions(commentPolicy: policy));
        expect(r.stats.commentCollisions, 1);
        expect(g.mainMove(kInitialKey)!.comment, expected);
      }
    });

    test('repertoire with a later start position ignores earlier moves', () {
      final start = play(['e4', 'c5']);
      final g = RepertoireGraph(color: Side.black, rootKey: positionKeyOf(start), rootFen: start.fen);
      final r = importIntoRepertoire(g, [ImportSource.game(PgnParser.parseOne(pgn))], const RepImportOptions());
      expect(r.stats.outsideMoves, 0);
      expect(g.movesFrom(positionKeyOf(start)).map((m) => m.san).toSet(), {'Nf3', 'c3', 'Nc3'});
      expectConsistent(g);
    });

    test('subtree import includes the path to the start node', () {
      final g = newRep(Side.black);
      final game = PgnParser.parseOne(pgn);
      final c3 = game.root.mainChild!.mainChild!.children[1]; // 2. c3
      importIntoRepertoire(g, [ImportSource(c3)], const RepImportOptions());
      expect(g.movesFrom(keyAfter(['e4', 'c5'])).single.san, 'c3');
      expect(g.moveCount, 6); // e4 c5 c3 d5 exd5 Qxd5
      expectConsistent(g);
    });
  });

  group('F-REP-09 export', () {
    test('export then import gives the same graph', () {
      final g = newRep(Side.black);
      addSanLine(g, Chess.initial, ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'd5']);
      addSanLine(g, Chess.initial, ['Nf3', 'Nf6', 'c4', 'e6', 'd4', 'd5']);
      addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6']);
      g.setMoveComment(g.move(kInitialKey, 'e2e4')!, 'Main test');
      for (final mode in TranspositionMode.values) {
        final game = repertoireToGame(g, mode: mode);
        final g2 = newRep(Side.black);
        importIntoRepertoire(g2, [ImportSource.game(game)], const RepImportOptions(ownAllVariations: true));
        expect(g2.positions.keys.toSet(), g.positions.keys.toSet(), reason: mode.name);
        expect(g2.moveCount, g.moveCount, reason: mode.name);
        expect(g2.move(kInitialKey, 'e2e4')!.comment, contains('Main test'));
        expectConsistent(g2);
      }
      final withComment = repertoireToGame(g, mode: TranspositionMode.comment);
      final texts = withComment.root.descendants().expand((n) => n.comments).map((c) => c.text);
      expect(texts.any((t) => t.startsWith('Transposes to: 1. d4 Nf6 2. c4 e6 3. Nf3')), isTrue);
    });
  });
}
