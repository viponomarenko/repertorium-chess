import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/domain/srs/fsrs.dart';
import 'package:tabiya/domain/training/training_engine.dart';

final t0 = DateTime(2026, 9, 27, 12);

RepertoireGraph longLine() {
  final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
  addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O']);
  return g;
}

/// Runs a session answering correctly; returns the questions asked
/// (non-demo ones on cards that were new before the session).
({int coldNewQuestions, int reviewed, int introduced}) run(TrainingEngine e, Set<PositionKey> newBefore) {
  var cold = 0;
  for (var i = 0; i < 400; i++) {
    final step = e.next();
    switch (step) {
      case AwaitUser(:final expected, :final demo, :final key):
        if (!demo && newBefore.contains(key) && !e.inRecall) cold++;
        e.submitMove(parseUciMove(e.position, expected.uci)!, responseTime: const Duration(seconds: 3));
      case LineComplete():
        e.startNextLine();
      case SessionComplete(:final summary):
        return (coldNewQuestions: cold, reviewed: summary.reviewed, introduced: summary.introduced);
      default:
    }
  }
  fail('session did not finish');
}

void main() {
  test('learn: after the new limit, unseen moves are not asked cold', () {
    final g = longLine();
    final newKeys = {for (final k in g.cards.keys) k};
    final e = TrainingEngine(
      graph: g,
      clock: () => t0,
      config: const TrainingConfig(mode: TrainingMode.learn, newLimit: 1, reviewLimit: 100),
    );
    final r = run(e, newKeys);
    expect(r.coldNewQuestions, 0);
    expect(r.introduced, lessThanOrEqualTo(1));
  });

  test('drill does not introduce never-learned moves', () {
    final g = longLine();
    final newKeys = {for (final k in g.cards.keys) k};
    final e = TrainingEngine(
      graph: g,
      clock: () => t0,
      config: const TrainingConfig(
        mode: TrainingMode.drill,
        newLimit: 100,
        reviewLimit: 100,
        drillAffectsSchedule: true,
      ),
    );
    final r = run(e, newKeys);
    expect(r.coldNewQuestions, 0);
    expect(r.introduced, 0);
  });

  test('review: the daily review limit holds inside a line', () {
    final g = longLine();
    for (final k in g.cards.keys.toList()) {
      g.updateCard(
        k,
        SrsState(
          stability: 5,
          difficulty: 5,
          due: t0.subtract(const Duration(days: 1)),
          lastReview: t0.subtract(const Duration(days: 6)),
          reps: 3,
          state: CardState.review,
        ),
      );
    }
    final e = TrainingEngine(
      graph: g,
      clock: () => t0,
      config: const TrainingConfig(mode: TrainingMode.review, newLimit: 0, reviewLimit: 1),
    );
    final r = run(e, const {});
    expect(r.reviewed, lessThanOrEqualTo(1));
  });
}
