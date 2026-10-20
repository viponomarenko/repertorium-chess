/// Puzzles from Lichess, the offline pack when Lichess cannot give them,
/// and the player's puzzle rating (D-123, D-125, D-126). The rating lives
/// in the settings table, so backups carry it.
library;

import 'dart:async';

import 'package:drift/drift.dart';

import '../../domain/puzzles/glicko2.dart';
import '../../domain/puzzles/puzzle.dart';
import '../../domain/puzzles/puzzle_pack.dart';
import '../../domain/puzzles/puzzle_profile.dart';
import '../db/database.dart';
import '../lichess/lichess_client.dart';

class PuzzleRepository {
  PuzzleRepository(this.db);
  final AppDatabase db;

  static const _key = 'puzzles';

  Future<PuzzleProfile> load() async {
    final row = await (db.select(db.settings)..where((t) => t.key.equals(_key))).getSingleOrNull();
    return PuzzleProfile.decode(row?.value);
  }

  Future<void> save(PuzzleProfile p) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion(key: const Value(_key), value: Value(p.encode())));

  Future<void> _tail = Future.value();

  /// Reads, changes and saves the profile, one change at a time: a result
  /// and the answer of Lichess to earlier ones must not overwrite each
  /// other.
  Future<PuzzleProfile> update(PuzzleProfile Function(PuzzleProfile) change) {
    final done = Completer<PuzzleProfile>();
    _tail = _tail.then((_) async {
      try {
        final p = change(await load());
        await save(p);
        done.complete(p);
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }
}

/// The Lichess difficulty that brings puzzles nearest to [rating]: anonymous
/// batches are centred on 1500.
String puzzleDifficultyFor(int rating) {
  const steps = {-600: 'easiest', -300: 'easier', 0: 'normal', 300: 'harder', 600: 'hardest'};
  final d = rating - 1500;
  var best = 0;
  for (final s in steps.keys) {
    if ((s - d).abs() < (best - d).abs()) best = s;
  }
  return steps[best]!;
}

/// Why puzzles come from the pack.
enum PuzzleOffline { network, limited }

/// Whether Lichess may be asked for puzzles now; shared by every theme, so
/// a failure in one sends the next straight to the pack (D-126).
class PuzzleNetwork {
  PuzzleNetwork({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;

  DateTime? _until;
  PuzzleOffline? _reason;

  /// After a network failure Lichess is tried again this soon.
  static const networkPause = Duration(seconds: 30);

  /// After a 429: the limit is per hour.
  static const limitPause = Duration(minutes: 10);

  /// Null when Lichess may be asked; otherwise why not.
  PuzzleOffline? get blocked {
    final until = _until;
    if (until == null || !_now().isBefore(until)) return null;
    return _reason;
  }

  void fail(PuzzleOffline reason) {
    _reason = reason;
    _until = _now().add(reason == PuzzleOffline.limited ? limitPause : networkPause);
  }

  void ok() => _until = null;
}

/// The Lichess account puzzles count for: its id and whether the token
/// may read and write puzzles.
typedef PuzzleAccount = ({String user, bool canWrite});

/// Puzzles of one theme: from Lichess while it answers, from the pack the
/// moment it does not (D-126). The next puzzle is fetched while the player
/// thinks, so "Next" opens at once. Anonymous calls take one puzzle (a
/// credit each, D-125); with the account three (one credit together).
class PuzzleFeed {
  PuzzleFeed({
    required this.client,
    required this.angle,
    required this.network,
    required this.pack,
    this.account,
    this.onLichessRating,
    this.firstTimeout = const Duration(seconds: 3),
    this.aheadTimeout = const Duration(seconds: 15),
  });

  final LichessClient client;
  final String angle;
  final PuzzleNetwork network;
  final Future<PuzzlePack?> Function() pack;
  PuzzleAccount? account;

  /// The player's rating as Lichess sent it with puzzles.
  final void Function(String user, Glicko rating)? onLichessRating;

  /// How long the player waits for Lichess before the pack takes over.
  final Duration firstTimeout;
  final Duration aheadTimeout;

  final _queue = <Puzzle>[];
  final _given = <String>{};
  Future<Puzzle?>? _ahead;

  /// Calls for one puzzle that may all bring puzzles already played: after
  /// that the pack. Within a minute Lichess draws anonymous puzzles from
  /// the same pool of 150.
  static const attempts = 3;

  /// The next puzzle for a player rated [rating] (the device's rating; the
  /// account's is known to Lichess) who has played [seen]. Throws only
  /// when neither Lichess nor the pack has one.
  Future<Puzzle> next({required int rating, required Iterable<String> seen}) async {
    final skip = {...seen, ..._given};
    final ahead = _ahead;
    _ahead = null;
    var p = ahead == null ? null : await ahead;
    if (p != null && skip.contains(p.id)) p = null;
    p ??= await _find(rating, skip, firstTimeout);
    if (p == null) throw const PuzzleFormatException('no puzzles');
    _given.add(p.id);
    final later = {...skip, p.id};
    _ahead = _find(rating, later, aheadTimeout);
    return p;
  }

  /// From the queue, Lichess, or the pack, in that order; never throws.
  Future<Puzzle?> _find(int rating, Set<String> skip, Duration timeout) async {
    _queue.removeWhere((p) => skip.contains(p.id));
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    if (network.blocked == null) {
      try {
        final p = await _online(rating, skip).timeout(timeout);
        network.ok();
        if (p != null) return p;
      } on LichessException catch (e) {
        if (e.isRateLimited) {
          network.fail(PuzzleOffline.limited);
        } else if (account != null && (e.status == 401 || e.status == 403)) {
          // The token cannot read puzzles: on without it.
          account = null;
        } else {
          network.fail(PuzzleOffline.network);
        }
      } catch (_) {
        network.fail(PuzzleOffline.network);
      }
    }
    final pk = await pack();
    if (pk == null) return null;
    return pk.pick(angle, rating, skip) ?? pk.pick(angle, rating, {..._given});
  }

  Future<Puzzle?> _online(int rating, Set<String> skip) async {
    final acc = account;
    for (var i = 0; i < attempts; i++) {
      final r = await client.puzzleBatch(
        angle,
        nb: acc == null ? 1 : 3,
        difficulty: acc == null ? puzzleDifficultyFor(rating) : 'normal',
        auth: acc != null,
      );
      final g = r.glicko;
      if (acc != null && g != null) {
        final rating = (g['rating'] as num?)?.toDouble();
        final dev = (g['deviation'] as num?)?.toDouble();
        if (rating != null && dev != null) onLichessRating?.call(acc.user, Glicko(rating: rating, deviation: dev));
      }
      for (final j in r.puzzles) {
        try {
          final p = Puzzle.fromLichessJson(j);
          p.setup();
          if (!skip.contains(p.id) && !_queue.any((q) => q.id == p.id)) _queue.add(p);
        } on PuzzleFormatException {
          // A puzzle that does not replay is skipped.
        }
      }
      if (_queue.isNotEmpty) return _queue.removeAt(0);
    }
    return null;
  }
}

/// Sends the results waiting in the profile to Lichess (D-126), a theme at
/// a time, and keeps the rating Lichess answers with. Calls while a send
/// runs share it, so a result is never sent twice.
class PuzzleSync {
  PuzzleSync(this.client, this.repository);
  final LichessClient client;
  final PuzzleRepository repository;

  Future<Map<String, int>>? _running;

  /// The rating change of each puzzle sent. Throws when Lichess cannot be
  /// reached; what was not sent waits for the next time.
  Future<Map<String, int>> send(String user) {
    final running = _running;
    if (running != null) return running;
    final run = _send(user).whenComplete(() => _running = null);
    _running = run;
    return run;
  }

  Future<Map<String, int>> _send(String user) async {
    final snapshot = (await repository.load()).forAccount(user);
    final diffs = <String, int>{};
    final byAngle = <String, List<PendingResult>>{};
    for (final r in snapshot.pending) {
      (byAngle[r.angle] ??= []).add(r);
    }
    for (final e in byAngle.entries) {
      for (var i = 0; i < e.value.length; i += 50) {
        final chunk = e.value.sublist(i, (i + 50).clamp(0, e.value.length));
        final j = await client.puzzleSolve(e.key, [for (final r in chunk) (id: r.id, win: r.win)]);
        final g = (j['glicko'] as Map?)?.cast<String, Object?>();
        final rating = (g?['rating'] as num?)?.toDouble();
        final dev = (g?['deviation'] as num?)?.toDouble();
        for (final r in (j['rounds'] as List?) ?? const []) {
          if (r is Map && r['id'] != null) diffs[r['id'].toString()] = (r['ratingDiff'] as num?)?.toInt() ?? 0;
        }
        final sent = [for (final r in chunk) r.id];
        await repository.update(
          (p) => p.afterSync(
            user,
            sent,
            rating == null || dev == null
                ? (p.lichessGlicko ?? const Glicko())
                : Glicko(rating: rating, deviation: dev),
          ),
        );
      }
    }
    return diffs;
  }
}
