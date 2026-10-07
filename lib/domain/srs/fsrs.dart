/// FSRS-6 (Free Spaced Repetition Scheduler) implementation.
///
/// Own implementation following the reference formulas of
/// https://github.com/open-spaced-repetition (py-fsrs / fsrs-rs, v6).
/// Deterministic (no interval fuzz), so that scheduling is reproducible in
/// tests. One card = one position where the user is to move (F-TRN-06).
library;

import 'dart:math' as math;

/// Review grade. Values match FSRS ratings 1..4.
enum Grade {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const Grade(this.value);
  final int value;

  static Grade fromName(String name) => Grade.values.firstWhere((g) => g.name == name, orElse: () => Grade.good);
}

enum CardState {
  newCard,
  learning,
  review,
  relearning;

  static CardState fromName(String name) =>
      CardState.values.firstWhere((s) => s.name == name, orElse: () => CardState.newCard);
}

/// Scheduling state of a card. Immutable.
class SrsState {
  const SrsState({
    this.stability = 0,
    this.difficulty = 0,
    this.due,
    this.lastReview,
    this.reps = 0,
    this.lapses = 0,
    this.state = CardState.newCard,
  });

  final double stability;
  final double difficulty;

  /// Null for new cards (never reviewed).
  final DateTime? due;
  final DateTime? lastReview;
  final int reps;
  final int lapses;
  final CardState state;

  bool get isNew => state == CardState.newCard;

  SrsState copyWith({
    double? stability,
    double? difficulty,
    DateTime? due,
    DateTime? lastReview,
    int? reps,
    int? lapses,
    CardState? state,
  }) => SrsState(
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    due: due ?? this.due,
    lastReview: lastReview ?? this.lastReview,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    state: state ?? this.state,
  );

  Map<String, Object?> toJson() => {
    's': stability,
    'd': difficulty,
    'due': due?.toUtc().toIso8601String(),
    'last': lastReview?.toUtc().toIso8601String(),
    'reps': reps,
    'lapses': lapses,
    'state': state.name,
  };

  factory SrsState.fromJson(Map<String, Object?> j) => SrsState(
    stability: (j['s'] as num?)?.toDouble() ?? 0,
    difficulty: (j['d'] as num?)?.toDouble() ?? 0,
    due: j['due'] == null ? null : DateTime.parse(j['due']! as String),
    lastReview: j['last'] == null ? null : DateTime.parse(j['last']! as String),
    reps: (j['reps'] as num?)?.toInt() ?? 0,
    lapses: (j['lapses'] as num?)?.toInt() ?? 0,
    state: CardState.fromName((j['state'] as String?) ?? 'newCard'),
  );

  @override
  String toString() =>
      'SrsState($state, S=${stability.toStringAsFixed(2)}, '
      'D=${difficulty.toStringAsFixed(2)}, due=$due, reps=$reps, lapses=$lapses)';
}

class FsrsParams {
  const FsrsParams({
    this.w = defaultWeights,
    this.desiredRetention = 0.9,
    this.maximumIntervalDays = 3650,
    this.relearnDelay = const Duration(minutes: 10),
    this.dayStartHour = 4,
  });

  /// FSRS-6 default parameters (21 weights).
  static const defaultWeights = <double>[
    0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, //
    0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425,
    0.0912, 0.0658, 0.1542,
  ];

  final List<double> w;
  final double desiredRetention;
  final int maximumIntervalDays;

  /// Delay before a lapsed card becomes due again (it is also re-queued
  /// in the current session, F-TRN-08).
  final Duration relearnDelay;

  /// Local hour at which a new "study day" begins. Cards scheduled N days
  /// ahead become due at this hour, so a card is due for the whole day.
  final int dayStartHour;
}

class Fsrs {
  Fsrs([this.params = const FsrsParams()]);

  final FsrsParams params;

  static const double _minStability = 0.001;

  List<double> get _w => params.w;
  double get _decay => -_w[20];
  double get _factor => math.pow(0.9, 1 / _decay).toDouble() - 1;

  /// Probability of recall after [elapsedDays] with stability [s].
  double retrievability(double elapsedDays, double s) {
    if (s <= 0) return 0;
    return math.pow(1 + _factor * math.max(0, elapsedDays) / s, _decay).toDouble();
  }

  /// Current retrievability of a card at [now] (1.0 for new cards).
  double currentRetrievability(SrsState st, DateTime now) {
    if (st.isNew || st.lastReview == null) return 0;
    final t = now.difference(st.lastReview!).inSeconds / 86400.0;
    return retrievability(t, st.stability);
  }

  double nextIntervalDays(double s) {
    final r = params.desiredRetention;
    final ivl = s / _factor * (math.pow(r, 1 / _decay) - 1);
    return ivl.clamp(1, params.maximumIntervalDays.toDouble()).toDouble();
  }

  double _initStability(Grade g) => math.max(_w[g.value - 1], _minStability);

  double _initDifficulty(Grade g) => (_w[4] - math.exp(_w[5] * (g.value - 1)) + 1).toDouble();

  double _clampD(double d) => d.clamp(1.0, 10.0).toDouble();

  double _nextDifficulty(double d, Grade g) {
    final delta = -_w[6] * (g.value - 3);
    final dPrime = d + delta * (10 - d) / 9;
    final target = _initDifficulty(Grade.easy);
    return _clampD(_w[7] * target + (1 - _w[7]) * dPrime);
  }

  double _recallStability(double d, double s, double r, Grade g) {
    final hardPenalty = g == Grade.hard ? _w[15] : 1.0;
    final easyBonus = g == Grade.easy ? _w[16] : 1.0;
    return s *
        (1 +
            math.exp(_w[8]) *
                (11 - d) *
                math.pow(s, -_w[9]) *
                (math.exp((1 - r) * _w[10]) - 1) *
                hardPenalty *
                easyBonus);
  }

  double _forgetStability(double d, double s, double r) {
    final longTerm = _w[11] * math.pow(d, -_w[12]) * (math.pow(s + 1, _w[13]) - 1) * math.exp((1 - r) * _w[14]);
    final shortTermCap = s / math.exp(_w[17] * _w[18]);
    return math.min(longTerm, shortTermCap).toDouble();
  }

  double _shortTermStability(double s, Grade g) {
    final inc = math.exp(_w[17] * (g.value - 3 + _w[18])) * math.pow(s, -_w[19]);
    final next = s * (g.value >= 3 ? math.max(inc, 1.0) : inc);
    return next.toDouble();
  }

  /// Start of the study day that contains [t] (local time).
  DateTime dayStart(DateTime t) {
    final local = t.toLocal();
    var start = DateTime(local.year, local.month, local.day, params.dayStartHour);
    if (local.isBefore(start)) {
      start = start.subtract(const Duration(days: 1));
    }
    return start;
  }

  /// End of the study day that contains [t].
  DateTime dayEnd(DateTime t) => _addDays(dayStart(t), 1);

  DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  /// Applies a review with [grade] at [now] and returns the new state.
  SrsState review(SrsState st, Grade grade, DateTime now) {
    double s;
    double d;
    if (st.isNew || st.lastReview == null) {
      s = _initStability(grade);
      d = _clampD(_initDifficulty(grade));
    } else {
      final elapsed = now.difference(st.lastReview!).inSeconds / 86400.0;
      final sameDay = !dayStart(st.lastReview!).isBefore(dayStart(now));
      if (sameDay || elapsed < 1) {
        s = _shortTermStability(st.stability, grade);
      } else {
        final r = retrievability(elapsed, st.stability);
        s = grade == Grade.again
            ? _forgetStability(st.difficulty, st.stability, r)
            : _recallStability(st.difficulty, st.stability, r, grade);
      }
      d = _nextDifficulty(st.difficulty, grade);
    }
    s = math.max(s, _minStability);

    final CardState state;
    final DateTime due;
    var lapses = st.lapses;
    if (grade == Grade.again) {
      state = st.state == CardState.review || st.state == CardState.relearning
          ? CardState.relearning
          : CardState.learning;
      if (st.state == CardState.review) lapses++;
      due = now.add(params.relearnDelay);
    } else {
      state = CardState.review;
      final days = nextIntervalDays(s).round().clamp(1, params.maximumIntervalDays);
      due = _addDays(dayStart(now), days);
    }
    return SrsState(
      stability: s,
      difficulty: d,
      due: due,
      lastReview: now,
      reps: st.reps + 1,
      lapses: lapses,
      state: state,
    );
  }

  /// A "light" check of a non-due card on the way to a due one (F-TRN §5.4):
  /// a correct answer does not change the schedule; a mistake is recorded
  /// as `again`.
  SrsState lightCheck(SrsState st, {required bool correct, required DateTime now}) =>
      correct ? st : review(st, Grade.again, now);

  /// Whether a card is due at [now].
  bool isDue(SrsState st, DateTime now) => !st.isNew && st.due != null && !st.due!.isAfter(now);

  /// Overdue amount in days (negative if not yet due). New cards: null.
  double? overdueDays(SrsState st, DateTime now) {
    if (st.isNew || st.due == null) return null;
    return now.difference(st.due!).inSeconds / 86400.0;
  }
}

/// Automatic grading (F-TRN-07).
class GradingPolicy {
  const GradingPolicy({
    this.goodThreshold = const Duration(seconds: 10),
    this.easyThreshold = const Duration(seconds: 3),
    this.easyEnabled = true,
    this.timed = true,
  });

  final Duration goodThreshold;
  final Duration easyThreshold;
  final bool easyEnabled;

  /// When false the time taken does not matter: right at the first try
  /// without a hint is always "good".
  final bool timed;

  Grade grade({required bool firstTry, required bool usedHint, required Duration responseTime}) {
    if (!firstTry || usedHint) return Grade.again;
    if (!timed) return Grade.good;
    if (responseTime > goodThreshold) return Grade.hard;
    if (easyEnabled && responseTime <= easyThreshold) return Grade.easy;
    return Grade.good;
  }
}
