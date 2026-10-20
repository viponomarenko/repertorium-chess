import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/puzzles/puzzle_repository.dart';
import 'package:tabiya/domain/puzzles/glicko2.dart';
import 'package:tabiya/domain/puzzles/puzzle.dart';
import 'package:tabiya/domain/puzzles/puzzle_profile.dart';
import 'package:tabiya/domain/puzzles/puzzle_run.dart';
import 'package:tabiya/domain/puzzles/puzzle_themes.dart';

/// Legal's mate, in the shape of the Lichess API (`PuzzleAndGame`).
Map<String, Object?> legalJson({List<String>? solution}) => {
  'game': {
    'id': 'abcdefgh',
    'pgn': 'e4 e5 Nf3 d6 Bc4 Bg4 Nc3 g6',
    'clock': '5+0',
    'rated': true,
    'perf': {'key': 'blitz', 'name': 'Blitz'},
    'players': const [],
  },
  'puzzle': {
    'id': 'LeGaL',
    'rating': 1350,
    'plays': 1000,
    'initialPly': 7,
    'solution': solution ?? ['f3e5', 'g4d1', 'c4f7', 'e8e7', 'c3d5'],
    'themes': ['opening', 'mateIn3', 'sacrifice'],
  },
};

/// 1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6: Qxf7 mates.
Map<String, Object?> scholarJson(List<String> solution) => {
  'game': {'id': 'g', 'pgn': 'e4 e5 Bc4 Nc6 Qh5 Nf6'},
  'puzzle': {
    'id': 'ScHoL',
    'rating': 800,
    'plays': 1,
    'solution': solution,
    'themes': const ['mateIn1'],
  },
};

Move uci(String s) => Move.parse(s)!;

void main() {
  group('Puzzle', () {
    test('replays the game: the last move is the opponent\'s, then the solver moves', () {
      final p = Puzzle.fromLichessJson(legalJson());
      expect(p.id, 'LeGaL');
      expect(p.rating, 1350);
      expect(p.themes, contains('mateIn3'));
      final s = p.setup();
      expect(s.solver, Side.white);
      expect(s.lastMove.uci, 'g7g6');
      expect(s.before.turn, Side.black);
    });

    test('a solution that does not fit the game is refused', () {
      final p = Puzzle.fromLichessJson(legalJson(solution: ['e1e3']));
      expect(p.setup, throwsA(isA<PuzzleFormatException>()));
    });
  });

  group('PuzzleRun', () {
    test('the right moves solve it, replies are played in between', () {
      final run = PuzzleRun(Puzzle.fromLichessJson(legalJson()));
      expect(run.solverToMove, isTrue);
      expect(run.submit(uci('f3e5')), PuzzleVerdict.correct);
      expect(run.solverToMove, isFalse);
      expect(run.playScripted()?.uci, 'g4d1');
      expect(run.submit(uci('c4f7')), PuzzleVerdict.correct);
      run.playScripted();
      expect(run.submit(uci('c3d5')), PuzzleVerdict.solved);
      expect(run.done, isTrue);
      expect(run.failed, isFalse);
      expect(run.position.isCheckmate, isTrue);
    });

    test('a wrong move leaves the position and fails the puzzle', () {
      final run = PuzzleRun(Puzzle.fromLichessJson(legalJson()));
      final before = run.position.fen;
      expect(run.submit(uci('d2d3')), PuzzleVerdict.wrong);
      expect(run.position.fen, before);
      expect(run.failed, isTrue);
      // The right move still goes on, but the result stays a loss.
      expect(run.submit(uci('f3e5')), PuzzleVerdict.correct);
      expect(run.failed, isTrue);
    });

    test('another move that mates also solves it', () {
      final run = PuzzleRun(Puzzle.fromLichessJson(scholarJson(['c4f7'])));
      expect(run.submit(uci('h5f7')), PuzzleVerdict.solved);
      expect(run.failed, isFalse);
    });

    test('shown solution plays every move and counts as a loss', () {
      final run = PuzzleRun(Puzzle.fromLichessJson(legalJson()))..reveal();
      var n = 0;
      while (run.playScripted() != null) {
        n++;
      }
      expect(n, 5);
      expect(run.failed, isTrue);
      expect(run.position.isCheckmate, isTrue);
    });
  });

  group('Glicko-2', () {
    test('the example of Glickman\'s paper', () {
      final r = glickoUpdate(const Glicko(rating: 1500, deviation: 200, volatility: 0.06), [
        (opponent: const Glicko(rating: 1400, deviation: 30), score: 1),
        (opponent: const Glicko(rating: 1550, deviation: 100), score: 0),
        (opponent: const Glicko(rating: 1700, deviation: 300), score: 0),
      ], tau: 0.5);
      expect(r.rating, closeTo(1464.06, 0.05));
      expect(r.deviation, closeTo(151.52, 0.05));
      expect(r.volatility, closeTo(0.05999, 0.0001));
    });
  });

  group('PuzzleProfile', () {
    final legal = Puzzle.fromLichessJson(legalJson());

    test('a win raises the rating, a loss lowers it; the same puzzle counts once', () {
      const start = PuzzleProfile();
      final w = start.record(legal, kPuzzleMix, win: true);
      expect(w.diff, greaterThan(0));
      expect(w.profile.played, 1);
      expect(w.profile.won, 1);
      expect(w.profile.byAngle[kPuzzleMix], (played: 1, won: 1));
      expect(w.profile.record(legal, kPuzzleMix, win: false).diff, 0);
      final l = start.record(legal, kPuzzleMix, win: false);
      expect(l.diff, lessThan(0));
      expect(l.profile.won, 0);
    });

    test('a theme that hints at the solution moves the rating less', () {
      const start = PuzzleProfile(glicko: Glicko(rating: 1500, deviation: 80, volatility: 0.06));
      final mix = start.record(legal, kPuzzleMix, win: true).diff;
      final mate = start.record(legal, 'mateIn1', win: true).diff;
      expect(mate, lessThan(mix));
      expect(puzzleRatingWeight('smotheredMate', win: false), 0.4);
      expect(puzzleRatingWeight('endgame', win: true), 0.7);
      expect(puzzleRatingWeight('fork', win: true), 0.2);
    });

    test('survives a round trip and bad JSON', () {
      final p = const PuzzleProfile().record(legal, 'fork', win: true).profile;
      final back = PuzzleProfile.decode(p.encode());
      expect(back.rating, p.rating);
      expect(back.seen, ['LeGaL']);
      expect(back.byAngle['fork'], (played: 1, won: 1));
      expect(PuzzleProfile.decode('not json').played, 0);
      expect(PuzzleProfile.decode(null).rating, 1500);
    });

    test('a new rating is provisional', () {
      expect(const PuzzleProfile().provisional, isTrue);
    });
  });

  test('difficulty follows the rating around 1500', () {
    expect(puzzleDifficultyFor(1500), 'normal');
    expect(puzzleDifficultyFor(1100), 'easier');
    expect(puzzleDifficultyFor(700), 'easiest');
    expect(puzzleDifficultyFor(1900), 'harder');
    expect(puzzleDifficultyFor(2600), 'hardest');
  });

  test('every theme stands once, mix first', () {
    final all = [for (final l in kPuzzleThemes.values) ...l];
    expect(all.first, kPuzzleMix);
    expect(all.toSet().length, all.length);
  });
}
