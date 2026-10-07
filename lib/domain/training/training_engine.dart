/// Training session state machine (ТЗ 5, F-TRN).
///
/// Pure Dart: the UI drives it with [TrainingEngine.next] and
/// [TrainingEngine.submitMove]; persistence happens through
/// [TrainingEngine.onReview].
///
/// Flow per call of [next]:
/// * [AwaitUser] — the user must move; answer with [submitMove];
/// * [AutoMove] — the engine played a move (opponent, auto-play); animate
///   it and call [next] again;
/// * [RecallStart] — Learn mode: the same line is replayed without hints;
/// * [LineComplete] — show a summary, then call [startNextLine];
/// * [SessionComplete] — done.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' hide PgnComment;

import '../chess/chess_utils.dart';
import '../repertoire/repertoire_graph.dart';
import '../srs/fsrs.dart';
import 'opponent_strategy.dart';

enum TrainingMode {
  learn,
  review,
  drill,
  problems;

  static TrainingMode fromName(String n) =>
      TrainingMode.values.firstWhere((m) => m.name == n, orElse: () => TrainingMode.review);
}

class TrainingConfig {
  const TrainingConfig({
    required this.mode,
    this.startKey,
    this.strategy = OpponentStrategy.dueFirst,
    this.acceptAlternatives = false,
    this.mistakesBeforeReveal = 2,
    this.autoplayToTarget = false,
    this.drillAffectsSchedule = false,
    this.maxLines,
    this.maxDuration,
    this.newLimit = 20,
    this.reviewLimit = 200,
    this.problemKeys = const [],
    this.grading = const GradingPolicy(),
    this.maxRequeue = 2,
    this.problemTail = 2,
  });

  final TrainingMode mode;

  /// Root of the trained subtree (default: repertoire root). F-TRN-05.
  final PositionKey? startKey;
  final OpponentStrategy strategy;

  /// Playing an `alternative` move: accept and continue (true) or ask for
  /// the main move without penalty (false, default).
  final bool acceptAlternatives;
  final int mistakesBeforeReveal;

  /// Auto-play moves until the first due / target position (5.4).
  final bool autoplayToTarget;
  final bool drillAffectsSchedule;
  final int? maxLines;
  final Duration? maxDuration;

  /// Remaining new cards / reviews for today (F-TRN-09).
  final int newLimit;
  final int reviewLimit;

  /// Problem positions, most problematic first (F-TRN-04).
  final List<PositionKey> problemKeys;
  final GradingPolicy grading;

  /// How many times an `again` card returns in one session (F-TRN-08).
  final int maxRequeue;

  /// Own moves trained after a problem position.
  final int problemTail;
}

/// A move played in the current line (for "Show line", F-TRN-14).
class LineMove {
  LineMove({
    required this.san,
    required this.uci,
    required this.fromKey,
    required this.byUser,
    required this.fenBefore,
    this.comment = '',
    this.mistakes = 0,
    this.hinted = false,
    this.grade,
    this.auto = false,
  });

  final String san;
  final String uci;
  final PositionKey fromKey;
  final String fenBefore;
  final bool byUser;
  final String comment;
  int mistakes;
  bool hinted;
  Grade? grade;
  final bool auto;
}

/// Persisted review event (ReviewLog + new card state).
class ReviewEvent {
  ReviewEvent({
    required this.key,
    required this.before,
    required this.after,
    required this.grade,
    required this.mode,
    required this.playedUci,
    required this.expectedUci,
    required this.responseMs,
    required this.scheduled,
    required this.timestamp,
  });

  final PositionKey key;
  final SrsState before;
  final SrsState after;
  final Grade grade;

  /// learn | review | drill | light | problems
  final String mode;

  /// First move played (wrong one if there was a mistake).
  final String playedUci;
  final String expectedUci;
  final int responseMs;

  /// Whether the schedule changed.
  final bool scheduled;
  final DateTime timestamp;
}

sealed class TrainingStep {
  const TrainingStep();
}

class AwaitUser extends TrainingStep {
  const AwaitUser({
    required this.key,
    required this.expected,
    this.demo = false,
    this.isDue = false,
    this.isNewCard = false,
  });
  final PositionKey key;

  /// The move that is accepted (main, or the recorded move in recall).
  final RepMove expected;

  /// Learn mode demonstration: show the move (arrow + comment) first.
  final bool demo;
  final bool isDue;
  final bool isNewCard;
}

class AutoMove extends TrainingStep {
  const AutoMove(this.move, {required this.byUserSide, this.fast = false, this.isAlternative = false});
  final RepMove move;
  final bool byUserSide;

  /// Auto-play to target: animate quickly.
  final bool fast;
  final bool isAlternative;
}

class RecallStart extends TrainingStep {
  const RecallStart();
}

class LineSummary {
  LineSummary(this.moves);
  final List<LineMove> moves;
  int get userMoves => moves.where((m) => m.byUser && !m.auto).length;
  int get mistakes => moves.fold(0, (a, m) => a + m.mistakes);
  int get clean => moves.where((m) => m.byUser && !m.auto && m.mistakes == 0 && !m.hinted).length;
}

class LineComplete extends TrainingStep {
  const LineComplete(this.summary);
  final LineSummary summary;
}

class SessionSummary {
  int lines = 0;
  int reviewed = 0;
  int introduced = 0;
  int mistakes = 0;
  final Map<Grade, int> grades = {for (final g in Grade.values) g: 0};
  Duration elapsed = Duration.zero;
}

class SessionComplete extends TrainingStep {
  const SessionComplete(this.summary);
  final SessionSummary summary;
}

enum MoveVerdict { correct, alternativeAccepted, alternativeRejected, wrong }

class MoveOutcome {
  const MoveOutcome(this.verdict, {this.played, this.expected, this.reveal = false, this.grade, this.comment = ''});
  final MoveVerdict verdict;
  final RepMove? played;
  final RepMove? expected;

  /// After N mistakes the expected move is shown (arrow) — user plays it.
  final bool reveal;
  final Grade? grade;

  /// Comment for the played move/position (shown after a correct move).
  final String comment;

  bool get accepted => verdict == MoveVerdict.correct || verdict == MoveVerdict.alternativeAccepted;
}

class HintInfo {
  const HintInfo(this.level, this.from, this.to);

  /// 1 = piece, 2 = destination square, 3 = arrow.
  final int level;
  final Square? from;
  final Square to;
}

enum _LinePhase { normal, learnDemo, learnRecall }

class TrainingEngine {
  TrainingEngine({
    required this.graph,
    required this.config,
    Fsrs? fsrs,
    DateTime Function()? clock,
    math.Random? random,
    this.onReview,
  }) : fsrs = fsrs ?? Fsrs(),
       clock = clock ?? DateTime.now,
       random = random ?? math.Random() {
    startKey = config.startKey ?? graph.rootKey;
    autoplay = config.autoplayToTarget;
    _startedAt = this.clock();
    _problems.addAll(config.problemKeys);
  }

  final RepertoireGraph graph;
  final TrainingConfig config;
  final Fsrs fsrs;
  final DateTime Function() clock;
  final math.Random random;

  /// Called for every graded answer (persist card + log).
  final void Function(ReviewEvent event)? onReview;

  late final PositionKey startKey;
  late final DateTime _startedAt;

  /// Auto-play to the target / first due position; can be toggled during
  /// the session (F-TRN-15).
  late bool autoplay;

  final SessionSummary summary = SessionSummary();
  final Set<PositionKey> _reviewed = {};
  final Set<PositionKey> _introduced = {};
  final Set<PositionKey> _covered = {};
  final Queue<PositionKey> _requeue = Queue();
  final Map<PositionKey, int> _requeueCount = {};
  final Queue<PositionKey> _problems = Queue();

  // Current line.
  late Position position;
  PositionKey get key => positionKeyOf(position);
  late Position lineStartPosition;
  final List<LineMove> line = [];
  Map<PositionKey, SubtreeInfo> _info = {};
  _LinePhase _phase = _LinePhase.normal;
  bool _lineActive = false;
  bool _finished = false;
  bool _lineDone = false;
  PositionKey? _target;
  List<RepMove> _targetPath = const [];
  int _targetIndex = 0;
  bool _targetReached = false;
  int _tailLeft = 0;
  final Set<PositionKey> _introducedThisLine = {};
  bool _hitDue = false;
  List<RepMove> _recorded = [];
  int _replayIndex = 0;
  bool _recallPending = false;

  /// Positions this line already left. A repertoire may contain a cycle
  /// (a repetition imported with a whole game): the line never returns to
  /// one of them, or it would not end.
  final Set<PositionKey> _passed = {};

  // Current question.
  int _attempts = 0;
  int _hintLevel = 0;
  bool _revealed = false;
  String? _firstWrongUci;
  AwaitUser? _awaiting;

  Side get orientation => graph.color;
  bool get isFinished => _finished;
  bool get inRecall => _phase == _LinePhase.learnRecall;
  AwaitUser? get awaiting => _awaiting;
  int get attempts => _attempts;
  int get hintLevel => _hintLevel;
  bool get revealed => _revealed;
  PositionKey? get currentTarget => _target;

  DateTime get _now => clock();

  // ------------------------------------------------------------ helpers

  bool _isDueNow(PositionKey k) {
    if (_reviewed.contains(k)) return false;
    final c = graph.cards[k];
    return c != null && graph.isTrainable(k) && fsrs.isDue(c.srs, _now);
  }

  bool _isNewNow(PositionKey k) {
    if (_introduced.contains(k)) return false;
    final c = graph.cards[k];
    return c != null && graph.isTrainable(k) && c.srs.isNew;
  }

  /// Drill covers learned moves only: a move that was never shown is not
  /// asked (and must not be introduced past the daily new limit).
  bool _isUncovered(PositionKey k) {
    if (_covered.contains(k) || !graph.isTrainable(k)) return false;
    // When the drill changes the schedule, never-learned moves are left to
    // Learn (otherwise they would bypass the daily new limit).
    if (!config.drillAffectsSchedule) return true;
    final c = graph.cards[k];
    return c == null || !c.srs.isNew;
  }

  /// A never-learned card that is not being introduced now and would be
  /// scheduled if answered.
  bool _unseenNew(PositionKey k) {
    if (config.mode == TrainingMode.drill && !config.drillAffectsSchedule) return false;
    final c = graph.cards[k];
    return c != null && c.srs.isNew && !_introduced.contains(k);
  }

  void _computeInfo() {
    switch (config.mode) {
      case TrainingMode.review:
        _info = computeSubtreeInfo(graph, fsrs, _now, from: startKey, isDue: _isDueNow, isNew: (_) => false);
      case TrainingMode.learn:
        _info = computeSubtreeInfo(graph, fsrs, _now, from: startKey, isDue: (_) => false, isNew: _isNewNow);
      case TrainingMode.drill:
        _info = computeSubtreeInfo(graph, fsrs, _now, from: startKey, isDue: (_) => false, isNew: _isUncovered);
      case TrainingMode.problems:
        _info = computeSubtreeInfo(graph, fsrs, _now, from: startKey);
    }
  }

  /// Whether the subtree from [k] still contains something to train in the
  /// current mode.
  bool _relevant(PositionKey k) {
    final i = _info[k];
    if (i == null) return false;
    return switch (config.mode) {
      TrainingMode.review => i.hasDue,
      TrainingMode.learn => i.hasNew,
      TrainingMode.drill => i.hasNew,
      TrainingMode.problems => false,
    };
  }

  bool get _limitsReached {
    if (config.maxLines != null && summary.lines >= config.maxLines!) return true;
    if (config.maxDuration != null && _now.difference(_startedAt) >= config.maxDuration!) return true;
    return false;
  }

  // ------------------------------------------------------------ lines

  /// Prepares the next line. Returns false when the session is over.
  bool startNextLine() {
    _lineActive = false;
    _lineDone = false;
    line.clear();
    _target = null;
    _targetPath = const [];
    _targetIndex = 0;
    _targetReached = false;
    _tailLeft = 0;
    _introducedThisLine.clear();
    _passed.clear();
    _recorded = [];
    _replayIndex = 0;
    _recallPending = false;
    _hitDue = false;
    _phase = _LinePhase.normal;
    _resetQuestion();

    if (_limitsReached) return _finish();
    _computeInfo();
    final start = graph.positions[startKey];
    if (start == null) return _finish();
    lineStartPosition = positionFromFen(start.fen);
    position = lineStartPosition;

    switch (config.mode) {
      case TrainingMode.review:
        if (summary.reviewed < config.reviewLimit && _relevant(startKey)) {
          break;
        }
        if (!_startRequeueLine()) return _finish();
      case TrainingMode.learn:
        if (_introduced.length < config.newLimit && _relevant(startKey)) {
          _phase = _LinePhase.learnDemo;
          break;
        }
        if (!_startRequeueLine()) return _finish();
      case TrainingMode.drill:
        if (!_relevant(startKey)) return _finish();
      case TrainingMode.problems:
        var started = false;
        while (_problems.isNotEmpty && !started) {
          started = _startTargetLine(_problems.removeFirst());
        }
        if (!started) return _finish();
        _tailLeft = config.problemTail;
    }
    _lineActive = true;
    return true;
  }

  /// Whether another line would start now (asked after a line is done, to
  /// tell "Next line" from "Finish"). Changes nothing.
  bool get hasNextLine {
    if (_finished || _limitsReached) return false;
    _computeInfo();
    bool requeued() => _requeue.any((k) => graph.isTrainable(k) && graph.pathFromRoot(k, from: startKey) != null);
    return switch (config.mode) {
      TrainingMode.review => (summary.reviewed < config.reviewLimit && _relevant(startKey)) || requeued(),
      TrainingMode.learn => (_introduced.length < config.newLimit && _relevant(startKey)) || requeued(),
      TrainingMode.drill => _relevant(startKey),
      TrainingMode.problems => _problems.any(
        (k) => graph.isTrainable(k) && graph.pathFromRoot(k, from: startKey) != null,
      ),
    };
  }

  bool _startRequeueLine() {
    while (_requeue.isNotEmpty) {
      if (_startTargetLine(_requeue.removeFirst())) return true;
    }
    return false;
  }

  bool _startTargetLine(PositionKey target) {
    final path = graph.pathFromRoot(target, from: startKey);
    if (path == null || !graph.isTrainable(target)) return false;
    _target = target;
    _targetPath = path;
    _targetIndex = 0;
    _targetReached = false;
    return true;
  }

  bool _finish() {
    _finished = true;
    _lineActive = false;
    summary.elapsed = _now.difference(_startedAt);
    return false;
  }

  void _resetQuestion() {
    _attempts = 0;
    _hintLevel = 0;
    _revealed = false;
    _firstWrongUci = null;
    _awaiting = null;
  }

  LineComplete _completeLine() {
    _lineDone = true;
    _lineActive = false;
    summary.lines++;
    return LineComplete(LineSummary(List.of(line)));
  }

  // ------------------------------------------------------------ stepping

  TrainingStep next() {
    if (_finished) return SessionComplete(summary);
    if (!_lineActive && !_lineDone) {
      if (!startNextLine()) return SessionComplete(summary);
    }
    if (_lineDone) return LineComplete(LineSummary(List.of(line)));
    if (_recallPending) {
      _recallPending = false;
      _phase = _LinePhase.learnRecall;
      position = lineStartPosition;
      line.clear();
      _replayIndex = 0;
      return const RecallStart();
    }
    if (_awaiting != null) return _awaiting!;

    final k = key;
    final userTurn = position.turn == graph.color;

    // Learn recall: replay the recorded line.
    if (_phase == _LinePhase.learnRecall) {
      if (_replayIndex >= _recorded.length) return _completeLine();
      final m = _recorded[_replayIndex];
      if (!userTurn || !graph.isTrainable(m.fromKey) || m.role != MoveRole.main) {
        return _auto(m, byUser: userTurn);
      }
      return _ask(m, isNewCard: _introducedThisLine.contains(k));
    }

    // Following a path to a target position.
    if (_target != null && !_targetReached) {
      if (k == _target) {
        _targetReached = true;
      } else if (_targetIndex < _targetPath.length) {
        final m = _targetPath[_targetIndex];
        if (!userTurn || m.role != MoveRole.main || !graph.isTrainable(k) || autoplay) {
          return _auto(m, byUser: userTurn, fast: autoplay || !userTurn);
        }
        return _ask(m);
      }
    }
    if (_target != null && _targetReached) {
      final main = graph.mainMove(k);
      if (k == _target && userTurn && main != null) {
        return _ask(main, isDue: true);
      }
      // After the target: short tail (problems) or end (requeue).
      if (_tailLeft <= 0 || graph.isLeaf(k)) return _completeLine();
      if (userTurn) {
        if (main == null || !graph.isTrainable(k)) return _completeLine();
        return _ask(main);
      }
      final opp = chooseOpponentMove(graph.movesFrom(k), config.strategy, _info, random);
      if (opp == null) return _completeLine();
      return _auto(opp, byUser: false);
    }

    if (graph.isLeaf(k)) return _endOfLine();

    if (userTurn) {
      final main = graph.mainMove(k);
      final own = graph.movesFrom(k);
      final trainable = graph.isTrainable(k) && main != null;
      final nodeRelevant = switch (config.mode) {
        TrainingMode.review => _isDueNow(k) && summary.reviewed < config.reviewLimit,
        TrainingMode.learn => _isNewNow(k) && _introduced.length < config.newLimit,
        TrainingMode.drill => _isUncovered(k),
        TrainingMode.problems => false,
      };
      if (trainable && nodeRelevant) {
        final demo = _phase == _LinePhase.learnDemo && _isNewNow(k);
        return _ask(main, demo: demo, isDue: config.mode == TrainingMode.review, isNewCard: demo);
      }
      // Choose which own move leads on.
      RepMove? next;
      if (main != null && _leadsOn(main)) {
        next = main;
      } else {
        for (final alt in own) {
          if (alt != main && _leadsOn(alt)) {
            next = alt;
            break;
          }
        }
      }
      if (next == null) return _endOfLine();
      if (next == main && trainable) {
        // Never quiz a move the user has not been shown: in Learn the line
        // ends (the new limit is reached), elsewhere it is played for them.
        if (_unseenNew(k)) {
          if (config.mode == TrainingMode.learn) return _endOfLine();
          return _auto(main, byUser: true, fast: true);
        }
        if (autoplay && config.mode == TrainingMode.review) {
          return _auto(main, byUser: true, fast: true);
        }
        return _ask(main);
      }
      return _auto(next, byUser: true, isAlternative: next.role == MoveRole.alternative);
    }

    // Opponent turn.
    final candidates = graph.movesFrom(k).where(_leadsOn).toList();
    if (candidates.isEmpty) return _endOfLine();
    final RepMove? chosen;
    if (config.mode == TrainingMode.learn) {
      // Deterministic: the most frequent line first.
      chosen = candidates.reduce((a, b) => b.weight > a.weight ? b : a);
    } else {
      chosen = chooseOpponentMove(candidates, config.strategy, _info, random);
    }
    return _auto(chosen!, byUser: false, fast: autoplay && config.mode == TrainingMode.review && !_hitDue);
  }

  /// A move worth following: something is left to train behind it and it
  /// does not return to a position of this line.
  bool _leadsOn(RepMove m) => _relevant(m.toKey) && !_passed.contains(m.toKey);

  TrainingStep _endOfLine() {
    if (_phase == _LinePhase.learnDemo && _introducedThisLine.isNotEmpty) {
      _recallPending = true;
      _recorded = [
        for (final lm in line)
          if (graph.move(lm.fromKey, lm.uci) != null) graph.move(lm.fromKey, lm.uci)!,
      ];
      return next();
    }
    return _completeLine();
  }

  AwaitUser _ask(RepMove expected, {bool demo = false, bool isDue = false, bool isNewCard = false}) {
    _resetQuestion();
    if (isDue) _hitDue = true;
    _questionStartedAt = _now;
    _awaiting = AwaitUser(key: key, expected: expected, demo: demo, isDue: isDue, isNewCard: isNewCard);
    return _awaiting!;
  }

  DateTime? _questionStartedAt;

  AutoMove _auto(RepMove m, {required bool byUser, bool fast = false, bool isAlternative = false}) {
    _apply(m, byUser: byUser, auto: true);
    return AutoMove(m, byUserSide: byUser, fast: fast, isAlternative: isAlternative);
  }

  void _apply(
    RepMove m, {
    required bool byUser,
    required bool auto,
    int mistakes = 0,
    bool hinted = false,
    Grade? grade,
  }) {
    final move = parseUciMove(position, m.uci);
    if (move == null) {
      throw StateError('Illegal repertoire move ${m.uci} in ${position.fen}');
    }
    final fenBefore = position.fen;
    _passed.add(m.fromKey);
    position = position.play(move);
    if (_target != null && !_targetReached) _targetIndex++;
    if (_phase == _LinePhase.learnRecall) _replayIndex++;
    final comment = [m.comment, graph.positions[m.toKey]?.comment ?? ''].where((t) => t.isNotEmpty).join('\n');
    line.add(
      LineMove(
        san: m.san,
        uci: m.uci,
        fromKey: m.fromKey,
        byUser: byUser,
        fenBefore: fenBefore,
        comment: comment,
        mistakes: mistakes,
        hinted: hinted,
        grade: grade,
        auto: auto,
      ),
    );
  }

  // ------------------------------------------------------------ answers

  /// Handles a move made by the user on the board.
  MoveOutcome submitMove(Move move, {Duration? responseTime}) {
    final q = _awaiting;
    if (q == null) throw StateError('Not waiting for a user move');
    final pos = position;
    final norm = normalizeMove(pos, move);
    if (!pos.isLegal(norm)) return MoveOutcome(MoveVerdict.wrong, expected: q.expected);
    final uci = standardUci(pos, norm);
    final played = graph.move(q.key, uci);
    final elapsed = responseTime ?? _now.difference(_questionStartedAt ?? _now);

    if (q.demo) {
      // Demonstration: the move is shown, no grading; wrong moves just retry.
      if (uci != q.expected.uci) {
        return MoveOutcome(MoveVerdict.wrong, expected: q.expected, reveal: true);
      }
      _introduced.add(q.key);
      _introducedThisLine.add(q.key);
      _awaiting = null;
      _apply(q.expected, byUser: true, auto: false);
      return MoveOutcome(MoveVerdict.correct, played: q.expected, expected: q.expected, comment: line.last.comment);
    }

    final isExpected = uci == q.expected.uci;
    if (!isExpected && played != null && played.role == MoveRole.alternative && played.fromKey == q.key) {
      if (!config.acceptAlternatives || _phase == _LinePhase.learnRecall || _target != null) {
        return MoveOutcome(MoveVerdict.alternativeRejected, played: played, expected: q.expected);
      }
      final grade = _grade(q, played.uci, elapsed);
      _awaiting = null;
      _apply(played, byUser: true, auto: false, mistakes: _attempts, hinted: _hintLevel > 0 || _revealed, grade: grade);
      return MoveOutcome(
        MoveVerdict.alternativeAccepted,
        played: played,
        expected: q.expected,
        grade: grade,
        comment: line.last.comment,
      );
    }
    if (!isExpected) {
      _attempts++;
      _firstWrongUci ??= uci;
      summary.mistakes++;
      if (_attempts >= config.mistakesBeforeReveal) _revealed = true;
      return MoveOutcome(MoveVerdict.wrong, played: played, expected: q.expected, reveal: _revealed);
    }
    final grade = _grade(q, uci, elapsed);
    _awaiting = null;
    _apply(
      q.expected,
      byUser: true,
      auto: false,
      mistakes: _attempts,
      hinted: _hintLevel > 0 || _revealed,
      grade: grade,
    );
    if (_target != null && _targetReached && q.key != _target) _tailLeft--;
    return MoveOutcome(
      MoveVerdict.correct,
      played: q.expected,
      expected: q.expected,
      grade: grade,
      comment: line.last.comment,
    );
  }

  /// Grades the answer at [q] and emits a [ReviewEvent]. Returns the grade.
  Grade? _grade(AwaitUser q, String playedUci, Duration elapsed) {
    final card = graph.cards[q.key];
    if (card == null) return null;
    final firstTry = _attempts == 0;
    final usedHint = _hintLevel > 0 || _revealed;
    final grade = config.grading.grade(firstTry: firstTry, usedHint: usedHint, responseTime: elapsed);
    final before = card.srs;
    final now = _now;
    SrsState after = before;
    var scheduled = false;
    var mode = config.mode.name;

    void schedule(Grade g) {
      after = fsrs.review(before, g, now);
      scheduled = true;
    }

    void light() {
      mode = 'light';
      if (grade == Grade.again) schedule(Grade.again);
    }

    final isTarget = _target != null && q.key == _target;
    switch (config.mode) {
      case TrainingMode.review:
        if (isTarget) {
          schedule(grade);
          _requeueIfNeeded(q.key, grade);
        } else if (_isDueNow(q.key) && summary.reviewed < config.reviewLimit) {
          // Over the daily limit a due move is still asked on the way, but
          // it stays due for another day instead of being scheduled.
          schedule(grade);
          _reviewed.add(q.key);
          summary.reviewed++;
          _requeueIfNeeded(q.key, grade);
        } else {
          light();
        }
      case TrainingMode.learn:
        if (_phase == _LinePhase.learnRecall && _introducedThisLine.contains(q.key) || isTarget) {
          // First real review of a new card: never "easy" right away.
          final g = grade == Grade.easy ? Grade.good : grade;
          after = fsrs.review(before, g, now);
          scheduled = true;
          if (!isTarget) summary.introduced++;
          _requeueIfNeeded(q.key, g);
        } else {
          light();
        }
      case TrainingMode.drill:
        _covered.add(q.key);
        if (config.drillAffectsSchedule) {
          schedule(grade);
        } else {
          mode = 'drill';
        }
      case TrainingMode.problems:
        mode = 'problems';
        if (grade == Grade.again) schedule(Grade.again);
    }
    summary.grades[grade] = (summary.grades[grade] ?? 0) + 1;
    if (scheduled) graph.updateCard(q.key, after);
    onReview?.call(
      ReviewEvent(
        key: q.key,
        before: before,
        after: after,
        grade: grade,
        mode: mode,
        playedUci: _firstWrongUci ?? playedUci,
        expectedUci: q.expected.uci,
        responseMs: elapsed.inMilliseconds,
        scheduled: scheduled,
        timestamp: now,
      ),
    );
    return grade;
  }

  void _requeueIfNeeded(PositionKey k, Grade g) {
    if (g != Grade.again) return;
    final n = _requeueCount[k] ?? 0;
    if (n >= config.maxRequeue) return;
    _requeueCount[k] = n + 1;
    _requeue.add(k);
  }

  /// Step-wise hint (F-TRN-12): piece, then square, then arrow.
  HintInfo? requestHint() {
    final q = _awaiting;
    if (q == null) return null;
    _hintLevel = math.min(3, _hintLevel + 1);
    final move = parseUciMove(position, q.expected.uci);
    Square? from;
    Square to;
    if (move is NormalMove) {
      from = move.from;
      final std = NormalMove.fromUci(q.expected.uci);
      to = std.to;
    } else {
      to = move!.to;
    }
    return HintInfo(_hintLevel, from, to);
  }

  /// Gives up on the current question: reveals the move (counts as a hint).
  void reveal() {
    if (_awaiting == null) return;
    _revealed = true;
    _hintLevel = 3;
  }
}
