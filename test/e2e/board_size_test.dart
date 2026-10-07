import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/notation_view.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// Every screen with a board uses one geometry (D-052): full width on an
/// ordinary phone, and one board size shared by all screens.
void main() {
  readingModeTests();
  sharedSizeTests();
  for (final size in const [Size(390, 844), Size(402, 874), Size(430, 932)]) {
    for (final route in const ['/build/1', '/analysis', '/repertoires/1']) {
      testWidgets('$route: board size at ${size.width.round()}x${size.height.round()}', (tester) async {
        final app = await pumpApp(tester, seed: seedRepertoire, size: size);
        await goTo(tester, route);
        final board = tester.getSize(find.byType(BoardView)).width;
        if (route == '/analysis') {
          expect(board, size.width);
        } else {
          // The repertoire keeps its tools on screen without scrolling, and
          // gives the board what is left (D-072): full width when the screen
          // is tall enough, a little less under the tab bar.
          expect(board, lessThanOrEqualTo(size.width));
          expect(board, greaterThan(size.width * 0.6));
          for (final tool in ['Тренувати', 'Аналіз']) {
            expect(find.text(tool).hitTestable(), findsOneWidget, reason: '$tool must be visible');
          }
          // And at least two rows of moves between the board and the tools.
          final below = tester.getRect(find.text('Аналіз')).top - tester.getRect(find.byType(BoardView)).bottom;
          expect(below, greaterThan(140));
        }
        expectClean(tester);
        await app.close(tester);
      });
    }
  }
}

/// Reading a lecture: a smaller board leaves room for the notation.
void readingModeTests() {
  testWidgets('reading mode shrinks the board and gives the notation room', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: const Size(402, 874));
    await goTo(tester, '/analysis');
    final fullBoard = tester.getSize(find.byType(BoardView)).width;
    final fullNotation = tester.getSize(find.byType(NotationView)).height;
    expect(fullBoard, 402);

    await tester.tap(find.byTooltip('Режим читання: менша дошка'));
    await settle(tester);
    expect(tester.getSize(find.byType(BoardView)).width, closeTo(402 * 0.6, 1));
    expect(tester.getSize(find.byType(NotationView)).height, greaterThan(fullNotation + 120));

    // The grip under the board: dragging down makes the board bigger.
    final grip = find.byKey(const ValueKey('board-size-grip'));
    await tester.drag(grip, const Offset(0, 80));
    await settle(tester);
    final dragged = tester.getSize(find.byType(BoardView)).width;
    expect(dragged, greaterThan(402 * 0.6 + 50));

    // Remembered: another analysis opens with the same board.
    await tester.binding.handlePopRoute();
    await settle(tester);
    await goTo(tester, '/analysis');
    expect(tester.getSize(find.byType(BoardView)).width, closeTo(dragged, 1));

    // And back to full width.
    await tester.tap(find.byTooltip('Дошка на всю ширину'));
    await settle(tester);
    expect(tester.getSize(find.byType(BoardView)).width, 402);
    expectClean(tester);
    await app.close(tester);
  });
}

/// A board resized on one screen is the same size on the others.
void sharedSizeTests() {
  testWidgets('board size is shared by analysis, repertoire and line editor', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: const Size(402, 874));
    await goTo(tester, '/repertoires/1');
    final initial = tester.getSize(find.byType(BoardView)).width;

    // Pull the grip up on the repertoire: the board gets smaller.
    await tester.drag(find.byKey(const ValueKey('board-size-grip')), const Offset(0, -120));
    await settle(tester);
    final resized = tester.getSize(find.byType(BoardView)).width;
    expect(resized, lessThan(initial - 80));

    for (final route in const ['/analysis', '/build/1']) {
      await goTo(tester, route);
      expect(tester.getSize(find.byType(BoardView)).width, closeTo(resized, 1), reason: route);
      expect(find.byKey(const ValueKey('board-size-grip')), findsOneWidget, reason: route);
    }
    expectClean(tester);
    await app.close(tester);
  });
}
