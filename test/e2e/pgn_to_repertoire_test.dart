import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/presentation/game/game_screen.dart';

import 'harness.dart';

/// A lecture: main line with a variation that has its own comment.
const lecture = '''
[Event "Лекція"]
[White "Два коні"]
[Black "?"]
[Result "*"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 {Захист двох коней} 4. Ng5 (4. d4 {гостріше} exd4 5. O-O) 4... d5 5. exd5 Na5 *
''';

void main() {
  test('lineThrough keeps one line with its comments, no side variations', () {
    final g = PgnParser.parseOne(lecture);
    final d4 = g.root.mainChild!.mainChild!.mainChild!.mainChild!.mainChild!.mainChild!.children[1];
    expect(d4.san, 'd4');
    final line = g.lineThrough(d4.mainChild!);
    expect(line.mainline.map((n) => n.san), ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6', 'd4', 'exd4', 'O-O']);
    expect(line.mainline[5].commentText, 'Захист двох коней');
    expect(line.mainline[6].commentText, 'гостріше');
    expect(line.root.descendants().every((n) => n.children.length <= 1), isTrue);
    expect(playersLine(line.headers['White'], line.headers['Black']), 'Два коні');
  });

  // Reading a file to learn from it: step into a variation, add just that
  // line, learn it. The wizard's Import button used to fill the screen.
  testWidgets('a line read in a PGN goes into a repertoire, ready to learn', (tester) async {
    final app = await pumpApp(tester);
    await goTo(tester, '/analysis', extra: const GameScreenArgs(pgn: lecture));
    // Into the variation 4. d4 exd4 5. O-O.
    await tapContaining(tester, 'exd4');
    await tapText(tester, 'Дії');
    expect(find.text('ВЧИТИ: ДОДАТИ В РЕПЕРТУАР'), findsOneWidget);
    await tapText(tester, 'Цю лінію');

    final import = find.widgetWithText(FilledButton, 'Імпортувати');
    expect(import, findsOneWidget);
    expect(tester.getSize(import).height, lessThan(80), reason: 'the button must not fill the screen');
    await settle(tester);
    await tester.tap(import);
    await settle(tester);
    expect(find.text('Вчити'), findsOneWidget, reason: 'snackbar offers to learn the new moves');

    final reps = (await tester.runAsync(() => RepertoireRepository(app.db).watchSummaries().first))!;
    expect(reps, hasLength(1));
    final g = (await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(reps.single.row.id)))!;
    final sans = <String>[];
    for (var key = g.rootKey; g.movesFrom(key).isNotEmpty; key = g.movesFrom(key).first.toKey) {
      expect(g.movesFrom(key), hasLength(1), reason: 'only the chosen line, no side variations');
      sans.add(g.movesFrom(key).first.san);
    }
    expect(sans, ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6', 'd4', 'exd4', 'O-O']);
    expectClean(tester);
    await app.close(tester);
  });
}
