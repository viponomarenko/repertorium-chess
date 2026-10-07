import 'dart:io';

import 'package:dartchess/dartchess.dart' hide File, PgnComment;
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/pgn/pgn_writer.dart';
import 'package:tabiya/domain/pgn/text_encoding.dart';

import '../helpers/pgn_compare.dart';

String fixture(String name) {
  final bytes = File('test/fixtures/pgn/$name').readAsBytesSync();
  return decodeChessText(bytes).text;
}

List<String> sans(Iterable<GameNode> nodes) => nodes.map((n) => n.san!).toList();

void main() {
  group('F-IMP-04 parser', () {
    test('nested variations, comments, NAGs, shapes, commands', () {
      final games = PgnParser.parseAll(fixture('nested.pgn'));
      expect(games, hasLength(2));
      final g = games[0].game;
      expect(g.issues, isEmpty);
      expect(g.headers['CustomTag'], 'some value with "quotes"');
      expect(g.headers['White'], 'Ivanenko, Petro');
      expect(g.root.comments.single.text, 'Game comment before the first move.');

      final e4 = g.root.children.single;
      expect(e4.san, 'e4');
      expect(e4.nags, [1]);
      expect(e4.comments.single.text, 'King pawn.');
      expect(e4.comments.single.command('clk'), '1:30:00');

      final nf3 = e4.children.single.children.single;
      expect(nf3.san, 'Nf3');
      expect(sans(nf3.children), ['Nc6', 'Nf6']);
      final petrov = nf3.children[1];
      expect(petrov.comments.single.text, 'Petrov');
      final nxe5 = petrov.children.first;
      expect(sans(petrov.children), ['Nxe5', 'd4']);
      // 3. d4 exd4 (3... Nxe4 4. dxe5) 4. e5
      final d4 = petrov.children[1];
      expect(sans(d4.children), ['exd4', 'Nxe4']);
      expect(d4.children[1].children.single.san, 'dxe5');
      // 3... d6 $6 (3... Nxe4?? 4. Qe2)
      expect(sans(nxe5.children), ['d6', 'Nxe4']);
      expect(nxe5.children[0].nags, [6]);
      expect(nxe5.children[1].nags, [4]);

      final bb5 = nf3.children.first.children.single;
      expect(bb5.san, 'Bb5');
      expect(bb5.comments.single.text, 'Spanish.');
      expect(bb5.shapes.toSet(), {
        const BoardShape(ShapeColor.green, Square.b5, Square.c6),
        const BoardShape(ShapeColor.red, Square.d8, Square.d1),
        const BoardShape(ShapeColor.green, Square.e5),
      });
      // Berlin with a start comment.
      final berlin = bb5.children[1];
      expect(berlin.san, 'Nf6');
      expect(berlin.startComments.single.text, 'Berlin:');
      expect(g.mainline.last.san, 'h3');
      expect(g.mainline.last.comments.single.commands, ['%eval 0.32', '%emt 0:00:12']);

      final g2 = games[1].game;
      expect(sans(g2.mainline), ['d4', 'd5', 'c4', 'e6', 'Nc3', 'Nf6', 'Bg5', 'Be7']);
      expect(games[1].startLine, greaterThan(10));
    });

    test('NAG symbols and ; comments', () {
      final g = PgnParser.parseOne(fixture('nags.pgn'));
      expect(g.issues, isEmpty);
      final m = g.mainline;
      expect(m[0].nags, [1]);
      expect(m[1].nags, [2]);
      expect(m[2].nags, [3]);
      expect(m[3].nags, [4]);
      expect(m[4].nags, [5]);
      expect(m[5].nags, [6]);
      expect(m[6].nags, [14]);
      expect(m[7].nags, [18]);
      expect(m[8].nags, [18]);
      expect(m[9].nags, [10]);
      expect(m[10].nags, [16]);
      expect(m[10].comments.single.text, 'rest-of-line comment here');
      expect(m.last.nags, [146]);
    });

    test('FEN setup and null move', () {
      final g = PgnParser.parseOne(fixture('setup.pgn'));
      expect(g.issues, isEmpty);
      expect(g.root.fen, startsWith('r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2'));
      final m = g.mainline;
      expect(sans(m), ['Bb5', 'a6', 'Ba4', '--', 'O-O', 'Nf6']);
      expect(m[3].isNullMove, isTrue);
      expect(m[4].position.turn, Side.black);
    });

    test('F-IMP-05 errors do not stop the import', () {
      final games = PgnParser.parseAll(fixture('errors.pgn'));
      expect(games, hasLength(5));
      expect(games[0].game.issues, isEmpty);

      final broken = games[1].game;
      expect(broken.issues, hasLength(1));
      expect(broken.issues.single.token, 'Qh8');
      expect(broken.issues.single.line, 19);
      expect(sans(broken.mainline), ['e4', 'e5', 'Nf3', 'Nc6']);

      final varBroken = games[2].game;
      expect(varBroken.issues, hasLength(1));
      expect(varBroken.issues.single.token, 'Ke3');
      expect(sans(varBroken.mainline), ['d4', 'd5', 'c4']);
      expect(sans(varBroken.root.children[1].line), ['e4']);
      expect(sans(varBroken.root.children[1].children.single.line), ['e4', 'e5']);

      final badFen = games[3].game;
      expect(badFen.issues.single.message, contains('FEN'));
      expect(badFen.mainline, isEmpty);

      final last = games[4].game;
      expect(last.issues, isEmpty);
      expect(last.mainline.last.san, 'Qh4#');
    });

    test('en passant and promotion', () {
      final games = PgnParser.parseAll(fixture('enpassant.pgn'));
      expect(games[0].game.issues, isEmpty);
      expect(games[0].game.mainline.last.san, 'O-O');
      expect(games[0].game.mainline.last.uci, 'e1g1');
      final promo = games[1].game;
      expect(promo.issues, isEmpty);
      expect(sans(promo.mainline), ['a8=Q', 'gxh1=Q+', 'Kxh1']);
      expect(promo.mainline.first.uci, 'a7a8q');
    });

    test('garbage input does not throw', () {
      expect(() => PgnParser.parseAll('garbage ((( } {'), returnsNormally);
      expect(PgnParser.parseAll(''), isEmpty);
      final onlyMoves = PgnParser.parseAll('1. e4 e5 2. Nf3');
      expect(onlyMoves.single.game.mainline, hasLength(3));
    });
  });

  group('F-IMP-03 encodings', () {
    test('cp1251 is detected and decoded', () {
      final bytes = File('test/fixtures/pgn/cp1251.pgn').readAsBytesSync();
      final d = decodeChessText(bytes);
      expect(d.encoding, TextEncodingKind.windows1251);
      final g = PgnParser.parseOne(d.text);
      expect(g.headers['White'], 'Іваненко, Петро');
      expect(g.headers['Black'], 'Ґудзь, Євген');
      expect(g.mainline.first.comments.single.text, startsWith('Найпопулярніший'));
      expect(g.issues, isEmpty);
    });

    test('cp1252 is detected and decoded', () {
      final bytes = File('test/fixtures/pgn/cp1252.pgn').readAsBytesSync();
      final d = decodeChessText(bytes);
      expect(d.encoding, TextEncodingKind.windows1252);
      final g = PgnParser.parseOne(d.text);
      expect(g.headers['White'], 'Müller, Jürgen');
      expect(g.mainline.first.comments.single.text, contains('Genève'));
    });

    test('UTF-8 with BOM', () {
      final bytes = File('test/fixtures/pgn/utf8_bom.pgn').readAsBytesSync();
      final d = decodeChessText(bytes);
      expect(d.encoding, TextEncodingKind.utf8);
      expect(d.hadBom, isTrue);
      final g = PgnParser.parseOne(d.text);
      expect(g.headers['Event'], 'Кириличний турнір');
    });

    test('manual override', () {
      final bytes = File('test/fixtures/pgn/cp1251.pgn').readAsBytesSync();
      final d = decodeChessText(bytes, forced: TextEncodingKind.windows1252);
      expect(d.text.contains('Іваненко'), isFalse);
    });
  });

  group('F-EDIT-07 round-trip', () {
    for (final name in [
      'nested.pgn',
      'nags.pgn',
      'setup.pgn',
      'errors.pgn',
      'enpassant.pgn',
      'cp1251.pgn',
      'cp1252.pgn',
      'utf8_bom.pgn',
    ]) {
      test(name, () {
        final original = PgnParser.parseAll(fixture(name));
        final exported = PgnWriter().writeAll(original.map((p) => p.game));
        final reparsed = PgnParser.parseAll(exported);
        expect(reparsed, hasLength(original.length));
        for (var i = 0; i < original.length; i++) {
          final diffs = diffGames(original[i].game, reparsed[i].game);
          expect(diffs, isEmpty, reason: 'game $i:\n${diffs.join('\n')}\n$exported');
          // No new problems appear after export (a bad FEN header stays bad,
          // a kept tail keeps its warning).
          expect(reparsed[i].game.issues.map((e) => e.message).toList(), [
            ...original[i].game.issues.where((e) => e.message.contains('FEN')).map((e) => e.message),
            // Moves that could not be read stay in a comment, and so does the warning.
            if (original[i].game.hasUnparsedTail) 'Unread moves are kept in a comment',
          ], reason: exported);
        }
        // Idempotent: writing again gives the same text.
        expect(PgnWriter().writeAll(reparsed.map((p) => p.game)), exported);
      });
    }
  });

  group('position key', () {
    Position play(List<String> moves) {
      Position pos = Chess.initial;
      for (final m in moves) {
        pos = pos.play(pos.parseSan(m)!);
      }
      return pos;
    }

    test('transpositions map to the same key', () {
      final a = play(['Nf3', 'Nf6', 'c4']);
      final b = play(['c4', 'Nf6', 'Nf3']);
      expect(positionKeyOf(a), positionKeyOf(b));
      expect(a.fen == b.fen, isFalse, reason: 'move counters are equal here, but check anyway');
    });

    test('move counters are ignored', () {
      final a = play(['Nf3', 'Nf6', 'Ng1', 'Ng8']);
      expect(positionKeyOf(a), kInitialKey);
    });

    test('ep square only when capture is legal', () {
      final afterE4 = play(['e4']);
      expect(positionKeyOf(afterE4).split(' ')[3], '-');
      final epLegal = play(['e4', 'Nf6', 'e5', 'd5']);
      expect(positionKeyOf(epLegal).split(' ')[3], 'd6');
      // Same placement reached without the double push: different key.
      final noEpFen = epLegal.fen.replaceFirst(' d6 ', ' - ');
      expect(normalizeFenToKey(noEpFen) == positionKeyOf(epLegal), isFalse);
      expect(normalizeFenToKey('rnbqkbnr/pppp1ppp/8/8/4Pp2/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 3').split(' ')[3], 'e3');
      expect(normalizeFenToKey('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1').split(' ')[3], '-');
    });

    test('castling UCI normalization', () {
      final pos = positionFromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(parseUciMove(pos, 'e1g1'), isNotNull);
      expect(parseUciMove(pos, 'e1h1'), isNotNull);
      expect(parseUciMove(pos, 'e1g1'), parseUciMove(pos, 'e1h1'));
      expect(standardUci(pos, parseUciMove(pos, 'e1h1')!), 'e1g1');
      expect(standardUci(pos, parseUciMove(pos, 'e1c1')!), 'e1c1');
    });
  });
}
