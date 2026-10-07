import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/domain/srs/fsrs.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';

const lines = [
  ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
  ['e4', 'c5', 'Nf3', 'd6', 'd4'],
];

/// Expected own move for each position of the repertoire.
Map<PositionKey, String> expectedMoves() {
  final out = <PositionKey, String>{};
  for (final line in lines) {
    Position pos = Chess.initial;
    for (final san in line) {
      if (pos.turn == Side.white) out[positionKeyOf(pos)] = san;
      pos = pos.play(pos.parseSan(san)!);
    }
  }
  return out;
}

void main() {
  // Regression (P0): "Next line" showed the same finished line forever.
  testWidgets('learning goes through several lines to the session summary', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final repo = RepertoireRepository(db);
        final id = await repo.create(name: 'Білі', color: Side.white);
        final g = await repo.loadGraph(id);
        for (final l in lines) {
          addSanLine(g, Chess.initial, l);
        }
        await repo.saveGraph(id, g);
      },
    );
    final expected = expectedMoves();
    await tapText(tester, 'Тренуватись');

    var linesDone = 0;
    var sawFinish = false;
    for (var step = 0; step < 300; step++) {
      if (find.text('Сесію завершено!').evaluate().isNotEmpty) break;
      // The button of the last line says "Finish".
      final next = find.text('Наступна лінія').evaluate().isNotEmpty ? 'Наступна лінія' : 'Завершити';
      if (find.text(next).evaluate().isNotEmpty) {
        linesDone++;
        sawFinish |= next == 'Завершити';
        await tapText(tester, next);
        continue;
      }
      final board = find.byType(BoardView);
      final enter = find.text('Ввести хід');
      if (board.evaluate().isNotEmpty && enter.evaluate().isNotEmpty) {
        final pos = tester.widget<BoardView>(board).position;
        final san = expected[positionKeyOf(pos)];
        if (san != null && pos.turn == Side.white) {
          await tapText(tester, 'Ввести хід');
          await tester.enterText(find.byType(TextField), san);
          await tapText(tester, 'OK');
          continue;
        }
      }
      await settle(tester, frames: 4);
    }
    expect(find.text('Сесію завершено!'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(linesDone, greaterThanOrEqualTo(2));
    expect(sawFinish, isTrue, reason: 'the last line offers Finish, not Next line');
    expectClean(tester);
    await app.close(tester);
  });

  // Regression (audit 05.10): after the last line of the first repertoire
  // the board froze with an empty status card; the second never started.
  testWidgets('a session over two repertoires reaches the summary', (tester) async {
    const white = ['e4', 'e5', 'Nf3'];
    const black = ['d4', 'd5', 'c4', 'e6'];
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final repo = RepertoireRepository(db);
        final w = await repo.create(name: 'Білі', color: Side.white);
        final gw = await repo.loadGraph(w);
        addSanLine(gw, Chess.initial, white);
        await repo.saveGraph(w, gw);
        final b = await repo.create(name: 'Чорні', color: Side.black);
        final gb = await repo.loadGraph(b);
        addSanLine(gb, Chess.initial, black);
        await repo.saveGraph(b, gb);
      },
    );
    final expected = <PositionKey, String>{};
    for (final (line, side) in [(white, Side.white), (black, Side.black)]) {
      Position pos = Chess.initial;
      for (final san in line) {
        if (pos.turn == side) expected[positionKeyOf(pos)] = san;
        pos = pos.play(pos.parseSan(san)!);
      }
    }
    await tapText(tester, 'Тренуватись');

    final played = <String>{};
    for (var step = 0; step < 300; step++) {
      if (find.text('Сесію завершено!').evaluate().isNotEmpty) break;
      final next = find.text('Наступна лінія').evaluate().isNotEmpty ? 'Наступна лінія' : 'Завершити';
      if (find.text(next).evaluate().isNotEmpty) {
        await tapText(tester, next);
        continue;
      }
      final board = find.byType(BoardView);
      if (board.evaluate().isNotEmpty && find.text('Ввести хід').evaluate().isNotEmpty) {
        final san = expected[positionKeyOf(tester.widget<BoardView>(board).position)];
        if (san != null) {
          await tapText(tester, 'Ввести хід');
          await tester.enterText(find.byType(TextField), san);
          await tapText(tester, 'OK');
          played.add(san);
          continue;
        }
      }
      await settle(tester, frames: 4);
    }
    expect(find.text('Сесію завершено!'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    // Moves of both repertoires were asked.
    expect(played, containsAll(<String>['e4', 'Nf3', 'd5', 'e6']));
    expectClean(tester);
    await app.close(tester);
  });

  // D-065: one "Train" button runs what is due, then new moves, in one session.
  testWidgets('the Train button chains review and new moves', (tester) async {
    const line = ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'];
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final repo = RepertoireRepository(db);
        final id = await repo.create(name: 'Білі', color: Side.white);
        final g = await repo.loadGraph(id);
        addSanLine(g, Chess.initial, line);
        // The first move is learned and due; the other two are new.
        final first = g.cards[kInitialKey]!.srs;
        g.updateCard(
          kInitialKey,
          first.copyWith(
            state: CardState.review,
            reps: 2,
            stability: 3,
            difficulty: 5,
            due: DateTime.now().subtract(const Duration(days: 1)),
            lastReview: DateTime.now().subtract(const Duration(days: 4)),
          ),
        );
        await repo.saveGraph(id, g);
      },
    );
    final expected = <PositionKey, String>{};
    Position pos = Chess.initial;
    for (final san in line) {
      if (pos.turn == Side.white) expected[positionKeyOf(pos)] = san;
      pos = pos.play(pos.parseSan(san)!);
    }
    expect(find.text('Тренуватись'), findsOneWidget);
    expect(find.textContaining('Вивчити нові'), findsNothing);
    expect(find.textContaining('1 повторення'), findsOneWidget);
    await tapText(tester, 'Тренуватись');
    expect(find.text('Повторення'), findsOneWidget);

    final titles = <String>{};
    for (var step = 0; step < 300; step++) {
      if (find.text('Сесію завершено!').evaluate().isNotEmpty) break;
      for (final t in ['Повторення', 'Нові ходи']) {
        if (find.text(t).evaluate().isNotEmpty) titles.add(t);
      }
      final next = find.text('Наступна лінія').evaluate().isNotEmpty ? 'Наступна лінія' : 'Завершити';
      if (find.text(next).evaluate().isNotEmpty) {
        await tapText(tester, next);
        continue;
      }
      final board = find.byType(BoardView);
      if (board.evaluate().isNotEmpty && find.text('Ввести хід').evaluate().isNotEmpty) {
        final san = expected[positionKeyOf(tester.widget<BoardView>(board).position)];
        if (san != null) {
          await tapText(tester, 'Ввести хід');
          await tester.enterText(find.byType(TextField), san);
          await tapText(tester, 'OK');
          continue;
        }
      }
      await settle(tester, frames: 4);
    }
    expect(find.text('Сесію завершено!'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(titles, {'Повторення', 'Нові ходи'}, reason: 'both parts of the session were played');
    // One suggestion on the summary, not a menu.
    expect(find.byType(OutlinedButton), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });
}
