import 'dart:convert';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:drift/drift.dart';

import '../../core/now.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../../domain/srs/fsrs.dart';
import '../../domain/training/opponent_strategy.dart';
import '../../domain/training/training_engine.dart';
import '../db/database.dart';

/// Per-repertoire training options (ТЗ 5.3).
class RepertoireOptions {
  const RepertoireOptions({this.strategy, this.acceptAlternatives});

  /// null = use the app default.
  final OpponentStrategy? strategy;
  final bool? acceptAlternatives;

  Map<String, Object?> toJson() => {
    if (strategy != null) 'strategy': strategy!.name,
    if (acceptAlternatives != null) 'acceptAlternatives': acceptAlternatives,
  };

  factory RepertoireOptions.decode(String s) {
    try {
      final j = (jsonDecode(s) as Map).cast<String, Object?>();
      return RepertoireOptions(
        strategy: j['strategy'] == null ? null : OpponentStrategy.fromName(j['strategy'] as String?),
        acceptAlternatives: j['acceptAlternatives'] as bool?,
      );
    } catch (_) {
      return const RepertoireOptions();
    }
  }

  String encode() => jsonEncode(toJson());
}

class RepertoireSummary {
  const RepertoireSummary({
    required this.row,
    required this.positions,
    required this.cards,
    required this.due,
    required this.newCards,
    required this.suspended,
    this.learned = 0,
  });

  final RepertoireRow row;
  final int positions;
  final int cards;
  final int due;
  final int newCards;
  final int suspended;

  Side get color => row.color == 'black' ? Side.black : Side.white;

  /// Cards reviewed at least once (suspended new cards are not "learned").
  final int learned;
  RepertoireOptions get options => RepertoireOptions.decode(row.optionsJson);
}

class ProblemPosition {
  const ProblemPosition(this.repertoireId, this.key, this.errors, this.lastSeen);
  final int repertoireId;
  final PositionKey key;
  final int errors;
  final DateTime lastSeen;
}

class DayCount {
  const DayCount(this.day, this.count);
  final DateTime day;
  final int count;
}

String encodeShapes(List<BoardShape> shapes) => shapes.map((s) => s.encoded).join(',');

List<BoardShape> decodeShapes(String s) =>
    s.isEmpty ? [] : s.split(',').map(BoardShape.parse).whereType<BoardShape>().toList();

/// The rows of a deleted repertoire (see [RepertoireRepository.snapshot]).
class RepertoireSnapshot {
  RepertoireSnapshot._(this._row, this._positions, this._moves, this._cards, this._logs, this._gaps);
  final RepertoireRow _row;
  final List<RepPositionRow> _positions;
  final List<RepMoveRow> _moves;
  final List<CardRow> _cards;
  final List<ReviewLogRow> _logs;
  final List<GapEventRow> _gaps;
}

class RepertoireRepository {
  RepertoireRepository(this.db, {Fsrs? fsrs}) : fsrs = fsrs ?? Fsrs();
  final AppDatabase db;
  Fsrs fsrs;

  // ------------------------------------------------------------ list

  Stream<List<RepertoireSummary>> watchSummaries() {
    // "Now" is taken by SQLite on every re-run (dates are unix seconds), not
    // frozen at subscription time; Today also re-subscribes at the next due.
    return db
        .customSelect(
          '''
SELECT r.*,
  (SELECT COUNT(*) FROM rep_positions p WHERE p.repertoire_id = r.id) AS n_pos,
  (SELECT COUNT(*) FROM cards c WHERE c.repertoire_id = r.id) AS n_cards,
  (SELECT COUNT(*) FROM cards c JOIN rep_positions p ON p.repertoire_id = c.repertoire_id AND p.position_key = c.position_key
     WHERE c.repertoire_id = r.id AND c.suspended = 0 AND p.conflict_deferred = 0 AND c.state != 'newCard'
       AND c.due <= CAST(strftime('%s', 'now') AS INTEGER)) AS n_due,
  (SELECT COUNT(*) FROM cards c JOIN rep_positions p ON p.repertoire_id = c.repertoire_id AND p.position_key = c.position_key
     WHERE c.repertoire_id = r.id AND c.state = 'newCard' AND c.suspended = 0 AND p.conflict_deferred = 0) AS n_new,
  (SELECT COUNT(*) FROM cards c WHERE c.repertoire_id = r.id AND c.state != 'newCard') AS n_learned,
  (SELECT COUNT(*) FROM cards c WHERE c.repertoire_id = r.id AND c.suspended = 1) AS n_susp
FROM repertoires r ORDER BY r.sort_order, r.created_at
''',
          readsFrom: {db.repertoires, db.repPositions, db.cards},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              RepertoireSummary(
                row: db.repertoires.map(r.data),
                positions: r.read<int>('n_pos'),
                cards: r.read<int>('n_cards'),
                due: r.read<int>('n_due'),
                newCards: r.read<int>('n_new'),
                suspended: r.read<int>('n_susp'),
                learned: r.read<int>('n_learned'),
              ),
          ],
        );
  }

  Future<RepertoireRow?> repertoire(int id) =>
      (db.select(db.repertoires)..where((r) => r.id.equals(id))).getSingleOrNull();

  Stream<RepertoireRow?> watchRepertoire(int id) =>
      (db.select(db.repertoires)..where((r) => r.id.equals(id))).watchSingleOrNull();

  Future<int> create({required String name, required Side color, String? rootFen, String description = ''}) async {
    final fen = rootFen ?? kInitialFen;
    final key = normalizeFenToKey(fen);
    final now = DateTime.now();
    return db.transaction(() async {
      final id = await db
          .into(db.repertoires)
          .insert(
            RepertoiresCompanion.insert(
              name: name,
              color: color.name,
              rootKey: key,
              rootFen: positionFromFen(fen).fen,
              description: Value(description),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.repPositions)
          .insert(RepPositionsCompanion.insert(repertoireId: id, positionKey: key, fen: positionFromFen(fen).fen));
      return id;
    });
  }

  Future<void> update(int id, {String? name, String? description, RepertoireOptions? options}) =>
      (db.update(db.repertoires)..where((r) => r.id.equals(id))).write(
        RepertoiresCompanion(
          name: name == null ? const Value.absent() : Value(name),
          description: description == null ? const Value.absent() : Value(description),
          optionsJson: options == null ? const Value.absent() : Value(options.encode()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> delete(int id) => db.transaction(() async {
    // Today's answers still count for the daily goal after the repertoire
    // (and its log) is gone.
    final day = fsrs.dayStart(appNow());
    final today = await answersSince(day, repId: id, withCarry: false);
    if (today > 0) await _setGoalCarry(day, await _goalCarry(day) + today);
    await (db.delete(db.reviewLogs)..where((t) => t.repertoireId.equals(id))).go();
    await (db.delete(db.cards)..where((t) => t.repertoireId.equals(id))).go();
    await (db.delete(db.repMoves)..where((t) => t.repertoireId.equals(id))).go();
    await (db.delete(db.repPositions)..where((t) => t.repertoireId.equals(id))).go();
    await (db.delete(db.gapEvents)..where((t) => t.repertoireId.equals(id))).go();
    await (db.delete(db.repertoires)..where((t) => t.id.equals(id))).go();
  });

  /// Everything [delete] removes, to bring a repertoire back ("Undo").
  Future<RepertoireSnapshot?> snapshot(int id) async {
    final row = await repertoire(id);
    if (row == null) return null;
    return RepertoireSnapshot._(
      row,
      await (db.select(db.repPositions)..where((t) => t.repertoireId.equals(id))).get(),
      await (db.select(db.repMoves)..where((t) => t.repertoireId.equals(id))).get(),
      await (db.select(db.cards)..where((t) => t.repertoireId.equals(id))).get(),
      await (db.select(db.reviewLogs)..where((t) => t.repertoireId.equals(id))).get(),
      await (db.select(db.gapEvents)..where((t) => t.repertoireId.equals(id))).get(),
    );
  }

  Future<void> restoreSnapshot(RepertoireSnapshot s) => db.transaction(() async {
    await db.into(db.repertoires).insert(s._row);
    await db.batch((b) {
      b.insertAll(db.repPositions, s._positions);
      b.insertAll(db.repMoves, s._moves);
      b.insertAll(db.cards, s._cards);
      b.insertAll(db.reviewLogs, s._logs);
      b.insertAll(db.gapEvents, s._gaps);
    });
    // The answers are back in the log: stop carrying them separately.
    final day = fsrs.dayStart(appNow());
    final today = s._logs.where((l) => !l.timestamp.isBefore(day)).length;
    final carry = await _goalCarry(day);
    if (today > 0 && carry > 0) await _setGoalCarry(day, carry > today ? carry - today : 0);
  });

  // ------------------------------------------------------------ graph

  Future<RepertoireGraph> loadGraph(int id) async {
    final rep = (await repertoire(id))!;
    final positions = await (db.select(db.repPositions)..where((p) => p.repertoireId.equals(id))).get();
    final moves = await (db.select(db.repMoves)..where((m) => m.repertoireId.equals(id))).get();
    final cards = await (db.select(db.cards)..where((c) => c.repertoireId.equals(id))).get();
    return RepertoireGraph.load(
      color: rep.color == 'black' ? Side.black : Side.white,
      rootKey: rep.rootKey,
      positions: [
        for (final p in positions)
          RepPosition(
            key: p.positionKey,
            fen: p.fen,
            comment: p.comment,
            shapes: decodeShapes(p.shapes),
            conflictDeferred: p.conflictDeferred,
            engineFlag: p.engineFlag,
          ),
      ],
      moves: [
        for (final m in moves)
          RepMove(
            fromKey: m.fromKey,
            uci: m.uci,
            toKey: m.toKey,
            san: m.san,
            role: MoveRole.fromDb(m.role),
            weight: m.weight,
            comment: m.comment,
            source: m.source,
            sortOrder: m.sortOrder,
            createdAt: m.createdAt,
          ),
      ],
      cards: {
        for (final c in cards)
          c.positionKey: CardInfo(
            srs: SrsState(
              stability: c.stability,
              difficulty: c.difficulty,
              due: c.due,
              lastReview: c.lastReview,
              reps: c.reps,
              lapses: c.lapses,
              state: CardState.fromName(c.state),
            ),
            suspended: c.suspended,
            createdAt: c.createdAt,
          ),
      },
    );
  }

  /// Persists the pending changes of [graph] in one transaction.
  Future<void> saveGraph(int id, RepertoireGraph graph) async {
    if (graph.changes.isEmpty) return;
    // Take the changes first: edits made while this transaction runs stay
    // pending for the next save instead of being cleared unwritten.
    final ch = graph.changes.take();
    try {
      await _writeChanges(id, graph, ch);
    } catch (_) {
      graph.changes.restore(ch);
      rethrow;
    }
  }

  Future<void> _writeChanges(int id, RepertoireGraph graph, GraphChanges ch) async {
    await db.transaction(() async {
      await db.batch((b) {
        for (final id2 in ch.deleteMoves) {
          final i = id2.lastIndexOf('|');
          b.deleteWhere(
            db.repMoves,
            (m) =>
                m.repertoireId.equals(id) & m.fromKey.equals(id2.substring(0, i)) & m.uci.equals(id2.substring(i + 1)),
          );
        }
        for (final k in ch.deleteCards) {
          b.deleteWhere(db.cards, (c) => c.repertoireId.equals(id) & c.positionKey.equals(k));
        }
        for (final k in ch.deletePositions) {
          b.deleteWhere(db.repPositions, (p) => p.repertoireId.equals(id) & p.positionKey.equals(k));
        }
        for (final k in ch.upsertPositions) {
          final p = graph.positions[k];
          if (p == null) continue;
          b.insert(
            db.repPositions,
            RepPositionsCompanion.insert(
              repertoireId: id,
              positionKey: k,
              fen: p.fen,
              comment: Value(p.comment),
              shapes: Value(encodeShapes(p.shapes)),
              conflictDeferred: Value(p.conflictDeferred),
              engineFlag: Value(p.engineFlag),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final mid in ch.upsertMoves) {
          final m = graph.moveById(mid);
          if (m == null) continue;
          b.insert(
            db.repMoves,
            RepMovesCompanion.insert(
              repertoireId: id,
              fromKey: m.fromKey,
              uci: m.uci,
              toKey: m.toKey,
              san: m.san,
              role: Value(m.role.dbValue),
              weight: Value(m.weight),
              comment: Value(m.comment),
              source: Value(m.source),
              sortOrder: Value(m.sortOrder),
              createdAt: m.createdAt,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final k in ch.upsertCards) {
          final c = graph.cards[k];
          if (c == null) continue;
          b.insert(db.cards, _cardCompanion(id, k, c), mode: InsertMode.insertOrReplace);
        }
      });
      await (db.update(
        db.repertoires,
      )..where((r) => r.id.equals(id))).write(RepertoiresCompanion(updatedAt: Value(DateTime.now())));
    });
  }

  CardsCompanion _cardCompanion(int repId, PositionKey k, CardInfo c) => CardsCompanion.insert(
    repertoireId: repId,
    positionKey: k,
    stability: Value(c.srs.stability),
    difficulty: Value(c.srs.difficulty),
    due: Value(c.srs.due),
    lastReview: Value(c.srs.lastReview),
    reps: Value(c.srs.reps),
    lapses: Value(c.srs.lapses),
    state: Value(c.srs.state.name),
    suspended: Value(c.suspended),
    createdAt: c.createdAt,
  );

  // ------------------------------------------------------------ reviews

  /// Stores a review: log + new card state (F-TRN-10).
  Future<void> recordReview(int repId, ReviewEvent e, {bool suspended = false}) => db.transaction(() async {
    await db
        .into(db.reviewLogs)
        .insert(
          ReviewLogsCompanion.insert(
            repertoireId: repId,
            positionKey: e.key,
            timestamp: e.timestamp,
            grade: e.grade.name,
            playedUci: Value(e.playedUci),
            expectedUci: Value(e.expectedUci),
            mode: e.mode,
            responseMs: Value(e.responseMs),
            scheduled: Value(e.scheduled),
          ),
        );
    if (e.scheduled) {
      await (db.update(db.cards)..where((c) => c.repertoireId.equals(repId) & c.positionKey.equals(e.key))).write(
        CardsCompanion(
          stability: Value(e.after.stability),
          difficulty: Value(e.after.difficulty),
          due: Value(e.after.due),
          lastReview: Value(e.after.lastReview),
          reps: Value(e.after.reps),
          lapses: Value(e.after.lapses),
          state: Value(e.after.state.name),
        ),
      );
    }
  });

  /// Marks a card `again` (e.g. from a game deviation, F-GAP-03). Returns
  /// false when there is nothing to reschedule: a move that was never
  /// learned goes through Learn first, a suspended one stays suspended.
  Future<bool> markAgain(int repId, PositionKey key) async {
    final row = await (db.select(
      db.cards,
    )..where((c) => c.repertoireId.equals(repId) & c.positionKey.equals(key))).getSingleOrNull();
    if (row == null || row.suspended) return false;
    final before = _srs(row);
    if (before.isNew) return false;
    final now = DateTime.now();
    final after = fsrs.review(before, Grade.again, now);
    await recordReview(
      repId,
      ReviewEvent(
        key: key,
        before: before,
        after: after,
        grade: Grade.again,
        mode: 'game',
        playedUci: '',
        expectedUci: '',
        responseMs: 0,
        scheduled: true,
        timestamp: now,
      ),
    );
    return true;
  }

  SrsState _srs(CardRow c) => SrsState(
    stability: c.stability,
    difficulty: c.difficulty,
    due: c.due,
    lastReview: c.lastReview,
    reps: c.reps,
    lapses: c.lapses,
    state: CardState.fromName(c.state),
  );

  // ------------------------------------------------------------ statistics

  /// Scheduled reviews done since [since] (learn + review modes).
  Future<int> reviewsSince(
    DateTime since, {
    int? repId,
    List<String> modes = const ['review'],
    bool onlyScheduled = true,
  }) async {
    // Distinct positions: a move repeated after a mistake in the same
    // session counts once, as it does in the session itself.
    final c = (db.reviewLogs.repertoireId.cast<String>() + const Constant('|') + db.reviewLogs.positionKey).count(
      distinct: true,
    );
    final q = db.selectOnly(db.reviewLogs)
      ..addColumns([c])
      ..where(db.reviewLogs.timestamp.isBiggerOrEqualValue(since) & db.reviewLogs.mode.isIn(modes));
    if (onlyScheduled) q.where(db.reviewLogs.scheduled.equals(true));
    if (repId != null) q.where(db.reviewLogs.repertoireId.equals(repId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  static const _goalCarryKey = 'goalCarry';

  /// Answers of the study day starting at [day] that belonged to
  /// repertoires deleted since.
  Future<int> _goalCarry(DateTime day) async {
    final row = await (db.select(db.settings)..where((t) => t.key.equals(_goalCarryKey))).getSingleOrNull();
    if (row == null) return 0;
    try {
      final m = jsonDecode(row.value) as Map<String, dynamic>;
      return m['day'] == day.toIso8601String() ? (m['count'] as num).toInt() : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _setGoalCarry(DateTime day, int count) => db
      .into(db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: _goalCarryKey, value: jsonEncode({'day': day.toIso8601String(), 'count': count})),
      );

  /// Every answer given since [since], in any mode: what the daily goal
  /// counts (D-058). [since] is the start of a study day.
  Future<int> answersSince(DateTime since, {int? repId, bool withCarry = true}) async {
    final c = db.reviewLogs.id.count();
    final q = db.selectOnly(db.reviewLogs)
      ..addColumns([c])
      ..where(db.reviewLogs.timestamp.isBiggerOrEqualValue(since));
    if (repId != null) q.where(db.reviewLogs.repertoireId.equals(repId));
    final n = (await q.getSingle()).read(c) ?? 0;
    return withCarry && repId == null ? n + await _goalCarry(since) : n;
  }

  /// Number of new cards introduced since [since] (first scheduled review).
  Future<int> introducedSince(DateTime since, {int? repId}) async {
    final rows = await db
        .customSelect(
          '''
SELECT COUNT(*) AS n FROM cards WHERE reps > 0 AND ${repId != null ? 'repertoire_id = ? AND' : ''}
  (SELECT MIN(timestamp) FROM review_logs l WHERE l.repertoire_id = cards.repertoire_id
     AND l.position_key = cards.position_key AND l.scheduled = 1) >= ?
''',
          variables: [if (repId != null) Variable.withInt(repId), Variable.withDateTime(since)],
          readsFrom: {db.cards, db.reviewLogs},
        )
        .getSingle();
    return rows.read<int>('n');
  }

  /// Answers per local day (for streaks and the activity chart).
  Future<List<DayCount>> activityByDay({int days = 90, int? repId}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows =
        await (db.select(db.reviewLogs)..where(
              (l) =>
                  l.timestamp.isBiggerOrEqualValue(since) &
                  (repId == null ? const Constant(true) : l.repertoireId.equals(repId)),
            ))
            .get();
    final map = <DateTime, int>{};
    for (final r in rows) {
      final d = fsrs.dayStart(r.timestamp);
      final day = DateTime(d.year, d.month, d.day);
      map[day] = (map[day] ?? 0) + 1;
    }
    final list = map.entries.map((e) => DayCount(e.key, e.value)).toList()..sort((a, b) => a.day.compareTo(b.day));
    return list;
  }

  /// Answers per study day for the last [days] days, oldest first, counted
  /// like the daily goal (every answer, all modes).
  Future<List<int>> answersPerDay({int days = 7}) async {
    final today = fsrs.dayStart(appNow());
    final first = DateTime(today.year, today.month, today.day - (days - 1), today.hour, today.minute);
    final rows = await (db.select(db.reviewLogs)..where((l) => l.timestamp.isBiggerOrEqualValue(first))).get();
    final counts = List<int>.filled(days, 0);
    for (final r in rows) {
      final i = days - 1 - calendarDaysBetween(fsrs.dayStart(r.timestamp), today);
      if (i >= 0 && i < days) counts[i]++;
    }
    counts[days - 1] += await _goalCarry(today);
    return counts;
  }

  /// Consecutive study days up to today (F-STAT-04).
  Future<int> streak() async {
    final days = await activityByDay(days: 400);
    final set = {for (final d in days) d.day};
    final today = fsrs.dayStart(appNow());
    var day = DateTime(today.year, today.month, today.day);
    var n = 0;
    // Calendar arithmetic: "minus 24 hours" lands on 23:00 or 01:00 around
    // a daylight-saving switch and would break the streak.
    if (!set.contains(day)) day = DateTime(day.year, day.month, day.day - 1);
    while (set.contains(day)) {
      n++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return n;
  }

  /// Due cards per day for the next [days] days (F-STAT-01).
  Future<List<DayCount>> forecast({int days = 30, int? repId}) async {
    final now = appNow();
    final end = now.add(Duration(days: days));
    final q = db.select(db.cards)
      ..where((c) => c.state.equals('newCard').not() & c.suspended.equals(false) & c.due.isSmallerOrEqualValue(end));
    if (repId != null) q.where((c) => c.repertoireId.equals(repId));
    final rows = await q.get();
    final todayStart = fsrs.dayStart(now);
    final counts = List<int>.filled(days + 1, 0);
    for (final r in rows) {
      final due = r.due!;
      final diff = due.isBefore(now) ? 0 : calendarDaysBetween(todayStart, fsrs.dayStart(due));
      if (diff >= 0 && diff <= days) counts[diff]++;
    }
    return [
      for (var i = 0; i <= days; i++)
        DayCount(DateTime(todayStart.year, todayStart.month, todayStart.day + i), counts[i]),
    ];
  }

  /// Share of correct answers in scheduled reviews since [since] (F-STAT-02).
  Future<(int total, int correct)> retention(DateTime since, {int? repId}) async {
    final q = db.select(db.reviewLogs)
      ..where((l) => l.timestamp.isBiggerOrEqualValue(since) & l.mode.equals('review') & l.scheduled.equals(true));
    if (repId != null) q.where((l) => l.repertoireId.equals(repId));
    final rows = await q.get();
    final correct = rows.where((r) => r.grade != 'again').length;
    return (rows.length, correct);
  }

  /// Positions with repeated mistakes in the last [days] days (F-TRN-04).
  /// One slip is not a problem yet: [minMistakes] of them are (D-059).
  Future<List<ProblemPosition>> problemPositions({
    int? repId,
    int days = 30,
    int limit = 30,
    int minMistakes = 2,
  }) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await db
        .customSelect(
          '''
SELECT repertoire_id, position_key, COUNT(*) AS n, MAX(timestamp) AS last FROM review_logs
WHERE grade = 'again' AND timestamp >= ? ${repId != null ? 'AND repertoire_id = ?' : ''}
GROUP BY repertoire_id, position_key HAVING COUNT(*) >= $minMistakes ORDER BY n DESC, last DESC LIMIT ?
''',
          variables: [
            Variable.withDateTime(since),
            if (repId != null) Variable.withInt(repId),
            Variable.withInt(limit),
          ],
          readsFrom: {db.reviewLogs},
        )
        .get();
    return [
      for (final r in rows)
        ProblemPosition(
          r.read<int>('repertoire_id'),
          r.read<String>('position_key'),
          r.read<int>('n'),
          DateTime.fromMillisecondsSinceEpoch(r.read<int>('last') * 1000),
        ),
    ];
  }

  Future<List<ReviewLogRow>> logsFor(int repId, PositionKey key, {int limit = 50}) =>
      (db.select(db.reviewLogs)
            ..where((l) => l.repertoireId.equals(repId) & l.positionKey.equals(key))
            ..orderBy([(l) => OrderingTerm.desc(l.timestamp)])
            ..limit(limit))
          .get();

  /// When the next review becomes due (null if nothing is scheduled).
  Future<DateTime?> nextDue({int? repId}) async {
    final min = db.cards.due.min();
    final q = db.selectOnly(db.cards)
      ..addColumns([min])
      ..where(
        db.cards.state.equals('newCard').not() &
            db.cards.suspended.equals(false) &
            db.cards.due.isBiggerThanValue(DateTime.now()),
      );
    if (repId != null) q.where(db.cards.repertoireId.equals(repId));
    return (await q.getSingle()).read(min);
  }

  Future<int> totalDue() async {
    final rows = await db
        .customSelect(
          '''
SELECT COUNT(*) AS n FROM cards c JOIN rep_positions p ON p.repertoire_id = c.repertoire_id AND p.position_key = c.position_key
WHERE c.suspended = 0 AND p.conflict_deferred = 0 AND c.state != 'newCard' AND c.due <= ?
''',
          variables: [Variable.withDateTime(DateTime.now())],
          readsFrom: {db.cards, db.repPositions},
        )
        .getSingle();
    return rows.read<int>('n');
  }
}
