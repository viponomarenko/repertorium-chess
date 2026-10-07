import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/import/pgn_import_service.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/domain/srs/fsrs.dart';
import 'package:tabiya/domain/training/training_engine.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('library: import, search, edit, export', () async {
    final repo = LibraryRepository(db);
    final id = await repo.createCollection('Test');
    final games = PgnImportService.parseTextSync('''
[Event "One"]
[White "Alice"]
[Black "Bob"]
[Result "1-0"]

1. e4 e5 2. Nf3 {comment [%clk 0:01:00]} Nc6 1-0

[Event "Two"]
[White "Carol"]
[Black "Dave"]
[Result "*"]

1. d4 d5 2. Qh8 *
''');
    expect(games[1].issues, isNotEmpty);
    await repo.addGames(id, games);
    final all = await repo.watchGames(id).first;
    expect(all, hasLength(2));
    final found = await repo.watchGames(id, filter: const GameFilter(query: 'carol')).first;
    expect(found.single.event, 'Two');
    final cols = await repo.watchCollections().first;
    expect(cols.single.gameCount, 2);

    final g = parseStoredGame(all.first.pgn);
    g.headers['White'] = 'Alicia';
    await repo.saveGame(all.first.id, g);
    final exported = await repo.exportPgn(collectionId: id);
    expect(exported, contains('Alicia'));
    expect(exported, contains('[%clk 0:01:00]'));
    expect(PgnParser.parseAll(exported), hasLength(2));
  });

  test('repertoire: persist graph changes and reviews', () async {
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'Black', color: Side.black);
    var graph = await repo.loadGraph(id);
    importIntoRepertoire(graph, [
      ImportSource.game(PgnParser.parseOne('1. e4 c5 2. Nf3 d6 (2... Nc6) 3. d4 cxd4 *')),
    ], const RepImportOptions(ownAllVariations: true));
    await repo.saveGraph(id, graph);
    expect(graph.changes.isEmpty, isTrue);

    graph = await repo.loadGraph(id);
    expect(graph.checkInvariants(), isEmpty);
    expect(graph.moveCount, 7);
    final nf3Key = normalizeFenToKey('rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2');
    expect(graph.mainMove(nf3Key)!.san, 'd6');

    // Delete a branch and persist.
    graph.deleteMove(graph.alternatives(nf3Key).single);
    await repo.saveGraph(id, graph);
    graph = await repo.loadGraph(id);
    expect(graph.moveCount, 6);
    expect(graph.checkInvariants(), isEmpty);

    final summaries = await repo.watchSummaries().first;
    expect(summaries.single.cards, 3);
    expect(summaries.single.newCards, 3);

    // Record a review.
    final key = graph.cards.keys.first;
    final now = DateTime.now();
    final after = Fsrs().review(const SrsState(), Grade.good, now);
    await repo.recordReview(
      id,
      ReviewEvent(
        key: key,
        before: const SrsState(),
        after: after,
        grade: Grade.good,
        mode: 'learn',
        playedUci: 'c7c5',
        expectedUci: 'c7c5',
        responseMs: 1200,
        scheduled: true,
        timestamp: now,
      ),
    );
    graph = await repo.loadGraph(id);
    expect(graph.cards[key]!.srs.state, CardState.review);
    expect(await repo.introducedSince(now.subtract(const Duration(hours: 1))), 1);
    expect(await repo.streak(), 1);
    final f = await repo.forecast(days: 7);
    expect(f.fold<int>(0, (a, d) => a + d.count), 1);
    // One slip is not a problem position yet; the second one is (D-059).
    expect(await repo.markAgain(id, key), isTrue);
    expect(await repo.problemPositions(), isEmpty);
    await repo.markAgain(id, key);
    final problems = await repo.problemPositions();
    expect(problems.single.key, key);
    // Every answer counts for the daily goal, and still does after the
    // repertoire is deleted (D-058).
    final day = repo.fsrs.dayStart(DateTime.now());
    final answers = await repo.answersSince(day);
    expect(answers, greaterThanOrEqualTo(3));
    await repo.delete(id);
    expect(await repo.answersSince(day), answers);
    expect((await repo.answersPerDay()).last, answers);
    expect(await repo.watchSummaries().first, isEmpty);
  });

  // Deleting a repertoire can be undone from the snackbar.
  test('snapshot brings a deleted repertoire back with its history', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'r', color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3']);
    await repo.saveGraph(id, g);
    final now = DateTime.now();
    final before = g.cards[kInitialKey]!.srs;
    await repo.recordReview(
      id,
      ReviewEvent(
        key: kInitialKey,
        before: before,
        after: repo.fsrs.review(before, Grade.good, now),
        grade: Grade.good,
        mode: 'learn',
        playedUci: 'e2e4',
        expectedUci: 'e2e4',
        responseMs: 900,
        scheduled: true,
        timestamp: now,
      ),
    );
    final day = repo.fsrs.dayStart(now);
    expect(await repo.answersSince(day), 1);
    final snap = await repo.snapshot(id);
    await repo.delete(id);
    expect(await repo.answersSince(day), 1, reason: 'the goal keeps the answer');
    await repo.restoreSnapshot(snap!);
    final back = await repo.loadGraph(id);
    expect(back.moveCount, 3);
    expect(back.cards[kInitialKey]!.srs.isNew, isFalse);
    expect(await repo.answersSince(day), 1, reason: 'not counted twice after the undo');
  });

  test('suspension of a branch is reported for its marker', () async {
    final g = RepertoireGraph(color: Side.white, rootKey: kInitialKey, rootFen: kInitialFen);
    addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    final afterE4 = g.movesFrom(kInitialKey).single.toKey;
    expect(g.suspension(afterE4), (any: false, all: false));
    g.setSuspendedSubtree(afterE4, true);
    expect(g.suspension(afterE4), (any: true, all: true));
    expect(g.suspension(kInitialKey).all, isFalse, reason: 'the first move itself is still trained');
  });

  test('markAgain leaves a never-learned card alone', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'r', color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3']);
    await repo.saveGraph(id, g);
    expect(await repo.markAgain(id, kInitialKey), isFalse);
    expect((await repo.loadGraph(id)).cards[kInitialKey]!.srs.isNew, isTrue);
    expect(await repo.problemPositions(), isEmpty);
  });

  // Regression: changes made while a save was running were cleared unwritten
  // (quick moves in the line editor disappeared after a reload).
  test('repertoire: edits during a running save are not lost', () async {
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'W', color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, ['e4', 'e5']);
    final first = repo.saveGraph(id, g);
    // Edit before the first save completes.
    addSanLine(g, Chess.initial, ['d4', 'd5']);
    await first;
    await repo.saveGraph(id, g);
    final reloaded = await repo.loadGraph(id);
    expect(reloaded.move(reloaded.rootKey, 'd2d4'), isNotNull);
    expect(reloaded.move(reloaded.rootKey, 'e2e4'), isNotNull);
  });
}
