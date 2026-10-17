import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/engine/engine_check.dart';
import 'package:tabiya/data/repositories/repertoire_repository.dart';
import 'package:tabiya/domain/repertoire/repertoire_graph.dart';
import 'package:tabiya/domain/repertoire/repertoire_import.dart';
import 'package:tabiya/presentation/widgets/ui/notice.dart';

import 'harness.dart';

/// White 1. e4 e5, where the engine flagged 1. e4 and prefers 1. d4.
Future<void> seedFlagged(AppDatabase db) async {
  final repo = RepertoireRepository(db);
  final id = await repo.create(name: 'Engine test', color: Side.white);
  final g = await repo.loadGraph(id);
  addSanLine(g, Chess.initial, ['e4', 'e5', 'Nf3']);
  g.setEngineFlag(
    g.rootKey,
    const EngineFlag(lossCp: 150, bestUci: 'd2d4', bestSan: 'd4', depth: 14, mainUci: 'e2e4').encode(),
  );
  await repo.saveGraph(id, g);
}

Future<RepertoireGraph> graphOf(WidgetTester tester, TestApp app) async =>
    (await tester.runAsync(() => RepertoireRepository(app.db).loadGraph(1)))!;

/// The ways out of an engine flag on the repertoire screen (D-090): keep
/// the own move or take the engine's, both undoable, and the problem
/// leaves the "Problems" tab either way.
void main() {
  testWidgets('keeping my move clears the flag; undo brings it back', (tester) async {
    final app = await pumpApp(tester, seed: seedFlagged);
    await goTo(tester, '/repertoires/1');
    expect(find.text('Зробити основним d4'), findsOneWidget);
    expect(find.text('Залишити мій хід'), findsOneWidget);

    await tapText(tester, 'Залишити мій хід');
    expect(find.text('Позначку знято: e4 лишається основним'), findsOneWidget);
    expect(find.text('Залишити мій хід'), findsNothing, reason: 'the flag is answered');
    var g = await graphOf(tester, app);
    final kept = EngineFlag.decode(g.positions[g.rootKey]!.engineFlag)!;
    expect(kept.dismissed, isTrue);
    expect(g.mainMove(g.rootKey)!.san, 'e4');

    await tapText(tester, 'Скасувати');
    expect(find.text('Залишити мій хід'), findsOneWidget);
    g = await graphOf(tester, app);
    expect(EngineFlag.isActive(g.positions[g.rootKey]!.engineFlag), isTrue);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('taking the engine move makes it main, keeps the old line; undo restores', (tester) async {
    final app = await pumpApp(tester, seed: seedFlagged);
    await goTo(tester, '/repertoires/1');
    await tapText(tester, 'Зробити основним d4');
    expect(find.text('d4 тепер основний; e4 – альтернатива'), findsOneWidget);
    expect(find.text('Зробити основним d4'), findsNothing);
    var g = await graphOf(tester, app);
    expect(g.mainMove(g.rootKey)!.san, 'd4');
    final e4 = g.move(g.rootKey, 'e2e4')!;
    expect(e4.role, MoveRole.alternative);
    expect(g.movesFrom(e4.toKey), isNotEmpty);
    expect(g.positions[g.rootKey]!.engineFlag, isEmpty);
    expect(g.checkInvariants(), isEmpty);

    await tapText(tester, 'Скасувати');
    g = await graphOf(tester, app);
    expect(g.mainMove(g.rootKey)!.san, 'e4');
    expect(g.move(g.rootKey, 'd2d4'), isNull, reason: 'the added move goes again');
    expect(EngineFlag.isActive(g.positions[g.rootKey]!.engineFlag), isTrue);
    expect(find.text('Зробити основним d4'), findsOneWidget);
    expectClean(tester);
    await app.close(tester);
  });

  testWidgets('an answered flag is not listed under Problems', (tester) async {
    final app = await pumpApp(tester, seed: seedFlagged);
    await goTo(tester, '/repertoires/1');
    await tapText(tester, 'Проблеми');
    expect(find.textContaining('Позначки рушія (1)'), findsOneWidget);
    await tapText(tester, 'Позиції');
    await tapText(tester, 'Залишити мій хід');
    // The notice at the top covers the tabs until it goes.
    await tester.pump(NoticeHost.withAction);
    await settle(tester);
    await tapText(tester, 'Проблеми');
    expect(find.textContaining('Позначки рушія (0)'), findsOneWidget);
    await app.close(tester);
  });
}
