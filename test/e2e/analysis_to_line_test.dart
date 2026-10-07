import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';

Future<int> _seed(RepertoireRepository repo) async {
  final id = await repo.create(name: 'Білі', color: Side.white);
  final g = await repo.loadGraph(id);
  addSanLine(g, Chess.initial, ['e4', 'e5']);
  await repo.saveGraph(id, g);
  return id;
}

void _play(WidgetTester tester, String san) {
  final board = tester.widget<BoardView>(find.byType(BoardView));
  board.onMove!(board.position.parseSan(san)!);
}

void main() {
  // Recording a line, the user analyses on the analysis board and brings
  // the analysed moves back into the line (they used to be stuck there).
  testWidgets('analysis opened from the line editor adds its moves to the line', (tester) async {
    late int id;
    final app = await pumpApp(tester, seed: (db) async => id = await _seed(RepertoireRepository(db)));
    final e4 = Chess.initial.play(Chess.initial.parseSan('e4')!);
    final afterE5 = positionKeyOf(e4.play(e4.parseSan('e5')!));
    await goTo(tester, '/build/$id?key=${Uri.encodeQueryComponent(afterE5)}');
    await tapText(tester, 'Аналіз');

    // The analysis says where the moves go and how to add them.
    expect(find.text('У репертуар «Білі»'), findsOneWidget);
    final add = find.widgetWithText(FilledButton, 'Додати');
    expect(tester.widget<FilledButton>(add).onPressed, isNull);

    _play(tester, 'Nf3');
    await settle(tester, frames: 4);
    _play(tester, 'Nc6');
    await settle(tester, frames: 4);
    expect(tester.widget<FilledButton>(add).onPressed, isNotNull);
    await tester.tap(add);
    await settle(tester);

    // Back in the editor, at the end of the added moves.
    expect(find.text('У репертуар «Білі»'), findsNothing);
    final g = (await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(id)))!;
    final sans = <String>[];
    var key = g.rootKey;
    while (g.movesFrom(key).isNotEmpty) {
      final m = g.movesFrom(key).first;
      sans.add(m.san);
      key = m.toKey;
    }
    expect(sans, ['e4', 'e5', 'Nf3', 'Nc6']);
    expect(find.text('Додано в репертуар'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('leaving the analysis with moves asks whether to add them', (tester) async {
    late int id;
    final app = await pumpApp(tester, seed: (db) async => id = await _seed(RepertoireRepository(db)));
    await goTo(tester, '/build/$id');
    await tapText(tester, 'Аналіз');
    _play(tester, 'd4');
    await settle(tester, frames: 4);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Додати ці ходи в лінію?'), findsOneWidget);
    await tapText(tester, 'Не додавати');
    final g = (await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(id)))!;
    expect(g.movesFrom(g.rootKey).map((m) => m.san), ['e4']);
    expectClean(tester);
    await app.close(tester);
  });

  // A floating "Train" button covered the content under the board and the
  // last rows of the tabs; training is an app-bar action now.
  testWidgets('the repertoire has Train in the app bar, nothing floating over the content', (tester) async {
    late int id;
    final app = await pumpApp(tester, seed: (db) async => id = await _seed(RepertoireRepository(db)));
    await goTo(tester, '/repertoires/$id');
    expect(find.byType(FloatingActionButton), findsNothing);
    final train = find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Тренувати'));
    expect(train, findsOneWidget);
    await tester.tap(train);
    await settle(tester);
    expect(find.text('Повторення'), findsOneWidget, reason: 'the training mode sheet opens');
    expectClean(tester);
    await app.close(tester);
  });
}
