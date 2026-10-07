import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/library/import_flow.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/san_text.dart';

import 'harness.dart';

void main() {
  test('numbers alone are not games; empty PGNs and positions remain valid', () {
    for (final text in ['12345', '1. 2. 3...', '...']) {
      expect(PgnParser.parseAll(text), isEmpty, reason: text);
    }
    for (final text in ['[Event "Empty"]\n*', '*', '{Starting position}', '1. e4 e5 *']) {
      expect(PgnParser.parseAll(text), hasLength(1), reason: text);
    }
  });

  testWidgets('import back keeps the input available for correction', (tester) async {
    final app = await pumpApp(tester);
    const pgn = '1. e4 e5 2. Nf3 *';
    await goTo(tester, '/import', extra: const ImportInput(text: pgn));
    expect(find.text('Знайдено 1 партію'), findsOneWidget);
    await tester.tap(find.byTooltip('Редагувати текст'));
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, pgn);
    await tapText(tester, 'Скасувати');
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.text('З файлу'), findsOneWidget);
    await tapText(tester, 'Вставити текст');
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, pgn);
    await tester.enterText(find.byType(TextField).last, '12345');
    await tapText(tester, 'Імпортувати');
    expect(find.text('Партій не знайдено'), findsOneWidget);
    expect(find.text('Зберегти в бібліотеку'), findsNothing);
    expectClean(tester);
    await app.close(tester);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('learning explanation is readable in ${mode.name} theme', (tester) async {
      const comment = 'Спочатку займіть центр.';
      final app = await pumpApp(
        tester,
        settings: AppSettings(onboardingDone: true, localeCode: 'uk', themeMode: mode, animationMs: 0),
        seed: (db) async {
          final repo = RepertoireRepository(db);
          final id = await repo.create(name: 'QA', color: Side.white);
          final graph = await repo.loadGraph(id);
          addSanLine(graph, Chess.initial, ['e4', 'e5']);
          graph.movesFrom(graph.rootKey).first.comment = comment;
          await repo.saveGraph(id, graph);
        },
      );
      await tapText(tester, 'Тренуватись');
      final explanation = find.byWidgetPredicate((w) => w is MovesText && w.text == comment);
      expect(explanation, findsOneWidget);
      final widget = tester.widget<MovesText>(explanation);
      final background = Theme.of(tester.element(explanation)).colorScheme.primaryContainer;
      expect(contrastRatio(widget.style!.color!, background), greaterThanOrEqualTo(4.5));
      expectClean(tester);
      await app.close(tester);
    });
  }
}
