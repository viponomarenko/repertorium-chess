import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/core/l10n.dart';
import 'package:tabiya/data/engine/engine_network.dart';
import 'package:tabiya/data/engine/engine_service.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/accounts/accounts_providers.dart';
import 'package:tabiya/presentation/app/providers.dart';
import 'package:tabiya/presentation/app/route_observer.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/engine_panel.dart';

import '../e2e/harness.dart';

class TrackingEngine implements EngineService {
  final requests = <(String, EngineOptions, StreamController<EngineEval>)>[];
  int cancelled = 0;
  int globalStops = 0;
  @override
  String get name => 'test';
  @override
  Stream<EngineEval> analyze(String fen, EngineOptions options) {
    final c = StreamController<EngineEval>(
      onCancel: () {
        cancelled++;
      },
    );
    requests.add((fen, options, c));
    return c.stream;
  }

  void finish() {
    final r = requests.last;
    r.$3.add(
      EngineEval(
        fen: r.$1,
        depth: 20,
        done: true,
        lines: const [
          PvLine(multipv: 1, moves: ['e2e4'], cp: 20),
        ],
      ),
    );
  }

  @override
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1}) => throw UnimplementedError();
  @override
  Future<void> stop() async {
    globalStops++;
  }

  @override
  Future<void> shutdown() async {}
}

class CloudRequests extends LichessClient {
  CloudRequests() : super(userAgent: 'test');
  final requests = <(String, int, Completer<CloudEval?>)>[];
  int cancelled = 0;
  @override
  Future<CloudEval?> cloudEval(
    String fen, {
    int multiPv = 1,
    Future<void>? abort,
    Duration budget = const Duration(seconds: 3),
  }) {
    unawaited(
      abort?.then((_) {
        cancelled++;
      }),
    );
    final c = Completer<CloudEval?>();
    requests.add((fen, multiPv, c));
    return c.future;
  }
}

class MemoryEngineSettings extends SettingsNotifier {
  @override
  Future<void> update(AppSettings Function(AppSettings) f) async => state = f(state);
}

class ReadyEngineNetwork extends EngineNetwork {
  @override
  Future<void> initialize() async {
    value = const EngineNetworkState(NetworkPhase.ready);
  }
}

void main() {
  late TrackingEngine engine;
  late CloudRequests cloud;
  late ValueNotifier<String> fen;
  late ReadyEngineNetwork network;
  final navigator = GlobalKey<NavigatorState>();
  final initial = Chess.initial.fen;
  final next = Chess.initial.play(Chess.initial.parseSan('e4')!).fen;
  const answer = CloudEval(
    depth: 35,
    knodes: 100,
    lines: [
      CloudEvalLine(moves: ['e2e4'], cp: 30),
    ],
  );
  Future<void> pump(
    WidgetTester tester, {
    bool cloudFirst = true,
    String? position,
    String model = 'light',
    double textScale = 1,
    bool dark = false,
    double? maxHeight,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    engine = TrackingEngine();
    cloud = CloudRequests();
    fen = ValueNotifier(position ?? initial);
    network = ReadyEngineNetwork();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(AppSettings(engineCloudFirst: cloudFirst, engineModel: model)),
          settingsProvider.overrideWith(MemoryEngineSettings.new),
          engineNetworkProvider.overrideWithValue(network),
          soundServiceProvider.overrideWithValue(SilentSound()),
          engineServiceProvider.overrideWithValue(engine),
          lichessClientProvider.overrideWithValue(cloud),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [pageRouteObserver],
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          locale: const Locale('uk'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: fen,
              builder: (context, value, child) => EnginePanel(fen: value, compact: true, maxHeight: maxHeight),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    fen.dispose();
    cloud.close();
    network.dispose();
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('bounded variants scroll with the engine name fixed at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, cloudFirst: false, textScale: scale, maxHeight: 260);
      await tester.tap(find.byTooltip('Розгорнути'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final request = engine.requests.last;
      request.$3.add(
        EngineEval(
          fen: request.$1,
          depth: 20,
          done: true,
          lines: [
            for (var i = 1; i <= 5; i++)
              PvLine(
                multipv: i,
                cp: 30 - i,
                moves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5a4', 'g8f6'],
              ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('engine-source-name'));
      final before = tester.getRect(name);
      final scroll = find.byType(SingleChildScrollView);
      await tester.drag(scroll, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, greaterThan(0));
      expect(tester.getRect(name), before);
      expect(tester.getSize(find.byType(EnginePanel)).height, lessThanOrEqualTo(260));
      expect(tester.takeException(), isNull);
      await end(tester);
    });
  }

  testWidgets('choosing a different native model starts exactly one search and leaves cloud', (tester) async {
    await pump(tester);
    cloud.requests.single.$3.complete(answer);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.textContaining('35'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Локальний рушій'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stockfish 19'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.requests, hasLength(1));
    expect(cloud.requests, hasLength(1));
    await end(tester);
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final model in ['light', 'full', 'cloud']) {
        testWidgets('source stays visible for $model at $width and text $scale', (tester) async {
          tester.view.physicalSize = Size(width, 900) * tester.view.devicePixelRatio;
          addTearDown(tester.view.resetPhysicalSize);
          await pump(tester, cloudFirst: model == 'cloud', model: model, textScale: scale, dark: scale == 2);
          final name = model == 'cloud'
              ? 'Lichess'
              : model == 'full'
              ? 'Stockfish 19'
              : 'Stockfish 19 Light';
          expect(find.text(name), findsOneWidget);
          final text = find.byKey(const ValueKey('engine-source-name'));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: text, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(tester.takeException(), isNull);
          if (model == 'cloud') {
            cloud.requests.single.$3.complete(answer);
          } else {
            engine.finish();
          }
          await tester.pump(const Duration(milliseconds: 1));
          expect(find.text(name), findsOneWidget);
          expect(find.textContaining('готово'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await end(tester);
        });
      }
    }
  }

  testWidgets('cloud hit never starts local computation', (tester) async {
    await pump(tester);
    cloud.requests.single.$3.complete(answer);
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, isEmpty);
    expect(find.textContaining('35'), findsOneWidget);
    await end(tester);
  });
  testWidgets('expanding pending cloud keeps source and cancels obsolete request', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Розгорнути'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(cloud.requests.map((r) => r.$2), [1, 3]);
    expect(cloud.cancelled, 1);
    expect(engine.requests, isEmpty);
    cloud.requests.first.$3.complete(answer);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('35'), findsNothing);
    cloud.requests.last.$3.complete(answer);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('35'), findsOneWidget);
    await end(tester);
  });
  testWidgets('rapid moves debounce requests and discard late cloud results', (tester) async {
    await pump(tester);
    fen.value = next;
    await tester.pump(const Duration(milliseconds: 1));
    fen.value = initial;
    await tester.pump(const Duration(milliseconds: 1));
    expect(cloud.cancelled, 1);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 1));
    expect(cloud.requests, hasLength(2));
    cloud.requests.first.$3.complete(answer);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.textContaining('35'), findsNothing);
    await end(tester);
  });
  testWidgets('explicit phone source persists across moves', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Оцінка Lichess'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Цей телефон'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, hasLength(1));
    fen.value = next;
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(engine.requests, hasLength(2));
    expect(cloud.requests, hasLength(1));
    await end(tester);
  });
  testWidgets('empty cloud result falls back to local analysis', (tester) async {
    await pump(tester);
    cloud.requests.single.$3.complete(const CloudEval(depth: 40, knodes: 0, lines: []));
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, hasLength(1));
    expect(find.text('Lichess'), findsNothing);
    expect(find.text('Stockfish 19 Light'), findsOneWidget);
    await end(tester);
  });
  testWidgets('completion action keeps expand control in place', (tester) async {
    await pump(tester, cloudFirst: false);
    final button = find.byTooltip('Розгорнути');
    final bounds = tester.getRect(button);
    engine.finish();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Глибше'), findsOneWidget);
    expect(tester.getRect(button), bounds);
    await end(tester);
  });
  testWidgets('completed local evaluation survives background without recalculation', (tester) async {
    await pump(tester, cloudFirst: false);
    engine.finish();
    await tester.pump(const Duration(milliseconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, hasLength(1));
    expect(engine.cancelled, 1);
    expect(find.textContaining('20'), findsWidgets);
    await end(tester);
  });
  testWidgets('running computation stops when covered and resumes on return', (tester) async {
    await pump(tester, cloudFirst: false);
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold())));
    await tester.pumpAndSettle();
    expect(engine.cancelled, 1);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(engine.requests, hasLength(2));
    await end(tester);
    expect(engine.cancelled, 2);
    expect(engine.globalStops, 0);
  });
  testWidgets('dispose cancels cloud lookup without starting local fallback', (tester) async {
    await pump(tester);
    await end(tester);
    expect(cloud.cancelled, 1);
    expect(engine.requests, isEmpty);
  });
  testWidgets('terminal positions never start a lookup or engine', (tester) async {
    await pump(tester, position: '7k/6Q1/5K2/8/8/8/8/8 b - - 0 1');
    expect(cloud.requests, isEmpty);
    expect(engine.requests, isEmpty);
    expect(find.text('У цій позиції немає ходів'), findsOneWidget);
    await end(tester);
  });
  testWidgets('engine error has a working retry action', (tester) async {
    await pump(tester, cloudFirst: false);
    engine.requests.last.$3.addError(StateError('failed'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.tap(find.text('Спробувати ще'));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(engine.requests, hasLength(2));
    await end(tester);
  });
  test('power saving bounds resources and explicit unlimited mode remains available', () {
    final normal = analysisOptions(const AppSettings(), multiPv: 1);
    expect(normal.effectiveThreads, lessThanOrEqualTo(2));
    expect(normal.effectiveHash, 32);
    expect(normal.depth, 20);
    expect(normal.movetime, const Duration(seconds: 8));
    final deeper = analysisOptions(const AppSettings(), multiPv: 3, deeper: true);
    expect(deeper.depth, 30);
    expect(deeper.movetime, const Duration(seconds: 30));
    final unlimited = analysisOptions(const AppSettings(enginePowerSaving: false), multiPv: 1);
    expect(goCommand(unlimited), 'go infinite');
  });
}
