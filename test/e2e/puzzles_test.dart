import 'dart:convert';
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/puzzles/puzzle_repository.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/app/app.dart';
import 'package:tabiya/presentation/game/game_screen.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import '../domain/puzzles_test.dart' show legalJson, scholarJson;
import 'audit_regression_test.dart' show loadAuditFonts;
import 'harness.dart';

/// Lichess answering puzzle batches; [asked] records the request URLs.
http.Client lichessPuzzles(List<Uri> asked) => MockClient((req) async {
  asked.add(req.url);
  if (!req.url.path.startsWith('/api/puzzle/batch/')) return http.Response('', 404);
  return http.Response(
    jsonEncode({
      'puzzles': [
        legalJson(),
        scholarJson(['h5f7']),
      ],
      'glicko': {'rating': 1500, 'deviation': 500},
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Future<void> play(WidgetTester tester, String uci) async {
  tester.widget<BoardView>(find.byType(BoardView)).onMove!(Move.parse(uci)!);
  await settle(tester);
}

void main() {
  testWidgets('More → Puzzles → a theme: solve, the rating goes up and is kept', (tester) async {
    final asked = <Uri>[];
    final app = await pumpApp(tester, network: lichessPuzzles(asked));
    await tapText(tester, 'Інше');
    await tapText(tester, 'Головоломки');

    // The rating of a new player, the note and the themes in their groups.
    expect(find.text('1500?'), findsOneWidget);
    expect(
      find.text(
        'Задачі надходять з Lichess, а без інтернету чи поки Lichess їх обмежує, з власного набору застосунку на 50 000 задач. Рейтинг зберігається на цьому пристрої.',
      ),
      findsOneWidget,
    );
    expect(find.text('РЕКОМЕНДОВАНО'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Вилка'), 300);
    expect(find.text('МОТИВИ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Мат у 3 ходи'), 300);
    await tester.ensureVisible(find.text('Мат у 3 ходи'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Мат у 3 ходи'));
    await settle(tester);
    // Anonymous: one puzzle asked, a credit each (D-125); the fake Lichess
    // sends two, the second waits for "Next".
    expect(asked, hasLength(1));
    expect(asked.first.path, '/api/puzzle/batch/mateIn3');
    expect(asked.first.queryParameters['difficulty'], 'normal');
    expect(asked.first.queryParameters['nb'], '1');

    // The opponent's move has been played: White to find the move.
    expect(find.text('Ваш хід: знайдіть найкращий хід за білих'), findsOneWidget);
    expect(tester.widget<BoardView>(find.byType(BoardView)).lastMove?.uci, 'g7g6');
    await play(tester, 'f3e5');
    await play(tester, 'c4f7');
    await play(tester, 'c3d5');
    expect(find.text('Розвʼязано'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(find.text('Наступна задача'), findsOneWidget);
    expectClean(tester);

    final saved = await tester.runAsync(() => PuzzleRepository(app.db).load());
    expect(saved!.played, 1);
    expect(saved.won, 1);
    expect(saved.rating, greaterThan(1500));
    expect(saved.byAngle['mateIn3'], (played: 1, won: 1));
    // The new rating and its change, beside the verdict.
    expect(find.text('${saved.rating}?'), findsWidgets);
    expect(find.text('+${saved.rating - 1500}'), findsOneWidget);

    // The analysis board opens with the puzzle and its solution.
    await tapText(tester, 'Аналізувати');
    expect(find.byType(GameScreen), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expectClean(tester);
    GoRouter.of(tester.element(find.byType(GameScreen))).pop();
    await settle(tester);

    await tapText(tester, 'Наступна задача');
    expect(tester.widget<BoardView>(find.byType(BoardView)).lastMove?.uci, 'g8f6');
    await app.close(tester);
  });

  testWidgets('a wrong move costs rating; the solution can be shown', (tester) async {
    final app = await pumpApp(tester, network: lichessPuzzles([]));
    await goTo(tester, '/puzzles/mix');
    await play(tester, 'd2d3');
    expect(find.text('Це не той хід. Спробуйте інший'), findsOneWidget);
    await tapText(tester, 'Показати рішення');
    await settle(tester, frames: 120);
    expect(find.text('Показано рішення'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    expect(tester.widget<BoardView>(find.byType(BoardView)).position.isCheckmate, isTrue);
    final saved = await tester.runAsync(() => PuzzleRepository(app.db).load());
    expect(saved!.played, 1, reason: 'a mistake and the shown solution are one loss');
    expect(saved.won, 0);
    expect(saved.rating, lessThan(1500));
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('every theme group down to the last one, without overflow', (tester) async {
    final app = await pumpApp(tester, textScale: 1.6);
    await goTo(tester, '/puzzles');
    await tester.scrollUntilVisible(find.text('Партії супергросмейстерів'), 600);
    expect(find.text('ПОХОДЖЕННЯ'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('Lichess limits puzzles: the next comes from the pack at once, and says so', (tester) async {
    final asked = <Uri>[];
    final app = await pumpApp(
      tester,
      network: MockClient((req) async {
        asked.add(req.url);
        return http.Response('{"error":"Too many requests"}', 429);
      }),
    );
    await goTo(tester, '/puzzles/fork');
    expect(find.text('Lichess зараз обмежує задачі: задача з набору застосунку'), findsOneWidget);
    expect(find.byType(BoardView), findsOneWidget);
    expect(asked, hasLength(1), reason: 'not retried, and the next one is not asked either');
    expectClean(tester);
    // The client's pause after a 429 runs out before the app closes.
    await tester.pump(const Duration(seconds: 61));
    await app.close(tester);
  });

  testWidgets('no internet: a puzzle from the pack, solved and counted as usual', (tester) async {
    final app = await pumpApp(tester);
    await goTo(tester, '/puzzles/fork');
    expect(find.text('Без інтернету: задача з набору застосунку'), findsOneWidget);
    await tapText(tester, 'Показати рішення');
    await settle(tester, frames: 160);
    expect(find.text('Показано рішення'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    final saved = await tester.runAsync(() => PuzzleRepository(app.db).load());
    expect(saved!.played, 1);
    expect(saved.byAngle['fork'], (played: 1, won: 0));
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('with a Lichess account: the Lichess rating, results sent there', (tester) async {
    final asked = <http.Request>[];
    final app = await pumpApp(
      tester,
      seed: (db) => db
          .into(db.linkedAccounts)
          .insert(
            LinkedAccountsCompanion.insert(
              provider: 'lichess',
              username: 'Tabiya',
              scopes: const Value('study:read puzzle:read puzzle:write'),
              connectedAt: DateTime(2026, 10, 20),
            ),
          ),
      network: MockClient((req) async {
        asked.add(req);
        if (req.method == 'POST') {
          return http.Response(
            jsonEncode({
              'puzzles': [],
              'glicko': {'rating': 1912.3, 'deviation': 60},
              'rounds': [
                {'id': 'LeGaL', 'win': true, 'ratingDiff': 7},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'puzzles': [legalJson()],
            'glicko': {'rating': 1905.4, 'deviation': 60},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await goTo(tester, '/puzzles');
    expect(find.textContaining('у ваш рейтинг на Lichess (tabiya)'), findsOneWidget);
    await goTo(tester, '/puzzles/mateIn3');
    expect(asked.first.url.queryParameters['nb'], '3');
    expect(find.text('1905'), findsOneWidget, reason: 'the rating Lichess sent');
    await play(tester, 'f3e5');
    await play(tester, 'c4f7');
    await play(tester, 'c3d5');
    final post = asked.where((r) => r.method == 'POST').single;
    expect(post.url.path, '/api/puzzle/batch/mateIn3');
    expect(jsonDecode(post.body), {
      'solutions': [
        {'id': 'LeGaL', 'win': true, 'rated': true},
      ],
    });
    expect(find.text('+7'), findsOneWidget, reason: 'the change Lichess answered with');
    expect(find.text('1912'), findsOneWidget);
    final saved = await tester.runAsync(() => PuzzleRepository(app.db).load());
    expect(saved!.pending, isEmpty);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('an account connected before puzzles is asked to connect again', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) => db
          .into(db.linkedAccounts)
          .insert(
            LinkedAccountsCompanion.insert(
              provider: 'lichess',
              username: 'Tabiya',
              scopes: const Value('study:read'),
              connectedAt: DateTime(2026, 10, 20),
            ),
          ),
    );
    await goTo(tester, '/puzzles');
    expect(
      find.text(
        'Щоб задачі зараховувались у ваш рейтинг на Lichess, підключіть акаунт ще раз: Lichess попросить доступ до задач.',
      ),
      findsOneWidget,
    );
    expect(find.text('Підключити'), findsOneWidget);
    expect(find.text('Рейтинг у задачах'), findsOneWidget, reason: 'meanwhile the device rating');
    expectClean(tester);
    await app.close(tester);
  });

  // The end of a puzzle: verdict and rating on the page, as the end of a
  // training line; reference images beside the other screens.
  for (final dark in [false, true]) {
    testWidgets('visual ${dark ? 'dark' : 'light'} solved puzzle', (tester) async {
      await loadAuditFonts();
      final app = await pumpApp(
        tester,
        network: lichessPuzzles([]),
        settings: AppSettings(
          onboardingDone: true,
          localeCode: 'uk',
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          animationMs: 0,
          opponentDelayMs: 0,
          sound: false,
          haptics: false,
          engineCloudFirst: false,
        ),
      );
      await goTo(tester, '/puzzles/mateIn3');
      await play(tester, 'f3e5');
      await play(tester, 'c4f7');
      await play(tester, 'c3d5');
      expectClean(tester);
      await expectLater(
        find.byType(TabiyaApp),
        Platform.isMacOS
            ? matchesGoldenFile(
                '../../docs/audit-2026-09-28/fixed-screenshots/${dark ? 'dark' : 'light'}_puzzle_solved.png',
              )
            : anything,
      );
      await app.close(tester);
    });
  }
}
