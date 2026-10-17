import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/notation_view.dart';

import 'harness.dart';

/// The analysis screen with every panel open (user screenshots: the engine
/// panel and the Lichess-login card pushed the notation out; the arrow bar
/// overflowed). The notation must stay visible and nothing may overflow.
void main() {
  for (final size in const [Size(320, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets('analysis with all panels, ${size.width.round()}px, text ${scale}x', (tester) async {
        final app = await pumpApp(tester, size: size, textScale: scale);
        await goTo(tester, '/analysis');
        // The notation is as tall as its moves (no empty box under a short
        // game), so there has to be a move to see.
        final board = tester.widget<BoardView>(find.byType(BoardView));
        board.onMove!(board.position.parseSan('e4')!);
        await settle(tester);
        await tapText(tester, 'Рушій');
        await tapText(tester, 'База');
        await tapText(tester, 'Дії');
        await tapText(tester, 'Малювати стрілки');
        expectClean(tester);
        final notation = tester.getSize(find.byType(NotationView));
        expect(notation.height, greaterThanOrEqualTo(40), reason: 'a row of moves must stay in view');
        if (scale == 1.0) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await app.close(tester);
      });
    }
  }

  // User screenshot (17.10): the engine unfolded with several long lines
  // overflowed its room above the notation.
  for (final size in const [Size(320, 640), Size(402, 874)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('unfolded engine lines fit at ${size.width.round()}px, text ${scale}x', (tester) async {
        final app = await pumpApp(tester, size: size, textScale: scale);
        await goTo(tester, '/analysis');
        final board = tester.widget<BoardView>(find.byType(BoardView));
        board.onMove!(board.position.parseSan('e4')!);
        await settle(tester);
        // A game with a variation, as on the screenshot: 1. e4 c5 (1... e5).
        var b = tester.widget<BoardView>(find.byType(BoardView));
        b.onMove!(b.position.parseSan('c5')!);
        await settle(tester);
        await tapText(tester, 'Назад');
        b = tester.widget<BoardView>(find.byType(BoardView));
        b.onMove!(b.position.parseSan('e5')!);
        await settle(tester);
        await tapText(tester, 'Рушій');
        await tester.tap(find.byTooltip('Розгорнути'));
        await settle(tester);
        expectClean(tester);
        expect(tester.getSize(find.byType(NotationView)).height, greaterThanOrEqualTo(40));
        await app.close(tester);
      });
    }
  }

  // User: "when I turn the engine on the board becomes small, and that's
  // it". The board keeps the size chosen with the grip; the grip still works.
  testWidgets('engine and explorer do not shrink the board', (tester) async {
    final app = await pumpApp(tester, size: const Size(402, 874));
    await goTo(tester, '/analysis');
    double board() => tester.getSize(find.byType(BoardView)).width;
    expect(board(), 402);
    await tapText(tester, 'Рушій');
    expect(board(), 402);
    expectClean(tester);
    await tapText(tester, 'База');
    expect(board(), 402);
    expectClean(tester);

    await tester.drag(find.byKey(const ValueKey('board-size-grip')), const Offset(0, -120));
    await settle(tester);
    final smaller = board();
    expect(smaller, lessThan(402 - 80));
    await tapText(tester, 'Рушій');
    expect(board(), closeTo(smaller, 1));
    await tester.drag(find.byKey(const ValueKey('board-size-grip')), const Offset(0, 200));
    await settle(tester);
    expect(board(), 402);
    expectClean(tester);
    await app.close(tester);
  });
}
