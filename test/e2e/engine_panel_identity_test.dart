import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/widgets/board_view.dart';
import 'package:tabiya/presentation/widgets/engine_panel.dart';

import 'harness.dart';

void main() {
  testWidgets('opening label appearing preserves analysis source and cached results', (tester) async {
    final app = await pumpApp(
      tester,
      settings: const AppSettings(
        onboardingDone: true,
        localeCode: 'uk',
        sound: false,
        haptics: false,
        engineCloudFirst: false,
      ),
    );
    await goTo(tester, '/analysis');
    await tapText(tester, 'Рушій');
    final panel = tester.state(find.byType(EnginePanel));
    final board = tester.widget<BoardView>(find.byType(BoardView));
    board.onMove!(board.position.parseSan('e4')!);
    await settle(tester);
    expect(find.textContaining('B00'), findsWidgets);
    expect(tester.state(find.byType(EnginePanel)), same(panel));
    await tapText(tester, 'Назад');
    expect(tester.state(find.byType(EnginePanel)), same(panel));
    expect(app.engine.starts, 2, reason: 'returning to the initial position uses its completed result');
    tester.view.physicalSize = const Size(844, 390) * tester.view.devicePixelRatio;
    await settle(tester);
    expect(tester.state(find.byType(EnginePanel)), same(panel));
    tester.view.physicalSize = const Size(390, 844) * tester.view.devicePixelRatio;
    await settle(tester);
    expect(tester.state(find.byType(EnginePanel)), same(panel));
    expect(app.engine.starts, 3, reason: 'only the expanded landscape MultiPV needs a new search');
    expectClean(tester);
    await app.close(tester);
  });
}
