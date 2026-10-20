/// Solving the puzzles of one theme (D-123): the opponent's move is shown,
/// the player finds the best reply; a mistake or a shown solution counts
/// as a loss for the rating, as on Lichess.
library;

import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../core/sound_service.dart';
import '../../data/lichess/lichess_client.dart';
import '../../data/puzzles/puzzle_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/puzzles/glicko2.dart';
import '../../domain/puzzles/puzzle.dart';
import '../../domain/puzzles/puzzle_profile.dart';
import '../../domain/puzzles/puzzle_run.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/board_layout.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import 'puzzle_providers.dart';
import 'puzzle_theme_names.dart';

enum _Feedback { find, correct, wrong, solved, failed }

class PuzzleScreen extends ConsumerStatefulWidget {
  const PuzzleScreen({super.key, required this.angle});

  /// The theme (or `mix`).
  final String angle;

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  PuzzleFeed? _feed;

  /// The Lichess account results count for; null: the device's rating.
  String? _user;
  PuzzleProfile? _profile;

  /// Why the puzzle on the board came from the pack; null: from Lichess.
  PuzzleOffline? _packReason;
  PuzzleRun? _run;
  Object? _error;
  bool _loading = true;

  /// The opponent's setting move is still to be played.
  bool _intro = false;

  /// A shown solution is playing.
  bool _revealing = false;

  /// The solution was shown (not found).
  bool _solutionShown = false;
  _Feedback _feedback = _Feedback.find;

  /// Bumped on every wrong move, so the card shakes each time.
  int _wrongCount = 0;

  /// The result went into the rating: the change, or null when the puzzle
  /// had been played before.
  bool _recorded = false;
  int? _diff;

  /// Ignores the timers of a puzzle the player has left.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_next());
  }

  Future<void> _next() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feed = _feed ?? await _makeFeed();
      final profile = await ref.read(puzzleRepositoryProvider).load();
      final puzzle = await feed.next(rating: profile.shown(_user).rating.round(), seen: profile.seen);
      if (!mounted || gen != _generation) return;
      setState(() {
        _profile = profile;
        _run = PuzzleRun(puzzle);
        _packReason = puzzle.source == PuzzleSource.pack
            ? (ref.read(puzzleNetworkProvider).blocked ?? PuzzleOffline.network)
            : null;
        _loading = false;
        _intro = true;
        _revealing = false;
        _solutionShown = false;
        _feedback = _Feedback.find;
        _recorded = false;
        _diff = null;
      });
      await Future<void>.delayed(TrainingPace.puzzleIntro);
      if (!mounted || gen != _generation) return;
      _playSound(_run!.setup.before, _run!.setup.lastMove);
      setState(() => _intro = false);
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<PuzzleFeed> _makeFeed() async {
    final account = await ref.read(puzzleAccountProvider.future);
    _user = puzzleUser(account);
    return _feed = PuzzleFeed(
      client: ref.read(lichessClientProvider),
      angle: widget.angle,
      network: ref.read(puzzleNetworkProvider),
      pack: () => ref.read(puzzlePackProvider.future),
      account: _user == null ? null : account,
      onLichessRating: (user, rating) => unawaited(_lichessRating(user, rating)),
    );
  }

  /// Lichess sent the player's rating with puzzles.
  Future<void> _lichessRating(String user, Glicko rating) async {
    final p = await ref.read(puzzleRepositoryProvider).update((p) => p.withLichessRating(user, rating));
    if (mounted) setState(() => _profile = p);
  }

  /// Sends what waits; the answer of Lichess replaces the estimate.
  Future<void> _send() async {
    final user = _user;
    if (user == null) return;
    try {
      final diffs = await ref.read(puzzleSyncProvider).send(user);
      final p = await ref.read(puzzleRepositoryProvider).load();
      if (!mounted) return;
      ref.invalidate(puzzleProfileProvider);
      final id = _run?.puzzle.id;
      setState(() {
        _profile = p;
        if (id != null && _recorded && diffs.containsKey(id)) _diff = diffs[id];
      });
    } catch (_) {
      // Offline or limited: the results wait, the estimate stays.
    }
  }

  void _playSound(Position before, Move move) {
    final capture = before.board.pieceAt(move.to) != null || before.makeSan(move).$2.contains('x');
    unawaited(ref.read(soundServiceProvider).play(capture ? GameSound.capture : GameSound.move));
  }

  Future<void> _record({required bool win}) async {
    final run = _run;
    if (_recorded || run == null) return;
    _recorded = true;
    int? diff;
    final p = await ref.read(puzzleRepositoryProvider).update((p) {
      final r = p.record(run.puzzle, widget.angle, win: win, lichessUser: _user);
      diff = identical(r.profile, p) ? null : r.diff;
      return r.profile;
    });
    if (!mounted) return;
    ref.invalidate(puzzleProfileProvider);
    setState(() {
      _profile = p;
      _diff = diff;
    });
    unawaited(_send());
  }

  void _onMove(Move move) {
    final run = _run;
    if (run == null || !run.solverToMove || _intro || _revealing) return;
    final before = run.position;
    final norm = normalizeMove(before, move);
    final verdict = run.submit(move);
    final l = context.l10n;
    switch (verdict) {
      case PuzzleVerdict.wrong:
        unawaited(ref.read(soundServiceProvider).play(GameSound.error));
        setState(() {
          _feedback = _Feedback.wrong;
          _wrongCount++;
        });
        _announce(l.puzzleWrongMove);
        unawaited(_record(win: false));
      case PuzzleVerdict.correct:
        _playSound(before, norm);
        setState(() => _feedback = _Feedback.correct);
        _announce(l.puzzleBestMove);
        unawaited(_reply());
      case PuzzleVerdict.solved:
        unawaited(ref.read(soundServiceProvider).play(GameSound.success));
        unawaited(_finish());
    }
  }

  /// The opponent's answer after a right move.
  Future<void> _reply() async {
    final gen = _generation;
    final delay = Duration(milliseconds: ref.read(settingsProvider).opponentDelayMs);
    await Future<void>.delayed(delay);
    final run = _run;
    if (!mounted || gen != _generation || run == null) return;
    final before = run.position;
    final m = run.playScripted();
    if (m != null) _playSound(before, m);
    setState(() {});
  }

  Future<void> _reveal() async {
    final run = _run;
    if (run == null || _revealing || run.done) return;
    final gen = _generation;
    run.reveal();
    setState(() {
      _revealing = true;
      _solutionShown = true;
    });
    unawaited(_record(win: false));
    while (!run.done) {
      await Future<void>.delayed(TrainingPace.solutionStep);
      if (!mounted || gen != _generation) return;
      final before = run.position;
      final m = run.playScripted();
      if (m != null) _playSound(before, m);
      setState(() {});
    }
    await _finish();
  }

  Future<void> _finish() async {
    final run = _run;
    if (run == null) return;
    await _record(win: !run.failed);
    if (!mounted) return;
    final l = context.l10n;
    setState(() {
      _revealing = false;
      _feedback = run.failed ? _Feedback.failed : _Feedback.solved;
    });
    _announce(run.failed ? l.puzzleNotSolved : l.puzzleSolved);
  }

  void _announce(String text) {
    final view = View.of(context);
    unawaited(SemanticsService.sendAnnouncement(view, text, Directionality.of(context)));
  }

  /// The puzzle with its solution, for the analysis board.
  String _pgn(PuzzleRun run) {
    var pos = run.setup.start;
    final sans = <String>[];
    for (final uci in run.puzzle.solution) {
      final m = parseUciMove(pos, uci);
      if (m == null) break;
      final (next, san) = pos.makeSan(m);
      sans.add(san);
      pos = next;
    }
    final start = run.setup.start;
    final moves = StringBuffer();
    var n = start.fullmoves;
    var white = start.turn == Side.white;
    for (final (i, san) in sans.indexed) {
      if (white) {
        moves.write('$n. ');
      } else if (i == 0) {
        moves.write('$n... ');
      }
      moves.write('$san ');
      if (!white) n++;
      white = !white;
    }
    return '[Site "https://lichess.org/training/${run.puzzle.id}"]\n'
        '[SetUp "1"]\n[FEN "${start.fen}"]\n\n${moves.toString()}*';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: Text(puzzleThemeName(l, widget.angle), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: Semantics(
                  label: '${l.puzzleRating}: ${puzzleRatingText(profile.shown(_user))}',
                  excludeSemantics: true,
                  child: Text(
                    puzzleRatingText(profile.shown(_user)),
                    style: Theme.of(context).textTheme.labelLarge?.tabular,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading && _run == null
          ? const LoadingView()
          : _error != null
          ? _errorState(context)
          : _body(context),
    );
  }

  Widget _errorState(BuildContext context) {
    final l = context.l10n;
    final e = _error;
    // A limit is not a fault: no technical details under it.
    if (e is LichessException && e.isRateLimited) return ErrorState(message: l.puzzleRateLimited, onRetry: _next);
    return ErrorState(message: l.puzzleLoadError, details: '$e', onRetry: _next);
  }

  Widget _body(BuildContext context) {
    final l = context.l10n;
    final run = _run!;
    final interactive = run.solverToMove && !_intro && !_revealing && !_loading;
    final board = BoardView(
      position: _intro ? run.setup.before : run.position,
      orientation: run.setup.solver,
      lastMove: _intro ? null : run.lastMove,
      playerSide: interactive
          ? (run.setup.solver == Side.white ? PlayerSide.white : PlayerSide.black)
          : PlayerSide.none,
      onMove: _onMove,
      semanticsLabel: l.boardLabel,
    );
    return SafeArea(
      child: BoardLayout(board: board, below: (context, g) => _panel(context, run)),
    );
  }

  Widget _panel(BuildContext context, PuzzleRun run) {
    final finished = _feedback == _Feedback.solved || _feedback == _Feedback.failed;
    return finished ? _result(context, run) : _status(context, run);
  }

  /// Why the puzzle came from the app's own set, if it did.
  String? _packSourceText(AppLocalizations l) => switch (_packReason) {
    null => null,
    PuzzleOffline.limited => l.puzzleFromPackLimited,
    PuzzleOffline.network => l.puzzleFromPackOffline,
  };

  /// While solving: the same verdict card as in training.
  Widget _status(BuildContext context, PuzzleRun run) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, icon) = switch (_feedback) {
      _ when _revealing => (cs.surfaceContainerLow, cs.onSurface, AppIcons.show),
      _Feedback.correct => (cs.successContainer, cs.success, AppIcons.okFilled),
      _Feedback.wrong => (cs.errorContainer, cs.onErrorContainer, AppIcons.wrong),
      _ => (cs.surfaceContainerHigh, cs.onSurface, AppIcons.yourMove),
    };
    final message = switch (_feedback) {
      _ when _revealing => l.puzzleSolutionShown,
      _Feedback.correct => l.puzzleBestMove,
      _Feedback.wrong => l.puzzleWrongMove,
      _ => run.setup.solver == Side.white ? l.puzzleFindWhite : l.puzzleFindBlack,
    };
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Semantics(
          liveRegion: true,
          child: Shake(
            trigger: _feedback == _Feedback.wrong ? _wrongCount : null,
            child: AnimatedContainer(
              duration: AppMotion.of(context).base,
              curve: AppMotion.standard,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(color: bg, borderRadius: AppRadius.mdAll),
              child: Row(
                children: [
                  PopIn(
                    trigger: _feedback,
                    child: Icon(icon, color: fg),
                  ),
                  AppGap.h12,
                  Expanded(
                    child: Text(message, style: context.tt.title.copyWith(color: fg)),
                  ),
                ],
              ),
            ),
          ),
        ),
        AppGap.v12,
        Center(
          child: OutlinedButton.icon(
            onPressed: _revealing || _intro ? null : _reveal,
            icon: const Icon(AppIcons.show),
            label: Text(l.puzzleShowSolution),
          ),
        ),
        if (_packSourceText(l) case final source?) ...[
          AppGap.v8,
          Text(source, textAlign: TextAlign.center, style: context.tt.meta),
        ],
      ],
    );
  }

  /// The end, as the end of a training line (D-115): the verdict and the
  /// rating on the page itself, no tinted card; only the change of the
  /// rating has a colour.
  Widget _result(BuildContext context, PuzzleRun run) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final solved = _feedback == _Feedback.solved;
    final profile = _profile;
    final diff = _diff;
    final title = solved ? l.puzzleSolved : (_solutionShown ? l.puzzleSolutionShown : l.puzzleNotSolved);
    final change = diff == null ? l.puzzleRatingUnchanged : (diff >= 0 ? '+$diff' : '\u2212${-diff}');
    final themes = run.puzzle.themes.map((t) => puzzleThemeName(l, t)).join(' · ');
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopIn(
                trigger: _feedback,
                child: Icon(solved ? AppIcons.okFilled : AppIcons.wrong, color: solved ? cs.success : cs.error),
              ),
              AppGap.h8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.title),
                    AppGap.v4,
                    Text(l.puzzleInfo(run.puzzle.id, run.puzzle.rating), style: context.tt.meta),
                    if (themes.isNotEmpty) Text(themes, style: context.tt.meta),
                    if (_packSourceText(l) case final source?) Text(source, style: context.tt.meta),
                  ],
                ),
              ),
              if (profile != null) ...[
                AppGap.h12,
                Semantics(
                  label: l.puzzleRatingAfter(puzzleRatingText(profile.shown(_user)), change),
                  excludeSemantics: true,
                  // The new rating stands in the app bar; here only how
                  // much it moved.
                  child: Text(
                    change,
                    style: diff == null || diff == 0
                        ? context.tt.meta
                        : context.tt.value.copyWith(color: diff > 0 ? cs.success : cs.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        AppGap.v12,
        FilledButton.icon(
          style: AppButtonSize.large,
          onPressed: _loading ? null : _next,
          icon: const Icon(AppIcons.nextGame),
          label: Text(l.puzzleNext),
        ),
        AppGap.v8,
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/analysis',
                  extra: GameScreenArgs(pgn: _pgn(run), orientation: run.setup.solver),
                ),
                icon: const Icon(AppIcons.analysis),
                label: Text(l.aboutAnalyze, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            AppGap.h8,
            Expanded(
              child: Tooltip(
                message: l.puzzleOnLichess,
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse('https://lichess.org/training/${run.puzzle.id}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(AppIcons.externalLink),
                  label: const Text('Lichess', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
