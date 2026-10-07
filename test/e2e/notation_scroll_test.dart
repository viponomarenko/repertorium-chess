import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/notation_view.dart';

import 'harness.dart';

/// After adding an engine line, the current move at the end of that line
/// must be visible in the notation, not scrolled off below.
void main() {
  testWidgets('notation follows the current move', (tester) async {
    final app = await pumpApp(tester, size: const Size(390, 844));
    await goTo(tester, '/analysis');
    await tapText(tester, 'Рушій');
    // An engine line becomes a variation and the cursor stays put.
    expect(find.byTooltip('Додати як варіант').first.hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Додати як варіант').first);
    await settle(tester);
    expect(tester.widget<BoardView>(find.byType(BoardView)).position.fullmoves, 1);
    // A long game played on the board: the notation outgrows its area.
    const moves = [
      'e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6', 'Ba4', 'Nf6', 'O-O', 'Be7', 'Re1', 'b5', 'Bb3', 'd6', //
      'c3', 'O-O', 'h3', 'Nb8', 'd4', 'Nbd7', 'c4', 'c6', 'Nc3', 'Bb7', 'Bg5', 'h6', 'Bh4', 'Re8',
    ];
    for (final san in moves) {
      final board = tester.widget<BoardView>(find.byType(BoardView));
      board.onMove!(board.position.parseSan(san)!);
      await settle(tester, frames: 6);
    }
    final notation = tester.getRect(find.byType(NotationView));
    // The highlighted (current) move is painted with the current-move colour.
    final current = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).color != null &&
          (w.decoration! as BoxDecoration).borderRadius == BorderRadius.circular(6),
    );
    expect(current, findsOneWidget);
    final r = tester.getRect(current);
    expect(notation.contains(r.center), isTrue, reason: 'current move $r outside notation $notation');
    expectClean(tester);
    await app.close(tester);
  });
}
