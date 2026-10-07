import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/import/pgn_import_service.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/pgn/pgn_writer.dart';

const broken =
    '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 '
    '10. Qxh7 Nbd7 {plan} 11. Nbd2 Bb7 *';

void main() {
  parserEdgeCases();
  // Audit 05.10: everything after an illegal move was dropped on first edit.
  test('moves after an illegal move are kept in a comment', () {
    final game = PgnParser.parseOne(broken);
    expect(game.mainline.length, 18);
    expect(game.issues, isNotEmpty);
    expect(game.hasUnparsedTail, isTrue);
    expect(game.mainline.last.comments.single.text, '$kUnparsedMarker 10. Qxh7 Nbd7 (plan) 11. Nbd2 Bb7');
  });

  test('the kept tail survives a round trip and still raises a warning', () {
    final pgn = gameToPgn(PgnParser.parseOne(broken));
    expect(pgn, contains('10. Qxh7 Nbd7 (plan) 11. Nbd2 Bb7'));
    final again = PgnParser.parseOne(pgn);
    expect(again.mainline.length, 18);
    expect(again.hasUnparsedTail, isTrue);
    expect(again.issues, isNotEmpty);
    expect(gameToPgn(again), pgn);
  });

  test('a black move that breaks the line keeps the rest', () {
    final game = PgnParser.parseOne('1. e4 e5 2. Nf3 Qxh2 3. Bc4 *');
    expect(game.mainline.length, 3);
    expect(game.mainline.last.comments.single.text, '$kUnparsedMarker Qxh2 3. Bc4');
  });

  test('an unsupported variant keeps its movetext in the root comment', () {
    final game = PgnParser.parseOne('[Variant "Atomic"]\n\n1. e4 e5 2. Nf3 Nc6 1-0');
    expect(game.mainline, isEmpty);
    expect(game.root.comments.single.text, '$kUnparsedMarker 1. e4 e5 2. Nf3 Nc6');
  });

  test('a clean game has no tail', () {
    final game = PgnParser.parseOne('1. e4 e5 2. Nf3 *');
    expect(game.hasUnparsedTail, isFalse);
    expect(game.issues, isEmpty);
  });

  test('saving an edited broken game keeps the moves and the warning', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = LibraryRepository(db);
    final cid = await repo.createCollection('c');
    final parsed = PgnParser.parseAll(broken).single;
    await repo.addGames(cid, [summarizeParsed(parsed, const {})]);
    final row = (await repo.gamesOf(cid)).single;
    final game = PgnParser.parseOne(row.pgn);
    game.mainline[4].comments.add(const PgnComment(text: 'note'));
    await repo.saveGame(row.id, game);
    final saved = (await repo.game(row.id))!;
    expect(saved.pgn, contains('Nbd2 Bb7'));
    expect(saved.issuesJson, isNotEmpty);

    // Removing the kept comment clears the warning.
    final g2 = PgnParser.parseOne(saved.pgn);
    g2.mainline.last.comments.clear();
    await repo.saveGame(row.id, g2);
    expect((await repo.game(row.id))!.issuesJson, isEmpty);
  });
}

// Audit 05.10: smaller parser defects.
void parserEdgeCases() {
  test('a comment after the result stays with its game', () {
    final games = PgnParser.parseAll('1. e4 e5 1-0 {White wins}\n\n[Event "Next"]\n\n1. d4 *');
    expect(games, hasLength(2));
    expect(games.first.game.mainline.last.comments.single.text, 'White wins');
    expect(games.last.game.headers['Event'], 'Next');
  });

  test('a byte-order mark between games is not a move', () {
    final games = PgnParser.parseAll('[Event "A"]\n\n1. e4 *\n\n﻿[Event "B"]\n\n1. d4 *');
    expect(games, hasLength(2));
    expect(games.every((g) => g.game.issues.isEmpty), isTrue);
  });

  test('0000 is a null move', () {
    final game = PgnParser.parseOne('1. e4 0000 2. d4 *');
    expect(game.issues, isEmpty);
    expect(game.mainline, hasLength(3));
    expect(game.mainline[1].isNullMove, isTrue);
  });

  test('plain text is not a game', () {
    expect(PgnParser.parseAll('hello, this is not chess at all'), isEmpty);
    expect(PgnParser.parseAll('1. e4 e5 2. Qxh9 *'), hasLength(1), reason: 'a game with a bad move is still a game');
  });
}
