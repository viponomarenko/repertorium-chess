import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/engine/engine_service.dart';
import '../../data/lichess/lichess_client.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/chess/chess_utils.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../app/route_observer.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'engine_model_sheet.dart';
import 'notation_view.dart';
import 'ui/motion.dart';

/// Evaluation in the user's locale: +0,32 / −1,50 / #3 (T-18).
String formatScore(BuildContext context, PvLine l) => context.fmtEval(cp: l.cp, mate: l.mate);

/// Converts UCI moves to SAN from [fen]; stops at the first illegal move.
List<String> uciLineToSan(String fen, List<String> uci, {int max = 12}) {
  final out = <String>[];
  Position? pos = tryPositionFromFen(fen);
  if (pos == null) return out;
  for (final u in uci.take(max)) {
    final m = parseUciMove(pos!, u);
    if (m == null) break;
    final (next, san) = pos.makeSan(m);
    final p = pos;
    out.add(p.turn == Side.white ? '${p.fullmoves}. $san' : (out.isEmpty ? '${p.fullmoves}... $san' : san));
    pos = next;
  }
  return out;
}

/// Vertical/horizontal evaluation bar (White's share).
class EvalBar extends StatelessWidget {
  const EvalBar({super.key, required this.line, this.horizontal = true, this.thickness = 8});
  final PvLine? line;
  final bool horizontal;
  final double thickness;

  double get _whiteShare {
    final l = line;
    if (l == null) return 0.5;
    if (l.mate != null) return l.mate! > 0 ? 1 : 0;
    final cp = (l.cp ?? 0).clamp(-1000, 1000);
    // Logistic mapping similar to common eval bars.
    return 1 / (1 + math.exp(-0.004 * cp));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: line == null ? null : formatScore(context, line!),
      child: ClipRRect(
        borderRadius: AppRadius.full,
        // The bar glides to the new evaluation instead of jumping.
        child: AnimatedFraction(
          value: _whiteShare,
          builder: (context, share) => SizedBox(
            height: horizontal ? thickness : null,
            width: horizontal ? null : thickness,
            child: horizontal
                ? Row(
                    children: [
                      Expanded(
                        flex: (share * 1000).round().clamp(1, 999),
                        child: ColoredBox(color: cs.sideWhite),
                      ),
                      Expanded(
                        flex: ((1 - share) * 1000).round().clamp(1, 999),
                        child: ColoredBox(color: cs.sideBlack),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: ((1 - share) * 1000).round().clamp(1, 999),
                        child: ColoredBox(color: cs.sideBlack),
                      ),
                      Expanded(
                        flex: (share * 1000).round().clamp(1, 999),
                        child: ColoredBox(color: cs.sideWhite),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Engine analysis panel (F-ENG-02): evaluation, depth, top lines; lines
/// can be added to the game. Optionally shows the Lichess cloud evaluation
/// (F-LI-11). The engine stops when the panel is disposed or the app goes
/// to the background (F-ENG-03).
class EnginePanel extends ConsumerStatefulWidget {
  const EnginePanel({
    super.key,
    required this.fen,
    this.onAddLine,
    this.onBestMove,
    this.compact = false,
    this.maxHeight,
  });
  final String fen;
  final void Function(List<String> uciMoves)? onAddLine;

  /// Reports the best move (for a board arrow).
  final void Function(String? uci)? onBestMove;
  final bool compact;

  /// Keeps the source and evaluation visible while longer variations scroll.
  final double? maxHeight;

  @override
  ConsumerState<EnginePanel> createState() => _EnginePanelState();
}

/// Engine limits for interactive analysis (D-034). With battery saving the
/// search is finite (depth 20 or 8 s, 2 threads, 32 MB); "Deeper" allows
/// depth 30 / 30 s once.
EngineOptions analysisOptions(AppSettings s, {required int multiPv, bool deeper = false}) {
  if (!s.enginePowerSaving) {
    return EngineOptions(
      threads: s.engineThreads,
      hashMb: s.engineHashMb,
      multiPv: multiPv,
      depth: s.engineDepth > 0 ? s.engineDepth : null,
    );
  }
  final cap = deeper ? 30 : 20;
  final cores = math.max(1, Platform.numberOfProcessors - 1);
  return EngineOptions(
    threads: math.min(s.engineThreads > 0 ? s.engineThreads : 2, math.min(2, cores)),
    hashMb: s.engineHashMb > 0 ? math.min(s.engineHashMb, 64) : 32,
    multiPv: multiPv,
    depth: s.engineDepth > 0 && !deeper ? math.min(s.engineDepth, cap) : cap,
    movetime: Duration(seconds: deeper ? 30 : 8),
  );
}

class _EnginePanelState extends ConsumerState<EnginePanel> with WidgetsBindingObserver, RouteAware {
  final Map<String, EngineEval> _completed = {};
  Completer<void>? _cloudAbort;

  StreamSubscription<EngineEval>? _sub;
  EngineEval? _eval;
  Object? _error;
  CloudEval? _cloud;
  bool _cloudLoading = false;
  bool _usingCloud = false;
  bool _cloudMissing = false;

  /// The user asked for the device engine although the cloud had an answer.
  bool? _sourceOverride;
  bool _deeper = false;
  bool _expanded = false;
  bool _backgrounded = false;
  bool _covered = false;
  Timer? _debounce;
  int _generation = 0;
  late final EngineService _engine = ref.read(engineServiceProvider);
  PageRoute<dynamic>? _route;

  bool get _active => !_backgrounded && !_covered;

  int get _multiPv => widget.compact && !_expanded ? 1 : ref.read(settingsProvider).engineLines.clamp(1, 5);

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _backgrounded = state != null && state != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _schedule(immediate: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) pageRouteObserver.unsubscribe(this);
      _route = route;
      pageRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(EnginePanel old) {
    super.didUpdateWidget(old);
    if (old.fen != widget.fen) {
      _cloud = null;
      _cloudMissing = false;
      _deeper = false;
      _schedule();
    } else if (old.compact != widget.compact && !_expanded) {
      _schedule(immediate: true);
    }
  }

  // Pause while another page covers the analysis (F-ENG-03, D-034).
  @override
  void didPushNext() {
    _covered = true;
    _halt();
  }

  @override
  void didPopNext() {
    _covered = false;
    _schedule(immediate: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_backgrounded) {
      _backgrounded = true;
      _halt();
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      _schedule(immediate: true);
    }
  }

  void _halt() {
    _generation++;
    _cloudLoading = false;
    _debounce?.cancel();
    _sub?.cancel();
    _sub = null;
    final abort = _cloudAbort;
    _cloudAbort = null;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  /// Restarts after a short pause, so stepping quickly through moves does
  /// not start a search for every position.
  void _schedule({bool immediate = false}) {
    _halt();
    _eval = null;
    _cloud = null;
    _error = null;
    _usingCloud = _sourceOverride ?? ref.read(settingsProvider).engineCloudFirst;
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation) widget.onBestMove?.call(null);
    });
    if (!_active) return;
    _debounce = Timer(immediate ? Duration.zero : AppTiming.engineDebounce, _begin);
  }

  Future<void> _begin() async {
    if (!mounted || !_active) return;
    final pos = tryPositionFromFen(widget.fen);
    if (pos == null || pos.isGameOver) {
      setState(() => _eval = null);
      widget.onBestMove?.call(null);
      return;
    }
    final s = ref.read(settingsProvider);
    if (_sourceOverride ?? s.engineCloudFirst) {
      final fen = widget.fen;
      final generation = _generation;
      final cloud = await _fetchCloud(fen, generation);
      if (!mounted || generation != _generation || fen != widget.fen || !_active) return;
      if (cloud != null && cloud.lines.isNotEmpty && uciLineToSan(fen, cloud.lines.first.moves, max: 1).isNotEmpty) {
        setState(() {
          _cloud = cloud;
          _cloudMissing = false;
        });
        final best = cloud.lines.isEmpty ? null : cloud.lines.first;
        widget.onBestMove?.call(best == null || best.moves.isEmpty ? null : best.moves.first);
        return;
      }
    }
    _startLocal();
  }

  Future<CloudEval?> _fetchCloud(String fen, int generation) async {
    final abort = Completer<void>();
    _cloudAbort = abort;
    if (mounted) setState(() => _cloudLoading = true);
    try {
      final r = await ref
          .read(lichessClientProvider)
          .cloudEval(fen, multiPv: _multiPv, abort: abort.future)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Cloud evaluation timed out');
            },
          );
      if (mounted && generation == _generation) setState(() => _cloudMissing = r == null);
      return r;
    } catch (_) {
      return null;
    } finally {
      if (_cloudAbort == abort) _cloudAbort = null;
      if (mounted && generation == _generation) setState(() => _cloudLoading = false);
    }
  }

  void _startLocal() {
    if (!mounted || !_active) return;
    final generation = ++_generation;
    _sub?.cancel();
    final s = ref.read(settingsProvider);
    final fen = widget.fen;
    final options = analysisOptions(s, multiPv: _multiPv, deeper: _deeper);
    final key =
        '${s.engineModel}/$fen/${options.effectiveThreads}/${options.effectiveHash}/${options.multiPv}/${options.depth}/${options.movetime}';
    final cached = _completed[key];
    setState(() {
      _cloudLoading = false;
      _usingCloud = false;
      _cloud = null;
      _eval = cached;
      _error = null;
    });
    void report(EngineEval e) {
      final best = e.best;
      widget.onBestMove?.call(best == null || best.moves.isEmpty ? null : best.moves.first);
    }

    if (cached != null) {
      report(cached);
      return;
    }
    _sub = _engine
        .analyze(fen, options)
        .listen(
          (e) {
            if (!mounted || !_active || generation != _generation || e.fen != widget.fen) return;
            if (e.done) {
              if (_completed.length >= 32) _completed.remove(_completed.keys.first);
              _completed[key] = e;
            }
            setState(() => _eval = e);
            report(e);
          },
          onError: (Object e) {
            if (mounted && generation == _generation) setState(() => _error = e);
          },
        );
  }

  void _useDevice() {
    _sourceOverride = false;
    _schedule(immediate: true);
  }

  void _applyChosenModel() {
    // The settings listener already starts a changed local model. Do not
    // cancel that new search a second time when its selection sheet closes.
    final needsRestart = _cloud != null || _cloudLoading || _error != null;
    _sourceOverride = false;
    if (needsRestart) _schedule(immediate: true);
  }

  Future<void> _useCloud() async {
    _sourceOverride = true;
    _cloud = null;
    _schedule(immediate: true);
  }

  /// Explains the two sources and lets the user pick one.
  Future<void> _sourceSheet() async {
    final l = context.l10n;
    final onCloud = _usingCloud;
    final choice = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final t = Theme.of(ctx);
        Widget option({
          required bool cloud,
          required IconData icon,
          required String title,
          required String hint,
          bool enabled = true,
        }) => ListTile(
          minTileHeight: 72,
          enabled: enabled,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(hint),
          trailing: cloud == onCloud ? const Icon(AppIcons.check) : null,
          selected: cloud == onCloud,
          onTap: () => Navigator.pop(ctx, cloud),
        );
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppInsets.sheetTitle,
                  child: Text(l.engineSourceTitle, style: t.textTheme.titleLarge),
                ),
                option(
                  cloud: true,
                  icon: AppIcons.cloud,
                  title: l.engineSourceCloud,
                  hint: _cloudMissing ? l.cloudMissingHint : l.engineSourceCloudHint,
                  enabled: !_cloudMissing,
                ),
                option(
                  cloud: false,
                  icon: AppIcons.phone,
                  title: l.engineSourcePhone,
                  hint:
                      '${ref.read(settingsProvider).engineModel == 'full' ? 'Stockfish 19' : 'Stockfish 19 Light'}. ${l.engineSourcePhoneHint}',
                ),
                ListTile(
                  title: Text(l.engineLocalModel),
                  trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final changed = await showEngineModelSheet(context);
                    if (mounted && changed == true) _applyChosenModel();
                  },
                ),
                AppGap.v12,
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    if (choice == onCloud) {
      _sourceOverride = choice;
      return;
    }
    if (choice) {
      await _useCloud();
    } else {
      _useDevice();
    }
  }

  void _goDeeper() {
    _deeper = true;
    _sourceOverride = false;
    _schedule(immediate: true);
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    // Keep the selected source, including while its request is in flight.
    _schedule(immediate: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pageRouteObserver.unsubscribe(this);
    _halt();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select(
        (s) => (
          s.engineThreads,
          s.engineHashMb,
          s.engineLines,
          s.engineDepth,
          s.enginePowerSaving,
          s.engineCloudFirst,
          s.engineModel,
        ),
      ),
      (previous, next) {
        if (previous == next) return;
        if (previous?.$6 != next.$6) _sourceOverride = null;
        if (previous?.$7 != next.$7) {
          _sourceOverride = false;
          _completed.clear();
        }
        _deeper = false;
        _cloud = null;
        _schedule(immediate: true);
      },
    );
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = _eval;
    final terminal = tryPositionFromFen(widget.fen)?.isGameOver ?? true;
    final cloudLines = _cloud?.lines.map((c) => PvLine(multipv: 0, moves: c.moves, cp: c.cp, mate: c.mate)).toList();
    final all = cloudLines ?? e?.lines ?? const <PvLine>[];
    // Only lines that are legal from this position (defensive).
    final lines = [
      for (final line in all)
        if (uciLineToSan(widget.fen, line.moves, max: 1).isNotEmpty) line,
    ];
    final s = ref.watch(settingsProvider);
    final sourceName = _usingCloud
        ? 'Lichess'
        : s.engineModel == 'full'
        ? 'Stockfish 19'
        : 'Stockfish 19 Light';
    final busy = !terminal && _error == null && (_cloudLoading || (!_usingCloud && !(e?.done ?? false)));
    final status = terminal
        ? l.engineNoMoves
        : _error != null
        ? l.engineError
        : _cloud != null
        ? l.engineDepthDone(_cloud!.depth)
        : e == null
        ? (_usingCloud ? l.cloudEval : l.engineStarting)
        : e.done
        ? l.engineDepthDone(e.depth)
        : l.engineDepth(e.depth);
    final Widget? action = _error != null
        ? _error is EngineNetworkUnavailable
              ? TextButton(
                  onPressed: () async {
                    final changed = await showEngineModelSheet(context);
                    if (mounted && changed == true) _applyChosenModel();
                  },
                  child: Text(l.engineLocalModel),
                )
              : _error is EnginePositionUnsupported
              ? null
              : TextButton(onPressed: () => _schedule(immediate: true), child: Text(l.retry))
        : !_usingCloud && (e?.done ?? false) && s.enginePowerSaving && !_deeper
        ? TextButton(onPressed: _goDeeper, child: Text(l.engineDeeper))
        : null;
    final shown = (widget.compact && !_expanded ? lines.take(1) : lines.take(5)).toList();

    Widget statusLabel() => Row(
      children: [
        if (busy) ...[
          const SizedBox.square(dimension: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
          AppGap.h8,
        ],
        Flexible(
          child: Tooltip(
            message: status,
            excludeFromSemantics: true,
            child: Text(
              status,
              key: const ValueKey('engine-status'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.tt.meta.tabular,
            ),
          ),
        ),
      ],
    );

    Widget source({required bool withStatus}) => Semantics(
      button: true,
      hint: l.engineSourceHint,
      child: InkWell(
        key: const ValueKey('engine-source'),
        onTap: _sourceSheet,
        borderRadius: AppRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.controlSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _usingCloud ? AppIcons.cloud : AppIcons.engine,
                    size: AppSizes.iconMd,
                    color: cs.onSurfaceVariant,
                  ),
                  AppGap.h8,
                  Flexible(
                    // The name opens the source sheet: words on a control (D-053).
                    child: Text(sourceName, key: const ValueKey('engine-source-name'), style: context.tt.control),
                  ),
                  AppGap.h4,
                  Icon(AppIcons.chevronRight, size: AppSizes.iconSm, color: cs.onSurfaceVariant),
                ],
              ),
              if (withStatus) statusLabel(),
            ],
          ),
        ),
      ),
    );

    // With lines on screen the status moves to the caption line; without
    // them (starting, an error) it stays under the source name.
    final inlineStatus = shown.isNotEmpty || action != null;
    final variations = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error is EngineNetworkUnavailable || _error is EnginePositionUnsupported)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              _error is EngineNetworkUnavailable ? l.engineNetworkRequired : l.enginePositionUnsupported,
              style: context.tt.body,
            ),
          ),
        if (shown.isNotEmpty || action != null)
          // One short line: the caption, and at its end the status
          // (depth, source state) instead of a row of its own (D-079).
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    (shown.length > 1 ? l.engineVariations : l.engineBest).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.overline,
                  ),
                ),
                // Still opens the source sheet, as it did under the name.
                if (inlineStatus) ...[
                  AppGap.h8,
                  Flexible(
                    child: InkWell(onTap: _sourceSheet, child: statusLabel()),
                  ),
                ],
                if (action != null)
                  Flexible(
                    child: Align(alignment: Alignment.centerRight, child: action),
                  ),
              ],
            ),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const Divider(height: AppSizes.hairline),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shown.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs, right: AppSpacing.md),
                  child: SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(48),
                    child: Text(formatScore(context, shown[i]), style: context.tt.title.tabular),
                  ),
                ),
              Expanded(
                child: Padding(
                  // Centred on the 36-high row when it is one line of text.
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: MoveLineText(
                    uciLineToSan(widget.fen, shown[i].moves).join(' '),
                    maxLines: widget.compact && !_expanded ? 2 : 3,
                  ),
                ),
              ),
              if (widget.onAddLine != null)
                IconButton(
                  tooltip: l.addLineAsVariation,
                  // As tall as a row of moves (36), still 48 wide: a line of
                  // one row of text must not be padded out to 48 (D-080).
                  constraints: const BoxConstraints(minWidth: AppSizes.tapTarget, minHeight: AppSizes.moveRow),
                  padding: EdgeInsets.zero,
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: () => widget.onAddLine!(shown[i].moves.take(10).toList()),
                  icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
                ),
            ],
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight ?? double.infinity),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 330 || MediaQuery.textScalerOf(context).scale(14) > 19;
                final score = Container(
                  key: const ValueKey('engine-score'),
                  constraints: const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: AppRadius.mdAll),
                  child: Text(
                    lines.isEmpty ? '…' : formatScore(context, lines.first),
                    textAlign: TextAlign.center,
                    style: context.tt.value,
                  ),
                );
                final expand = widget.compact
                    ? IconButton(
                        tooltip: _expanded ? l.collapse : l.expand,
                        onPressed: _toggleExpanded,
                        icon: Icon(_expanded ? AppIcons.collapse : AppIcons.expand, size: AppSizes.iconMd),
                      )
                    : null;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: source(withStatus: !stacked && !inlineStatus)),
                        if (!stacked) ...[AppGap.h12, score],
                        ?expand,
                      ],
                    ),
                    if (stacked) ...[
                      AppGap.v4,
                      Row(
                        children: [
                          Expanded(
                            child: inlineStatus
                                ? const SizedBox.shrink()
                                : InkWell(onTap: _sourceSheet, child: statusLabel()),
                          ),
                          AppGap.h12,
                          score,
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            EvalBar(line: lines.isEmpty ? null : lines.first, thickness: AppSizes.gripHeight),
            if (widget.maxHeight != null) Flexible(child: SingleChildScrollView(child: variations)) else variations,
          ],
        ),
      ),
    );
  }
}
