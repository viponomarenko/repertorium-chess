import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/domain/pgn/pgn_model.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/presentation/game/game_screen.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';

class FailingLibrary extends LibraryRepository {
  FailingLibrary(super.db);
  bool failWrites = true;
  @override
  Future<void> saveGame(int id, ChessGame game) async {
    if (failWrites) throw StateError('simulated disk failure');
    await super.saveGame(id, game);
  }
}

void main() {
  testWidgets('failed autosave prevents leaving, retry persists edits and enables leaving', (tester) async {
    late FailingLibrary repository;
    late int id;
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final library = LibraryRepository(db);
        final collection = await library.createCollection('Save test');
        id = await library.createGame(collection, PgnParser.parseOne('*'));
      },
      libraryRepository: (db) => repository = FailingLibrary(db),
    );
    try {
      await goTo(tester, '/game/$id');
      final board = tester.widget<BoardView>(find.byType(BoardView));
      board.onMove!(board.position.parseSan('e4')!);
      await settle(tester);
      expect(find.byTooltip('Спробувати ще'), findsOneWidget);
      expectClean(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      // Still here, with a way out: retry, copy the game, or leave without
      // the last changes (the screen used to be a trap).
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text('Незбережені зміни'), findsOneWidget);
      expect(find.text('Вийти без збереження'), findsOneWidget);
      expect(find.text('Скопіювати PGN'), findsOneWidget);
      expectClean(tester);
      // A retry that fails again keeps the dialog.
      await tapText(tester, 'Спробувати ще');
      expect(find.text('Незбережені зміни'), findsOneWidget);
      repository.failWrites = false;
      await tapText(tester, 'Спробувати ще');
      final stored = await tester.runAsync(() => repository.game(id));
      expect(stored!.pgn, contains('e4'));
      expect(find.byType(GameScreen), findsNothing);
      expectClean(tester);
    } finally {
      repository.failWrites = false;
      await app.close(tester);
    }
  });

  testWidgets('a game that cannot be saved can still be left', (tester) async {
    late FailingLibrary repository;
    late int id;
    final app = await pumpApp(
      tester,
      seed: (db) async {
        final library = LibraryRepository(db);
        final collection = await library.createCollection('Save test');
        id = await library.createGame(collection, PgnParser.parseOne('*'));
      },
      libraryRepository: (db) => repository = FailingLibrary(db),
    );
    try {
      await goTo(tester, '/game/$id');
      final board = tester.widget<BoardView>(find.byType(BoardView));
      board.onMove!(board.position.parseSan('e4')!);
      await settle(tester);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      await tapText(tester, 'Вийти без збереження');
      expect(find.byType(GameScreen), findsNothing);
      expectClean(tester);
    } finally {
      repository.failWrites = false;
      await app.close(tester);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('accessible position form places, moves, cancels and removes pieces at text $scale', (tester) async {
      final app = await pumpApp(tester, size: const Size(320, 640), textScale: scale);
      try {
        await goTo(tester, '/position-editor');
        Future<void> open() async {
          await tapText(tester, 'Клітинки та фігури');
          expect(find.byType(AlertDialog), findsOneWidget);
          expectClean(tester);
        }

        Future<void> pickOption(String label) async {
          final menu = find.byType(Scrollable).last;
          await tester.drag(menu, const Offset(0, 10000));
          await settle(tester);
          await tester.scrollUntilVisible(find.text(label), 120, scrollable: menu, maxScrolls: 150);
          await Scrollable.ensureVisible(tester.element(find.text(label).last), alignment: 0.5);
          await settle(tester);
          await tester.tap(find.text(label).last);
          await settle(tester);
        }

        Future<void> choosePiece(String label) async {
          await tester.ensureVisible(find.byType(DropdownButtonFormField<Piece>));
          await tester.tap(find.byType(DropdownButtonFormField<Piece>));
          await settle(tester);
          await pickOption(label);
        }

        Future<Pieces> pieces() async {
          await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
          await settle(tester);
          return tester.widget<ChessboardEditor>(find.byType(ChessboardEditor)).pieces;
        }

        const queen = Piece(color: Side.white, role: Role.queen);
        final e4 = Square.fromName('e4');
        final d4 = Square.fromName('d4');
        await open();
        await choosePiece('Білі Ферзь');
        await tapText(tester, 'Готово');
        expect((await pieces())[e4], queen);
        await open();
        await choosePiece('Порожня клітинка');
        await tapText(tester, 'Скасувати');
        expect((await pieces())[e4], queen);
        await open();
        final destination = find.byType(DropdownButtonFormField<Square>).last;
        await tester.ensureVisible(destination);
        await tester.tap(destination);
        await settle(tester);
        await pickOption('d4');
        await tapText(tester, 'Готово');
        expect((await pieces())[e4], isNull);
        expect((await pieces())[d4], queen);
        await open();
        await tester.tap(find.byType(DropdownButtonFormField<Square>).first);
        await settle(tester);
        await pickOption('d4: Білі Ферзь');
        await choosePiece('Порожня клітинка');
        await tapText(tester, 'Готово');
        expect((await pieces())[d4], isNull);
        expectClean(tester);
      } finally {
        await app.close(tester);
      }
    });
  }
}
