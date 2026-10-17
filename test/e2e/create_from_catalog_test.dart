import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// A new repertoire can start from an opening picked in the catalog,
/// without typing moves or a FEN (D-088).
void main() {
  testWidgets('the start position comes from the opening catalog', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    await tapText(tester, 'Створити');
    await tapText(tester, 'Обрати з каталогу дебютів');
    for (var i = 0; i < 20 && find.text('Sicilian Defense').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await settle(tester, frames: 4);
    }
    await tapText(tester, 'Sicilian Defense');

    // The moves, the name and the opening are filled in.
    Finder field(String text) => find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);
    expect(field('1. e4 c5'), findsOneWidget);
    expect(field('Sicilian Defense'), findsOneWidget);
    expect(find.text('B20 · Sicilian Defense'), findsOneWidget);
    expectClean(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Створити'));
    await settle(tester);
    final reps = await tester.runAsync(() => app.db.select(app.db.repertoires).get());
    final created = reps!.firstWhere((r) => r.name == 'Sicilian Defense');
    final start = Chess.initial.play(Chess.initial.parseSan('e4')!);
    expect(created.rootFen, start.play(start.parseSan('c5')!).fen);
    await app.close(tester);
  });
}
