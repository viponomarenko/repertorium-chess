import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/typography.dart';
import 'package:tabiya/presentation/widgets/board_layout.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show deepKey, seedRepertoire;

/// Text under and beside the board uses only the standard roles (D-053):
/// no stray sizes or weights (user: "fonts wander under the board").
void main() {
  Set<(double?, FontWeight?)> allowed(TabiyaText tt) => {
    for (final s in [
      tt.title,
      tt.body,
      tt.meta,
      tt.value,
      tt.control,
      tt.overline,
      tt.comment,
      tt.moveMain,
      tt.moveNumber,
    ])
      (s.fontSize, s.fontWeight),
  };

  Set<String> strays(WidgetTester tester) {
    final layout = find.byType(BoardLayout);
    final tt = tester.element(layout).tt;
    final ok = allowed(tt);
    final out = <String>{};
    final texts = find.descendant(of: layout, matching: find.byType(RichText));
    for (final e in texts.evaluate()) {
      // The board's own coordinates and the 18-high result bar are graphics.
      if (e.findAncestorWidgetOfExactType<BoardView>() != null) continue;
      final rich = e.widget as RichText;
      rich.text.visitChildren((span) {
        final t = (span as TextSpan).text;
        if (t == null || t.trim().isEmpty) return true;
        final st = e.findAncestorWidgetOfExactType<DefaultTextStyle>()?.style.merge(span.style) ?? span.style;
        // Icon glyphs are drawn with an icon font, not text.
        if (st?.fontFamily?.contains('Icons') ?? false) return true;
        final key = (st?.fontSize, st?.fontWeight);
        if (!ok.contains(key)) out.add('"$t" ${key.$1} ${key.$2}');
        return true;
      });
    }
    return out;
  }

  testWidgets('analysis with engine and explorer', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire, size: const Size(402, 874));
    await goTo(tester, '/analysis');
    await tapText(tester, 'Рушій');
    await settle(tester);
    expect(strays(tester), isEmpty);
    await tapText(tester, 'База');
    expect(strays(tester), isEmpty);
    await app.close(tester);
  });

  for (final route in ['/repertoires/1?key=${deepKey()}', '/build/1?key=${deepKey()}']) {
    testWidgets('under the board on $route', (tester) async {
      final app = await pumpApp(tester, seed: seedRepertoire, size: const Size(402, 874));
      await goTo(tester, route);
      expect(strays(tester), isEmpty);
      await app.close(tester);
    });
  }
}
