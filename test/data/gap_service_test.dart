import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/data/sync/gap_service.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

/// "Compare with repertoire" on My games (user: "Something went wrong").
void main() {
  test('analyzeAll finds where games leave the repertoire', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'Сицилійська', color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
    await repo.saveGraph(id, g);
    for (final (i, moves) in ['1. e4 c5 2. Nf3 Nc6 3. d4 1-0', '1. e4 c5 2. c3 d5 0-1'].indexed) {
      await db
          .into(db.importedGames)
          .insert(
            ImportedGamesCompanion.insert(
              provider: 'lichess',
              externalId: 'g$i',
              pgn: '[White "me"]\n[Black "opp"]\n\n$moves',
              playedAt: DateTime(2026, 9, 1 + i),
              userColor: 'white',
              result: const Value('1-0'),
            ),
          );
    }
    final summary = await GapService(db, repo).analyzeAll();
    expect(summary.games, 2);
    expect(summary.reached, 2);
    expect(summary.events, 2);
    final events = await GapService(db, repo).watchEvents().first;
    expect(events.map((e) => e.event.playedSan).toSet(), {'Nc6', 'c3'});
  });

  test('a repertoire that starts after a few moves meets only games reaching it', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RepertoireRepository(db);
    // Starts after 1. g3 e5 2. Bg2 d5 (like the user's Hungarian repertoire).
    Position start = Chess.initial;
    for (final san in ['g3', 'e5', 'Bg2', 'd5']) {
      start = start.play(start.parseSan(san)!);
    }
    final id = await repo.create(name: 'Hungarian', color: Side.white, rootFen: start.fen);
    final g = await repo.loadGraph(id);
    addSanLine(g, start, ['b4']);
    await repo.saveGraph(id, g);
    await db
        .into(db.importedGames)
        .insert(
          ImportedGamesCompanion.insert(
            provider: 'chesscom',
            externalId: 'x',
            pgn: '1. e4 e5 2. Nf3 d6 1-0',
            playedAt: DateTime(2026, 9, 1),
            userColor: 'white',
          ),
        );
    final summary = await GapService(db, repo).analyzeAll();
    expect((summary.games, summary.reached, summary.events), (1, 0, 0));
  });

  // Audit 05.10: with a 1.e4 and a 1.d4 repertoire every 1.e4 game was
  // reported as leaving the 1.d4 one (D-057).
  test('a game is judged against the repertoire it follows the longest', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RepertoireRepository(db);
    final e4 = await repo.create(name: 'e4', color: Side.white);
    var g = await repo.loadGraph(e4);
    addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
    await repo.saveGraph(e4, g);
    final d4 = await repo.create(name: 'd4', color: Side.white);
    g = await repo.loadGraph(d4);
    addSanLine(g, Chess.initial, ['d4', 'd5', 'c4']);
    await repo.saveGraph(d4, g);
    for (final (i, moves) in [
      '1. e4 c5 2. Nf3 d6 3. d4 1-0', // stays inside the e4 repertoire
      '1. e4 c5 2. c3 d5 0-1', // leaves the e4 repertoire on move 2
      '1. d4 d5 2. Nf3 1-0', // leaves the d4 repertoire on move 2
    ].indexed) {
      await db
          .into(db.importedGames)
          .insert(
            ImportedGamesCompanion.insert(
              provider: 'lichess',
              externalId: 'g$i',
              pgn: '[White "me"]\n[Black "opp"]\n\n$moves',
              playedAt: DateTime(2026, 9, 1 + i),
              userColor: 'white',
              result: const Value('1-0'),
            ),
          );
    }
    final summary = await GapService(db, repo).analyzeAll();
    expect(summary.events, 2);
    final events = await GapService(db, repo).watchEvents().first;
    expect({for (final e in events) (e.repertoireId, e.event.playedSan)}, {(e4, 'c3'), (d4, 'Nf3')});
  });
}
