import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/library/import_flow.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';

void main() {
  // A UTF-8 file with one stray Windows byte was shown as "Р§РµРјРїС–..."
  // everywhere; and the import did not show any of the file's text.
  testWidgets('a PGN file is shown in readable Ukrainian before saving', (tester) async {
    final app = await pumpApp(tester);
    final bytes = File('test/fixtures/pgn/utf8_stray_byte.pgn').readAsBytesSync();
    await goTo(
      tester,
      '/import',
      extra: ImportInput(bytes: bytes, fileName: 'game.pgn'),
    );
    await settle(tester);
    expect(
      find.text('Шевченко, Олександр - Коваленко, Дмитро · Чемпіонат України\n«Найпопулярніший перший хід.»'),
      findsOneWidget,
    );
    expect(find.textContaining('Р§'), findsNothing);
    expectClean(tester);
    await app.close(tester);
  });

  // The selected annotation was a solid black circle: black symbol on the
  // black selected chip.
  testWidgets('the selected annotation symbol is readable', (tester) async {
    final app = await pumpApp(tester);
    await goTo(tester, '/analysis');
    final board = tester.widget<BoardView>(find.byType(BoardView));
    board.onMove!(board.position.parseSan('e4')!);
    await settle(tester, frames: 4);
    await tapText(tester, 'Дії');
    await tapText(tester, 'Оцінка');
    await tapText(tester, '⩲');

    final chip = find.ancestor(of: find.text('⩲'), matching: find.byType(FilterChip));
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    final cs = Theme.of(tester.element(chip)).colorScheme;
    final label = tester.renderObject<RenderParagraph>(find.text('⩲'));
    expect(label.text.style?.color, cs.onPrimary, reason: 'symbol colour on the selected (primary) chip');
    expectClean(tester);
    await app.close(tester);
  });
}
