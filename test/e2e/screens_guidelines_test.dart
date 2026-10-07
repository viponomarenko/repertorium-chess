import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';

import 'harness.dart';

/// Every main screen on small/normal/large phones at 100 % and 200 % text:
/// no overflow, and every tappable thing is finger-sized (D-035).
Future<void> seedRepertoire(AppDatabase db) async {
  final repo = RepertoireRepository(db);
  final id = await repo.create(name: 'Білі: основи 1.e4', color: Side.white);
  final g = await repo.loadGraph(id);
  addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
  addSanLine(g, Chess.initial, ['e4', 'c5', 'Nf3', 'd6', 'd4']);
  await repo.saveGraph(id, g);
}

/// Deep in the Sicilian line: the move breadcrumbs overflow the width.
String deepKey() {
  Position p = Chess.initial;
  for (final san in ['e4', 'c5', 'Nf3', 'd6', 'd4']) {
    p = p.play(p.parseSan(san)!);
  }
  return Uri.encodeQueryComponent(positionKeyOf(p));
}

const sizes = [Size(320, 640), Size(390, 844), Size(430, 932)];
final routes = [
  '/today',
  '/repertoires',
  '/repertoires/1',
  '/repertoires/1?key=${deepKey()}',
  '/build/1?key=${deepKey()}',
  '/library',
  '/more',
  '/settings',
  '/analysis',
  '/stats',
  '/my-openings',
];

/// Controls stay clear of the screen edges, where a thumb (and a phone
/// case) cannot reach them comfortably, and never sit in a sideways
/// scrolling row, where they can scroll off the screen.
void expectClearOfEdges(WidgetTester tester) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  bool inSideScroll(Element e) {
    var found = false;
    e.visitAncestorElements((a) {
      final w = a.widget;
      if (w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.horizontal) {
        // Tab pages (a page view) and the row of tabs scroll sideways by
        // design.
        if (w.controller is PageController) return true;
        found = a.findAncestorWidgetOfExactType<TabBar>() == null;
        return false;
      }
      return true;
    });
    return found;
  }

  final problems = <String>[];
  void check(Finder f, String what, double margin, {bool allowSideScroll = false}) {
    for (final e in f.evaluate()) {
      final box = e.renderObject;
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      final r = box.localToGlobal(Offset.zero) & box.size;
      // Off screen vertically (scrolled away) is fine.
      if (r.bottom <= 0 || r.top >= tester.view.physicalSize.height / tester.view.devicePixelRatio) continue;
      if (r.width > width / 2) continue; // full-width rows reach the edge by design
      final side = inSideScroll(e);
      if (side && !allowSideScroll) problems.add('$what in a sideways scrolling row at $r');
      if (!side && (r.left < margin || r.right > width - margin)) problems.add('$what at $r (margin $margin)');
    }
  }

  // The glyph of an icon button (its 48 dp box is transparent padding).
  check(find.descendant(of: find.byType(IconButton), matching: find.byType(Icon)), 'icon button', 12);
  // Material 3 builds an icon button from a ButtonStyleButton: checked
  // above by its glyph.
  check(
    find.byElementPredicate(
      (e) => e.widget is ButtonStyleButton && e.findAncestorWidgetOfExactType<IconButton>() == null,
    ),
    'button',
    8,
  );
  check(find.byType(FloatingActionButton), 'floating button', 8);
  check(find.byType(RawChip), 'chip', 8, allowSideScroll: true);
  expect(problems, isEmpty);
}

void main() {
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      for (final route in routes) {
        testWidgets('$route at ${size.width.round()}x${size.height.round()}, text ${scale}x', (tester) async {
          final app = await pumpApp(tester, seed: seedRepertoire, size: size, textScale: scale);
          await goTo(tester, route);
          expectClean(tester);
          expectClearOfEdges(tester);
          if (scale == 1.0) {
            await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          }
          await app.close(tester);
        });
      }
    }
  }
}
