import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/domain/srs/fsrs.dart';
import 'package:tabiya/domain/training/opponent_strategy.dart';
import 'package:tabiya/domain/training/training_engine.dart';

final t0 = DateTime(2026, 9, 27, 12);

Position play(List<String> sans, [Position? from]) {
  var pos = from ?? Chess.initial;
  for (final s in sans) {
    pos = pos.play(pos.parseSan(s)!);
  }
  return pos;
}

PositionKey keyAfter(List<String> sans) => positionKeyOf(play(sans));

RepertoireGraph whiteRep() {
  final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
  addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
  addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
  return g;
}

/// Marks every card as reviewed, due in [daysAhead] days.
void scheduleAll(RepertoireGraph g, {int daysAhead = 5}) {
  for (final k in g.cards.keys.toList()) {
    g.updateCard(
      k,
      SrsState(
        stability: 5,
        difficulty: 5,
        due: t0.add(Duration(days: daysAhead)),
        lastReview: t0.subtract(const Duration(days: 3)),
        reps: 3,
        state: CardState.review,
      ),
    );
  }
}

void makeDue(RepertoireGraph g, PositionKey k, {int overdueDays = 1}) {
  g.updateCard(k, g.cards[k]!.srs.copyWith(due: t0.subtract(Duration(days: overdueDays))));
}

Move san(TrainingEngine e, String s) => e.position.parseSan(s)!;

/// Drives the engine answering correctly until the session ends.
/// Returns the list of SAN moves of all lines.
List<List<String>> runPerfect(TrainingEngine e, {int maxSteps = 500}) {
  final lines = <List<String>>[];
  var current = <String>[];
  for (var i = 0; i < maxSteps; i++) {
    final step = e.next();
    switch (step) {
      case AwaitUser(:final expected):
        final r = e.submitMove(parseUciMove(e.position, expected.uci)!, responseTime: const Duration(seconds: 5));
        expect(r.accepted, isTrue);
        current.add(expected.san);
      case AutoMove(:final move):
        current.add(move.san);
      case RecallStart():
        current.add('|recall|');
      case LineComplete():
        lines.add(current);
        current = [];
        e.startNextLine();
      case SessionComplete():
        return lines;
    }
  }
  fail('session did not finish');
}

void main() {
  group('FSRS (F-TRN-06)', () {
    final fsrs = Fsrs();

    test('new card: good schedules days ahead, again soon', () {
      final good = fsrs.review(const SrsState(), Grade.good, t0);
      expect(good.state, CardState.review);
      expect(good.due!.isAfter(t0.add(const Duration(hours: 12))), isTrue);
      final again = fsrs.review(const SrsState(), Grade.again, t0);
      expect(again.state, CardState.learning);
      expect(again.due, t0.add(const Duration(minutes: 10)));
      final easy = fsrs.review(const SrsState(), Grade.easy, t0);
      expect(easy.stability, greaterThan(good.stability));
    });

    test('successful reviews grow intervals; lapse shrinks stability', () {
      var s = fsrs.review(const SrsState(), Grade.good, t0);
      var now = t0;
      final intervals = <int>[];
      for (var i = 0; i < 4; i++) {
        now = s.due!.add(const Duration(hours: 1));
        final next = fsrs.review(s, Grade.good, now);
        intervals.add(next.due!.difference(now).inDays);
        s = next;
      }
      for (var i = 1; i < intervals.length; i++) {
        expect(intervals[i], greaterThan(intervals[i - 1]));
      }
      final lapse = fsrs.review(s, Grade.again, s.due!);
      expect(lapse.stability, lessThan(s.stability));
      expect(lapse.lapses, 1);
      expect(lapse.state, CardState.relearning);
    });

    test('due at the start of the study day (4:00)', () {
      final s = fsrs.review(const SrsState(), Grade.good, DateTime(2026, 9, 27, 22));
      expect(s.due!.hour, 4);
      expect(fsrs.isDue(s, s.due!), isTrue);
      expect(fsrs.isDue(s, s.due!.subtract(const Duration(minutes: 1))), isFalse);
    });

    // D-066: without a visible clock the time does not change the grade.
    test('untimed grading ignores the response time', () {
      const p = GradingPolicy(timed: false);
      const slow = Duration(minutes: 2);
      expect(p.grade(firstTry: true, usedHint: false, responseTime: slow), Grade.good);
      expect(p.grade(firstTry: true, usedHint: false, responseTime: Duration.zero), Grade.good);
      expect(p.grade(firstTry: false, usedHint: false, responseTime: Duration.zero), Grade.again);
      expect(p.grade(firstTry: true, usedHint: true, responseTime: Duration.zero), Grade.again);
    });

    test('grading policy (F-TRN-07)', () {
      const p = GradingPolicy();
      expect(p.grade(firstTry: true, usedHint: false, responseTime: const Duration(seconds: 1)), Grade.easy);
      expect(p.grade(firstTry: true, usedHint: false, responseTime: const Duration(seconds: 5)), Grade.good);
      expect(p.grade(firstTry: true, usedHint: false, responseTime: const Duration(seconds: 15)), Grade.hard);
      expect(p.grade(firstTry: false, usedHint: false, responseTime: const Duration(seconds: 1)), Grade.again);
      expect(p.grade(firstTry: true, usedHint: true, responseTime: const Duration(seconds: 1)), Grade.again);
      const noEasy = GradingPolicy(easyEnabled: false);
      expect(noEasy.grade(firstTry: true, usedHint: false, responseTime: const Duration(seconds: 1)), Grade.good);
    });
  });

  group('opponent strategies (5.3)', () {
    final rnd = math.Random(1);
    final moves = [
      RepMove(fromKey: 'a', uci: 'a', toKey: 'A', san: 'a', role: MoveRole.opponent, weight: 90),
      RepMove(fromKey: 'a', uci: 'b', toKey: 'B', san: 'b', role: MoveRole.opponent, weight: 10),
      RepMove(fromKey: 'a', uci: 'c', toKey: 'C', san: 'c', role: MoveRole.opponent, weight: 0),
    ];
    final info = {
      'A': const SubtreeInfo(hasDue: true, maxOverdueDays: 1, minStability: 10),
      'B': const SubtreeInfo(hasDue: true, maxOverdueDays: 7, minStability: 2),
      'C': const SubtreeInfo(minStability: 0, hasNew: true),
    };

    test('dueFirst picks the most overdue', () {
      expect(chooseOpponentMove(moves, OpponentStrategy.dueFirst, info, rnd)!.uci, 'b');
    });

    test('weighted follows weights', () {
      final counts = <String, int>{};
      for (var i = 0; i < 2000; i++) {
        final m = chooseOpponentMove(moves, OpponentStrategy.weighted, info, rnd)!;
        counts[m.uci] = (counts[m.uci] ?? 0) + 1;
      }
      expect(counts['a']!, greaterThan(1600));
      expect(counts['b']!, inInclusiveRange(100, 350));
      expect(counts['c'], isNull);
    });

    test('uniform covers all', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(chooseOpponentMove(moves, OpponentStrategy.uniform, info, rnd)!.uci);
      }
      expect(seen, {'a', 'b', 'c'});
    });

    test('leastLearned picks the weakest subtree', () {
      expect(chooseOpponentMove(moves, OpponentStrategy.leastLearned, info, rnd)!.uci, 'c');
    });

    test('dueFirst with no due falls back to weights', () {
      final noDue = {
        for (final k in ['A', 'B', 'C']) k: const SubtreeInfo(),
      };
      final m = chooseOpponentMove(moves.take(2).toList(), OpponentStrategy.dueFirst, noDue, math.Random(3))!;
      expect(['a', 'b'], contains(m.uci));
    });
  });

  group('Review (F-TRN-02, 5.4)', () {
    test('path to a deep due position: light checks, then graded review', () {
      final g = whiteRep();
      scheduleAll(g);
      final target = keyAfter(['e4', 'c5']);
      makeDue(g, target);
      final events = <ReviewEvent>[];
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
        random: math.Random(1),
        onReview: events.add,
      );
      final lines = runPerfect(e);
      expect(lines, [
        ['e4', 'c5', 'Nf3'],
      ]);
      expect(events.map((ev) => ev.mode), ['light', 'review']);
      expect(events.last.key, target);
      expect(events.last.scheduled, isTrue);
      expect(events.first.scheduled, isFalse);
      expect(g.cards[target]!.srs.due!.isAfter(t0), isTrue);
      expect(e.summary.reviewed, 1);
    });

    test('autoplay to the first due position', () {
      final g = whiteRep();
      scheduleAll(g);
      makeDue(g, keyAfter(['e4', 'e5', 'Nf3', 'Nc6']));
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review, autoplayToTarget: true),
        clock: () => t0,
      );
      final first = e.next();
      expect(first, isA<AutoMove>());
      expect((first as AutoMove).fast, isTrue);
      final steps = <TrainingStep>[first];
      while (e.awaiting == null) {
        steps.add(e.next());
      }
      expect(steps.whereType<AutoMove>().map((s) => s.move.san), ['e4', 'e5', 'Nf3', 'Nc6']);
      expect(e.awaiting!.expected.san, 'Bb5');
    });

    test('mistakes: piece returns, reveal after 2, again is re-queued (F-TRN-08)', () {
      final g = whiteRep();
      scheduleAll(g);
      final target = keyAfter(['e4', 'e5']);
      makeDue(g, target);
      final events = <ReviewEvent>[];
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review, autoplayToTarget: true),
        clock: () => t0,
        onReview: events.add,
      );
      TrainingStep s;
      do {
        s = e.next();
      } while (s is! AwaitUser);
      expect(s.expected.san, 'Nf3');
      final w1 = e.submitMove(san(e, 'd4'));
      expect(w1.verdict, MoveVerdict.wrong);
      expect(w1.reveal, isFalse);
      final w2 = e.submitMove(san(e, 'Bc4'));
      expect(w2.reveal, isTrue);
      expect(e.next(), same(e.awaiting), reason: 'still the same question');
      final ok = e.submitMove(san(e, 'Nf3'));
      expect(ok.grade, Grade.again);
      expect(events.single.playedUci, 'd2d4');
      expect(events.single.grade, Grade.again);
      // Re-queued at the end of the session.
      final rest = runPerfect(e);
      expect(rest.length, 2);
      expect(rest.last.last, 'Nf3');
      expect(events.last.key, target);
      expect(events.last.grade, isNot(Grade.again));
    });

    test('alternative move: asked for main without penalty', () {
      final g = whiteRep();
      g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.asAlternative);
      scheduleAll(g);
      makeDue(g, kInitialKey);
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
      );
      e.next();
      final r = e.submitMove(san(e, 'd4'));
      expect(r.verdict, MoveVerdict.alternativeRejected);
      expect(e.attempts, 0);
      final ok = e.submitMove(san(e, 'e4'));
      expect(ok.verdict, MoveVerdict.correct);
      expect(ok.grade, isNot(Grade.again));
    });

    test('alternative accepted when configured', () {
      final g = whiteRep();
      g.addMove(Chess.initial, Chess.initial.parseSan('d4')!, policy: OwnMovePolicy.asAlternative);
      scheduleAll(g);
      makeDue(g, kInitialKey);
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review, acceptAlternatives: true),
        clock: () => t0,
      );
      e.next();
      final r = e.submitMove(san(e, 'd4'));
      expect(r.verdict, MoveVerdict.alternativeAccepted);
    });

    test('nothing due: session completes immediately', () {
      final g = whiteRep();
      scheduleAll(g);
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
      );
      expect(e.next(), isA<SessionComplete>());
    });

    test('suspended and deferred positions are auto-played', () {
      final g = whiteRep();
      scheduleAll(g);
      g.setSuspendedSubtree(kInitialKey, false);
      g.cards[kInitialKey]!.suspended = true;
      makeDue(g, keyAfter(['e4', 'e5']));
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
      );
      final first = e.next();
      expect(first, isA<AutoMove>());
      expect((first as AutoMove).move.san, 'e4');
    });

    test('transposition: one card, reviewed once (F-TRN-11)', () {
      final g = RepertoireGraph(color: Side.black, rootKey: kInitialKey, rootFen: kInitialFen);
      addSanLine(g, Chess.initial, ['d4', 'Nf6', 'c4', 'e6', 'Nf3', 'd5']);
      addSanLine(g, Chess.initial, ['Nf3', 'Nf6', 'c4', 'e6', 'd4', 'd5']);
      scheduleAll(g);
      final shared = keyAfter(['d4', 'Nf6', 'c4', 'e6', 'Nf3']);
      makeDue(g, shared);
      final events = <ReviewEvent>[];
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
        onReview: events.add,
      );
      final lines = runPerfect(e);
      expect(lines, hasLength(1));
      expect(events.where((ev) => ev.mode == 'review').single.key, shared);
    });
  });

  // Audit 05.10: a repetition imported with a whole game makes a cycle of
  // positions; a line through it never ended.
  group('cycle of positions', () {
    RepertoireGraph cyclic() {
      final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
      addSanLine(g, Chess.initial, ['Nf3', 'Nf6', 'Ng1', 'Ng8', 'Nf3', 'Nf6']);
      return g;
    }

    test('the graph really has a cycle', () {
      final g = cyclic();
      expect(g.move(keyAfter(['Nf3', 'Nf6', 'Ng1']), 'f6g8')!.toKey, kInitialKey);
    });

    test('learn ends and schedules both moves', () {
      final g = cyclic();
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.learn, newLimit: 20),
        clock: () => t0,
      );
      runPerfect(e);
      expect(g.cards.values.where((c) => !c.srs.isNew), hasLength(2));
    });

    for (final autoplay in [false, true]) {
      test('review ends (autoplay: $autoplay)', () {
        final g = cyclic();
        scheduleAll(g, daysAhead: -1);
        final e = TrainingEngine(
          graph: g,
          config: TrainingConfig(mode: TrainingMode.review, autoplayToTarget: autoplay),
          clock: () => t0,
        );
        runPerfect(e);
        expect(e.summary.reviewed, 2);
      });
    }

    test('drill ends', () {
      final g = cyclic();
      scheduleAll(g);
      runPerfect(
        TrainingEngine(
          graph: g,
          config: const TrainingConfig(mode: TrainingMode.drill),
          clock: () => t0,
        ),
      );
    });
  });

  group('Learn (F-TRN-01)', () {
    test('demo then recall; cards leave the new state', () {
      final g = whiteRep();
      final events = <ReviewEvent>[];
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.learn, newLimit: 3),
        clock: () => t0,
        onReview: events.add,
      );
      final first = e.next() as AwaitUser;
      expect(first.demo, isTrue);
      final lines = runPerfect(e);
      expect(lines.first.where((m) => m == '|recall|'), hasLength(1));
      expect(e.summary.introduced, 3);
      final learned = g.cards.values.where((c) => !c.srs.isNew).length;
      expect(learned, 3);
      expect(events.where((ev) => ev.mode == 'learn' && ev.scheduled), hasLength(3));
    });

    test('new limit respected', () {
      final g = whiteRep();
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.learn, newLimit: 1),
        clock: () => t0,
      );
      runPerfect(e);
      expect(g.cards.values.where((c) => !c.srs.isNew), hasLength(1));
    });
  });

  group('Drill (F-TRN-03) and from position (F-TRN-05)', () {
    test('covers every line; schedule untouched by default', () {
      final g = whiteRep();
      scheduleAll(g);
      final before = {for (final e in g.cards.entries) e.key: e.value.srs.due};
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.drill, strategy: OpponentStrategy.uniform),
        clock: () => t0,
        random: math.Random(2),
      );
      final lines = runPerfect(e);
      expect(lines, hasLength(2));
      expect(lines.map((l) => l.join(' ')).toSet(), {'e4 e5 Nf3 Nc6 Bb5', 'e4 c5 Nf3 d6 d4'});
      for (final entry in g.cards.entries) {
        expect(entry.value.srs.due, before[entry.key]);
      }
    });

    test('from a position trains only its subtree', () {
      final g = whiteRep();
      final e = TrainingEngine(
        graph: g,
        config: TrainingConfig(mode: TrainingMode.drill, startKey: keyAfter(['e4', 'c5'])),
        clock: () => t0,
      );
      final lines = runPerfect(e);
      expect(lines, [
        ['Nf3', 'd6', 'd4'],
      ]);
    });
  });

  group('Problems (F-TRN-04)', () {
    test('goes to each problem position', () {
      final g = whiteRep();
      scheduleAll(g);
      final p1 = keyAfter(['e4', 'c5', 'Nf3', 'd6']);
      final e = TrainingEngine(
        graph: g,
        config: TrainingConfig(mode: TrainingMode.problems, problemKeys: [p1], autoplayToTarget: true),
        clock: () => t0,
      );
      TrainingStep s;
      do {
        s = e.next();
      } while (s is! AwaitUser);
      expect(s.key, p1);
      expect(s.expected.san, 'd4');
    });
  });

  group('hints (F-TRN-12)', () {
    test('three levels, any hint grades again', () {
      final g = whiteRep();
      scheduleAll(g);
      makeDue(g, kInitialKey);
      final e = TrainingEngine(
        graph: g,
        config: const TrainingConfig(mode: TrainingMode.review),
        clock: () => t0,
      );
      e.next();
      final h1 = e.requestHint()!;
      expect(h1.level, 1);
      expect(h1.from, Square.e2);
      expect(e.requestHint()!.level, 2);
      expect(e.requestHint()!.to, Square.e4);
      final r = e.submitMove(san(e, 'e4'));
      expect(r.grade, Grade.again);
    });
  });
}
