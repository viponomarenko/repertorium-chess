import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/repositories/library_repository.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// An empty screen shows each action once (no floating button repeating
/// the big button in the middle).
void main() {
  testWidgets('empty repertoire list: one "New repertoire" button', (tester) async {
    final app = await pumpApp(tester);
    await goTo(tester, '/repertoires');
    expect(find.text('Новий репертуар'), findsOneWidget);
    expect(find.byTooltip('Готові репертуари'), findsNothing);
    await app.close(tester);
  });

  testWidgets('empty library: one "Import" button', (tester) async {
    final app = await pumpApp(tester);
    await goTo(tester, '/library');
    expect(find.text('Імпортувати'), findsOneWidget);
    await app.close(tester);
  });

  // No button floats over a list: with content, the action is in the bar.
  testWidgets('repertoire list with content: create in the app bar, nothing floating', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    await goTo(tester, '/repertoires');
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Новий репертуар')), findsOneWidget);
    await tester.tap(find.byTooltip('Новий репертуар').last);
    await settle(tester);
    expect(find.text('Створити'), findsWidgets, reason: 'the new-repertoire sheet opened');
    // Ready-made repertoires are offered here, not by an icon in the bar.
    expect(find.byTooltip('Готові репертуари'), findsNothing);
    expect(find.byTooltip('Каталог дебютів'), findsNothing);
    expect(find.text('Або взяти готовий репертуар'), findsOneWidget);
    await tapText(tester, 'Або взяти готовий репертуар');
    await settle(tester, frames: 60);
    expect(find.text('Встановити'), findsWidgets, reason: 'the list of ready-made repertoires opened');
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('library with content: import in the app bar, nothing floating', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db) async {
        await LibraryRepository(db).createCollection('Колекція');
      },
    );
    await goTo(tester, '/library');
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Імпортувати')), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });
}
