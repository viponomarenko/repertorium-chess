import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/data/sync/gap_service.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/library/import_flow.dart';
import 'package:tabiya/presentation/repertoire/import_wizard_screen.dart';
import 'package:tabiya/presentation/repertoire/repertoire_screen.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';

/// Behaviours fixed after the audit of 05.10.2026.
void main() {
  Future<void> seedRep(AppDatabase db) async {
    final repo = RepertoireRepository(db);
    final id = await repo.create(name: 'Білі', color: Side.white);
    final g = await repo.loadGraph(id);
    addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3']);
    await repo.saveGraph(id, g);
  }

  // Tapping the current tab again dropped moves that were not added yet.
  // The repertoire screen covers the main navigation (D-078), so the way
  // out is "Back".
  testWidgets('leaving asks about moves not added to the repertoire', (tester) async {
    final app = await pumpApp(tester, seed: seedRep);
    try {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/repertoires/1');
      await settle(tester);
      final board = tester.widget<BoardView>(find.byType(BoardView));
      board.onMove!(board.position.parseSan('a3')!);
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(find.text('Додати нові ходи?'), findsOneWidget);
      await tapText(tester, 'Залишитися');
      expect(find.byType(RepertoireScreen), findsOneWidget);
      expectClean(tester);
      // Discarding lets it through.
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tapText(tester, 'Не зберігати');
      await settle(tester);
      expect(find.byType(RepertoireScreen), findsNothing);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // D-067: one repertoire screen; in the editing mode a move is added at
  // once and can be taken back.
  testWidgets('editing adds a move at once, Undo takes it back', (tester) async {
    final app = await pumpApp(tester, seed: seedRep);
    try {
      // After 1.e4: an opponent move is added without questions.
      final afterE4 = positionKeyOf(Chess.initial.play(Chess.initial.parseSan('e4')!));
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .go('/repertoires/1?key=${Uri.encodeQueryComponent(afterE4)}');
      await settle(tester);
      expect(find.byTooltip('Тренувати'), findsOneWidget);
      await tester.tap(find.byTooltip('Редагувати'));
      await settle(tester);
      expect(find.byTooltip('Тренувати'), findsNothing, reason: 'editing shows its own tools');
      final board = tester.widget<BoardView>(find.byType(BoardView));
      board.onMove!(board.position.parseSan('c5')!);
      await settle(tester);
      expect(find.text('Додати нові ходи?'), findsNothing);
      expect(find.text('Хід додано'), findsOneWidget);
      final repo = RepertoireRepository(app.db);
      expect((await tester.runAsync(() => repo.loadGraph(1)))!.moveCount, 4);
      await tester.tap(find.text('Скасувати дію'));
      await settle(tester);
      expect((await tester.runAsync(() => repo.loadGraph(1)))!.moveCount, 3);
      // "Done" returns to viewing.
      await tester.tap(find.byTooltip('Готово'));
      await settle(tester);
      expect(find.byTooltip('Тренувати'), findsOneWidget);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // The name of the first import stuck in the field for the next one.
  testWidgets('import: the collection name follows the source, duplicates are skipped', (tester) async {
    final app = await pumpApp(tester);
    try {
      await goTo(tester, '/import', extra: const ImportInput(text: '[White "A"]\n[Black "B"]\n\n1. e4 e5 *'));
      // The "Read" choice says where the games will go.
      expect(find.text('Зберегти в бібліотеку: A - B'), findsOneWidget);
      expect(find.text('Читати'), findsOneWidget);
      expect(find.text('Вчити'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      // A different text through the same screen.
      await tapText(tester, 'Вставити текст');
      await tester.enterText(find.byType(TextField).last, '[White "C"]\n[Black "D"]\n\n1. d4 d5 *');
      await tapText(tester, 'Імпортувати');
      expect(find.text('Зберегти в бібліотеку: C - D'), findsOneWidget);
      expect(find.text('Зберегти в бібліотеку: A - B'), findsNothing);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // D-068: "Learn" adds the games to the only repertoire without a wizard.
  testWidgets('import: Learn adds moves straight to the repertoire', (tester) async {
    final app = await pumpApp(tester, seed: seedRep);
    try {
      await goTo(tester, '/import', extra: const ImportInput(text: '1. e4 c5 2. Nf3 d6 *'));
      expect(find.text('Додати в репертуар: Білі'), findsOneWidget);
      await tapText(tester, 'Вчити');
      expect(find.textContaining('додано в «Білі»'), findsOneWidget);
      expect(find.text('Вчити зараз'), findsOneWidget);
      final g = await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(1));
      expect(g!.moveCount, 6);
      await tapText(tester, 'Готово');
      expect(find.byType(ImportFlowScreen), findsNothing);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // D-069: one "My games" screen with three tabs; the report is split by
  // what happened, and another first move is not a forgotten one.
  testWidgets('my games: tabs, report sections, another opening apart', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) async {
        await seedRep(db);
        for (final (i, moves) in ['1. e4 e5 2. Bc4 Nc6 1-0', '1. b3 e5 2. Bb2 Nc6 0-1'].indexed) {
          await db
              .into(db.importedGames)
              .insert(
                ImportedGamesCompanion.insert(
                  provider: 'lichess',
                  externalId: 'g$i',
                  pgn: '[White "me"]\n[Black "opp"]\n\n$moves',
                  playedAt: DateTime(2026, 9, 1 + i),
                  userColor: 'white',
                  result: const Value('1-0'),
                ),
              );
        }
        await GapService(db, RepertoireRepository(db)).analyzeAll();
      },
    );
    try {
      await goTo(tester, '/gaps');
      // The three tabs of one screen.
      for (final tab in ['Партії', 'Дебюти', 'Розбіжності']) {
        expect(find.widgetWithText(Tab, tab), findsOneWidget);
      }
      // Section headers are set in capitals.
      expect(find.textContaining(RegExp('забули свій хід', caseSensitive: false)), findsOneWidget);
      expect(find.text('Повторити'), findsOneWidget);
      // 1.b3 is another opening: folded away, not counted as a forgotten move.
      expect(find.text('Інший дебют'), findsOneWidget);
      expect(find.text('Для цього дебюту репертуару немає'), findsNothing);
      await tapText(tester, 'Інший дебют');
      expect(find.text('Для цього дебюту репертуару немає'), findsOneWidget);
      expectClean(tester);
      await tester.tap(find.widgetWithText(Tab, 'Партії'));
      await settle(tester);
      expect(
        find.textContaining('vs').evaluate().isNotEmpty || find.textContaining('проти').evaluate().isNotEmpty,
        isTrue,
      );
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // D-070: a newcomer gets one way to start, and it leads into the first lesson.
  testWidgets('first run: a ready-made repertoire starts the first lesson', (tester) async {
    final app = await pumpApp(tester);
    try {
      expect(find.byType(FilledButton), findsOneWidget, reason: 'one primary action on the empty Today');
      await tapText(tester, 'Почати з готового репертуару');
      await settle(tester, frames: 60);
      await tester.tap(find.text('Встановити').first);
      await settle(tester, frames: 80);
      // Straight into "New moves", not onto the repertoire screen.
      expect(find.text('Нові ходи'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
      expect(find.byType(BoardView), findsOneWidget);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  // D-073: "Learn" does not pour a line into a repertoire it does not
  // belong to just because that repertoire is the only one.
  testWidgets('import: a line that does not fit the only repertoire asks where to put it', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final repo = RepertoireRepository(db);
        final id = await repo.create(name: 'Чорні проти 1.d4', color: Side.black);
        final g = await repo.loadGraph(id);
        addSanLine(g, Chess.initial, ['d4', 'd5', 'c4', 'e6']);
        await repo.saveGraph(id, g);
      },
    );
    try {
      await goTo(tester, '/import', extra: const ImportInput(text: '1. e4 c5 2. Nf3 d6 *'));
      await settle(tester);
      expect(find.text('Обрати репертуар'), findsOneWidget);
      expect(find.textContaining('Додати в репертуар: Чорні'), findsNothing);
      await tapText(tester, 'Вчити');
      // The wizard, with nothing written yet.
      expect(find.byType(ImportWizardScreen), findsOneWidget);
      final g = await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(1));
      expect(g!.moveCount, 4);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  testWidgets('import: with two repertoires the line goes to the one it continues', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final repo = RepertoireRepository(db);
        final black = await repo.create(name: 'Чорні проти 1.d4', color: Side.black);
        var g = await repo.loadGraph(black);
        addSanLine(g, Chess.initial, ['d4', 'd5', 'c4', 'e6']);
        await repo.saveGraph(black, g);
        final white = await repo.create(name: 'Білі 1.e4', color: Side.white);
        g = await repo.loadGraph(white);
        addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3']);
        await repo.saveGraph(white, g);
      },
    );
    try {
      await goTo(tester, '/import', extra: const ImportInput(text: '1. e4 c5 2. Nf3 d6 *'));
      await settle(tester);
      expect(find.text('Додати в репертуар: Білі 1.e4'), findsOneWidget);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  test('the same game is recognised whatever its layout', () {
    expect(LibraryRepository.pgnKey('1. e4  e5\n2. Nf3 *\n'), LibraryRepository.pgnKey('1. e4 e5 2. Nf3 *'));
  });
}
