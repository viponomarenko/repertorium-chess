import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/domain/training/training_engine.dart';
import 'package:tabiya/presentation/accounts/accounts_screen.dart';
import 'package:tabiya/presentation/repertoire/repertoire_screen.dart';
import 'package:tabiya/presentation/training/training_args.dart';
import 'package:tabiya/presentation/training/training_screen.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/common.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// D-101: the iOS swipe back from the left edge, and the touches that must
/// never be taken for it.
void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  /// A finger from [from] by [by] in [steps] moves of 16 ms.
  Future<void> drag(WidgetTester tester, Offset from, Offset by, {int steps = 12}) async {
    final g = await tester.startGesture(from);
    for (var i = 0; i < steps; i++) {
      await g.moveBy(by / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await settle(tester);
  }

  testWidgets('a swipe from the edge goes back; a twitch, a scroll or a swipe from the middle do not', (tester) async {
    final app = await pumpApp(tester);
    try {
      await goTo(tester, '/accounts');
      expect(find.byType(AccountsScreen), findsOneWidget);

      // A twitch from the edge: 30 pt, quickly.
      await drag(tester, const Offset(6, 400), const Offset(30, 0), steps: 2);
      expect(find.byType(AccountsScreen), findsOneWidget, reason: 'a twitch is not a swipe back');

      // A scroll down that starts at the edge.
      await drag(tester, const Offset(6, 300), const Offset(25, 300));
      expect(find.byType(AccountsScreen), findsOneWidget, reason: 'a scroll stays a scroll');

      // Sideways, but from the middle of the screen.
      await drag(tester, const Offset(120, 400), const Offset(250, 0));
      expect(find.byType(AccountsScreen), findsOneWidget, reason: 'only the edge starts it');

      // Slowly a quarter of the way, then let go: the screen slides back.
      await drag(tester, const Offset(6, 400), const Offset(90, 0), steps: 30);
      expect(find.byType(AccountsScreen), findsOneWidget, reason: 'not far enough');

      // From the edge, past the middle: back.
      await drag(tester, const Offset(6, 400), const Offset(260, 0));
      expect(find.byType(AccountsScreen), findsNothing);
    } finally {
      await app.close(tester);
    }
  }, variant: ios);

  testWidgets('a piece dragged from the edge file stays on the board; below the board the swipe works', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    try {
      await goTo(tester, '/repertoires/1');
      final board = tester.getRect(find.byType(BoardView));
      expect(board.left, lessThan(kBackSwipeEdge), reason: 'the board reaches the edge strip');
      // From the edge of a1 to the right and a little up, as a rook move:
      // without the guard this slid the screen away.
      final sq = board.width / 8;
      await drag(tester, Offset(board.left + 4, board.bottom - sq / 2), Offset(sq * 3, -sq / 2));
      expect(find.byType(RepertoireScreen), findsOneWidget);

      // The same stroke under the board is a swipe back.
      await drag(tester, Offset(4, board.bottom + 60), Offset(sq * 4, 0));
      expect(find.byType(RepertoireScreen), findsNothing);
    } finally {
      await app.close(tester);
    }
  }, variant: ios);

  testWidgets('training cannot be swiped away: only its Back leaves', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    try {
      await goTo(
        tester,
        '/train',
        extra: const TrainingArgs(repertoireIds: [1], mode: TrainingMode.learn),
      );
      expect(find.byType(TrainingScreen), findsOneWidget);
      await drag(tester, const Offset(6, 700), const Offset(300, 0));
      expect(find.byType(TrainingScreen), findsOneWidget);
    } finally {
      await app.close(tester);
    }
  }, variant: ios);
}
