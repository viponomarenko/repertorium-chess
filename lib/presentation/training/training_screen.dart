import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/sound_service.dart';
import '../../data/db/database.dart';
import '../../data/engine/engine_service.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/srs/fsrs.dart';
import '../../domain/training/opponent_strategy.dart';
import '../../domain/training/training_engine.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/board_layout.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/engine_panel.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';
import '../widgets/spoken.dart';
import 'training_args.dart';

enum _Feedback { none, correct, wrong, alternative, demo }

/// Room under the board for the feedback card and its button, on top of
/// what every board screen keeps.
const double _feedbackRoom = 40;

/// The progress line under the app bar.
const double _progressHeight = 4;

/// The summary reads as one narrow column, also on a tablet.
const double _summaryWidth = 480;

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key, required this.args});
  final TrainingArgs args;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> with WidgetsBindingObserver {
  /// The part of the session being played (see [TrainingArgs.staged]).
  int _stageIndex = 0;
  late final List<TrainingStage> _stages = widget.args.allStages;
  TrainingStage get _stage => _stages[_stageIndex];
  TrainingMode get _mode => _stage.mode;
  List<int> get _ids => _stage.repertoireIds;

  /// What was already answered when the current part began: the progress
  /// in the header counts the part, not the whole session.
  int _baseReviewed = 0, _baseIntroduced = 0, _baseLines = 0;

  /// The next part has just begun: say so once its first line starts.
  bool _announceStage = false;
  List<RepertoireSummary> _summaries = const [];

  int _repIndex = 0;
  RepertoireRow? _row;
  TrainingEngine? _engine;
  Position? _position;
  Move? _lastMove;
  bool _loading = true;
  bool _animating = false;
  TrainingStep? _step;
  _Feedback _feedback = _Feedback.none;
  String _message = '';
  String _comment = '';
  HintInfo? _hint;
  bool _revealed = false;
  Square? _markSquare;
  bool _markGood = true;
  final Stopwatch _sw = Stopwatch();

  /// Time actually spent training: stops in the background and while a
  /// sheet is open, so the minutes limit and the summary do not count it.
  final Stopwatch _session = Stopwatch()..start();

  /// True once the user answered anything (leaving before that needs no
  /// confirmation).
  bool _answered = false;
  int _remainingNew = 0;
  int _remainingReviews = 0;
  final SessionSummary _total = SessionSummary();
  bool _allDone = false;
  int? _maxLines;
  int? _maxMinutes;
  Future<void> _writes = Future.value();
  bool _writeErrorShown = false;
  Object? _loadError;

  /// Expected number of answers in this session (for the progress bar);
  /// null when unknown.
  int? _planned;
  late final RefreshTick _refresh;

  /// Frozen when the session ends (the summary must not keep counting).
  Duration? _elapsed;

  /// True while [_advance] runs; guards against double taps on "Next line".
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _refresh = ref.read(refreshTickProvider.notifier);
    _maxLines = widget.args.maxLines;
    _maxMinutes = widget.args.maxMinutes;
    unawaited(WakelockPlus.enable().catchError((_) {}));
    WidgetsBinding.instance.addObserver(this);
    unawaited(_init());
  }

  bool _clockWasRunning = false;

  /// The answer clock does not run while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_clockWasRunning) _sw.start();
      _clockWasRunning = false;
      if (!_allDone) _session.start();
    } else {
      _session.stop();
      if (_sw.isRunning) {
        _clockWasRunning = true;
        _sw.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable().catchError((_) {}));
    // Refresh Today's counters only after the last answers are written,
    // and not synchronously inside dispose (providers are locked there).
    final refresh = _refresh;
    unawaited(_writes.whenComplete(refresh.bump));
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _prepare();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loadError = null;
      _loading = true;
    });
    await _init();
  }

  Future<void> _prepare() async {
    final repo = ref.read(repertoireRepositoryProvider);
    final fsrs = ref.read(fsrsProvider);
    final s = ref.read(settingsProvider);
    final dayStart = fsrs.dayStart(DateTime.now());
    final introduced = await repo.introducedSince(dayStart);
    final reviewed = await repo.reviewsSince(dayStart);
    _remainingNew = (s.newPerDay - introduced).clamp(0, 100000);
    _remainingReviews = (s.reviewsPerDay - reviewed).clamp(0, 100000);
    // Read from the database, not from repertoiresProvider: that stream is
    // rebuilt on every refresh tick, and a read racing a rebuild could wait
    // forever (an endless spinner at the start of a session).
    _summaries = await repo.watchSummaries().first.timeout(const Duration(seconds: 10));
    final all = widget.args.allRepertoireIds.toSet();
    _newAvailable = _summaries.where((x) => all.contains(x.row.id)).fold<int>(0, (a, x) => a + x.newCards);
    _planStage();
    await _loadRepertoire();
  }

  /// What the current part of the session plans to ask (for the progress
  /// bar), and where the counters stood when it began.
  void _planStage() {
    final ids = _ids.toSet();
    final sums = _summaries.where((x) => ids.contains(x.row.id));
    _planned = switch (_mode) {
      TrainingMode.review when widget.args.startKey == null => math.min(
        _remainingReviews,
        sums.fold<int>(0, (a, x) => a + x.due),
      ),
      TrainingMode.learn when widget.args.startKey == null => math.min(
        _remainingNew,
        sums.fold<int>(0, (a, x) => a + x.newCards),
      ),
      TrainingMode.problems when _stages.length > 1 => _stage.problemKeys.values.fold<int>(0, (a, k) => a + k.length),
      _ => null,
    };
    _baseReviewed = _total.reviewed;
    _baseIntroduced = _total.introduced;
    _baseLines = _total.lines;
  }

  /// New moves in the trained repertoires (for "Learn new lines").
  int _newAvailable = 0;

  /// Done / planned for the progress bar. Drill and problems count lines
  /// against the session limit chosen now (it can change mid-session).
  (int, int)? get _progress {
    final planned = _planned ?? _maxLines;
    if (planned == null || planned <= 0) return null;
    final cur = _engine?.summary;
    final done = switch (_mode) {
      TrainingMode.review when widget.args.startKey == null => _total.reviewed - _baseReviewed + (cur?.reviewed ?? 0),
      TrainingMode.learn when widget.args.startKey == null =>
        _total.introduced - _baseIntroduced + (cur?.introduced ?? 0),
      _ => _total.lines - _baseLines + (cur?.lines ?? 0),
    };
    return (math.min(done, planned), planned);
  }

  void _onWriteError() {
    if (_writeErrorShown || !mounted) return;
    _writeErrorShown = true;
    showSnack(context, context.l10n.reviewSaveFailed);
  }

  Future<void> _loadRepertoire() async {
    try {
      if (await _loadRepertoireUnsafe()) unawaited(_advance());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  /// Loads the next repertoire that has something to train. Returns false
  /// when there is none (the session is then finished). The caller runs
  /// [_advance]: starting it here would be swallowed by its re-entrancy
  /// guard when this is called from inside [_advanceSteps].
  Future<bool> _loadRepertoireUnsafe() async {
    if (!mounted) return false;
    setState(() => _loading = true);
    final repo = ref.read(repertoireRepositoryProvider);
    final fsrs = ref.read(fsrsProvider);
    final s = ref.read(settingsProvider);
    while (true) {
      if (_repIndex >= _ids.length) {
        // This part of the session is done: on to the next one, if any.
        if (_stageIndex >= _stages.length - 1) break;
        _stageIndex++;
        _repIndex = 0;
        _planStage();
        _announceStage = true;
        continue;
      }
      final id = _ids[_repIndex];
      final row = await repo.repertoire(id);
      if (row == null) {
        _repIndex++;
        continue;
      }
      final graph = await repo.loadGraph(id);
      if (!mounted) return false;
      final opts = RepertoireOptions.decode(row.optionsJson);
      final mode = _mode;
      final engine = TrainingEngine(
        graph: graph,
        fsrs: fsrs,
        config: TrainingConfig(
          mode: mode,
          startKey: _ids.length == 1 ? widget.args.startKey : null,
          // Due-first only makes sense in Review; other modes use weights.
          strategy: opts.strategy ?? (mode == TrainingMode.review ? s.defaultStrategy : OpponentStrategy.weighted),
          acceptAlternatives: opts.acceptAlternatives ?? s.acceptAlternatives,
          mistakesBeforeReveal: s.mistakesBeforeReveal,
          autoplayToTarget: s.autoplayToDue,
          drillAffectsSchedule: s.drillAffectsSchedule,
          newLimit: _remainingNew,
          reviewLimit: _remainingReviews,
          problemKeys: _stage.problemKeys[id] ?? const [],
          grading: s.grading,
        ),
        onReview: (e) {
          _writes = _writes.then((_) => repo.recordReview(id, e)).catchError((_) => _onWriteError());
        },
      );
      _row = row;
      _engine = engine;
      _position = engine.startNextLine() ? engine.position : null;
      if (_position == null) {
        _accumulate(engine.summary);
        _repIndex++;
        continue;
      }
      if (_announceStage) {
        _announceStage = false;
        showSnack(context, context.l10n.nextStage(modeTitle(_mode, context.l10n)));
      }
      setState(() {
        _loading = false;
        _lastMove = null;
      });
      return true;
    }
    await _finishSession();
    return false;
  }

  /// Ends the session: waits for the answers to be written, refreshes
  /// Today's counters and freezes the session time for the summary.
  Future<void> _finishSession() async {
    _session.stop();
    _elapsed ??= _session.elapsed;
    await _writes;
    if (!mounted) return;
    _refresh.bump();
    setState(() {
      _engine = null;
      _loading = false;
      _allDone = true;
    });
  }

  void _accumulate(SessionSummary s) {
    _total.lines += s.lines;
    _total.reviewed += s.reviewed;
    _total.introduced += s.introduced;
    _total.mistakes += s.mistakes;
    for (final g in Grade.values) {
      _total.grades[g] = (_total.grades[g] ?? 0) + (s.grades[g] ?? 0);
    }
    _remainingNew = (_remainingNew - s.introduced).clamp(0, 100000);
    _remainingReviews = (_remainingReviews - s.reviewed).clamp(0, 100000);
  }

  bool get _limitReached {
    if (_maxLines != null && _total.lines + (_engine?.summary.lines ?? 0) >= _maxLines!) return true;
    if (_maxMinutes != null && _session.elapsed.inMinutes >= _maxMinutes!) return true;
    return false;
  }

  void _syncBoard() {
    final e = _engine!;
    _position = e.position;
    final last = e.line.isEmpty ? null : e.line.last;
    _lastMove = last == null ? null : Move.parse(last.uci);
  }

  void _announce(String san, {bool opponent = false}) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(View.of(context), spokenSan(san, context.l10n), Directionality.of(context));
  }

  /// Runs automatic steps until the user must act.
  Future<void> _advance() async {
    if (_advancing) return;
    _advancing = true;
    try {
      await _advanceSteps();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e;
        });
      }
    } finally {
      _advancing = false;
    }
  }

  Future<void> _advanceSteps() async {
    final first = _engine;
    if (first == null || !mounted) return;
    var e = first;
    final s = ref.read(settingsProvider);
    final sound = ref.read(soundServiceProvider);
    while (mounted) {
      final step = e.next();
      switch (step) {
        case AutoMove(:final move, :final fast):
          _animating = true;
          await Future<void>.delayed(fast ? TrainingPace.fastMove : Duration(milliseconds: s.opponentDelayMs));
          if (!mounted) return;
          setState(() {
            _syncBoard();
            _hint = null;
            _markSquare = null;
          });
          unawaited(sound.play(move.san.contains('x') ? GameSound.capture : GameSound.move));
          _announce(move.san, opponent: true);
          await Future<void>.delayed(fast ? TrainingPace.fastSettle : Duration(milliseconds: s.animationMs));
          _animating = false;
          continue;
        case RecallStart():
          setState(() {
            _step = step;
            _message = context.l10n.recallStart;
            _comment = '';
            _feedback = _Feedback.none;
          });
          await Future<void>.delayed(TrainingPace.recallIntro);
          if (!mounted) return;
          setState(_syncBoard);
          continue;
        case AwaitUser(:final demo, :final expected):
          setState(() {
            _step = step;
            _syncBoard();
            _hint = null;
            _revealed = false;
            _feedback = demo ? _Feedback.demo : _Feedback.none;
            _message = demo
                ? context.l10n.demoMessage
                : (step.isDue ? context.l10n.yourMoveDue : context.l10n.yourMove);
            _comment = demo && s.showComments ? expected.comment : '';
          });
          _sw
            ..reset()
            ..start();
          return;
        case LineComplete():
          unawaited(sound.play(GameSound.line));
          setState(() {
            _step = step;
            _syncBoard();
            _hint = null;
          });
          return;
        case SessionComplete(:final summary):
          _accumulate(summary);
          _repIndex++;
          _engine = null;
          // The next repertoire of the session continues in this loop.
          if (!await _loadRepertoireUnsafe()) return;
          e = _engine!;
          continue;
      }
    }
  }

  void _onMove(Move move) {
    final e = _engine;
    final step = _step;
    if (e == null || step is! AwaitUser || _animating) return;
    final l = context.l10n;
    final s = ref.read(settingsProvider);
    final sound = ref.read(soundServiceProvider);
    _sw.stop();
    final r = e.submitMove(move, responseTime: _sw.elapsed);
    _answered = true;
    final norm = normalizeMove(_position!, move);
    final dest = Move.parse(standardUci(_position!, norm))?.to;
    switch (r.verdict) {
      case MoveVerdict.correct:
      case MoveVerdict.alternativeAccepted:
        unawaited(sound.play(GameSound.success));
        setState(() {
          _syncBoard();
          _feedback = _Feedback.correct;
          _markSquare = dest;
          _markGood = true;
          _hint = null;
          _message = r.verdict == MoveVerdict.alternativeAccepted
              ? l.alternativeAccepted
              : switch (r.grade) {
                  null => l.correct,
                  Grade.again => l.correctAgain,
                  Grade.hard => l.correctHard(s.grading.goodThreshold.inSeconds),
                  Grade.good => l.correctGood,
                  Grade.easy => l.correctEasy,
                };
          _comment = s.showComments ? r.comment : '';
          _step = null;
        });
        _announce(r.played?.san ?? '');
        unawaited(
          Future<void>.delayed(_comment.isEmpty ? TrainingPace.afterAnswer : TrainingPace.afterComment).then((_) {
            if (mounted) _advance();
          }),
        );
      case MoveVerdict.alternativeRejected:
        unawaited(sound.play(GameSound.move));
        setState(() {
          _feedback = _Feedback.alternative;
          _message = l.alternativeRejected(r.played?.san ?? '');
        });
        _sw.start();
      case MoveVerdict.wrong:
        unawaited(sound.play(GameSound.error));
        setState(() {
          _feedback = _Feedback.wrong;
          _markSquare = dest;
          _markGood = false;
          _revealed = r.reveal;
          _message = step.demo ? l.repeatShownMove : (r.reveal ? l.wrongRevealed : l.wrongTryAgain(e.attempts));
        });
        _sw.start();
    }
  }

  void _requestHint() {
    final h = _engine?.requestHint();
    if (h == null) return;
    setState(() {
      _hint = h;
      _message = context.l10n.hintLevel(h.level);
    });
  }

  void _reveal() {
    _engine?.reveal();
    setState(() {
      _revealed = true;
      _message = context.l10n.wrongRevealed;
    });
  }

  Set<Shape> _shapes() {
    final shapes = <Shape>{};
    final step = _step;
    final pos = _position;
    if (step is AwaitUser && pos != null) {
      final exp = Move.parse(step.expected.uci);
      if (exp is NormalMove) {
        final showArrow = step.demo || _revealed || (_hint?.level ?? 0) >= 3;
        if (showArrow) {
          shapes.add(Arrow(color: BoardColors.mainMove, orig: exp.from, dest: exp.to));
        } else if (_hint != null) {
          if (_hint!.from != null) shapes.add(Circle(color: BoardColors.mainMove, orig: _hint!.from!));
          if (_hint!.level >= 2) shapes.add(Circle(color: BoardColors.blue, orig: _hint!.to));
        }
      }
    }
    return shapes;
  }

  Map<Square, Annotation> _annotations() {
    if (_markSquare == null) return const {};
    final cs = Theme.of(context).colorScheme;
    return {
      _markSquare!: Annotation(
        symbol: _markGood ? '✓' : '✗',
        color: _markGood ? cs.markCorrect : cs.markWrong,
        duration: TrainingPace.mark,
      ),
    };
  }

  /// The last move made by the user in the current line.
  LineMove? get _lastUserMove {
    final e = _engine;
    if (e == null) return null;
    for (final m in e.line.reversed) {
      if (m.byUser && !m.auto) return m;
    }
    return null;
  }

  Future<void> _why([LineMove? move]) async {
    final e = _engine;
    if (e == null || e.line.isEmpty) return;
    final last = move ?? _lastUserMove ?? e.line.last;
    final book = ref.read(openingBookProvider).value;
    final keys = [e.startKey, for (final m in e.line) positionKeyOf(positionFromFen(m.fenBefore))];
    final opening = book?.deepest(keys);
    await _pausingClock(
      () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => _WhySheet(move: last, openingName: opening == null ? null : '${opening.eco} ${opening.name}'),
      ),
    );
  }

  /// Time spent reading a sheet must not count as thinking time (grading
  /// uses the response time).
  Future<T> _pausingClock<T>(Future<T> Function() f) async {
    final running = _sw.isRunning;
    _sw.stop();
    _session.stop();
    try {
      return await f();
    } finally {
      if (mounted && !_allDone) _session.start();
      if (running && mounted) _sw.start();
    }
  }

  Future<void> _sessionSettings() async {
    final l = context.l10n;
    await _pausingClock(
      () => showAppSheet<void>(
        context,
        title: l.sessionSettings,
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final s = ref.watch(settingsProvider);
            final n = ref.read(settingsProvider.notifier);
            return StatefulBuilder(
              builder: (ctx, set) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    value: s.autoplayToDue,
                    title: Text(l.autoplayToDue),
                    subtitle: Text(l.autoplayToDueHint),
                    onChanged: (v) {
                      n.update((x) => x.copyWith(autoplayToDue: v));
                      _engine?.autoplay = v;
                    },
                  ),
                  SwitchListTile(
                    value: s.showComments,
                    title: Text(l.showComments),
                    onChanged: (v) => n.update((x) => x.copyWith(showComments: v)),
                  ),
                  SwitchListTile(
                    value: s.sound,
                    title: Text(l.sound),
                    onChanged: (v) => n.update((x) => x.copyWith(sound: v)),
                  ),
                  ListTile(
                    title: Text(l.animationSpeed),
                    subtitle: Slider(
                      value: s.animationMs.toDouble(),
                      min: 0,
                      max: 600,
                      divisions: 6,
                      label: l.unitMs('${s.animationMs}'),
                      onChanged: (v) => n.update((x) => x.copyWith(animationMs: v.round())),
                    ),
                  ),
                  ListTile(
                    title: Text(l.sessionLimit),
                    subtitle: Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final (label, lines, mins) in [
                          (l.noLimit, null, null),
                          (l.linesN(5), 5, null),
                          (l.linesN(10), 10, null),
                          (l.minutesN(5), null, 5),
                          (l.minutesN(15), null, 15),
                        ])
                          ChoiceChip(
                            label: Text(label),
                            selected: _maxLines == lines && _maxMinutes == mins,
                            onSelected: (_) => set(() {
                              setState(() {
                                _maxLines = lines;
                                _maxMinutes = mins;
                              });
                            }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _typeMove() async {
    final pos = _position;
    if (pos == null) return;
    final move = await showDialog<Move>(
      context: context,
      builder: (_) => _TypeMoveDialog(position: pos),
    );
    if (move != null && mounted) _onMove(move);
  }

  void _nextLine() {
    final e = _engine;
    if (e == null || _advancing || _step is! LineComplete) return;
    if (_limitReached) {
      // Clearing the step makes a second tap a no-op: the totals must not
      // be added twice while the answers are still being written.
      setState(() => _step = null);
      _accumulate(e.summary);
      unawaited(_finishSession());
      return;
    }
    // The engine keeps reporting the finished line until it is told to
    // start the next one; when there is none, next() ends the session.
    e.startNextLine();
    setState(() {
      _step = null;
      _feedback = _Feedback.none;
      _message = '';
      _comment = '';
      _markSquare = null;
    });
    unawaited(_advance());
  }

  /// Whether "Next line" would end the session (the button then says so).
  /// Unknown while other repertoires of the session are still ahead.
  bool get _isLastLine {
    final e = _engine;
    if (e == null) return false;
    if (_limitReached) return true;
    return _stageIndex >= _stages.length - 1 && _repIndex >= _ids.length - 1 && !e.hasNextLine;
  }

  Future<bool> _confirmExit() async {
    if (_allDone || _engine == null || !_answered) return true;
    final l = context.l10n;
    return confirm(context, title: l.exitTrainingQ, message: l.exitTrainingMessage, confirmLabel: l.exit);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final modeName = modeTitle(_mode, l);
    final progress = _progress;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // The mode, and the repertoire under it: one line cut both.
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(modeName, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_row != null && !_allDone)
                Text(_row!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.meta),
            ],
          ),
          bottom: progress == null || _allDone
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(_progressHeight),
                  child: Semantics(
                    label: l.progressOf(progress.$1, progress.$2),
                    child: AnimatedFraction(
                      value: progress.$1 / progress.$2,
                      builder: (_, v) => LinearProgressIndicator(value: v, minHeight: _progressHeight),
                    ),
                  ),
                ),
          actions: [
            if (_engine != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Center(
                  child: Text(
                    progress != null
                        ? l.progressOf(progress.$1, progress.$2)
                        : _mode == TrainingMode.learn
                        ? l.progressLearn(_total.introduced + _engine!.summary.introduced)
                        : l.lineNumber(_total.lines + _engine!.summary.lines + (_step is LineComplete ? 0 : 1)),
                    style: Theme.of(context).textTheme.labelLarge?.tabular,
                  ),
                ),
              ),
            IconButton(tooltip: l.sessionSettings, onPressed: _sessionSettings, icon: const Icon(AppIcons.options)),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : _loadError != null
            ? ErrorState(message: l.somethingWentWrong, details: '$_loadError', onRetry: _retry)
            : _allDone
            ? _Summary(
                total: _total,
                elapsed: _elapsed ?? _session.elapsed,
                reason: _nothingReason(l),
                onClose: () => context.pop(),
                onExtra: () => context.pushReplacement(
                  '/train',
                  extra: TrainingArgs(
                    repertoireIds: widget.args.allRepertoireIds,
                    mode: TrainingMode.drill,
                    maxLines: 5,
                  ),
                ),
                onLearn: _remainingNew > 0 && _newLeftAfter > 0
                    ? () => context.pushReplacement(
                        '/train',
                        extra: TrainingArgs(repertoireIds: widget.args.allRepertoireIds, mode: TrainingMode.learn),
                      )
                    : null,
              )
            : _trainingBody(context),
      ),
    );
  }

  /// Why there was nothing to train (shown instead of a summary).
  /// New moves still unlearned after this session.
  int get _newLeftAfter => _newAvailable - _total.introduced;

  String _nothingReason(AppLocalizations l) => switch (_mode) {
    TrainingMode.review when _remainingReviews == 0 => l.reviewLimitReached,
    TrainingMode.learn when _remainingNew == 0 => l.newLimitReached,
    _ => l.nothingDueHint,
  };

  Widget _trainingBody(BuildContext context) {
    final l = context.l10n;
    final e = _engine!;
    final step = _step;
    final awaiting = step is AwaitUser;
    final board = BoardView(
      position: _position!,
      orientation: e.orientation,
      lastMove: _lastMove,
      playerSide: awaiting ? (e.orientation == Side.white ? PlayerSide.white : PlayerSide.black) : PlayerSide.none,
      onMove: _onMove,
      shapes: _shapes(),
      annotations: _annotations(),
      semanticsLabel: l.boardLabel,
    );
    final panel = step is LineComplete
        ? _LineSummary(
            summary: step.summary,
            last: _isLastLine,
            onNext: _nextLine,
            onWhy: _why,
            engineWhy: ref.watch(settingsProvider).engineInTraining,
          )
        : _statusPanel(context, awaiting);
    // Same board geometry as every other screen with a board (D-052); a
    // little more room under it for the feedback card and its button.
    return SafeArea(
      child: BoardLayout(board: board, extraBelow: (_) => _feedbackRoom, below: (context, g) => panel),
    );
  }

  Widget _statusPanel(BuildContext context, bool awaiting) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final lastUser = _lastUserMove;
    final (bg, fg, icon) = switch (_feedback) {
      _Feedback.correct => (theme.colorScheme.successContainer, theme.colorScheme.success, AppIcons.okFilled),
      _Feedback.wrong => (theme.colorScheme.errorContainer, theme.colorScheme.onErrorContainer, AppIcons.wrong),
      _Feedback.alternative => (
        theme.colorScheme.secondaryContainer,
        theme.colorScheme.onSecondaryContainer,
        AppIcons.alternativeMove,
      ),
      _Feedback.demo => (theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer, AppIcons.show),
      _Feedback.none => (theme.colorScheme.surfaceContainerHigh, theme.colorScheme.onSurface, AppIcons.yourMove),
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Semantics(
          liveRegion: true,
          // A wrong answer shakes the card; the verdict's icon pops in; a
          // comment opens the card smoothly (D-077).
          child: Shake(
            trigger: _feedback == _Feedback.wrong ? _message : null,
            child: AnimatedContainer(
              duration: AppMotion.of(context).base,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
              child: AnimatedSize(
                duration: AppMotion.of(context).base,
                curve: AppMotion.standard,
                alignment: Alignment.topLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PopIn(
                          trigger: _feedback,
                          child: Icon(icon, color: fg),
                        ),
                        AppGap.h12,
                        Expanded(
                          child: MovesText(_message, style: context.tt.title.copyWith(color: fg)),
                        ),
                      ],
                    ),
                    if (_comment.isNotEmpty) ...[
                      AppGap.v8,
                      MovesText(_comment, style: context.tt.comment.copyWith(color: fg)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        AppGap.v12,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: [
            if (awaiting && !(_step as AwaitUser).demo) ...[
              OutlinedButton.icon(
                onPressed: (_hint?.level ?? 0) >= 3 || _revealed ? null : _requestHint,
                icon: const Icon(AppIcons.hint),
                label: Text(l.hint),
              ),
              OutlinedButton.icon(
                onPressed: _revealed ? null : _reveal,
                icon: const Icon(AppIcons.show),
                label: Text(l.showAnswer),
              ),
            ],
            if (awaiting)
              OutlinedButton.icon(onPressed: _typeMove, icon: const Icon(AppIcons.typeMove), label: Text(l.enterMove)),
          ],
        ),
        // The explanation of the previous move stays available until the
        // next answer (not only for a moment after it).
        if (lastUser != null) ...[
          AppGap.v4,
          Center(
            child: TextButton.icon(
              onPressed: () => _why(lastUser),
              icon: const Icon(AppIcons.help),
              label: MovesText(l.whyMove(lastUser.san)),
            ),
          ),
        ],
        if (awaiting && (_step as AwaitUser).isNewCard && !(_step as AwaitUser).demo)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(l.newCardRecall, textAlign: TextAlign.center, style: context.tt.meta),
          ),
      ],
    );
  }
}

String modeTitle(TrainingMode m, AppLocalizations l) => switch (m) {
  TrainingMode.learn => l.modeLearn,
  TrainingMode.review => l.modeReview,
  TrainingMode.drill => l.modeDrill,
  TrainingMode.problems => l.modeProblems,
};

String gradeName(Grade g, AppLocalizations l) => switch (g) {
  Grade.again => l.gradeAgain,
  Grade.hard => l.gradeHard,
  Grade.good => l.gradeGood,
  Grade.easy => l.gradeEasy,
};

class _LineSummary extends StatelessWidget {
  const _LineSummary({
    required this.summary,
    required this.last,
    required this.onNext,
    required this.onWhy,
    required this.engineWhy,
  });
  final LineSummary summary;

  /// No line follows: the button ends the session.
  final bool last;
  final VoidCallback onNext;
  final void Function(LineMove move) onWhy;
  final bool engineWhy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final perfect = summary.mistakes == 0 && summary.moves.every((m) => !m.hinted);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Icon(
              perfect ? AppIcons.trophy : AppIcons.flagFilled,
              color: perfect ? theme.colorScheme.warning : theme.colorScheme.primary,
            ),
            AppGap.h8,
            Expanded(
              child: Text(
                perfect ? l.lineCompletePerfect : l.lineCompleteMistakes(summary.mistakes),
                style: context.tt.title,
              ),
            ),
          ],
        ),
        AppGap.v12,
        FilledButton.icon(
          style: AppButtonSize.large,
          onPressed: onNext,
          icon: Icon(last ? AppIcons.check : AppIcons.nextGame),
          label: Text(last ? l.finishSession : l.nextLine),
        ),
        AppGap.v8,
        AppExpansionTile(
          title: Text(l.showLine),
          initiallyExpanded: !perfect,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.tapMoveForWhy, style: context.tt.meta),
                  AppGap.v8,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [for (final m in summary.moves) _LineMoveChip(m, onTap: () => onWhy(m))],
                  ),
                ],
              ),
            ),
            for (final m in summary.moves.where((m) => m.comment.isNotEmpty))
              ListTile(
                title: MovesText(m.san, style: context.tt.moveMain),
                subtitle: MovesText(m.comment, style: context.tt.comment),
                onTap: () => onWhy(m),
              ),
          ],
        ),
      ],
    );
  }
}

class _LineMoveChip extends StatelessWidget {
  const _LineMoveChip(this.m, {required this.onTap});
  final LineMove m;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final pos = positionFromFen(m.fenBefore);
    final label = pos.turn == Side.white ? '${pos.fullmoves}. ${m.san}' : m.san;
    Color? bg;
    Color? fg;
    IconData? icon;
    String? tip;
    if (m.byUser && !m.auto) {
      if (m.mistakes > 0) {
        (bg, fg, icon, tip) = (cs.errorContainer, cs.onErrorContainer, AppIcons.close, null);
      } else if (m.hinted) {
        (bg, fg, icon, tip) = (cs.warningContainer, cs.onWarningContainer, AppIcons.hint, l.hintUsed);
      } else {
        (bg, fg, icon, tip) = (cs.successContainer, cs.onSuccessContainer, AppIcons.check, null);
      }
    }
    final chip = ActionChip(
      backgroundColor: bg,
      avatar: icon == null ? null : Icon(icon, size: AppSizes.iconSm, color: fg),
      label: MoveLineText(label, color: fg),
      onPressed: onTap,
    );
    return tip == null ? chip : Tooltip(message: tip, child: chip);
  }
}

class _WhySheet extends ConsumerStatefulWidget {
  const _WhySheet({required this.move, this.openingName});
  final LineMove move;
  final String? openingName;

  @override
  ConsumerState<_WhySheet> createState() => _WhySheetState();
}

class _WhySheetState extends ConsumerState<_WhySheet> {
  EngineEval? _eval;
  bool _running = false;
  late final EngineService _engine = ref.read(engineServiceProvider);

  Future<void> _runEngine() async {
    setState(() => _running = true);
    try {
      final e = await _engine.evaluate(widget.move.fenBefore, depth: 18, multiPv: 3);
      if (mounted) setState(() => _eval = e);
    } on EngineCancelled {
      // Backgrounding or closing the sheet is an intentional cancellation.
    } catch (_) {
      if (mounted) showSnack(context, context.l10n.engineError);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    if (_running) unawaited(_engine.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final m = widget.move;
    return SafeArea(
      child: Padding(
        padding: AppInsets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MovesText(l.whyTitle(m.san), style: theme.textTheme.titleLarge),
            if (widget.openingName != null) ...[AppGap.v4, Text(widget.openingName!, style: context.tt.meta)],
            AppGap.v12,
            MovesText(
              m.comment.isEmpty ? l.noCommentYet : m.comment,
              style: m.comment.isEmpty ? context.tt.comment : theme.textTheme.bodyLarge,
            ),
            AppGap.v16,
            if (_eval == null)
              OutlinedButton.icon(
                onPressed: _running ? null : _runEngine,
                icon: _running ? const InlineSpinner() : const Icon(AppIcons.engine),
                label: Text(l.engineOpinion),
              )
            else ...[
              Text(l.engineDepth(_eval!.depth), style: theme.textTheme.labelLarge),
              for (final line in _eval!.lines)
                ListTile(
                  dense: true,
                  leading: Text(
                    context.fmtEval(cp: line.cp, mate: line.mate),
                    style: theme.textTheme.titleSmall?.tabular,
                  ),
                  title: MovesText(uciLineToSan(m.fenBefore, line.moves, max: 8).join(' ')),
                  trailing: line.moves.isNotEmpty && _sameMove(m, line.moves.first)
                      ? Icon(AppIcons.check, color: theme.colorScheme.success)
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _sameMove(LineMove m, String uci) {
    final pos = positionFromFen(m.fenBefore);
    final mv = parseUciMove(pos, uci);
    return mv != null && standardUci(pos, mv) == m.uci;
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    required this.total,
    required this.elapsed,
    required this.reason,
    required this.onClose,
    required this.onExtra,
    this.onLearn,
  });
  final SessionSummary total;
  final Duration elapsed;

  /// Shown when there was nothing to train.
  final String reason;
  final VoidCallback onClose;
  final VoidCallback onExtra;
  final VoidCallback? onLearn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final answers = total.grades.values.fold<int>(0, (a, b) => a + b);
    final correct = answers - (total.grades[Grade.again] ?? 0);
    final empty = answers == 0;
    final goal = ref.watch(settingsProvider.select((s) => s.dailyGoal));
    final today = ref.watch(todayCountProvider).value;
    final streak = ref.watch(streakProvider).value ?? 0;
    final seconds = elapsed.inSeconds % 60;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _summaryWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                empty ? AppIcons.ok : AppIcons.celebrate,
                size: AppSizes.iconHero,
                color: empty ? cs.onSurfaceVariant : cs.primary,
              ),
              AppGap.v12,
              Text(
                empty ? l.nothingToTrain : l.sessionDone,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (empty) ...[
                AppGap.v8,
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
              ] else ...[
                AppGap.v24,
                // Two centred rows: five tiles in a Wrap left the last one
                // alone on its own line.
                for (final row in [
                  [
                    StatTile(value: context.fmtInt(total.lines), label: l.statLines(total.lines)),
                    StatTile(value: '${context.fmtInt(correct)}/${context.fmtInt(answers)}', label: l.statCorrect),
                    StatTile(value: '${elapsed.inMinutes}:${seconds.toString().padLeft(2, '0')}', label: l.statTime),
                  ],
                  [
                    StatTile(value: context.fmtInt(total.reviewed), label: l.statReviewed),
                    StatTile(value: context.fmtInt(total.introduced), label: l.statIntroduced),
                  ],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final tile in row) Expanded(child: Center(child: tile))],
                    ),
                  ),
              ],
              if (today != null && !empty) ...[
                AppGap.v24,
                Container(
                  padding: AppInsets.strip,
                  decoration: BoxDecoration(
                    color: today >= goal ? cs.successContainer : cs.surfaceContainerHigh,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            today >= goal ? AppIcons.flagFilled : AppIcons.flag,
                            color: today >= goal ? cs.onSuccessContainer : cs.primary,
                          ),
                          AppGap.h12,
                          Expanded(
                            child: Text(
                              today >= goal ? l.goalReached : l.goalProgress(today, goal),
                              style: theme.textTheme.titleMedium?.tabular.copyWith(
                                color: today >= goal ? cs.onSuccessContainer : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (streak > 0) ...[
                        AppGap.v8,
                        Row(
                          children: [
                            Icon(AppIcons.streak, color: cs.warning),
                            AppGap.h12,
                            Expanded(child: Text(l.streakDays(streak), style: theme.textTheme.bodyMedium)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              AppGap.v32,
              FilledButton(style: AppButtonSize.large, onPressed: onClose, child: Text(l.done)),
              AppGap.v8,
              // One suggestion of what next, not a menu (D-065).
              if (onLearn != null)
                OutlinedButton.icon(
                  style: AppButtonSize.wide,
                  onPressed: onLearn,
                  icon: const Icon(AppIcons.learn),
                  label: Text(l.learnNewLines),
                )
              else
                OutlinedButton.icon(
                  style: AppButtonSize.wide,
                  onPressed: onExtra,
                  icon: const Icon(AppIcons.drill),
                  label: Text(l.extraPractice),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accessible move input (SAN in English or Ukrainian letters, UCI). Owns
/// its controller so it outlives the closing animation.
class _TypeMoveDialog extends StatefulWidget {
  const _TypeMoveDialog({required this.position});
  final Position position;

  @override
  State<_TypeMoveDialog> createState() => _TypeMoveDialogState();
}

class _TypeMoveDialogState extends State<_TypeMoveDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final m = parseTypedMove(widget.position, _ctrl.text);
    if (m == null) {
      setState(() => _error = context.l10n.illegalMove);
    } else {
      Navigator.pop(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.enterMove),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        // A Latin keyboard: squares are written a-h whatever the language
        // of the system keyboard is.
        keyboardType: TextInputType.visiblePassword,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: l.enterMoveHint, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(l.ok)),
      ],
    );
  }
}
