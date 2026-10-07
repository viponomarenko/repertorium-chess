@Tags(['perf'])
library;

import 'dart:io';
import 'dart:math';

import 'package:dartchess/dartchess.dart' hide File, PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/pgn/pgn_writer.dart';

/// Generates a large file with random games and variations.
String generate(int games, {int seed = 42}) {
  final rnd = Random(seed);
  final sb = StringBuffer();
  for (var g = 0; g < games; g++) {
    final game = ChessGame(headers: ChessGame.defaultHeaders());
    game.headers['Event'] = 'Perf $g';
    var node = game.root;
    for (var ply = 0; ply < 60; ply++) {
      final moves = <Move>[];
      node.position.legalMoves.forEach((from, tos) {
        for (final to in tos.squares) {
          moves.add(NormalMove(from: from, to: to));
        }
      });
      if (moves.isEmpty) break;
      // Avoid promotions without role.
      final m = moves[rnd.nextInt(moves.length)];
      GameNode next;
      try {
        next = node.addMove(m);
      } catch (_) {
        break;
      }
      if (rnd.nextInt(6) == 0) next.comments.add(const PgnComment(text: 'A comment about this move'));
      if (rnd.nextInt(8) == 0 && moves.length > 1) {
        try {
          var v = node.addMove(moves[(moves.indexOf(m) + 1) % moves.length]);
          for (var k = 0; k < 6; k++) {
            final vm = <Move>[];
            v.position.legalMoves.forEach((f, t) {
              for (final to in t.squares) {
                vm.add(NormalMove(from: f, to: to));
              }
            });
            if (vm.isEmpty) break;
            v = v.addMove(vm[rnd.nextInt(vm.length)]);
          }
        } catch (_) {}
      }
      node = next;
    }
    sb.write(PgnWriter().write(game));
    sb.write('\n');
  }
  return sb.toString();
}

void main() {
  test('parse ~5 MB PGN', () {
    final text = generate(2000);
    File('build/perf.pgn')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    final sw = Stopwatch()..start();
    final games = PgnParser.parseAll(text);
    sw.stop();
    final nodes = games.fold<int>(0, (a, g) => a + g.game.nodeCount);
    // ignore: avoid_print
    print(
      'size=${(text.length / 1e6).toStringAsFixed(2)}MB games=${games.length} nodes=$nodes parse=${sw.elapsedMilliseconds}ms',
    );
    expect(games, hasLength(2000));
  });
}
