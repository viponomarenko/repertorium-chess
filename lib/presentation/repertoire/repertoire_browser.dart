import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/engine/engine_check.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_writer.dart';
import '../../domain/repertoire/repertoire_export.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../../domain/srs/fsrs.dart';
import '../../domain/training/training_engine.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/board_layout.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';
import '../widgets/spoken.dart';
import 'repertoire_controller.dart';
import 'repertoire_screen.dart' show confirmDiscardPending;
import 'repertoire_tree.dart';

/// What the repertoire screen keeps under the board beyond the usual
/// minimum, so that the path row, a caption, two moves and the bottom bar
/// fit exactly (48 + 18 + 2 x 36 + 64), and not a point more.
const kRepertoireExtraBelow = 42.0;

/// The fade at the start of the path row, where older moves scroll away;
/// also the room after the latest move.
const _pathFade = AppSpacing.md;

/// SAN line from the root for a path of repertoire moves.
String pathToText(List<RepMove> path, RepertoireGraph g) {
  if (path.isEmpty) return '';
  final sb = StringBuffer();
  for (var i = 0; i < path.length; i++) {
    final m = path[i];
    final pos = positionFromFen(g.positions[m.fromKey]!.fen);
    if (pos.turn == Side.white) {
      if (sb.isNotEmpty) sb.write(' ');
      sb.write('${pos.fullmoves}. ${m.san}');
    } else {
      sb.write(i == 0 ? '${pos.fullmoves}... ${m.san}' : ' ${m.san}');
    }
  }
  return sb.toString();
}

String moveNumberPrefix(Position pos) => pos.turn == Side.white ? '${pos.fullmoves}. ' : '${pos.fullmoves}... ';

/// Human description of a card's schedule.
String cardStatus(CardInfo? c, AppLocalizations l, Fsrs fsrs, {bool deferred = false}) {
  if (deferred) return l.cardDeferred;
  if (c == null) return l.cardNone;
  if (c.suspended) return l.cardSuspended;
  final s = c.srs;
  if (s.isNew) return l.cardNew;
  final now = DateTime.now();
  if (fsrs.isDue(s, now)) return l.cardDueNow;
  final days = fsrs.dayStart(s.due!).difference(fsrs.dayStart(now)).inHours ~/ 24;
  return days <= 0 ? l.cardDueToday : l.cardDueInDays(days);
}

/// Adds [c]'s pending moves to the repertoire, asking what to do when an
/// own move conflicts with an existing main move.
Future<void> commitPendingInteractive(BuildContext context, RepertoireController c, {bool quiet = false}) async {
  final l = context.l10n;
  var outcome = await c.commitPending();
  // One question per conflicting own move.
  while (outcome == AddMoveOutcome.needsDecision) {
    if (!context.mounted) return;
    final main = c.graph!.mainMove(c.path.isEmpty ? c.graph!.rootKey : c.path.last.toKey);
    final choice = await showDialog<OwnMovePolicy>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.mainExistsTitle),
        content: MovesText(l.mainExistsMessage(main?.san ?? '', c.pending.isEmpty ? '' : c.pending.first.$2)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, OwnMovePolicy.asAlternative), child: Text(l.addAsAlternative)),
          FilledButton(onPressed: () => Navigator.pop(ctx, OwnMovePolicy.replaceMain), child: Text(l.replaceMain)),
        ],
      ),
    );
    if (choice == null) return;
    outcome = await c.commitPending(policy: choice);
  }
  if (!quiet && context.mounted && outcome != AddMoveOutcome.needsDecision) showSnack(context, l.movesAdded);
}

/// Plays [ucis] from [c]'s position (moves already in the repertoire are
/// just followed) and adds the new ones; ends at the last move.
Future<void> playAndAddLine(
  BuildContext context,
  RepertoireController c,
  List<String> ucis, {
  required String alreadyMessage,
}) async {
  for (final u in ucis) {
    final m = parseUciMove(c.position, u);
    if (m == null) break;
    c.playOnBoard(m);
  }
  if (c.pending.isNotEmpty) {
    await commitPendingInteractive(context, c);
  } else if (context.mounted) {
    showSnack(context, alreadyMessage);
  }
}

/// Asks before an action that would drop moves not yet added to the
/// repertoire; true when it may proceed.
Future<bool> confirmLeavePending(BuildContext context, RepertoireController c) async {
  if (c.pending.isEmpty) return true;
  return confirmDiscardPending(context, c);
}

/// Pending (not yet added) moves with move numbers, e.g. "5... Nf6 6. Bg5".
String pendingToText(RepertoireController c) {
  final g = c.graph!;
  var pos = positionFromFen(g.positions[c.path.isEmpty ? g.rootKey : c.path.last.toKey]!.fen);
  final sb = StringBuffer();
  for (var i = 0; i < c.pending.length; i++) {
    final (_, san, next) = c.pending[i];
    if (sb.isNotEmpty) sb.write(' ');
    if (pos.turn == Side.white) {
      sb.write('${pos.fullmoves}. $san');
    } else {
      sb.write(i == 0 ? '${pos.fullmoves}... $san' : san);
    }
    pos = next;
  }
  return sb.toString();
}

/// Board + breadcrumbs + moves of the current position; the core of the
/// repertoire view and the builder (F-REP-02, F-REP-07, F-REP-08).
class RepertoireBrowser extends ConsumerStatefulWidget {
  const RepertoireBrowser({
    super.key,
    required this.c,
    this.extraPanels = const [],
    this.builderMode = false,
    this.enableTree = false,
    this.problemKeys = const {},
    this.onAddedInView,
  });
  final RepertoireController c;
  final List<Widget> extraPanels;
  final bool builderMode;
  final bool enableTree;
  final Set<PositionKey> problemKeys;

  /// The user added moves with the "Add" bar while only viewing: the
  /// screen switches to editing from here on.
  final VoidCallback? onAddedInView;

  @override
  ConsumerState<RepertoireBrowser> createState() => _RepertoireBrowserState();
}

class _RepertoireBrowserState extends ConsumerState<RepertoireBrowser> with AutomaticKeepAliveClientMixin {
  bool _arrows = true;
  bool _treeMode = false;
  final _treeTools = RepertoireTreeTools();

  @override
  void dispose() {
    _treeTools.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  RepertoireController get c => widget.c;

  Future<void> _commit({bool quiet = false}) => commitPendingInteractive(context, c, quiet: quiet);

  Future<void> _selectTreePosition(PositionKey key) async {
    if (!await confirmLeavePending(context, c) || !mounted) return;
    c.jumpTo(key);
  }

  Future<void> _onBoardMove(Move m) async {
    // What to go back to if the user takes the move back ("Undo").
    final before = widget.builderMode ? (c.graph!.clone(), List.of(c.path)) : null;
    c.playOnBoard(m);
    // While editing, every new move goes straight into the repertoire.
    if (before == null || c.pending.isEmpty) return;
    final l = context.l10n;
    await _commit(quiet: true);
    if (!mounted || c.pending.isNotEmpty) return;
    showSnack(
      context,
      l.moveAddedShort,
      action: SnackBarAction(label: l.undo, onPressed: () => unawaited(c.restore(before.$1, before.$2))),
    );
  }

  /// "Add" on the bar of moves that are not in the repertoire yet.
  Future<void> _addPending() async {
    await _commit();
    if (mounted && c.pending.isEmpty) widget.onAddedInView?.call();
  }

  /// Opens the analysis board at this position; the line analysed there
  /// comes back and is added here in one step (the analysis shows which
  /// moves and has a pinned "Add" button).
  Future<void> _analyze() async {
    final l = context.l10n;
    final ucis = await context.push<List<String>>(
      '/analysis',
      extra: GameScreenArgs(fen: c.position.fen, orientation: c.graph!.color, lineFor: c.row?.name ?? ''),
    );
    if (ucis == null || ucis.isEmpty || !mounted) return;
    await playAndAddLine(context, c, ucis, alreadyMessage: l.lineAlreadyInRepertoire);
  }

  /// The engine's move becomes main; the notice offers to undo it.
  Future<void> _applyEngine(PositionKey key) async {
    if (!await confirmLeavePending(context, c) || !mounted) return;
    final l = context.l10n;
    final done = await c.applyEngineSuggestion(key);
    if (done == null || !mounted) return;
    showNotice(
      l.engineApplied(done.best, done.old),
      actionLabel: l.undo,
      onAction: () => unawaited(c.restore(done.before, done.path)),
    );
  }

  /// The user keeps their move; the notice offers to undo it.
  Future<void> _keepMine(PositionKey key) async {
    final l = context.l10n;
    final main = c.graph!.mainMove(key);
    final before = await c.dismissEngineFlag(key);
    if (before == null || !mounted) return;
    showNotice(
      l.engineKept(main?.san ?? ''),
      actionLabel: l.undo,
      onAction: () => unawaited(c.setEngineFlag(key, before)),
    );
  }

  Future<void> _moveMenu(RepMove m) async {
    final l = context.l10n;
    final g = c.graph!;
    final own = g.isUserTurn(m.fromKey);
    await showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: MovesText(m.san, style: Theme.of(ctx).textTheme.titleLarge)),
          if (own && m.role != MoveRole.main)
            ListTile(
              leading: const Icon(AppIcons.mainMove),
              title: Text(l.makeMain),
              onTap: () {
                Navigator.pop(ctx);
                c.setRole(m, MoveRole.main);
              },
            ),
          if (own && m.role == MoveRole.main)
            ListTile(
              leading: const Icon(AppIcons.notMain),
              title: Text(l.makeAlternative),
              onTap: () {
                Navigator.pop(ctx);
                c.setRole(m, MoveRole.alternative);
              },
            ),
          if (!own)
            ListTile(
              leading: const Icon(AppIcons.weight),
              title: Text(l.weightValue(m.weight)),
              subtitle: Text(l.weightHint),
              onTap: () {
                Navigator.pop(ctx);
                _editWeight(m);
              },
            ),
          ListTile(
            leading: const Icon(AppIcons.comment),
            title: Text(l.moveComment),
            subtitle: m.comment.isEmpty ? null : MovesText(m.comment, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () async {
              Navigator.pop(ctx);
              final t = await promptText(context, title: l.moveComment, initial: m.comment, maxLines: 6);
              if (t != null) await c.setMoveComment(m, t.trim());
            },
          ),
          // Only the action that changes something is offered.
          if (!g.suspension(m.toKey).all)
            ListTile(
              leading: const Icon(AppIcons.suspend),
              title: Text(l.suspendBranch),
              onTap: () async {
                Navigator.pop(ctx);
                final n = await c.setSuspended(m.toKey, true);
                if (mounted) showSnack(context, l.cardsSuspended(n));
              },
            ),
          if (g.suspension(m.toKey).any)
            ListTile(
              leading: const Icon(AppIcons.resume),
              title: Text(l.resumeBranch),
              onTap: () async {
                Navigator.pop(ctx);
                final n = await c.setSuspended(m.toKey, false);
                if (mounted) showSnack(context, l.cardsResumed(n));
              },
            ),
          ListTile(
            leading: Icon(AppIcons.delete, color: Theme.of(ctx).colorScheme.error),
            title: Text(l.deleteBranch),
            onTap: () {
              Navigator.pop(ctx);
              _delete(m);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editWeight(RepMove m) async {
    final l = context.l10n;
    var v = m.weight.toDouble();
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: MovesText(l.weightFor(m.san)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${v.round()}', style: Theme.of(ctx).textTheme.headlineMedium),
              Slider(
                value: v,
                min: 0,
                max: 100,
                divisions: 20,
                label: '${v.round()}',
                onChanged: (x) => set(() => v = x),
              ),
              Text(l.weightHint, style: ctx.tt.meta),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, v.round()), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (r != null) await c.setWeight(m, r);
  }

  Future<void> _delete(RepMove m) async {
    final l = context.l10n;
    final plan = c.graph!.planDeleteMove(m);
    final ok = await confirm(
      context,
      title: ref.read(notationFormatterProvider).text(l.deleteMoveQ(m.san)),
      message:
          l.deletePlan(plan.positions.length, plan.cards.length) +
          (plan.promotedAlternative != null
              ? '\n${ref.read(notationFormatterProvider).text(l.alternativeBecomesMain(c.graph!.moveById(plan.promotedAlternative!)!.san))}'
              : ''),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    final snapshot = c.graph!.clone();
    final oldPath = List.of(c.path);
    await c.delete(plan);
    if (!mounted) return;
    showSnack(
      context,
      ref.read(notationFormatterProvider).text(l.moveDeleted(m.san)),
      action: SnackBarAction(label: l.undo, onPressed: () => unawaited(c.restore(snapshot, oldPath))),
    );
  }

  Set<Shape> _shapes(RepertoireGraph g, PositionKey key) {
    final shapes = <Shape>{};
    final pos = g.positions[key];
    if (pos != null) {
      for (final s in pos.shapes) {
        shapes.add(BoardAppearance.toShape(s));
      }
    }
    if (!_arrows || !c.inRepertoire) return shapes;
    final moves = g.movesFrom(key);
    final maxW = moves.fold<int>(1, (a, m) => m.weight > a ? m.weight : a);
    for (final m in moves) {
      final mv = Move.parse(m.uci);
      if (mv is! NormalMove) continue;
      final color = switch (m.role) {
        MoveRole.main => BoardColors.mainMove,
        MoveRole.alternative => BoardColors.alternativeMove,
        MoveRole.opponent => BoardColors.opponentMove,
      };
      final scale = m.role == MoveRole.opponent ? (0.45 + 0.5 * m.weight / maxW).clamp(0.4, 1.0) : 0.9;
      shapes.add(Arrow(color: color, orig: mv.from, dest: mv.to, scale: scale.toDouble()));
    }
    return shapes;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final theme = Theme.of(context);
    final g = c.graph!;
    final key = c.key;
    final pos = c.position;
    final fsrs = ref.watch(fsrsProvider);
    final book = ref.watch(openingBookProvider).value;
    final keys = [g.rootKey, for (final m in c.path) m.toKey, for (final p in c.pending) positionKeyOf(p.$3)];
    final opening = book?.deepest(keys);
    final inRep = c.inRepertoire;
    final moves = inRep ? g.movesFrom(key) : const <RepMove>[];
    final into = inRep ? g.movesTo(key) : const <RepMove>[];
    final userTurn = pos.turn == g.color;
    final card = g.cards[key];
    final repPos = g.positions[key];
    final decoded = repPos == null ? null : EngineFlag.decode(repPos.engineFlag);
    // An answered flag ("keep my move") is no longer shown.
    final flag = decoded != null && decoded.active && g.mainMove(key) != null ? decoded : null;

    final board = BoardView(
      position: pos,
      orientation: g.color,
      lastMove: c.lastMove,
      playerSide: PlayerSide.both,
      onMove: (m) => unawaited(_onBoardMove(m)),
      shapes: _shapes(g, key),
      semanticsLabel: l.boardLabel,
    );

    final small = context.tt.meta;
    // One dense line: a small icon and text (no cards, no empty rows).
    Widget infoLine(IconData icon, Widget text, {Color? color, Widget? trailing}) => Padding(
      padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: color ?? theme.colorScheme.onSurfaceVariant),
          AppGap.h4,
          Expanded(child: text),
          // Shares the row with the text, never pushes it off the screen.
          if (trailing != null)
            Flexible(
              child: Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
            ),
        ],
      ),
    );
    Future<void> editComment() async {
      final t = await promptText(context, title: l.positionComment, initial: repPos?.comment ?? '', maxLines: 6);
      if (t != null) await c.setPositionComment(key, t.trim());
    }

    final details = <Widget>[
      // One row for the way here and the Moves/Tree switch: every row
      // under the board costs board (D-074).
      _PathLine(
        c: c,
        problems: widget.problemKeys.length,
        actions: [
          if (widget.enableTree)
            IconSegmentedSwitch(
              key: const ValueKey('repertoire-view-switch'),
              icons: const [AppIcons.list, AppIcons.repertoire],
              labels: [l.positionDetails, l.tabTree],
              selected: _treeMode ? 1 : 0,
              onChanged: (i) => setState(() => _treeMode = i == 1),
            ),
        ],
      ),
      // The opening: its code in ink, the name in grey (D-095).
      if (opening != null)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.page),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: opening.eco,
                  style: small.copyWith(fontWeight: context.tt.title.fontWeight, color: theme.colorScheme.onSurface),
                ),
                TextSpan(text: ' · ${opening.name}'),
              ],
            ),
            style: small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      // Whose moves these are; for the user's own, how well the move is
      // known sits on the right - a warm chip when it is time to review
      // (D-095); for the opponent's, the header of the share column.
      if (inRep)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: infoLine(
            userTurn ? AppIcons.card : AppIcons.opponentMove,
            Text(userTurn ? l.yourMoves : l.opponentMoves, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: repPos?.conflictDeferred ?? false
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(l.cardDeferred, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(onPressed: () => c.setDeferred(key, false), child: Text(l.resolve)),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm, right: AppSpacing.sm),
                    child: userTurn
                        ? (card != null || moves.isNotEmpty
                              ? _CardState(
                                  text: cardStatus(card, l, fsrs),
                                  due:
                                      card != null &&
                                      !card.suspended &&
                                      !card.srs.isNew &&
                                      fsrs.isDue(card.srs, DateTime.now()),
                                )
                              : null)
                        : (moves.isEmpty ? null : Text(l.opponentShareHeader, style: small)),
                  ),
          ),
        ),
      if (inRep && into.length > 1)
        infoLine(
          AppIcons.transposition,
          MovesText(
            l.transpositionNotice(
              into
                  .where((m) => c.path.isEmpty || m.id != c.path.last.id)
                  .map((m) => pathToText([...?g.pathFromRoot(m.fromKey), m], g))
                  .take(3)
                  .join('; '),
            ),
            style: small,
          ),
        ),
      if (flag != null) ...[
        infoLine(
          AppIcons.warning,
          MovesText(
            '${l.engineFlagTitle(context.fmtDecimal(flag.lossCp / 100))} · ${l.engineFlagHint(flag.bestSan, flag.depth)}',
            style: small,
          ),
          color: theme.colorScheme.warning,
        ),
        // The two ways out of the flag, each undoable (D-090).
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonal(
                style: AppButtonSize.compact,
                onPressed: () => unawaited(_applyEngine(key)),
                child: MovesText(l.engineApply(flag.bestSan)),
              ),
              TextButton(
                style: AppButtonSize.compact,
                onPressed: () => unawaited(_keepMine(key)),
                child: Text(l.engineKeepMine),
              ),
            ],
          ),
        ),
      ],
      if (inRep && repPos != null && repPos.comment.isNotEmpty)
        InkWell(
          onTap: editComment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
            child: MovesText(repPos.comment, style: context.tt.comment),
          ),
        ),
      if (inRep && moves.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.page, bottom: AppSpacing.xs),
          child: Text(userTurn ? l.noOwnMoveHint : l.noOpponentMovesHint, style: small),
        ),
      for (final m in moves)
        _MoveTile(
          m: m,
          g: g,
          prefix: moveNumberPrefix(pos),
          share: () {
            final total = moves.fold<int>(0, (a, x) => a + x.weight);
            return total == 0 ? 0.0 : m.weight / total;
          }(),
          onTap: () => c.go(m),
          onMenu: () => _moveMenu(m),
        ),
      ...widget.extraPanels,
    ];

    // The position's tools: the bottom bar of the screen, in place of the
    // main navigation and built like the bar of the analysis (D-078).
    // Training and analysis first; then the tools of the current view
    // (comment and arrows for the moves, folding for the tree).
    Widget tool(String tooltip, BarButton button) => Expanded(
      child: Tooltip(message: tooltip, child: button),
    );
    final canTrain = inRep && g.reachableFrom(key).any(g.isTrainable);
    final tools = ThumbBar(
      children: [
        tool(
          l.trainFromHereLong,
          BarButton(
            icon: AppIcons.drill,
            label: l.trainFromHereShort,
            onTap: canTrain
                ? () => context.push(
                    '/train',
                    extra: TrainingArgs(repertoireIds: [c.id], mode: TrainingMode.drill, startKey: key),
                  )
                : null,
          ),
        ),
        tool(l.analyze, BarButton(icon: AppIcons.analysis, label: l.analyze, onTap: inRep ? _analyze : null)),
        if (widget.enableTree && _treeMode)
          ListenableBuilder(
            listenable: _treeTools,
            builder: (context, _) => Expanded(
              flex: 2,
              child: Row(
                children: [
                  tool(
                    _treeTools.allExpanded ? l.collapseAll : l.expandAll,
                    BarButton(
                      icon: _treeTools.allExpanded ? AppIcons.collapseAll : AppIcons.expandAll,
                      label: _treeTools.allExpanded ? l.collapse : l.expand,
                      onTap: _treeTools.onlyProblems ? null : _treeTools.toggleAll,
                    ),
                  ),
                  tool(
                    l.onlyProblems,
                    BarButton(
                      icon: AppIcons.onlyProblems,
                      selectedIcon: AppIcons.onlyProblemsOn,
                      label: l.onlyProblems,
                      selected: _treeTools.onlyProblems,
                      onTap: _treeTools.toggleOnlyProblems,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          tool(
            repPos == null || repPos.comment.isEmpty ? l.addPositionComment : l.positionComment,
            BarButton(
              icon: AppIcons.comment,
              label: l.moveComment,
              onTap: inRep && repPos != null ? editComment : null,
            ),
          ),
          tool(
            l.showArrows,
            BarButton(
              icon: AppIcons.arrows,
              label: l.arrowsShort,
              selected: _arrows,
              onTap: () => setState(() => _arrows = !_arrows),
            ),
          ),
        ],
      ],
    );

    final pendingBar = inRep
        ? null
        : Appear(
            child: _PendingBar(c: c, onAdd: _addPending),
          );
    // Details scroll under a fixed board.
    final list = ListView(
      key: const PageStorageKey('repertoire-position-details'),
      padding: EdgeInsets.zero,
      children: widget.enableTree ? details.skip(1).toList() : details,
    );
    // The pinned tools go from edge to edge; the rest keeps to the column
    // of the board (a tablet in portrait).
    Widget panel(double gutter) {
      final inColumn = EdgeInsets.symmetric(horizontal: gutter);
      return widget.enableTree
          ? Column(
              children: [
                Padding(padding: inColumn, child: details.first),
                Expanded(
                  // The other view fades in; nothing moves (the board, the
                  // switch and the rows keep their places).
                  child: Padding(
                    padding: inColumn,
                    child: FadeOnChange(
                      trigger: _treeMode,
                      child: IndexedStack(
                        index: _treeMode ? 1 : 0,
                        children: [
                          list,
                          RepertoireTree(
                            c: c,
                            onOpen: _selectTreePosition,
                            problemKeys: widget.problemKeys,
                            tools: _treeTools,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                tools,
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(padding: inColumn, child: list),
                ),
                tools,
              ],
            );
    }

    // Same board geometry as every other screen with a board (D-052).
    // With a keyboard (a tablet): the arrows walk the line, as in the
    // analysis.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (c.path.isNotEmpty || c.pending.isNotEmpty) c.back();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (c.pending.isEmpty && moves.isNotEmpty) c.go(moves.first);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () async {
          if (await confirmLeavePending(context, c)) c.toRoot();
        },
      },
      child: Focus(autofocus: true, child: _layout(board, pendingBar, panel)),
    );
  }

  Widget _layout(Widget board, Widget? pendingBar, Widget Function(double gutter) panel) {
    return BoardLayout(
      board: board,
      // Room for the path, the Moves/Tree switch, a couple of moves and the
      // pinned tools: on a phone the board is a little smaller here than a
      // full-width one, and the tools never need scrolling to (D-072).
      extraBelow: (_) => kRepertoireExtraBelow,
      belowBleeds: true,
      below: (context, g) => Column(
        children: [
          if (pendingBar != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: g.gutter),
              child: pendingBar,
            ),
          Expanded(child: panel(g.gutter)),
        ],
      ),
    );
  }
}

/// Moves played on the board that are not in the repertoire yet; pinned
/// under the board so the actions are always reachable.
class _PendingBar extends StatelessWidget {
  const _PendingBar({required this.c, required this.onAdd});
  final RepertoireController c;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.newMovesShort, style: context.tt.title.copyWith(color: cs.onSecondaryContainer)),
                  MoveLineText(pendingToText(c), maxLines: 2, color: cs.onSecondaryContainer),
                ],
              ),
            ),
            IconButton(tooltip: l.undoMove, onPressed: c.back, icon: const Icon(AppIcons.undo)),
            AppGap.h4,
            Tooltip(
              message: l.addToRepertoire,
              child: FilledButton.icon(onPressed: onAdd, icon: const Icon(AppIcons.add), label: Text(l.addShort)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The row under the board (D-095), 48 high. At the start position: "Start
/// position" and how much is learned (and how many problems there are) in
/// place of the inactive back/start buttons. After moves: a white capsule
/// with back and start, a white capsule with the way here as notation (a
/// move jumps back there; moves not in the repertoire yet follow in the
/// accent colour; the moves scroll, ending at the latest one), then the
/// [actions] (the Moves / Tree switch).
class _PathLine extends ConsumerWidget {
  const _PathLine({required this.c, this.problems = 0, this.actions = const []});
  final RepertoireController c;

  /// Problems of the repertoire, named at the start position.
  final int problems;

  /// Small tools at the end of the row.
  final List<Widget> actions;

  static const double _capsule = 36;
  static const double _current = 26;
  static const double _divider = 16;
  static const double _moveDivider = 12;
  static const double _backIcon = 18;
  static const double _startIcon = 17;
  static const double _numberAlpha = 0.7;

  /// Around a move in the path, around a divider between full moves, and
  /// the path's right inner padding.
  static const double _movePadding = 5;
  static const double _dividerGap = 3;
  static const double _pathEnd = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final g = c.graph!;
    final atStart = c.path.isEmpty && c.pending.isEmpty;
    final tools = [
      for (final a in actions) ...[AppGap.h8, a],
    ];

    if (atStart) {
      final summary = ref.watch(repertoiresProvider).value?.where((r) => r.row.id == c.id).firstOrNull;
      final facts = [
        if (summary != null) l.repertoireCounts(summary.learned, summary.cards),
        if (problems > 0) l.problemsCount(problems),
      ].join(' · ');
      // At least a finger high; with large text the two lines grow it.
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.startPosition, style: context.tt.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (facts.isNotEmpty)
                      Text(facts, style: context.tt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              ...tools,
            ],
          ),
        ),
      );
    }

    final last = c.pending.isEmpty ? c.path.length - 1 : -1;
    // A move joining the path (just played) slides in (D-086).
    Widget token(
      String key,
      String number,
      String san, {
      required bool current,
      bool pending = false,
      VoidCallback? onTap,
    }) {
      final fg = current ? cs.onPrimary : (pending ? cs.secondary : cs.onSurface);
      final numberColor = current ? cs.onPrimary.withValues(alpha: _numberAlpha) : cs.onSurfaceVariant;
      final f = ref.watch(notationFormatterProvider);
      final text = Text.rich(
        TextSpan(
          children: [
            if (number.isNotEmpty)
              TextSpan(
                text: number,
                style: context.tt.moveNumber.copyWith(color: numberColor),
              ),
            ...f.spans(san, context.tt.moveMain.copyWith(color: fg)),
          ],
        ),
        maxLines: 1,
        softWrap: false,
      );
      return MoveEntrance(
        key: ValueKey(key),
        child: Semantics(
          button: onTap != null,
          selected: current,
          label: '$number${spokenSan(san, l)}'.trim(),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              height: AppSizes.tapTarget,
              child: Center(
                widthFactor: 1,
                child: current
                    ? Container(
                        height: _current,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - AppSpacing.xxs),
                        decoration: BoxDecoration(color: cs.primary, borderRadius: AppRadius.full),
                        child: Center(widthFactor: 1, child: text),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _movePadding),
                        child: text,
                      ),
              ),
            ),
          ),
        ),
      );
    }

    Widget moveDivider() => Container(
      width: AppSizes.hairline,
      height: _moveDivider,
      margin: const EdgeInsets.symmetric(horizontal: _dividerGap),
      color: cs.secondaryContainer,
    );

    final items = <Widget>[];
    for (var i = 0; i < c.path.length; i++) {
      final m = c.path[i];
      final pos = positionFromFen(g.positions[m.fromKey]!.fen);
      final white = pos.turn == Side.white;
      final number = white ? '${pos.fullmoves}. ' : (i == 0 ? '${pos.fullmoves}... ' : '');
      // Between full moves: before each move number of White.
      if (white && i > 0) items.add(moveDivider());
      items.add(
        token(
          '$i ${m.san}',
          number,
          m.san,
          current: i == last,
          onTap: () async {
            if (await confirmLeavePending(context, c)) c.truncate(i + 1);
          },
        ),
      );
    }
    for (var i = 0; i < c.pending.length; i++) {
      items.add(token('p$i ${c.pending[i].$2}', '', c.pending[i].$2, current: false, pending: true));
    }

    final capsule = BoxDecoration(
      color: cs.surfaceContainerLow,
      borderRadius: AppRadius.full,
      border: Border.all(color: cs.secondaryContainer, width: AppSizes.hairline),
    );
    Widget navButton(String tooltip, IconData icon, double size, VoidCallback onTap) => Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: AppSizes.tapTarget,
            height: AppSizes.tapTarget,
            child: Icon(icon, size: size, color: cs.onSurface),
          ),
        ),
      ),
    );
    return SizedBox(
      height: AppSizes.tapTarget,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: Row(
          children: [
            // Back and start in one capsule; each a full finger target.
            Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  top: (AppSizes.tapTarget - _capsule) / 2,
                  bottom: (AppSizes.tapTarget - _capsule) / 2,
                  child: DecoratedBox(decoration: capsule),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    navButton(l.undoMove, AppIcons.back, _backIcon, c.back),
                    Container(width: AppSizes.hairline, height: _divider, color: cs.secondaryContainer),
                    navButton(l.start, AppIcons.start, _startIcon, () async {
                      if (await confirmLeavePending(context, c)) c.toRoot();
                    }),
                  ],
                ),
              ],
            ),
            AppGap.h8,
            Expanded(
              child: Container(
                height: _capsule,
                decoration: capsule,
                clipBehavior: Clip.antiAlias,
                child: OverflowBox(
                  maxHeight: AppSizes.tapTarget,
                  child: ShaderMask(
                    // Any opaque colour: only its alpha is used (dstIn).
                    shaderCallback: (r) => LinearGradient(
                      colors: [Colors.transparent, cs.surface],
                    ).createShader(Rect.fromLTWH(0, 0, _pathFade, r.height)),
                    blendMode: BlendMode.dstIn,
                    child: LayoutBuilder(
                      builder: (context, cons) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        padding: const EdgeInsets.only(left: AppSpacing.md, right: _pathEnd),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: math.max(0, cons.maxWidth - AppSpacing.md - _pathEnd)),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: EntranceScope(
                              child: Row(mainAxisSize: MainAxisSize.min, children: items),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...tools,
          ],
        ),
      ),
    );
  }
}

/// How well the user's move here is known (D-095): a warm chip when it is
/// time to review it, otherwise the state in grey.
class _CardState extends StatelessWidget {
  const _CardState({required this.text, required this.due});
  final String text;
  final bool due;

  static const double _chip = 20;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!due) return Text(text, style: context.tt.meta, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Container(
      height: _chip,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(color: cs.flameContainer, borderRadius: AppRadius.full),
      child: Center(
        widthFactor: 1,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onFlameContainer),
          ),
        ),
      ),
    );
  }
}

/// A move from this position, one row 36 high (D-046, D-095). The
/// opponent's: the move with its weight, a bar of its share of the
/// opponent's moves here and the percentage. The user's: the role icon,
/// the move and, on the right, its comment, "end of line" or its role. The
/// row opens the move; its menu is the long press or the dots at the end.
class _MoveTile extends ConsumerWidget {
  const _MoveTile({
    required this.m,
    required this.g,
    required this.prefix,
    required this.onTap,
    required this.onMenu,
    this.share = 0,
  });
  final RepMove m;
  final RepertoireGraph g;
  final String prefix;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  /// This move's share of the opponent's moves from the position.
  final double share;

  /// The opponent's move with its weight; the share bar's thickness and the
  /// percentage column.
  static const double _moveColumn = 104;
  static const double _bar = 6;
  static const double _percent = 34;
  static const double _menuWidth = 44;
  static const double _roleIcon = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final transposes = g.movesTo(m.toKey).length > 1;
    final subtreeSize = g.movesFrom(m.toKey).length;
    final opponent = m.role == MoveRole.opponent;
    final (icon, color, label) = switch (m.role) {
      // Monochrome: the icon shape tells main from alternative.
      MoveRole.main => (AppIcons.mainMove, cs.onSurface, l.roleMain),
      MoveRole.alternative => (AppIcons.alternativeMove, cs.onSurfaceVariant, l.roleAlternative),
      MoveRole.opponent => (AppIcons.opponentMove, cs.onSurfaceVariant, l.weightShort(m.weight)),
    };
    final note = m.comment.isNotEmpty ? m.comment : (subtreeSize == 0 ? l.lineEnds : label);
    final paused = g.suspension(m.toKey).all;
    final small = context.tt.meta;
    final marks = [
      if (transposes)
        Tooltip(
          message: l.transposition,
          child: Icon(AppIcons.transposition, size: AppSizes.iconSm, color: cs.tertiary),
        ),
      if (paused)
        Tooltip(
          message: l.branchPaused,
          child: Icon(AppIcons.suspend, size: AppSizes.iconSm, color: cs.onSurfaceVariant),
        ),
    ];
    final menu = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onMenu,
      child: Tooltip(
        message: l.more,
        child: const SizedBox(
          width: _menuWidth,
          height: kMoveChipMinHeight,
          child: Icon(AppIcons.moreVertical, size: AppSizes.iconMd),
        ),
      ),
    );
    final row = opponent
        ? Row(
            children: [
              AppGap.h16,
              SizedBox(
                width: _moveColumn,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: MoveText(number: prefix, san: m.san),
                    ),
                    AppGap.h8,
                    Flexible(
                      child: Text(
                        label,
                        style: small.tabular,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
              ),
              for (final mark in marks) ...[mark, AppGap.h4],
              Expanded(
                child: AppProgressBar(value: share, height: _bar, color: cs.secondary),
              ),
              SizedBox(
                width: _percent,
                child: Text(
                  context.fmtPercent(share),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: context.tt.title.tabular,
                ),
              ),
              menu,
            ],
          )
        : Row(
            children: [
              AppGap.h16,
              SizedBox(
                width: _roleIcon,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Tooltip(
                    message: label,
                    child: Icon(icon, size: AppSizes.iconSm, color: color),
                  ),
                ),
              ),
              MoveText(number: prefix, san: m.san),
              for (final mark in marks) ...[AppGap.h4, mark],
              AppGap.h8,
              Expanded(
                child: MovesText(note, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              menu,
            ],
          );
    return Semantics(
      button: true,
      label: opponent ? '$prefix${m.san}, ${context.fmtPercent(share)}' : '$prefix${m.san}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
          child: row,
        ),
      ),
    );
  }
}

/// Exports the repertoire as PGN text (F-REP-09).
String exportRepertoirePgn(RepertoireGraph g, String name, String mode, AppLocalizations l) => gameToPgn(
  repertoireToGame(
    g,
    name: name,
    mode: mode == 'expand' ? TranspositionMode.expand : TranspositionMode.comment,
    transpositionLabel: l.transposesTo,
  )..headers['Orientation'] = g.color.name,
);
