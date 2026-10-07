import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/repertoire/repertoire_tree.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// The repertoire tree (D-050): a line runs as one row until it branches,
/// branches fold, and the tree keeps its state across tabs.
void main() {
  Finder move(String text) =>
      find.descendant(of: find.byType(RepertoireTree), matching: find.text(text, findRichText: true));

  testWidgets('lines are rows between branching points', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    await goTo(tester, '/repertoires/1');
    await tapText(tester, 'Дерево');
    // The board is full width; pulling the grip up gives the tree room.
    await tester.drag(find.byKey(const ValueKey('board-size-grip')), const Offset(0, -200));
    await settle(tester);

    // 1. e4 - one row; the two replies are rows under it, each a whole line.
    for (final m in ['1. e4', '1... e5', 'Nc6', '3. Bb5', '1... c5', 'd6', '3. d4']) {
      expect(move(m), findsOneWidget, reason: m);
    }
    expect(move('2. Nf3'), findsNWidgets(2));
    final e4 = tester.getTopLeft(move('1. e4'));
    final e5 = tester.getTopLeft(move('1... e5'));
    final nf3 = tester.getTopLeft(move('2. Nf3').first);
    final bb5 = tester.getTopLeft(move('3. Bb5'));
    expect(e5.dx, greaterThan(e4.dx), reason: 'continuations are indented');
    // A line without branches runs as text (wrapping, not a staircase).
    expect(nf3.dy, e5.dy);
    expect(bb5.dx, anyOf(greaterThan(nf3.dx), e5.dx));

    // Folding: the row shows how many lines it hides.
    await tapTooltip(tester, 'Згорнути все');
    expect(move('1... e5'), findsNothing);
    expect(find.textContaining('2 лінії'), findsOneWidget);
    await tapContaining(tester, '2 лінії');
    expect(move('1... e5'), findsOneWidget);
    expect(find.byTooltip('Згорнути все'), findsOneWidget);

    // Selecting a move updates the shared board without leaving the tree.
    final boardBounds = tester.getRect(find.byType(BoardView));
    final moveBounds = tester.getRect(move('3. Bb5'));
    final scroll = tester
        .widget<ListView>(find.descendant(of: find.byType(RepertoireTree), matching: find.byType(ListView)))
        .controller!;
    final offset = scroll.offset;
    await tester.tap(move('3. Bb5'));
    for (var frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(RepertoireTree), findsOneWidget);
      expect(tester.getRect(find.byType(BoardView)), boardBounds);
      expect(tester.getRect(move('3. Bb5')), moveBounds);
      expect(scroll.offset, offset);
    }
    expect(tester.widget<BoardView>(find.byType(BoardView)).position.board.pieceAt(Square.b5)?.role, Role.bishop);
    await tapText(tester, 'Ходи');
    await tapText(tester, 'Дерево');
    expect(move('3. Bb5'), findsOneWidget);
    expect(move('1... c5'), findsOneWidget);
    expect(tester.getSemantics(move('3. Bb5')), isSemantics(isSelected: true));
    await tapText(tester, 'Проблеми');
    await tapText(tester, 'Позиції');
    expect(move('3. Bb5'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  for (final size in [const Size(320, 640), const Size(402, 874), const Size(900, 600)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('board and tree fit $size with text $scale', (tester) async {
        final app = await pumpApp(tester, seed: seedRepertoire, size: size, textScale: scale);
        await goTo(tester, '/repertoires/1');
        // Switching changes only the lower panel, including during animation.
        final fixedElements = [
          find.byType(BoardView),
          find.byKey(const ValueKey('repertoire-view-switch')),
          find.text('Ходи'),
          find.text('Дерево'),
          find.byTooltip('Початок'),
        ];
        final bounds = fixedElements.map(tester.getRect).toList();
        for (final label in ['Дерево', 'Ходи', 'Дерево']) {
          await tester.tap(find.text(label));
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 40));
            for (var i = 0; i < fixedElements.length; i++) {
              expect(tester.getRect(fixedElements[i]), bounds[i], reason: '$label frame $frame element $i');
            }
          }
        }
        expect(find.byType(BoardView), findsOneWidget);
        expect(find.byType(RepertoireTree), findsOneWidget);
        await tapTooltip(tester, 'Згорнути все');
        await tapTooltip(tester, 'Розгорнути все');
        final treeList = find.descendant(of: find.byType(RepertoireTree), matching: find.byType(ListView));
        expect(tester.getSize(treeList).height, greaterThan(36));
        await tester.drag(treeList, const Offset(0, -180));
        await settle(tester);
        expectClean(tester);
        await app.close(tester);
      });
    }
  }
}

Future<void> tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await settle(tester);
}
