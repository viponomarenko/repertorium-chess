import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/presentation/home/today_screen.dart';
import 'package:tabiya/presentation/repertoire/repertoire_grid_card.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// The tablet Repertoires, Library and Collection (D-104), and the phone
/// keeping its own lists.
const _tablet = Size(834, 1210);
const _phone = Size(390, 844);

Future<void> _seed(AppDatabase db) async {
  await seedRepertoire(db);
  final library = LibraryRepository(db);
  final col = await library.createCollection('Класичні мініатюри', source: 'file');
  for (final pgn in [
    '[Event "Paris Opera"]\n[White "Paul Morphy"]\n[Black "Duke Karl"]\n[Date "1858.11.02"]\n[Result "1-0"]\n\n'
        '1. e4 e5 2. Nf3 d6 1-0',
    '[Event "Paris Opera"]\n[White "A"]\n[Black "B"]\n[Result "1/2-1/2"]\n\n1. d4 d5 1/2-1/2',
    '[Event "London"]\n[White "Adolf Anderssen"]\n[Black "Lionel Kieseritzky"]\n[Result "0-1"]\n\n1. e4 e5 0-1',
  ]) {
    await library.createGame(col, PgnParser.parseOne(pgn));
  }
  await library.createCollection('Турнір клубу');
}

void main() {
  testWidgets('a tablet shows the overview and the grid of repertoires', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _tablet);
    await goTo(tester, '/repertoires');
    expect(find.text('Тренувати все'), findsOneWidget);
    expect(find.byType(RepertoireGridCard), findsOneWidget);
    // The first moves of the main line: 1. e4 e5 2. Nf3 Nc6 3. Bb5.
    expect(find.byType(FirstMovesLine), findsOneWidget);
    expectClean(tester);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await app.close(tester);
  });

  testWidgets('a phone keeps its list of repertoires', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _phone);
    await goTo(tester, '/repertoires');
    expect(find.text('Тренувати все'), findsNothing);
    expect(find.byType(RepertoireCard), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('a tablet Library has search, import tiles and a grid', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _tablet);
    await goTo(tester, '/library');
    expect(find.text('Файл PGN'), findsOneWidget);
    expect(find.text('З буфера'), findsOneWidget);
    expect(find.text('За посиланням'), findsOneWidget);
    expect(find.text('Класичні мініатюри'), findsOneWidget);
    // The search keeps only the matching collections.
    await tester.enterText(find.byType(TextField), 'клуб');
    await settle(tester);
    expect(find.text('Класичні мініатюри'), findsNothing);
    expect(find.text('Турнір клубу'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('a phone keeps its list of collections', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _phone);
    await goTo(tester, '/library');
    expect(find.text('Файл PGN'), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
    await app.close(tester);
  });

  testWidgets('a tablet collection groups games by event and counts results', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _tablet);
    await goTo(tester, '/library/1');
    expect(find.text('PARIS OPERA'), findsOneWidget);
    expect(find.text('LONDON'), findsOneWidget);
    expect(find.text('Paul Morphy'), findsOneWidget);
    // "1-0 1" on its filter, all three under "Усі".
    expect(find.textContaining('Усі 3'), findsOneWidget);
    // The search narrows the list and the counts.
    await tester.enterText(find.byType(TextField), 'Anderssen');
    await settle(tester);
    expect(find.text('PARIS OPERA'), findsNothing);
    expect(find.textContaining('Усі 1'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('selecting games on a tablet shows the bar along the bottom', (tester) async {
    final app = await pumpApp(tester, seed: _seed, size: _tablet);
    await goTo(tester, '/library/1');
    await tester.tap(find.text('Вибрати'));
    await settle(tester);
    await tester.tap(find.text('Paul Morphy'));
    await settle(tester);
    expect(find.text('Вибрано: 1'), findsOneWidget);
    expect(find.text('В репертуар'), findsOneWidget);
    // Back ends the selection, not the page.
    await tester.tap(find.text('Готово'));
    await settle(tester);
    expect(find.text('Вибрано: 1'), findsNothing);
    expect(find.text('Вибрати'), findsOneWidget);
    await app.close(tester);
  });

  // A narrowed window: the side rail is there, so is the wide version,
  // even when the page beside the rail is narrower than the rail's rule.
  for (final width in [700.0, 760.0]) {
    testWidgets('a ${width.toInt()} pt window shows the wide version with the rail', (tester) async {
      final app = await pumpApp(tester, seed: _seed, size: Size(width, 1000), textScale: 1.3);
      await goTo(tester, '/repertoires');
      expect(find.text('Тренувати все'), findsOneWidget);
      expectClean(tester);
      await goTo(tester, '/library');
      expect(find.text('Файл PGN'), findsOneWidget);
      expectClean(tester);
      await goTo(tester, '/library/1');
      expect(find.text('PARIS OPERA'), findsOneWidget);
      expectClean(tester);
      await app.close(tester);
    });
  }

  for (final scale in [1.3, 2.0]) {
    testWidgets('the tablet pages at text scale $scale', (tester) async {
      final app = await pumpApp(tester, seed: _seed, size: _tablet, textScale: scale);
      for (final route in ['/repertoires', '/library', '/library/1']) {
        await goTo(tester, route);
        expectClean(tester);
      }
      await app.close(tester);
    });
  }
}
