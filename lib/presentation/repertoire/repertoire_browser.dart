import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
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

/// The column of the role icon in a row of the position's moves.
const _roleColumn = 44.0;

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
    final flag = repPos == null ? null : EngineFlag.decode(repPos.engineFlag);

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
          ?trailing,
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
        actions: [
          if (widget.enableTree)
            PillSwitch(
              key: const ValueKey('repertoire-view-switch'),
              labels: [l.positionDetails, l.tabTree],
              selected: _treeMode ? 1 : 0,
              onChanged: (i) => setState(() => _treeMode = i == 1),
            ),
        ],
      ),
      if (opening != null)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.page, bottom: AppSpacing.xxs),
          child: Text('${opening.eco} · ${opening.name}', style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      // Whose moves these are, and for the user's own: how well the move
      // is known. One small line (it used to be a line and a header).
      if (inRep)
        infoLine(
          userTurn ? AppIcons.card : AppIcons.opponentMove,
          Text(
            userTurn && (card != null || moves.isNotEmpty)
                ? '${l.yourMoves} · ${cardStatus(card, l, fsrs, deferred: repPos?.conflictDeferred ?? false)}'
                : (userTurn ? l.yourMoves : l.opponentMoves),
            style: small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: repPos?.conflictDeferred ?? false
              ? TextButton(onPressed: () => c.setDeferred(key, false), child: Text(l.resolve))
              : null,
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
      if (flag != null)
        infoLine(
          AppIcons.warning,
          MovesText(
            '${l.engineFlagTitle(context.fmtDecimal(flag.lossCp / 100))} · ${l.engineFlagHint(flag.bestSan, flag.depth)}',
            style: small,
          ),
          color: theme.colorScheme.warning,
        ),
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
        _MoveTile(m: m, g: g, prefix: moveNumberPrefix(pos), onTap: () => c.go(m), onMenu: () => _moveMenu(m)),
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
            label: l.trainFromHere,
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
    final panel = widget.enableTree
        ? Column(
            children: [
              details.first,
              Expanded(
                // The other view fades in; nothing moves (the board, the
                // switch and the rows keep their places).
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
              tools,
            ],
          )
        : Column(
            children: [
              Expanded(child: list),
              tools,
            ],
          );
    // Same board geometry as every other screen with a board (D-052).
    return BoardLayout(
      board: board,
      // Room for the path, the Moves/Tree switch, a couple of moves and the
      // pinned tools: on a phone the board is a little smaller here than a
      // full-width one, and the tools never need scrolling to (D-072).
      extraBelow: (_) => kRepertoireExtraBelow,
      below: (context, g) => Column(
        children: [
          ?pendingBar,
          Expanded(child: panel),
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

/// The way to this position as one line of notation ("1. e4 e5 2. Nf3"):
/// a move jumps back there; the home icon goes to the start. Moves not in
/// the repertoire yet follow in the accent colour. The back arrow stays put
/// clear of the screen edge; the moves scroll, ending at the latest one.
class _PathLine extends ConsumerWidget {
  const _PathLine({required this.c, this.actions = const []});
  final RepertoireController c;

  /// Small tools at the end of the row.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final g = c.graph!;
    final last = c.pending.isEmpty ? c.path.length - 1 : -1;

    // Same fonts, sizes and chip as the notation (D-052).
    Widget token(String number, String san, {required bool current, bool pending = false, VoidCallback? onTap}) =>
        MoveChip(
          number: number,
          san: san,
          current: current,
          color: pending ? theme.colorScheme.secondary : null,
          onTap: onTap,
          tapHeight: AppSizes.tapTarget,
        );

    final items = <Widget>[];
    for (var i = 0; i < c.path.length; i++) {
      final m = c.path[i];
      final pos = positionFromFen(g.positions[m.fromKey]!.fen);
      final number = pos.turn == Side.white ? '${pos.fullmoves}. ' : (i == 0 ? '${pos.fullmoves}... ' : '');
      items.add(
        token(
          number,
          m.san,
          current: i == last,
          onTap: () async {
            if (await confirmLeavePending(context, c)) c.truncate(i + 1);
          },
        ),
      );
    }
    for (final p in c.pending) {
      items.add(token('', p.$2, current: false, pending: true));
    }
    return LayoutBuilder(
      builder: (context, row) => Row(
        children: [
          AppGap.h4,
          IconButton(
            tooltip: l.undoMove,
            onPressed: c.path.isEmpty && c.pending.isEmpty ? null : c.back,
            icon: const Icon(AppIcons.back, size: AppSizes.iconMd),
          ),
          IconButton(
            tooltip: l.start,
            onPressed: c.path.isEmpty && c.pending.isEmpty
                ? null
                : () async {
                    if (await confirmLeavePending(context, c)) c.toRoot();
                  },
            icon: const Icon(AppIcons.start, size: AppSizes.iconMd),
          ),
          Expanded(
            child: ShaderMask(
              // Any opaque colour: only its alpha is used (dstIn).
              shaderCallback: (r) =>
                  LinearGradient(colors: [Colors.transparent, theme.colorScheme.surface])
                      .createShader(Rect.fromLTWH(0, 0, _pathFade, r.height)),
              blendMode: BlendMode.dstIn,
              child: LayoutBuilder(
                builder: (context, cons) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  padding: const EdgeInsets.only(left: AppSpacing.sm, right: _pathFade),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: math.max(0, cons.maxWidth - AppSpacing.sm - _pathFade)),
                    child: items.isEmpty
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Text(l.start, style: context.tt.meta),
                          )
                        : Row(children: items),
                  ),
                ),
              ),
            ),
          ),
          // At most two thirds of the room after the buttons: in a narrow
          // panel with a large text the words are cut, the row never overflows.
          for (final a in actions)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.max(0, row.maxWidth - 2 * AppSizes.tapTarget) * 2 / 3),
              child: a,
            ),
          AppGap.h4,
        ],
      ),
    );
  }
}

class _MoveTile extends ConsumerWidget {
  const _MoveTile({required this.m, required this.g, required this.prefix, required this.onTap, required this.onMenu});
  final RepMove m;
  final RepertoireGraph g;
  final String prefix;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final transposes = g.movesTo(m.toKey).length > 1;
    final subtreeSize = g.movesFrom(m.toKey).length;
    final (icon, color, label) = switch (m.role) {
      // Monochrome: the icon shape tells main from alternative.
      MoveRole.main => (AppIcons.mainMove, theme.colorScheme.onSurface, l.roleMain),
      MoveRole.alternative => (AppIcons.alternativeMove, theme.colorScheme.onSurfaceVariant, l.roleAlternative),
      MoveRole.opponent => (AppIcons.opponentMove, theme.colorScheme.onSurfaceVariant, l.weightShort(m.weight)),
    };
    final note = m.comment.isNotEmpty ? m.comment : (subtreeSize == 0 ? l.lineEnds : '');
    final paused = g.suspension(m.toKey).all;
    final small = context.tt.meta;
    // One dense row, as high as a row of notation (36, D-046): role icon,
    // the move, its note on the same line. The row is one target for
    // "open"; its menu is the long press or the dots at the end.
    return Semantics(
      button: true,
      label: '$prefix${m.san}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kMoveChipMinHeight),
          child: Row(
            children: [
              SizedBox(
                width: _roleColumn,
                child: Tooltip(
                  message: label,
                  child: Icon(icon, size: AppSizes.iconMd, color: color),
                ),
              ),
              MoveText(number: prefix, san: m.san),
              if (transposes) ...[
                AppGap.h4,
                Tooltip(
                  message: l.transposition,
                  child: Icon(AppIcons.transposition, size: AppSizes.iconSm, color: theme.colorScheme.tertiary),
                ),
              ],
              AppGap.h8,
              Expanded(
                child: MovesText(note, style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (paused) ...[
                Tooltip(
                  message: l.branchPaused,
                  child: Icon(AppIcons.suspend, size: AppSizes.iconSm, color: theme.colorScheme.onSurfaceVariant),
                ),
                AppGap.h8,
              ],
              if (m.role == MoveRole.opponent) Text(label, style: small.tabular),
              // As wide as a finger, as high as the row.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMenu,
                child: Tooltip(
                  message: l.more,
                  child: const SizedBox(
                    width: AppSizes.tapTarget,
                    height: kMoveChipMinHeight,
                    child: Icon(AppIcons.moreVertical, size: AppSizes.iconMd),
                  ),
                ),
              ),
            ],
          ),
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
