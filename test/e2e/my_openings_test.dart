import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/l10n/gen/app_localizations.dart';
import 'package:tabiya/presentation/accounts/my_games_screen.dart' show timeControlText;
import 'package:tabiya/presentation/game/game_screen.dart';
import 'package:tabiya/presentation/stats/my_openings_screen.dart';

import 'harness.dart';

/// The user's games: 4× the Najdorf-ish line, 2× the Alapin-less 2...Nc6,
/// all as White; one game as Black.
const _lines = [
  ('1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6', '1-0'),
  ('1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6', '1-0'),
  ('1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6', '0-1'),
  ('1. e4 c5 2. Nf3 d6 3. d4 cxd4 4. Nxd4 Nf6', '1/2-1/2'),
  ('1. e4 c5 2. Nf3 Nc6 3. d4 cxd4 4. Nxd4 Nf6', '1-0'),
  ('1. e4 c5 2. Nf3 Nc6 3. Bb5 g6 4. O-O Bg7', '0-1'),
];

Future<void> _seed(AppDatabase db) async {
  var i = 0;
  for (final (moves, result) in _lines) {
    await db
        .into(db.importedGames)
        .insert(
          ImportedGamesCompanion.insert(
            provider: i.isEven ? 'lichess' : 'chesscom',
            externalId: 'g$i',
            pgn: '[White "me"]\n[Black "opp$i"]\n[Result "$result"]\n\n$moves $result',
            playedAt: DateTime.now().subtract(Duration(days: i)),
            userColor: 'white',
            result: Value(result),
            opponent: Value('opp$i'),
          ),
        );
    i++;
  }
  await db
      .into(db.importedGames)
      .insert(
        ImportedGamesCompanion.insert(
          provider: 'lichess',
          externalId: 'b1',
          pgn: '1. d4 d5 2. c4 e6 1-0',
          playedAt: DateTime.now(),
          userColor: 'black',
          result: const Value('1-0'),
        ),
      );
  // A White repertoire: the Open Sicilian against 2...d6 only.
  final repo = RepertoireRepository(db);
  final id = await repo.create(name: 'Відкрита сицилійська', color: Side.white);
  final g = await repo.loadGraph(id);
  addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4', 'cxd4', 'Nxd4', 'Nf6']);
  await repo.saveGraph(id, g);
}

void main() {
  testWidgets('time controls read as people say them', (tester) async {
    final app = await pumpApp(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Navigator).first));
    expect(timeControlText('300', l), '5 хв');
    expect(timeControlText('180+2', l), '3+2');
    expect(timeControlText('90', l), '1,5 хв');
    expect(timeControlText('1/259200', l), '3 дні');
    expect(timeControlText('', l), '');
    await app.close(tester);
  });

  testWidgets('my openings: frequent variations, their scores and the repertoire', (tester) async {
    final app = await pumpApp(tester, seed: _seed);
    await goTo(tester, '/my-openings');

    // Variations to move 3 (6 plies), most frequent first, as White only.
    await tapText(tester, 'до 3-го ходу');
    expect(find.text('6 партій'), findsOneWidget, reason: 'the Black game is not counted');
    expect(find.text('4'), findsOneWidget, reason: '1. e4 c5 2. Nf3 d6 3. d4 cxd4 – 4 games');
    expect(find.textContaining(RegExp(r'^67\s?%$')), findsOneWidget);
    expect(find.text('У вашому репертуарі'), findsOneWidget);
    // The win/draw/loss bars are really drawn (they were 0 high once).
    final seg = find.descendant(of: find.byType(ScoreBar).first, matching: find.byType(ColoredBox)).first;
    expect(tester.getSize(seg).height, 6);
    expect(find.textContaining('Немає в репертуарі'), findsWidgets, reason: '2...Nc6 is not covered');

    // Into the tree at the most frequent line.
    await tapText(tester, '4');
    expect(find.text('4 партії'), findsOneWidget);
    expect(find.text('+2 =1 −1'), findsOneWidget);

    // Back to the start: 1. e4 in all 6 games, in the repertoire.
    await tester.tap(find.byTooltip('Початок'));
    await settle(tester);
    expect(find.text('6 партій'), findsWidgets);
    expect(find.byTooltip('У вашому репертуарі'), findsOneWidget);

    // After 1. e4 c5 2. Nf3: 2...Nc6 (2 games) has no answer in the repertoire.
    for (final m in ['1. e4', '1... c5', '2. Nf3']) {
      await tapText(tester, m);
    }
    expect(find.text('2... Nc6'), findsOneWidget);
    expect(find.byTooltip('немає відповіді в репертуарі'), findsOneWidget);

    // From here straight into the repertoire.
    // The ⋮ of that row opens the same menu as a long press.
    final row = find.ancestor(of: find.text('2... Nc6'), matching: find.byType(InkWell)).first;
    await tester.tap(find.descendant(of: row, matching: find.byType(IconButton)));
    await settle(tester);
    await tapText(tester, 'Додати в репертуар');
    expect(find.text('Відкрита сицилійська (Білі)'), findsOneWidget, reason: 'the compared repertoire is the target');
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('the explorer panel can show my own games', (tester) async {
    final app = await pumpApp(tester, seed: _seed);
    await goTo(tester, '/analysis', extra: const GameScreenArgs());
    await tapText(tester, 'База');
    await tapText(tester, 'Мої партії');
    // 1. e4 was played in 6 games (as White); 1. d4 in the one as Black.
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('d4'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^86\s?%$')), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });
}
