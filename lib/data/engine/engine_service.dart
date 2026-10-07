/// Chess engine abstraction (F-ENG-05): the UI and batch checks depend on
/// [EngineService] only, so another engine (e.g. an external UCI engine on
/// Android) can be added later without rework.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:multistockfish/multistockfish.dart';

import '../../domain/chess/chess_utils.dart';
import 'engine_configuration.dart';

export 'engine_configuration.dart';

class PvLine {
  const PvLine({required this.multipv, required this.moves, this.cp, this.mate});

  final int multipv;

  /// UCI moves (castling as sent by the engine, e.g. e1g1).
  final List<String> moves;

  /// Score from White's point of view.
  final int? cp;
  final int? mate;

  /// Comparable score in centipawns (mates mapped to ±10000).
  int get score => mate != null ? (mate! > 0 ? 10000 - mate! : -10000 - mate!) : (cp ?? 0);
}

class EngineEval {
  const EngineEval({
    required this.fen,
    required this.depth,
    required this.lines,
    this.nodes = 0,
    this.nps = 0,
    this.done = false,
  });

  final String fen;
  final int depth;

  /// Sorted by multipv.
  final List<PvLine> lines;
  final int nodes;
  final int nps;
  final bool done;

  PvLine? get best => lines.isEmpty ? null : lines.first;
}

class EngineOptions {
  const EngineOptions({this.threads = 0, this.hashMb = 0, this.multiPv = 3, this.depth, this.movetime});

  /// 0 = automatic.
  final int threads;
  final int hashMb;
  final int multiPv;
  final int? depth;
  final Duration? movetime;

  int get effectiveThreads => threads > 0
      ? threads.clamp(1, math.max(1, Platform.numberOfProcessors - 1))
      : math.max(1, math.min(4, Platform.numberOfProcessors - 1));
  int get effectiveHash => hashMb > 0 ? hashMb.clamp(1, 512) : 64;
}

abstract class EngineService {
  String get name;

  /// Continuous analysis; emits improving evaluations. Starting a new
  /// analysis stops the previous one.
  Stream<EngineEval> analyze(String fen, EngineOptions options);

  /// Single evaluation to a fixed depth (batch checks, F-ENG-04).
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1});

  Future<void> stop();

  /// Frees resources (called when the app goes to background).
  Future<void> shutdown();
}

/// Parses a UCI "info" line. Returns null for lines without a score/pv.
PvLine? parseInfoLine(String line, {required bool whiteToMove}) {
  if (!line.startsWith('info ') || !line.contains(' pv ')) return null;
  if (line.contains(' lowerbound') || line.contains(' upperbound')) return null;
  final parts = line.split(' ');
  var multipv = 1;
  int? cp;
  int? mate;
  final pvIdx = parts.indexOf('pv');
  for (var i = 0; i < pvIdx; i++) {
    switch (parts[i]) {
      case 'multipv':
        multipv = int.tryParse(parts[i + 1]) ?? 1;
      case 'cp':
        if (i > 0 && parts[i - 1] == 'score') cp = int.tryParse(parts[i + 1]);
      case 'mate':
        if (i > 0 && parts[i - 1] == 'score') mate = int.tryParse(parts[i + 1]);
    }
  }
  if (cp == null && mate == null) return null;
  final sign = whiteToMove ? 1 : -1;
  return PvLine(
    multipv: multipv,
    moves: parts.sublist(pvIdx + 1).where((s) => s.isNotEmpty).toList(),
    cp: cp == null ? null : cp * sign,
    mate: mate == null ? null : mate * sign,
  );
}

/// UCI `go` for [o]: depth and/or time limit; infinite only when neither
/// is set.
String goCommand(EngineOptions o) {
  final parts = ['go'];
  if (o.depth != null && o.depth! > 0) parts.add('depth ${o.depth}');
  if (o.movetime != null) parts.add('movetime ${o.movetime!.inMilliseconds}');
  if (parts.length == 1) parts.add('infinite');
  return parts.join(' ');
}

int? _infoInt(String line, String key) {
  final parts = line.split(' ');
  final i = parts.indexOf(key);
  return i >= 0 && i + 1 < parts.length ? int.tryParse(parts[i + 1]) : null;
}

/// Transport boundary keeps UCI lifecycle tests independent of native FFI.
abstract class UciDriver {
  Stream<String> get output;
  Future<void> start({EngineConfiguration configuration = const EngineConfiguration()});
  void send(String command);
  Future<void> quit();
}

class NativeStockfishDriver implements UciDriver {
  Stockfish? _sf;
  @override
  Stream<String> get output => _sf!.stdout;
  @override
  Future<void> start({EngineConfiguration configuration = const EngineConfiguration()}) async {
    _sf = await Stockfish.create(
      flavor: configuration.model == EngineModel.full ? StockfishFlavor.latestNoNNUE : StockfishFlavor.light,
      nnuePath: configuration.nnuePath,
    );
  }

  @override
  void send(String command) => _sf!.stdin = command;
  @override
  Future<void> quit() async {
    final sf = _sf;
    _sf = null;
    await sf?.dispose();
  }
}

class EnginePositionUnsupported implements Exception {
  const EnginePositionUnsupported();
}

/// SF19 rejects impossible material with a fatal native error. Validate it
/// before sending any position, including positions imported from the editor.
String stockfishFen(String fen) {
  final position = tryPositionFromFen(fen);
  if (position == null) throw const EnginePositionUnsupported();
  for (final side in Side.values) {
    int count(Role role) => position.board.piecesOf(side, role).size;
    final bishops = position.board.piecesOf(side, Role.bishop);
    final promotions =
        math.max(count(Role.queen) - 1, 0) +
        math.max(count(Role.rook) - 2, 0) +
        math.max(count(Role.knight) - 2, 0) +
        math.max(bishops.intersect(SquareSet.lightSquares).size - 1, 0) +
        math.max(bishops.intersect(SquareSet.darkSquares).size - 1, 0);
    if (count(Role.pawn) + promotions > 8) throw const EnginePositionUnsupported();
  }
  return position.fen;
}

class EngineCancelled implements Exception {
  const EngineCancelled();
}

/// One serialized native engine. A subscription owns its search; cancelling
/// an old subscription cannot stop a newer one. Idle engines release memory.
class StockfishEngine implements EngineService {
  StockfishEngine({
    UciDriver? driver,
    Future<EngineConfiguration> Function()? configuration,
    this.stopTimeout = const Duration(milliseconds: 800),
    this.idleTimeout = const Duration(seconds: 15),
  }) : _driver = driver ?? NativeStockfishDriver(),
       _configuration = configuration ?? (() async => const EngineConfiguration());

  final UciDriver _driver;
  final Future<EngineConfiguration> Function() _configuration;
  EngineConfiguration _activeConfiguration = const EngineConfiguration();
  final Duration stopTimeout;
  final Duration idleTimeout;
  StreamSubscription<String>? _sub;
  StreamController<EngineEval>? _current;
  bool _running = false;
  bool _searching = false;
  bool _suspended = false;
  Completer<void>? _bestmove;
  Future<void> _queue = Future.value();
  Timer? _idle;
  (int, int, int)? _options;

  @override
  String get name => _activeConfiguration.name;

  Future<void> _enqueue(Future<void> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.catchError((Object _) {});
    return result;
  }

  void setForeground(bool foreground) {
    if (_suspended == !foreground) return;
    _suspended = !foreground;
    if (_suspended) unawaited(shutdown());
  }

  Future<void> _quit() async {
    _idle?.cancel();
    await _sub?.cancel();
    _sub = null;
    if (_running) {
      // Do not start another native engine until the old one has exited.
      await _driver.quit();
      _running = false;
    }
    _searching = false;
    _bestmove = null;
    _options = null;
  }

  void _releaseWhenIdle() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, () {
      unawaited(
        _enqueue(() async {
          if (_current == null && !_searching) await _quit();
        }),
      );
    });
  }

  Future<void> _stopSearch() async {
    if (!_searching) return;
    final completion = _bestmove!;
    _driver.send('stop');
    try {
      await completion.future.timeout(stopTimeout);
    } on TimeoutException {
      // readyok does not mean a previous search has stopped. Restart rather
      // than ever attributing its late info/bestmove to the next position.
      await _quit();
    }
    _searching = false;
  }

  @override
  Stream<EngineEval> analyze(String fen, EngineOptions options) {
    final controller = StreamController<EngineEval>();
    controller.onListen = () {
      final previous = _current;
      _current = controller;
      _idle?.cancel();
      unawaited(previous?.close());
      unawaited(
        _enqueue(() async {
          try {
            await _run(fen, options, controller);
          } catch (e, st) {
            await _quit();
            if (!controller.isClosed) {
              controller.addError(e, st);
              unawaited(controller.close());
            }
            if (_current == controller) _current = null;
          }
        }),
      );
    };
    controller.onCancel = () {
      if (_current != controller) return;
      _current = null;
      unawaited(
        _enqueue(() async {
          await _stopSearch();
          _releaseWhenIdle();
        }),
      );
    };
    return controller.stream;
  }

  bool _owns(StreamController<EngineEval> controller) => !_suspended && _current == controller && !controller.isClosed;

  Future<void> _run(String fen, EngineOptions options, StreamController<EngineEval> controller) async {
    if (!_owns(controller)) {
      if (_current == controller) _current = null;
      unawaited(controller.close());
      return;
    }
    await _stopSearch();
    if (!_owns(controller)) return;
    final normalizedFen = stockfishFen(fen);
    final configuration = await _configuration();
    if (!_owns(controller)) return;
    if (configuration != _activeConfiguration) await _quit();
    _activeConfiguration = configuration;
    if (!_running) {
      await _driver.start(configuration: configuration);
      _running = true;
    }
    if (!_owns(controller)) {
      _releaseWhenIdle();
      return;
    }
    await _sub?.cancel();
    final whiteToMove = fen.split(' ')[1] == 'w';
    final lines = <int, PvLine>{};
    var depth = 0;
    var nodes = 0;
    var nps = 0;
    final ready = Completer<void>();
    final elapsed = Stopwatch()..start();
    var lastEmission = -100;
    void emit({bool done = false}) {
      if (!_owns(controller)) return;
      if (!done && elapsed.elapsedMilliseconds - lastEmission < 100) return;
      lastEmission = elapsed.elapsedMilliseconds;
      final sorted = lines.values.toList()..sort((a, b) => a.multipv.compareTo(b.multipv));
      controller.add(EngineEval(fen: fen, depth: depth, lines: sorted, nodes: nodes, nps: nps, done: done));
    }

    void failed(Object error) {
      if (!_owns(controller)) return;
      controller.addError(error);
      _current = null;
      unawaited(controller.close());
      if (!ready.isCompleted) ready.completeError(error);
      if (_bestmove != null && !_bestmove!.isCompleted) _bestmove!.complete();
      _searching = false;
      unawaited(_enqueue(_quit));
    }

    _sub = _driver.output.listen(
      (line) {
        if (line.contains('CRITICAL ERROR')) {
          failed(StateError('Stockfish rejected the command'));
          return;
        }
        if (line.trim() == 'readyok') {
          if (!ready.isCompleted) ready.complete();
          return;
        }
        if (line.startsWith('bestmove')) {
          if (_bestmove != null && !_bestmove!.isCompleted) _bestmove!.complete();
          _searching = false;
          emit(done: true);
          if (_current == controller) _current = null;
          unawaited(controller.close());
          _releaseWhenIdle();
          return;
        }
        if (!ready.isCompleted || !_searching || !_owns(controller)) return;
        final pv = parseInfoLine(line, whiteToMove: whiteToMove);
        if (pv == null) return;
        depth = math.max(depth, _infoInt(line, 'depth') ?? depth);
        nodes = _infoInt(line, 'nodes') ?? nodes;
        nps = _infoInt(line, 'nps') ?? nps;
        lines[pv.multipv] = pv;
        emit();
      },
      onError: failed,
      onDone: () => failed(StateError('Stockfish exited')),
    );
    final config = (options.effectiveThreads, options.effectiveHash, options.multiPv.clamp(1, 5));
    if (_options?.$1 != config.$1) _driver.send('setoption name Threads value ${config.$1}');
    if (_options?.$2 != config.$2) _driver.send('setoption name Hash value ${config.$2}');
    if (_options?.$3 != config.$3) _driver.send('setoption name MultiPV value ${config.$3}');
    _options = config;
    _driver.send('isready');
    await ready.future.timeout(const Duration(seconds: 5));
    if (!_owns(controller)) return;
    _driver.send('position fen $normalizedFen');
    _bestmove = Completer<void>();
    _searching = true;
    _driver.send(goCommand(options));
  }

  @override
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1}) => analyze(
    fen,
    EngineOptions(threads: 2, hashMb: 32, multiPv: multiPv, depth: depth, movetime: const Duration(seconds: 8)),
  ).firstWhere((e) => e.done, orElse: () => throw const EngineCancelled());

  @override
  Future<void> stop() {
    final controller = _current;
    _current = null;
    // close can wait for a paused or unlistened stream. Never await it before stop.
    unawaited(controller?.close());
    return _enqueue(() async {
      await _stopSearch();
      _releaseWhenIdle();
    });
  }

  @override
  Future<void> shutdown() {
    final controller = _current;
    _current = null;
    _idle?.cancel();
    unawaited(controller?.close());
    return _enqueue(() async {
      await _stopSearch();
      await _quit();
    });
  }
}
