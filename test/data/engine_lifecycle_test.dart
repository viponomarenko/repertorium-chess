import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/engine/engine_service.dart';

class TestUciDriver implements UciDriver {
  final outputController = StreamController<String>.broadcast();
  final commands = <String>[];
  Completer<void>? starting;
  bool acknowledgeStop = true;
  bool acknowledgeReady = true;
  int starts = 0;
  int quits = 0;
  final configurations = <EngineConfiguration>[];
  @override
  Stream<String> get output => outputController.stream;
  @override
  Future<void> start({EngineConfiguration configuration = const EngineConfiguration()}) async {
    starts++;
    configurations.add(configuration);
    await starting?.future;
  }

  @override
  Future<void> quit() async {
    quits++;
  }

  @override
  void send(String command) {
    commands.add(command);
    if (command == 'isready' && acknowledgeReady) emit('readyok');
    if (command == 'stop' && acknowledgeStop) emit('bestmove e2e4');
  }

  void emit(String line) => outputController.add(line);
  Iterable<String> get searches => commands.where((s) => s.startsWith('go '));
}

Future<void> flush() async {
  for (var i = 0; i < 12; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late TestUciDriver driver;
  late StockfishEngine engine;
  final fen = Chess.initial.fen;
  final next = Chess.initial.play(Chess.initial.parseSan('e4')!).fen;
  setUp(() {
    driver = TestUciDriver();
    engine = StockfishEngine(driver: driver, stopTimeout: const Duration(milliseconds: 10));
  });
  tearDown(() async {
    await engine.shutdown();
    await driver.outputController.close();
  });

  test('changing engine disposes previous instance and reapplies UCI options', () async {
    var config = const EngineConfiguration();
    engine = StockfishEngine(driver: driver, configuration: () async => config);
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    config = const EngineConfiguration(model: EngineModel.full, nnuePath: '/weights.nnue');
    engine.analyze(next, const EngineOptions()).listen((_) {});
    await flush();
    expect(driver.quits, 1);
    expect(driver.configurations.map((c) => c.model), [EngineModel.light, EngineModel.full]);
    expect(engine.name, 'Stockfish 19');
    expect(driver.commands.where((s) => s.startsWith('setoption name Hash')), hasLength(2));
    config = const EngineConfiguration();
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    expect(driver.quits, 2);
    expect(engine.name, 'Stockfish 19 Light');
  });

  test('invalid material is rejected before native startup', () async {
    Object? error;
    engine
        .analyze('rnbqkbnr/pppppppp/8/8/8/4Q3/PPPPPPPP/RNBQKBNR w KQkq - 0 1', const EngineOptions())
        .listen((_) {}, onError: (Object e) => error = e);
    await flush();
    expect(error, isA<EnginePositionUnsupported>());
    expect(driver.starts, 0);
    expect(driver.commands, isEmpty);
  });

  test('native stream exit reports failure instead of leaving analysis running', () async {
    Object? error;
    engine.analyze(fen, const EngineOptions()).listen((_) {}, onError: (Object e) => error = e);
    await flush();
    await driver.outputController.close();
    await flush();
    expect(error, isA<StateError>());
    expect(driver.quits, 1);
  });

  test('an unlistened stream does not replace or start a search', () async {
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    engine.analyze(next, const EngineOptions());
    await flush();
    expect(driver.searches, hasLength(1));
    expect(driver.commands, isNot(contains('stop')));
  });

  test('cancel before queued startup never starts the engine', () async {
    final sub = engine.analyze(fen, const EngineOptions()).listen((_) {});
    await sub.cancel();
    await flush();
    expect(driver.starts, 0);
    expect(driver.searches, isEmpty);
  });

  test('shutdown during initialization waits then quits without starting a search', () async {
    driver.starting = Completer<void>();
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    final stopped = engine.shutdown();
    driver.starting!.complete();
    await stopped;
    expect(driver.searches, isEmpty);
    expect(driver.quits, 1);
  });

  test('stop cannot discard a newer analysis while its old stream closes', () async {
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    final stopping = engine.stop();
    final results = <EngineEval>[];
    engine.analyze(next, const EngineOptions()).listen(results.add);
    await stopping;
    await flush();
    driver.emit('info depth 12 score cp 30 pv e7e5');
    await flush();
    expect(driver.searches, hasLength(2));
    expect(results.single.fen, next);
    expect(results.single.best!.cp, -30);
  });

  test('paused output stream cannot block stop', () async {
    final sub = engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    sub.pause();
    await engine.stop().timeout(const Duration(seconds: 1));
    expect(driver.commands, contains('stop'));
    await sub.cancel();
  });

  test('only latest queued position starts and old cancellation cannot stop it', () async {
    final first = engine.analyze(fen, const EngineOptions()).listen((_) {});
    engine.analyze(next, const EngineOptions()).listen((_) {});
    engine.analyze(fen, const EngineOptions(depth: 9)).listen((_) {});
    await flush();
    await first.cancel();
    await flush();
    expect(driver.searches.toList(), ['go depth 9']);
    expect(driver.commands, isNot(contains('stop')));
  });

  test('waits for readiness before sending position and go', () async {
    driver.acknowledgeReady = false;
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    expect(driver.searches, isEmpty);
    driver.emit('readyok');
    await flush();
    expect(driver.searches, hasLength(1));
  });

  test('unacknowledged stop restarts native engine before next search', () async {
    driver.acknowledgeStop = false;
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    engine.analyze(next, const EngineOptions()).listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await flush();
    expect(driver.quits, 1);
    expect(driver.starts, 2);
    expect(driver.searches, hasLength(2));
    driver.acknowledgeStop = true;
  });

  test('completed search closes output and releases idle native memory', () async {
    engine = StockfishEngine(driver: driver, idleTimeout: const Duration(milliseconds: 20));
    final result = engine.analyze(fen, const EngineOptions()).toList();
    await flush();
    driver.emit('info depth 14 score cp 32 nodes 150 nps 3000 pv e2e4');
    driver.emit('bestmove e2e4');
    final events = await result;
    expect(events.last.done, isTrue);
    expect(events.last.nodes, 150);
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(driver.quits, 1);
  });

  test('changing MultiPV does not reallocate threads and hash', () async {
    engine.analyze(fen, const EngineOptions(multiPv: 1)).listen((_) {});
    await flush();
    engine.analyze(fen, const EngineOptions(multiPv: 3)).listen((_) {});
    await flush();
    expect(driver.commands.where((s) => s.startsWith('setoption name Threads')), hasLength(1));
    expect(driver.commands.where((s) => s.startsWith('setoption name Hash')), hasLength(1));
    expect(driver.commands.where((s) => s.startsWith('setoption name MultiPV')), hasLength(2));
  });

  test('bursts are throttled but final evaluation retains latest depth', () async {
    final result = engine.analyze(fen, const EngineOptions()).toList();
    await flush();
    for (var i = 1; i <= 80; i++) {
      driver.emit('info depth $i score cp $i pv e2e4');
    }
    driver.emit('bestmove e2e4');
    final events = await result;
    expect(events.length, lessThanOrEqualTo(3));
    expect(events.last.depth, 80);
    expect(events.last.best!.cp, 80);
  });

  test('background blocks queued work until foreground', () async {
    engine.setForeground(false);
    final events = await engine.analyze(fen, const EngineOptions()).toList();
    expect(events, isEmpty);
    expect(driver.starts, 0);
    engine.setForeground(true);
    engine.analyze(fen, const EngineOptions()).listen((_) {});
    await flush();
    expect(driver.starts, 1);
  });

  test('batch evaluations are bounded and cancellation is explicit', () async {
    final result = engine.evaluate(fen, depth: 18, multiPv: 3);
    final assertion = expectLater(result, throwsA(isA<EngineCancelled>()));
    await flush();
    expect(driver.searches.single, 'go depth 18 movetime 8000');
    await engine.stop();
    await assertion;
  });
}
