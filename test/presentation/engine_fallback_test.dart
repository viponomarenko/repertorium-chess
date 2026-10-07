import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/core/l10n.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/accounts/accounts_providers.dart';
import 'package:tabiya/presentation/app/providers.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/engine_panel.dart';

import '../e2e/harness.dart';

class SlowCloud extends LichessClient {
  SlowCloud() : super(userAgent: 'test');
  final response = Completer<CloudEval?>();
  @override
  Future<CloudEval?> cloudEval(
    String fen, {
    int multiPv = 1,
    Future<void>? abort,
    Duration budget = const Duration(seconds: 3),
  }) => response.future;
}

void main() {
  Future<FakeEngine> pump(WidgetTester tester, SlowCloud cloud, String fen) async {
    final engine = FakeEngine();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(const AppSettings(engineCloudFirst: true)),
          soundServiceProvider.overrideWithValue(SilentSound()),
          engineServiceProvider.overrideWithValue(engine),
          lichessClientProvider.overrideWithValue(cloud),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('uk'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EnginePanel(fen: fen)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    return engine;
  }

  testWidgets('slow cloud falls back after three seconds and ignores late results', (tester) async {
    final cloud = SlowCloud();
    final engine = await pump(tester, cloud, Chess.initial.fen);
    expect(engine.starts, 0);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(engine.starts, 1);
    cloud.response.complete(const CloudEval(depth: 50, knodes: 1, lines: []));
    await tester.pump();
    expect(find.textContaining('50'), findsNothing);
    expect(find.textContaining('12'), findsWidgets);
    expectClean(tester);
    await tester.pumpWidget(const SizedBox());
    cloud.close();
  });

  testWidgets('phone can be selected while cloud is loading', (tester) async {
    final cloud = SlowCloud();
    final position = Chess.initial.play(Chess.initial.parseSan('d4')!);
    final engine = await pump(tester, cloud, position.fen);
    expect(find.text('Оцінка Lichess'), findsOneWidget, reason: visibleTexts(tester).join(' | '));
    await tester.tap(find.text('Оцінка Lichess'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final context = tester.element(find.byType(EnginePanel));
    await tester.tap(find.text(context.l10n.engineSourcePhone));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(engine.starts, 1);
    cloud.response.complete(const CloudEval(depth: 51, knodes: 1, lines: []));
    await tester.pump();
    expect(find.textContaining('51'), findsNothing);
    expectClean(tester);
    await tester.pumpWidget(const SizedBox());
    cloud.close();
  });
}
