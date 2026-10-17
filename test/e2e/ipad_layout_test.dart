import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/common.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show deepKey, expectClearOfEdges, routes, seedRepertoire;

/// Tablets (D-084): every main screen on an 11" and a 13" iPad, upright
/// and on its side, and in half of a split screen; then the rules of the
/// wide layout one by one.
const tablets = {
  '11" portrait': Size(834, 1210),
  '11" landscape': Size(1210, 834),
  '13" portrait': Size(1032, 1376),
  '13" landscape': Size(1376, 1032),
  'split view': Size(507, 1032),
};

Rect rectOf(WidgetTester tester, Finder f) => tester.getRect(f.first);

void main() {
  for (final t in tablets.entries) {
    for (final route in [...routes, '/position-editor', '/accounts', '/about', '/backup', '/openings', '/import']) {
      testWidgets('$route on ${t.key}', (tester) async {
        final app = await pumpApp(tester, seed: seedRepertoire, size: t.value);
        await goTo(tester, route);
        expectClean(tester);
        expectClearOfEdges(tester);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await app.close(tester);
      });
    }
    testWidgets('large text on ${t.key}', (tester) async {
      final app = await pumpApp(tester, seed: seedRepertoire, size: t.value, textScale: 2);
      for (final route in ['/repertoires/1?key=${deepKey()}', '/analysis', '/settings', '/position-editor']) {
        await goTo(tester, route);
        expectClean(tester);
      }
      await app.close(tester);
    });
  }

  testWidgets('the main navigation stands at the side of a tablet', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['11" portrait']!);
    expect(find.byType(ThumbBar), findsNothing);
    expect(find.byType(BarButton), findsNWidgets(4));
    for (final e in find.byType(BarButton).evaluate()) {
      expect(tester.getRect(find.byWidget(e.widget)).right, lessThanOrEqualTo(AppSizes.railWidth));
    }
    // The same buttons work: the second one opens the repertoires.
    await tester.tap(find.byType(BarButton).at(1));
    await settle(tester);
    expect(find.text('Білі: основи 1.e4'), findsWidgets);
    expect(find.text('Новий'), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('half of a split screen is a phone: the navigation is at the bottom', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['split view']!);
    expect(find.byType(ThumbBar), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('a page is a readable column in the middle of a wide screen', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['13" landscape']!);
    for (final route in ['/settings', '/about', '/backup']) {
      await goTo(tester, route);
      final tile = rectOf(tester, find.byType(ListTile));
      expect(tile.width, lessThanOrEqualTo(AppSizes.maxContentWidth), reason: route);
      expect((tile.center.dx - 1376 / 2).abs(), lessThan(1), reason: '$route is centred');
    }
    // The list itself takes the whole width: it scrolls from the margins.
    expect(rectOf(tester, find.byType(ListView)).width, 1376);
    await app.close(tester);
  });

  testWidgets('Today is two columns on a tablet', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['13" portrait']!);
    final plan = rectOf(tester, find.text('ТРЕНУВАТИСЬ'));
    final rep = rectOf(tester, find.text('Білі: основи 1.e4'));
    expect(rep.left, greaterThan(plan.right));
    expect(plan.width, lessThan(AppSizes.dashboardSide));
    await app.close(tester);
  });

  testWidgets('upright, the board leaves the text its share of the height', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['13" portrait']!);
    await goTo(tester, '/repertoires/1');
    final board = rectOf(tester, find.byType(BoardView));
    expect(board.width, lessThan(1032 * 0.9));
    expect((board.center.dx - 1032 / 2).abs(), lessThan(1));
    expect(1376 - board.bottom, greaterThan(1376 * AppBreakpoints.textShareBelowBoard));
    // The tools go from edge to edge; the moves keep to the board's column.
    expect(rectOf(tester, find.byType(ThumbBar)).width, 1032);
    expect(rectOf(tester, find.byTooltip('Ходи')).right, lessThanOrEqualTo(board.right));
    await app.close(tester);
  });

  testWidgets('on its side, the board takes the height and the tools stand beside it', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['13" landscape']!);
    await goTo(tester, '/analysis');
    final board = rectOf(tester, find.byType(BoardView));
    expect(board.left, lessThan(AppSpacing.lg));
    expect(board.height, greaterThan(1032 * 0.85));
    // The tools stand under the text, beside the board.
    expect(rectOf(tester, find.byType(ThumbBar)).left, greaterThanOrEqualTo(board.right));
    await app.close(tester);
  });

  testWidgets('a sheet is a card in the middle of a tablet', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['11" landscape']!);
    await goTo(tester, '/settings');
    await tapText(tester, 'Мова');
    expect(find.byType(BottomSheet), findsNothing);
    final card = rectOf(tester, find.byType(Dialog));
    final surface = rectOf(tester, find.descendant(of: find.byType(Dialog), matching: find.byType(Material)));
    expect(card.size, const Size(1210, 834));
    expect(surface.width, lessThanOrEqualTo(AppSizes.sheetCardWidth));
    expect((surface.center.dx - 1210 / 2).abs(), lessThan(1));
    expectClean(tester);
    await tapText(tester, 'English');
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Language'), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('the same choice is a sheet from the bottom on a phone', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    await goTo(tester, '/settings');
    await tapText(tester, 'Мова');
    expect(find.byType(BottomSheet), findsOneWidget);
    await app.close(tester);
  });

  testWidgets('the position editor fits a tablet on its side without scrolling', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: tablets['11" landscape']!);
    await goTo(tester, '/position-editor');
    final button = rectOf(tester, find.text('Аналізувати позицію'));
    expect(button.bottom, lessThan(834));
    await app.close(tester);
  });
}
