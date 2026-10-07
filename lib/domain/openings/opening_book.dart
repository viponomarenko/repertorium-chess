/// Opening names and ECO codes (F-THEORY-01), from lichess-org/chess-openings
/// (CC0). Lookup is by position key, so transpositions are recognized.
library;

import '../chess/chess_utils.dart';

class OpeningInfo {
  const OpeningInfo({required this.key, required this.eco, required this.name, required this.moves});

  final PositionKey key;
  final String eco;
  final String name;

  /// SAN moves from the initial position.
  final List<String> moves;

  /// Family name, e.g. "Sicilian Defense" for "Sicilian Defense: Najdorf".
  String get family => name.split(':').first.trim();

  int get ply => moves.length;
}

class OpeningBook {
  OpeningBook(Iterable<OpeningInfo> entries) {
    for (final e in entries) {
      // Keep the most specific (longest) name for duplicate positions.
      final prev = _byKey[e.key];
      if (prev == null || e.name.length > prev.name.length) _byKey[e.key] = e;
      _all.add(e);
    }
  }

  factory OpeningBook.parseTsv(String tsv) {
    final entries = <OpeningInfo>[];
    for (final line in tsv.split('\n')) {
      if (line.isEmpty) continue;
      final p = line.split('\t');
      if (p.length < 4) continue;
      entries.add(OpeningInfo(key: p[0], eco: p[1], name: p[2], moves: p[3].split(' ')));
    }
    return OpeningBook(entries);
  }

  static final empty = OpeningBook(const []);

  final Map<PositionKey, OpeningInfo> _byKey = {};
  final List<OpeningInfo> _all = [];

  List<OpeningInfo> get all => _all;

  OpeningInfo? lookup(PositionKey key) => _byKey[key];

  /// Deepest known opening along a line of position keys (latest first
  /// match walking backwards).
  OpeningInfo? deepest(Iterable<PositionKey> keysFromStart) {
    final list = keysFromStart.toList();
    for (var i = list.length - 1; i >= 0; i--) {
      final o = _byKey[list[i]];
      if (o != null) return o;
    }
    return null;
  }

  /// Search by name or ECO code (F-THEORY-02).
  List<OpeningInfo> search(String query, {int limit = 100}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _all.take(limit).toList();
    final isEco = RegExp(r'^[a-e]\d{0,2}$').hasMatch(q);
    final res = <OpeningInfo>[];
    for (final o in _all) {
      final match = isEco ? o.eco.toLowerCase().startsWith(q) : o.name.toLowerCase().contains(q);
      if (match) {
        res.add(o);
        if (res.length >= limit) break;
      }
    }
    return res;
  }
}
