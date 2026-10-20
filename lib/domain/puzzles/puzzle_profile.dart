/// The player's puzzle rating and history, kept on the device (D-123).
/// With a Lichess account the rating that counts is the one on Lichess:
/// results wait in [PuzzleProfile.pending] until they are sent (D-126).
library;

import 'dart:convert';

import 'glicko2.dart';
import 'puzzle.dart';
import 'puzzle_themes.dart';

/// Wins and attempts in one theme.
typedef ThemeScore = ({int played, int won});

/// A result not yet sent to Lichess.
typedef PendingResult = ({String id, String angle, bool win});

class PuzzleProfile {
  const PuzzleProfile({
    this.glicko = const Glicko(),
    this.played = 0,
    this.won = 0,
    this.seen = const [],
    this.byAngle = const {},
    this.lichessUser,
    this.lichessGlicko,
    this.pending = const [],
  });

  /// The rating on this device, without an account.
  final Glicko glicko;
  final int played;
  final int won;

  /// Ids of the latest puzzles played, newest last; not offered again.
  final List<String> seen;

  /// Results by the theme chosen to play (the angle), not by the themes
  /// of each puzzle.
  final Map<String, ThemeScore> byAngle;

  /// The Lichess account the fields below belong to (lowercase id).
  final String? lichessUser;

  /// The puzzle rating on Lichess as last known, with the pending results
  /// estimated on top of it.
  final Glicko? lichessGlicko;

  /// Results played with the account and not yet sent, oldest first.
  final List<PendingResult> pending;

  /// How many ids [seen] keeps.
  static const seenLimit = 3000;

  /// How many results wait at most; older ones are dropped.
  static const pendingLimit = 500;

  /// The deviation Lichess does not give for a puzzle: a settled rating.
  static const puzzleDeviation = 80.0;

  /// The most one puzzle can move the rating (lila `maxRatingDelta`).
  static const maxRatingDelta = 700.0;

  /// The rating shown: the Lichess one for [user], else the device's.
  Glicko shown(String? user) => user != null && user == lichessUser && lichessGlicko != null ? lichessGlicko! : glicko;

  int get rating => glicko.rating.round();
  bool get provisional => glicko.provisional;

  /// The ratings after [puzzle] in [angle]: solved without a mistake
  /// ([win]) or not. With [lichessUser] the result also waits to be sent,
  /// and [diff] is the change of the Lichess rating (an estimate until
  /// Lichess answers). The same puzzle again does not count.
  ({PuzzleProfile profile, int diff}) record(Puzzle puzzle, String angle, {required bool win, String? lichessUser}) {
    if (seen.contains(puzzle.id)) return (profile: this, diff: 0);
    final local = _rate(glicko, puzzle, angle, win);
    final score = byAngle[angle] ?? (played: 0, won: 0);
    final ids = [...seen, puzzle.id];
    var profile = PuzzleProfile(
      glicko: local,
      played: played + 1,
      won: won + (win ? 1 : 0),
      seen: ids.length > seenLimit ? ids.sublist(ids.length - seenLimit) : ids,
      byAngle: {...byAngle, angle: (played: score.played + 1, won: score.won + (win ? 1 : 0))},
      lichessUser: this.lichessUser,
      lichessGlicko: lichessGlicko,
      pending: pending,
    );
    if (lichessUser == null) return (profile: profile, diff: local.rating.round() - glicko.rating.round());
    profile = profile.forAccount(lichessUser);
    final before = profile.lichessGlicko ?? const Glicko();
    final after = _rate(before, puzzle, angle, win);
    final queue = [...profile.pending, (id: puzzle.id, angle: angle, win: win)];
    profile = profile._copy(
      lichessGlicko: after,
      pending: queue.length > pendingLimit ? queue.sublist(queue.length - pendingLimit) : queue,
    );
    return (profile: profile, diff: after.rating.round() - before.rating.round());
  }

  static Glicko _rate(Glicko from, Puzzle puzzle, String angle, bool win) {
    final full = glickoUpdate(from, [
      (
        opponent: Glicko(rating: puzzle.rating.toDouble(), deviation: puzzle.deviation ?? puzzleDeviation),
        score: win ? 1.0 : 0.0,
      ),
    ]);
    final next = from.towards(full, puzzleRatingWeight(angle, win: win)).capped();
    final delta = (next.rating - from.rating).clamp(-maxRatingDelta, maxRatingDelta);
    return Glicko(rating: from.rating + delta, deviation: next.deviation, volatility: next.volatility).capped();
  }

  /// The Lichess part for [user]: another account starts afresh (its
  /// rating comes with the first answer of Lichess).
  PuzzleProfile forAccount(String user) =>
      user == lichessUser ? this : _copy(lichessUser: user, lichessGlicko: null, pending: const [], clearLichess: true);

  /// The rating Lichess gave for [user]. While results wait, the estimate
  /// on top of the older rating is kept: Lichess does not know them yet.
  PuzzleProfile withLichessRating(String user, Glicko rating) {
    final p = forAccount(user);
    if (p.pending.isNotEmpty) return p;
    return p._copy(lichessGlicko: rating);
  }

  /// [sent] results reached Lichess, which answered with [rating].
  PuzzleProfile afterSync(String user, Iterable<String> sent, Glicko rating) {
    final p = forAccount(user);
    final ids = sent.toSet();
    final rest = [
      for (final r in p.pending)
        if (!ids.contains(r.id)) r,
    ];
    // Results still waiting keep their estimate on top of the new rating.
    return p._copy(pending: rest, lichessGlicko: rest.isEmpty ? rating : p.lichessGlicko);
  }

  PuzzleProfile _copy({
    String? lichessUser,
    Glicko? lichessGlicko,
    List<PendingResult>? pending,
    bool clearLichess = false,
  }) => PuzzleProfile(
    glicko: glicko,
    played: played,
    won: won,
    seen: seen,
    byAngle: byAngle,
    lichessUser: lichessUser ?? this.lichessUser,
    lichessGlicko: clearLichess ? lichessGlicko : (lichessGlicko ?? this.lichessGlicko),
    pending: pending ?? this.pending,
  );

  String encode() => jsonEncode({
    'glicko': glicko.toJson(),
    'played': played,
    'won': won,
    'seen': seen,
    'angles': {
      for (final e in byAngle.entries) e.key: [e.value.played, e.value.won],
    },
    if (lichessUser != null) 'lichessUser': lichessUser,
    if (lichessGlicko != null) 'lichessGlicko': lichessGlicko!.toJson(),
    if (pending.isNotEmpty)
      'pending': [
        for (final r in pending) [r.id, r.angle, r.win],
      ],
  });

  static PuzzleProfile decode(String? text) {
    if (text == null || text.isEmpty) return const PuzzleProfile();
    try {
      final j = jsonDecode(text);
      if (j is! Map) return const PuzzleProfile();
      int n(Object? v) => v is num ? v.toInt() : 0;
      final angles = <String, ThemeScore>{};
      final a = j['angles'];
      if (a is Map) {
        for (final e in a.entries) {
          final v = e.value;
          if (v is List && v.length == 2) angles[e.key.toString()] = (played: n(v[0]), won: n(v[1]));
        }
      }
      final pending = <PendingResult>[];
      for (final r in (j['pending'] as List?) ?? const []) {
        if (r is List && r.length == 3 && r[2] is bool) {
          pending.add((id: r[0].toString(), angle: r[1].toString(), win: r[2] as bool));
        }
      }
      final user = j['lichessUser'];
      return PuzzleProfile(
        glicko: Glicko.fromJson(j['glicko']),
        played: n(j['played']),
        won: n(j['won']),
        seen: [for (final s in (j['seen'] as List?) ?? const []) s.toString()],
        byAngle: angles,
        lichessUser: user is String ? user : null,
        lichessGlicko: j['lichessGlicko'] == null ? null : Glicko.fromJson(j['lichessGlicko']),
        pending: user is String ? pending : const [],
      );
    } on FormatException {
      return const PuzzleProfile();
    }
  }
}
