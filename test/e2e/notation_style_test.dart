import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/typography.dart';
import 'package:tabiya/presentation/widgets/notation_view.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show deepKey, seedRepertoire;

/// Moves look the same everywhere (D-052): the path under the board uses
/// the notation's fonts and sizes, current move or not.
void main() {
  for (final route in ['/build/1?key=${deepKey()}', '/repertoires/1?key=${deepKey()}']) {
    testWidgets('path moves use the notation style on $route', (tester) async {
      final app = await pumpApp(tester, seed: seedRepertoire, size: const Size(402, 874));
      await goTo(tester, route);
      final chips = find.byType(MoveChip);
      expect(chips, findsWidgets);
      final tt = tester.element(chips.first).tt;
      final sizes = <double?>{};
      final weights = <FontWeight?>{};
      for (final e in find.descendant(of: chips, matching: find.byType(RichText)).evaluate()) {
        (e.widget as RichText).text.visitChildren((span) {
          final style = (span as TextSpan).style;
          if (span.text != null && span.text!.trim().isNotEmpty) {
            sizes.add(style?.fontSize);
            if (!RegExp(r'^\d+\.').hasMatch(span.text!)) weights.add(style?.fontWeight);
          }
          return true;
        });
      }
      expect(sizes, {tt.moveMain.fontSize});
      expect(weights, {tt.moveMain.fontWeight});
      expectClean(tester);
      await app.close(tester);
    });
  }
}
