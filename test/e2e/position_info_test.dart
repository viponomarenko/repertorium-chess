import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/game/game_screen.dart';
import 'package:tabiya/presentation/position_info/position_info_sheet.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/comment_editor.dart';
import 'package:tabiya/presentation/widgets/engine_panel.dart';

import 'harness.dart';

/// "About this position" (D-105) on the analysis board and after a
/// training line.

PositionKey keyAfter(List<String> sans) {
  Position p = Chess.initial;
  for (final san in sans) {
    p = p.play(p.parseSan(san)!);
  }
  return positionKeyOf(p);
}

const line = ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'];
const comment = 'Тут головне - тиснути на e5.';
const finalComment = 'Іспанська партія: план c3 і d4.';

Future<void> seed(AppDatabase db) async {
  final repo = RepertoireRepository(db);
  final id = await repo.create(name: 'Білі', color: Side.white);
  final g = await repo.loadGraph(id);
  addSanLine(g, Chess.initial, line);
  await repo.saveGraph(id, g);
  await repo.setPositionComment(id, keyAfter(['e4', 'e5', 'Nf3', 'Nc6']), comment);
  await repo.setPositionComment(id, keyAfter(line), finalComment);
}

/// Opens the analysis of [pgn] at its last move and the panel over it.
Future<void> openPanelAfter(WidgetTester tester, String pgn, int plies) async {
  await goTo(tester, '/analysis', extra: GameScreenArgs(pgn: pgn));
  for (var i = 0; i < plies; i++) {
    await tapText(tester, 'Далі');
  }
  await tapText(tester, 'Позиція');
}

Future<void> closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(PositionInfoView))).pop();
  await settle(tester);
}

/// The opening line of the panel ("C60 Ruy Lopez").
String? openingShown(WidgetTester tester) {
  final eco = RegExp(r'^[A-E]\d\d ');
  for (final e in find.descendant(of: find.byType(PositionInfoView), matching: find.byType(Text)).evaluate()) {
    final t = (e.widget as Text).data;
    if (t != null && eco.hasMatch(t)) return t;
  }
  return null;
}

void main() {
  testWidgets('a transposition shows the same opening and comment', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await openPanelAfter(tester, '1. e4 e5 2. Nf3 Nc6 *', 4);
    expect(find.text(comment), findsOneWidget);
    final direct = openingShown(tester);
    expect(direct, isNotNull);
    await closeSheet(tester);
    Navigator.of(tester.element(find.byType(BoardView))).pop();
    await settle(tester);
    expect(find.byType(BoardView), findsNothing);

    await openPanelAfter(tester, '1. Nf3 Nc6 2. e4 e5 *', 4);
    expect(find.text(comment), findsOneWidget);
    expect(openingShown(tester), direct);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('empty blocks are hidden; the engine answers on request', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    // Not in any repertoire, not a named opening, no text on the way, no
    // structure and no pawn features.
    await goTo(tester, '/analysis', extra: const GameScreenArgs(fen: '4k3/pppppppp/8/8/8/8/PPPPPPPP/4K3 w - - 0 1'));
    await tapText(tester, 'Позиція');
    expect(find.text('МІЙ КОМЕНТАР'), findsNothing);
    expect(find.text('ДЕБЮТ'), findsNothing);
    expect(find.text('СТРУКТУРА'), findsNothing);
    expect(find.textContaining('Про цю позицію ще нічого немає'), findsOneWidget);
    expect(find.text('РУШІЙ'), findsOneWidget);
    await tapText(tester, 'Аналізувати');
    expect(find.text('Позиція рівна'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(find.textContaining('Найкращий хід:'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('cloud first but offline: the device engine answers', (tester) async {
    final app = await pumpApp(
      tester,
      seed: seed,
      settings: const AppSettings(
        onboardingDone: true,
        localeCode: 'uk',
        animationMs: 0,
        opponentDelayMs: 0,
        sound: false,
        haptics: false,
        engineCloudFirst: true,
      ),
    );
    await openPanelAfter(tester, '1. a3 h5 *', 2);
    await tapText(tester, 'Аналізувати');
    expect(find.text('Позиція рівна'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('a position in a repertoire without a comment offers to add one', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await openPanelAfter(tester, '1. e4 e5 *', 2);
    await tapText(tester, 'Додати коментар до позиції');
    await tester.enterText(find.byType(TextField), 'Новий коментар');
    await tapText(tester, 'Зберегти');
    expect(find.text('Новий коментар'), findsOneWidget);
    final refs = await tester.runAsync(() => RepertoireRepository(app.db).positionComments(keyAfter(['e4', 'e5'])));
    expect(refs!.single.comment, 'Новий коментар');
    await app.close(tester);
  });

  testWidgets('Wikibooks text: attribution, the same text for a transposition, an earlier position named', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await openPanelAfter(tester, '1. e4 c5 2. Nc3 Nc6 3. f4 *', 5);
    expect(find.textContaining('CC BY-SA 4.0'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(find.textContaining('Є пояснення до позиції після'), findsNothing);
    // With a translation the original is a tap away, and back.
    if (find.text('Оригінал').evaluate().isNotEmpty) {
      await tapText(tester, 'Оригінал');
      expect(find.textContaining('Grand Prix attack'), findsOneWidget);
      expect(find.text('Переклад'), findsOneWidget);
    } else {
      expect(find.textContaining('Grand Prix attack'), findsOneWidget);
    }
    await closeSheet(tester);
    Navigator.of(tester.element(find.byType(BoardView))).pop();
    await settle(tester);

    // A move past the page (D-113): only a link to the explanation of
    // 3. f4; the text itself opens on a tap.
    await openPanelAfter(tester, '1. e4 c5 2. Nc3 Nc6 3. f4 h6 4. h3 *', 7);
    expect(find.textContaining('Є пояснення до позиції після 3. f4'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(find.textContaining('CC BY-SA 4.0'), findsNothing);
    expect(find.textContaining('Grand Prix'), findsNothing);
    await tester.tap(find.textContaining('Є пояснення до позиції після 3. f4'));
    await settle(tester);
    expect(find.textContaining('CC BY-SA 4.0'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('a translation a person approved says so', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await openPanelAfter(tester, '1. e4 *', 1);
    expect(find.text('Wikibooks · переклад перевірено · CC BY-SA 4.0'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    await app.close(tester);
  });

  testWidgets('structure and pawn features (D-107)', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    // Panov attack: White's isolated d4 pawn.
    await openPanelAfter(tester, '1. e4 c6 2. d4 d5 3. exd5 cxd5 4. c4 Nf6 5. Nc3 e6 6. Nf3 Be7 7. cxd5 Nxd5 *', 14);
    expect(find.text('СТРУКТУРА'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(find.text('Ізольований ферзевий пішак · у білих'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    // Read and approved (D-107), so no "not reviewed yet".
    expect(find.text('Repertorium chess'), findsOneWidget);
    expect(find.text('Repertorium chess · ще не вичитано'), findsNothing);
    expect(find.textContaining('У білих ізольований пішак d4'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('the comment editor: the position, signs at the cursor, delete (D-110)', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await openPanelAfter(tester, '1. e4 e5 2. Nf3 Nc6 *', 4);
    await tapText(tester, comment);
    expect(find.byType(CommentEditor), findsOneWidget);
    expect(find.byType(MiniBoard), findsOneWidget);
    expect(find.text('Білі'), findsOneWidget, reason: 'the repertoire is named under the title');
    await tester.enterText(find.byType(TextField), 'Тут 3. Bb5');
    await tester.tap(find.text('!'));
    await settle(tester);
    await tester.tap(find.text('±'));
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Тут 3. Bb5! ± ');
    // Black better sits next to White better; the rest is one tap away.
    expect(find.text('∓'), findsOneWidget);
    expect(find.text('!!'), findsNothing);
    await tester.tap(find.byTooltip('Більше знаків'));
    await settle(tester);
    for (final sign in ['!!', '??', '□', '+−', '⩲', '⩱', '−+', '∞', '↑', '→', '⇆', '∆', 'N']) {
      expect(find.text(sign), findsOneWidget, reason: sign);
    }
    expect(find.text('ОЦІНКА ХОДУ'), findsOneWidget);
    await tester.tap(find.text('∆'));
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Тут 3. Bb5! ± ∆ ');
    await tester.tap(find.byTooltip('Менше знаків'));
    await settle(tester);
    expect(find.text('!!'), findsNothing);
    expectClean(tester);
    // Deleting empties the comment; the position stays in the repertoire.
    await tester.tap(find.byTooltip('Видалити'));
    await settle(tester);
    final refs = await tester.runAsync(() => RepertoireRepository(app.db).positionComments(keyAfter(['e4', 'e5', 'Nf3', 'Nc6'])));
    expect(refs!.single.comment, '');
    await app.close(tester);
  });

  for (final size in const [Size(320, 640), Size(430, 932)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('the comment editor fits at ${size.width.round()}px, text ${scale}x', (tester) async {
        final app = await pumpApp(tester, seed: seed, size: size, textScale: scale);
        await openPanelAfter(tester, '1. e4 e5 2. Nf3 Nc6 *', 4);
        await tapText(tester, comment);
        expectClean(tester);
        if (scale == 1.0) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        // And with every sign open.
        await tester.tap(find.byTooltip('Більше знаків'));
        await settle(tester);
        expectClean(tester);
        if (scale == 1.0) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await app.close(tester);
      });
    }
  }

  testWidgets('the engine panel pauses under the sheet and comes back', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    await goTo(tester, '/analysis');
    final board = tester.widget<BoardView>(find.byType(BoardView));
    board.onMove!(board.position.parseSan('e4')!);
    await settle(tester);
    await tapText(tester, 'Рушій');
    expect(find.byType(EnginePanel), findsOneWidget);
    final before = app.engine.starts;
    await tapText(tester, 'Позиція');
    // The panel's evaluation shows at once; the sheet finishes the rest.
    expect(find.text('РУШІЙ'), findsOneWidget);
    expect(find.textContaining('Найкращий хід:'), findsOneWidget);
    expect(find.text('Аналізувати'), findsNothing);
    await closeSheet(tester);
    expect(find.byType(EnginePanel), findsOneWidget);
    // Back from its cache, no new search for the same position.
    expect(app.engine.starts, before);
    expect(find.descendant(of: find.byType(EnginePanel), matching: find.textContaining('0,')), findsWidgets);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('training: no panel during the line, the final position after it', (tester) async {
    final app = await pumpApp(tester, seed: seed);
    final own = <PositionKey, String>{};
    Position p = Chess.initial;
    for (final san in line) {
      if (p.turn == Side.white) own[positionKeyOf(p)] = san;
      p = p.play(p.parseSan(san)!);
    }
    await tapText(tester, 'ТРЕНУВАТИСЬ');
    for (var step = 0; step < 200; step++) {
      if (find.text('Про кінцеву позицію').evaluate().isNotEmpty) break;
      expect(find.text('Позиція'), findsNothing, reason: 'nothing may reveal the next move during the line');
      expect(find.text('Про позицію'), findsNothing);
      final board = find.byType(BoardView);
      if (board.evaluate().isNotEmpty && find.text('Ввести хід').evaluate().isNotEmpty) {
        final pos = tester.widget<BoardView>(board).position;
        final san = own[positionKeyOf(pos)];
        if (san != null && pos.turn == Side.white) {
          await tapText(tester, 'Ввести хід');
          await tester.enterText(find.byType(TextField), san);
          await tapText(tester, 'OK');
          continue;
        }
      }
      await settle(tester, frames: 4);
    }
    await tapText(tester, 'Про кінцеву позицію');
    expect(find.text('Про позицію'), findsOneWidget);
    expect(find.text(finalComment), findsOneWidget);
    // "Engine in Why?" is off by default: no engine in training.
    expect(find.text('РУШІЙ'), findsNothing);
    expectClean(tester);
    await app.close(tester);
  });

  for (final size in const [Size(320, 640), Size(390, 844), Size(430, 932)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('the panel fits at ${size.width.round()}px, text ${scale}x', (tester) async {
        final app = await pumpApp(tester, seed: seed, size: size, textScale: scale);
        await openPanelAfter(tester, '1. e4 e5 2. Nf3 Nc6 *', 4);
        await tapText(tester, 'Аналізувати');
        expectClean(tester);
        if (scale == 1.0) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await app.close(tester);
      });
    }
  }
}
