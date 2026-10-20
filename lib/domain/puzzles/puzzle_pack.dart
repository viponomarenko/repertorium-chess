/// The offline puzzle pack (D-126): 50 000 Lichess puzzles shipped with the
/// app, for when Lichess cannot be reached or limits the puzzles.
library;

import 'dart:math' as math;

import 'puzzle.dart';
import 'puzzle_themes.dart';

class PuzzlePack {
  /// [lines] are pack lines sorted by rating (as the build script writes).
  PuzzlePack(List<String> lines) : _lines = lines, _ratings = List.filled(lines.length, 0) {
    for (var i = 0; i < lines.length; i++) {
      final f = lines[i].split('\t');
      if (f.length < 6) continue;
      _ratings[i] = int.tryParse(f[3]) ?? 0;
      for (final t in f[5].split(' ')) {
        if (t.isNotEmpty) (_byTheme[t] ??= []).add(i);
      }
    }
    // Lines come sorted by rating; keep each theme list sorted too.
    for (final l in _byTheme.values) {
      l.sort((a, b) => _ratings[a].compareTo(_ratings[b]));
    }
    _all = List.generate(lines.length, (i) => i)..sort((a, b) => _ratings[a].compareTo(_ratings[b]));
  }

  final List<String> _lines;
  final List<int> _ratings;
  final Map<String, List<int>> _byTheme = {};
  late final List<int> _all;

  int get length => _lines.length;

  /// How many puzzles [angle] has.
  int count(String angle) => (angle == kPuzzleMix ? _all : _byTheme[angle] ?? const []).length;

  /// A puzzle of [angle] near [rating], not in [skip]: random among the
  /// closest few, the window widening until one is found. Null when the
  /// theme has no puzzle left.
  Puzzle? pick(String angle, int rating, Set<String> skip, {math.Random? random}) {
    final list = angle == kPuzzleMix ? _all : _byTheme[angle];
    if (list == null || list.isEmpty) return null;
    final rnd = random ?? math.Random();
    // First index with a rating >= target.
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_ratings[list[mid]] < rating) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    for (final window in const [75, 150, 300, 600, 1200, 5000]) {
      final found = <int>[];
      for (var i = lo - 1; i >= 0 && rating - _ratings[list[i]] <= window; i--) {
        if (!skip.contains(_id(list[i]))) found.add(list[i]);
        if (found.length >= 40) break;
      }
      for (var i = lo; i < list.length && _ratings[list[i]] - rating <= window; i++) {
        if (!skip.contains(_id(list[i]))) found.add(list[i]);
        if (found.length >= 80) break;
      }
      if (found.isEmpty) continue;
      // Lines that do not replay are dropped, and another is tried.
      found.shuffle(rnd);
      for (final i in found) {
        try {
          final p = Puzzle.fromPackLine(_lines[i]);
          p.setup();
          return p;
        } on PuzzleFormatException {
          continue;
        }
      }
    }
    return null;
  }

  String _id(int i) {
    final line = _lines[i];
    final tab = line.indexOf('\t');
    return tab < 0 ? line : line.substring(0, tab);
  }
}
