import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/ui/menu.dart';

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

/// Menus are sheets with groups (D-112).
void main() {
  testWidgets('groups, captions, a disabled row, a check, the chosen value', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppMenuButton<String>(
            tooltip: 'Ще',
            title: 'Репертуар',
            subtitle: 'Вивчено 0 з 34 ходів',
            onSelected: (v) => chosen = v,
            itemBuilder: (_) => [
              appMenuItem(value: 'a', label: 'Перейменувати'),
              appMenuDivider('Інструменти'),
              appMenuItem(value: 'b', label: 'Вимкнено', enabled: false),
              appMenuItem(value: 'c', label: 'Вибране', selected: true),
              appMenuDivider(),
              appMenuItem(value: 'd', label: 'Видалити', destructive: true),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ще'));
    await tester.pumpAndSettle();
    expect(find.text('Репертуар'), findsOneWidget);
    expect(find.text('Вивчено 0 з 34 ходів'), findsOneWidget);
    expect(find.text('ІНСТРУМЕНТИ'), findsOneWidget);
    // Three groups: the delete stands alone.
    expect(find.byType(Material).evaluate().where((e) => (e.widget as Material).borderRadius == AppRadius.mdAll), hasLength(3));
    await tester.tap(find.text('Вимкнено'));
    await tester.pumpAndSettle();
    expect(chosen, isNull, reason: 'a disabled row does nothing');
    await tester.tap(find.text('Вибране'));
    await tester.pumpAndSettle();
    expect(chosen, 'c');
    expect(find.text('Перейменувати'), findsNothing, reason: 'the sheet closed');
  });

  testWidgets('tiles form one row at the top and return their value (D-114)', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: AppMenuButton<String>(
            tooltip: 'Ще',
            title: 'Аналіз',
            onSelected: (v) => chosen = v,
            itemBuilder: (_) => [
              appMenuTile(value: 'export', icon: Icons.ios_share, label: 'Експорт PGN'),
              appMenuTile(value: 'fen', icon: Icons.copy, label: 'Копіювати FEN'),
              appMenuItem(value: 'info', label: 'Інформація', subtitle: 'Гравці, дата'),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Ще'));
    await tester.pumpAndSettle();
    // Two tiles side by side, above the group of rows.
    final export = tester.getRect(find.text('Експорт PGN'));
    final fen = tester.getRect(find.text('Копіювати FEN'));
    expect((export.center.dy - fen.center.dy).abs(), lessThan(1));
    expect(export.left, lessThan(fen.left));
    expect(tester.getRect(find.text('Інформація')).top, greaterThan(export.bottom));
    expect(find.text('Гравці, дата'), findsOneWidget);
    await tester.tap(find.text('Копіювати FEN'));
    await tester.pumpAndSettle();
    expect(chosen, 'fen');
  });

  testWidgets('the training modes: a title, what is off under its own caption (D-114)', (tester) async {
    final app = await pumpApp(tester, seed: seedRepertoire);
    await tapText(tester, 'Режими');
    expect(find.text('Як тренуватись'), findsOneWidget);
    expect(find.text('ПОКИ НЕДОСТУПНО'), findsOneWidget);
    // Nothing learned yet: the drill says when it opens.
    expect(find.text('Зʼявиться, щойно ви вивчите перший хід'), findsOneWidget);
    expect(
      tester.getRect(find.text('Нові ходи')).top,
      lessThan(tester.getRect(find.text('ПОКИ НЕДОСТУПНО')).top),
      reason: 'what can be trained now comes first',
    );
    expectClean(tester);
    await app.close(tester);
  });

  for (final size in const [Size(320, 640), Size(402, 874)]) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('the repertoire menu at ${size.width.round()}px, text ${scale}x', (tester) async {
        final app = await pumpApp(tester, seed: seedRepertoire, size: size, textScale: scale);
        await goTo(tester, '/repertoires/1');
        await tester.tap(find.byTooltip('Ще').last);
        await settle(tester);
        expect(find.text('Білі: основи 1.e4'), findsWidgets);
        expect(find.text('ІМПОРТ І ЕКСПОРТ'), findsOneWidget);
        expect(find.text('ІНСТРУМЕНТИ'), findsOneWidget);
        expect(find.text('Видалити репертуар'), findsOneWidget);
        expectClean(tester);
        if (scale == 1.0) await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        // A choice closes the sheet and runs the action.
        await tapText(tester, 'Перейменувати');
        expect(find.byType(TextField), findsOneWidget);
        await app.close(tester);
      });
    }
  }
}
