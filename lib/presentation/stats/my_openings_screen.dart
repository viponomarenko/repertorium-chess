import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../../domain/stats/opening_tree.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../repertoire/import_wizard_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/board_layout.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';
import 'my_openings_providers.dart';

final _graphProvider = FutureProvider.autoDispose.family<RepertoireGraph, int>(
  (ref, id) => ref.watch(repertoireRepositoryProvider).loadGraph(id),
);

/// Columns of a move's row in the tree, before the text scale: the move
/// with its mark, its share of the games, the number of games.
const _moveColumn = 92.0;
const _shareColumn = 44.0;
const _gamesColumn = 36.0;

/// The list of games takes at most this share of the screen height.
const _gamesSheetShare = 0.7;

/// A line of facts under the path, aligned with the screen margin.
const _factPadding = EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.page, bottom: AppSpacing.xxs);

/// "1. e4 c5 2. Nf3" for moves from the initial position.
String _lineText(List<String> sans, {int from = 0}) {
  final sb = StringBuffer();
  for (var i = 0; i < sans.length; i++) {
    final ply = from + i;
    if (sb.isNotEmpty) sb.write(' ');
    if (ply.isEven) {
      sb.write('${ply ~/ 2 + 1}. ${sans[i]}');
    } else {
      sb.write(i == 0 ? '${ply ~/ 2 + 1}... ${sans[i]}' : sans[i]);
    }
  }
  return sb.toString();
}

/// A game of [ucis] from the initial position (to add to a repertoire).
ChessGame _gameOf(List<String> ucis) {
  final g = ChessGame.fromFen(Chess.initial.fen);
  var n = g.root;
  for (final u in ucis) {
    final m = parseUciMove(n.position, u);
    if (m == null) break;
    n = n.addMove(m);
  }
  return g;
}

/// The user's own opening statistics (D-048): the most frequent variations
/// and a tree to walk, both compared with a repertoire of that colour.
class MyOpeningsScreen extends ConsumerStatefulWidget {
  const MyOpeningsScreen({super.key, this.embedded = false, this.onTab});

  /// Shown as a tab of the "My games" screen: no app bar of its own, and
  /// "Variations / Tree" as a small switch instead of a second tab bar.
  final bool embedded;
  final void Function(int tab)? onTab;

  @override
  ConsumerState<MyOpeningsScreen> createState() => _MyOpeningsScreenState();
}

class _MyOpeningsScreenState extends ConsumerState<MyOpeningsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  MyGamesFilter _filter = const MyGamesFilter(color: Side.white);

  /// Plies per variation: to move 2, 3, 5 (blitz games rarely share more).
  int _plies = 6;

  /// The tree position: moves from the start.
  List<String> _path = const [];

  /// Repertoire to compare with (-1: none; null: the first of the colour).
  int? _repId;

  @override
  void initState() {
    super.initState();
    // Keeps the small switch in step when a row opens the tree.
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    // Someone who only has repertoires for Black starts on their games as
    // Black (the filter used to open on White with nothing to compare).
    final reps = ref.read(repertoiresProvider).value ?? const <RepertoireSummary>[];
    if (reps.isNotEmpty && reps.every((r) => r.color == Side.black)) {
      _filter = const MyGamesFilter(color: Side.black);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  RepertoireSummary? _repertoire(List<RepertoireSummary> reps) {
    final ofColor = reps.where((r) => r.color == _filter.color).toList();
    if (_repId == -1) return null;
    return ofColor.where((r) => r.row.id == _repId).firstOrNull ?? ofColor.firstOrNull;
  }

  void _openInTree(List<String> ucis) {
    setState(() => _path = ucis);
    _tabs.animateTo(1);
  }

  Future<void> _addToRepertoire(List<String> ucis, RepertoireSummary? rep) async {
    await context.push(
      '/rep-import',
      extra: RepImportRequest(
        games: [_gameOf(ucis)],
        targetRepertoireId: rep?.row.id,
        defaultColor: _filter.color,
        sourceLabel: context.l10n.myOpeningsTitle,
      ),
    );
    ref.invalidate(_graphProvider);
  }

  Future<void> _showGames(List<int> ids) async {
    final l = context.l10n;
    final all = ref.read(importedGamesProvider).value ?? const <ImportedGameRow>[];
    final games = [
      for (final g in all)
        if (ids.contains(g.id)) g,
    ];
    await showAppSheet<void>(
      context,
      scrollable: false,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * _gamesSheetShare),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in games)
              ListTile(
                leading: Icon(g.provider == 'lichess' ? AppIcons.online : AppIcons.myGames),
                title: Text(l.vsOpponent(g.opponent.isEmpty ? '?' : g.opponent)),
                subtitle: Text('${context.fmtShortDate(g.playedAt)} · ${g.result}'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/analysis', extra: GameScreenArgs(pgn: g.pgn));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final rep = _repertoire(reps);
    final graph = rep == null ? null : ref.watch(_graphProvider(rep.row.id)).value;
    final tree = ref.watch(myOpeningTreeProvider(_filter));
    void toGames() => widget.onTab != null ? widget.onTab!(0) : context.push('/my-games');
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(l.myOpeningsTitle),
              actions: [
                IconButton(
                  tooltip: l.myGames,
                  onPressed: () => context.push('/my-games'),
                  icon: const Icon(AppIcons.download),
                ),
              ],
              bottom: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l.tabVariations),
                  Tab(text: l.tabTree),
                ],
              ),
            ),
      body: Column(
        children: [
          if (widget.embedded)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.sm, right: AppSpacing.md),
              child: ChoiceSegments<int>(
                options: [ChoiceOption(0, l.tabVariations), ChoiceOption(1, l.tabTree)],
                selected: _tabs.index,
                onChanged: (i) => setState(() => _tabs.index = i),
              ),
            ),
          _filters(context, reps, rep),
          Expanded(
            child: tree.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorState(onRetry: () => ref.invalidate(myOpeningTreeProvider(_filter))),
              data: (t) => t.totalGames == 0
                  ? EmptyState(
                      icon: AppIcons.myGames,
                      title: l.myOpeningsEmpty,
                      message: l.myOpeningsEmptyHint,
                      actions: [FilledButton(onPressed: toGames, child: Text(l.myGames))],
                    )
                  : TabBarView(
                      controller: _tabs,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [_variations(context, t, graph), _tree(context, t, graph, rep)],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Colour, source, period and the repertoire to compare with.
  Widget _filters(BuildContext context, List<RepertoireSummary> reps, RepertoireSummary? rep) {
    final l = context.l10n;
    final ofColor = reps.where((r) => r.color == _filter.color).toList();
    final source = switch (_filter.provider) {
      'lichess' => 'Lichess',
      'chesscom' => 'Chess.com',
      _ => l.all,
    };
    final period = switch (_filter.days) {
      365 => l.periodYear,
      92 => l.period3Months,
      _ => l.allTime,
    };
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.xs, right: AppSpacing.md),
      child: Align(
        alignment: Alignment.center,
        child: Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilterPill<Side>(
              label: _filter.color == Side.white ? l.asWhite : l.asBlack,
              items: [(Side.white, l.asWhite), (Side.black, l.asBlack)],
              onSelected: (c) => setState(() {
                _filter = _filter.copyWith(color: c);
                _path = const [];
                _repId = null;
              }),
            ),
            FilterPill<String?>(
              label: source,
              items: [(null, l.all), ('lichess', 'Lichess'), ('chesscom', 'Chess.com')],
              onSelected: (v) => setState(() => _filter = _filter.copyWith(provider: v, clearProvider: v == null)),
            ),
            FilterPill<int?>(
              label: period,
              items: [(null, l.allTime), (365, l.periodYear), (92, l.period3Months)],
              onSelected: (v) => setState(() => _filter = _filter.copyWith(days: v, clearDays: v == null)),
            ),
            FilterPill<int>(
              label: rep == null ? l.noCompare : l.compareWith(rep.row.name),
              items: [(-1, l.noCompare), for (final r in ofColor) (r.row.id, r.row.name)],
              onSelected: (v) => setState(() => _repId = v),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ variations

  Widget _variations(BuildContext context, OpeningTree t, RepertoireGraph? graph) {
    final l = context.l10n;
    final list = t.topVariations(plies: _plies);
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: ChoiceSegments<int>(
            options: [ChoiceOption(4, l.upToMove(2)), ChoiceOption(6, l.upToMove(3)), ChoiceOption(10, l.upToMove(5))],
            selected: _plies,
            onChanged: (v) => setState(() => _plies = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
          child: Text(l.gamesCount(t.totalGames), style: context.tt.meta),
        ),
        for (final v in list) _VariationRow(v: v, total: t.totalGames, graph: graph, onTap: () => _openInTree(v.ucis)),
      ],
    );
  }

  // ------------------------------------------------------------ tree

  Widget _tree(BuildContext context, OpeningTree t, RepertoireGraph? graph, RepertoireSummary? rep) {
    final l = context.l10n;
    Position pos = Chess.initial;
    final sans = <String>[];
    for (final u in _path) {
      final m = parseUciMove(pos, u);
      if (m == null) break;
      final (next, san) = pos.makeSan(m);
      sans.add(san);
      pos = next;
    }
    final stat = t.at(positionKeyOf(pos));
    final fit = graph == null ? null : fitRepertoire(graph, _path);
    final small = context.tt.meta;
    // Same board geometry as every other screen with a board (D-052).
    return BoardLayout(
      board: BoardView(position: pos, orientation: _filter.color!, semanticsLabel: l.boardLabel),
      below: (context, g) => Column(
        children: [
          Row(
            children: [
              AppGap.h4,
              IconButton(
                tooltip: l.undoMove,
                onPressed: _path.isEmpty ? null : () => setState(() => _path = _path.sublist(0, _path.length - 1)),
                icon: const Icon(AppIcons.back, size: AppSizes.iconMd),
              ),
              IconButton(
                tooltip: l.start,
                onPressed: _path.isEmpty ? null : () => setState(() => _path = const []),
                icon: const Icon(AppIcons.start, size: AppSizes.iconMd),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: sans.isEmpty
                      ? Text(l.start, style: context.tt.meta)
                      : Row(
                          children: [
                            for (var i = 0; i < sans.length; i++)
                              MoveChip(
                                number: i.isEven ? '${i ~/ 2 + 1}. ' : '',
                                san: sans[i],
                                current: i == sans.length - 1,
                                tapHeight: AppSizes.tapTarget,
                                onTap: () => setState(() => _path = _path.sublist(0, i + 1)),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          if (stat != null)
            Padding(
              padding: _factPadding,
              child: Row(
                children: [
                  Expanded(child: Text(l.gamesCount(stat.score.games), style: small)),
                  Text(l.scoreLine(stat.score.wins, stat.score.draws, stat.score.losses), style: small.tabular),
                ],
              ),
            ),
          if (fit != null && !fit.inBook && (fit.leftAtPly ?? 0) <= _path.length)
            Padding(
              padding: _factPadding,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusLine(icon: AppIcons.warning, text: l.outOfBookHere, tone: Tone.warning),
              ),
            ),
          Expanded(
            child: stat == null || stat.moves.isEmpty
                ? Center(child: Text(l.explorerMineEmpty, style: small))
                : ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    children: [
                      for (final m in stat.sortedMoves)
                        _MoveStatRow(
                          m: m,
                          prefix: pos.turn == Side.white ? '${pos.fullmoves}. ' : '${pos.fullmoves}... ',
                          total: stat.score.games,
                          marker: fit == null || !fit.inBook ? null : _marker(graph!, [..._path, m.uci], pos),
                          onTap: () => setState(() => _path = [..._path, m.uci]),
                          onMenu: () => _moveMenu(m, rep),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// In the repertoire, a user move off it, or an opponent move without an
  /// answer; for a position that is itself in the repertoire.
  _Marker _marker(RepertoireGraph graph, List<String> ucis, Position pos) {
    final f = fitRepertoire(graph, ucis);
    if (f.inBook) return _Marker.inBook;
    return pos.turn == graph.color ? _Marker.userLeft : _Marker.gap;
  }

  Future<void> _moveMenu(MoveStat m, RepertoireSummary? rep) async {
    final l = context.l10n;
    await showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.addToRepertoire),
            title: Text(l.addToRepertoire),
            subtitle: rep == null ? null : Text(rep.row.name),
            onTap: () {
              Navigator.pop(ctx);
              _addToRepertoire([..._path, m.uci], rep);
            },
          ),
          ListTile(
            leading: const Icon(AppIcons.list),
            title: Text(l.gamesN(m.gameIds.length)),
            onTap: () {
              Navigator.pop(ctx);
              _showGames(m.gameIds);
            },
          ),
        ],
      ),
    );
  }
}

enum _Marker { inBook, userLeft, gap }

/// One frequent variation: the moves, how often, how it scores, and how it
/// relates to the repertoire.
class _VariationRow extends StatelessWidget {
  const _VariationRow({required this.v, required this.total, required this.graph, required this.onTap});
  final VariationStat v;
  final int total;
  final RepertoireGraph? graph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final small = context.tt.meta;
    final fit = graph == null ? null : fitRepertoire(graph!, v.ucis);
    Widget? fitLine;
    if (fit != null) {
      final (icon, color, text) = fit.inBook
          ? (AppIcons.okFilled, cs.success, l.fitInBook)
          : () {
              final i = (fit.leftAtPly ?? 1) - 1;
              final move = i < v.sans.length ? _lineText([v.sans[i]], from: i) : '';
              return fit.userLeft
                  ? (AppIcons.error, cs.error, l.fitUserLeft(move))
                  : (AppIcons.help, cs.warning, l.fitOpponentLeft(move));
            }();
      // A [StatusLine] whose words may hold a move: the notation setting
      // applies to it.
      fitLine = Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: color),
          AppGap.h4,
          Expanded(
            child: MovesText(
              text,
              style: small.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: MoveLineText(_lineText(v.sans))),
                AppGap.h8,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${v.score.games}', style: context.tt.title.tabular),
                    Text(context.fmtPercent(v.score.games / math.max(1, total)), style: small.tabular),
                  ],
                ),
              ],
            ),
            AppGap.v4,
            ScoreBar(score: v.score),
            if (fitLine != null) ...[AppGap.v4, fitLine],
          ],
        ),
      ),
    );
  }
}

class _MoveStatRow extends StatelessWidget {
  const _MoveStatRow({
    required this.m,
    required this.prefix,
    required this.total,
    required this.marker,
    required this.onTap,
    required this.onMenu,
  });
  final MoveStat m;
  final String prefix;
  final int total;
  final _Marker? marker;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final scale = MediaQuery.textScalerOf(context);
    final small = context.tt.meta.tabular;
    final (IconData? icon, Color? color, String? tip) = switch (marker) {
      _Marker.inBook => (AppIcons.okFilled, cs.success, l.fitInBook),
      _Marker.userLeft => (AppIcons.error, cs.error, l.moveNotInRep),
      _Marker.gap => (AppIcons.help, cs.warning, l.moveGap),
      null => (null, null, null),
    };
    return InkWell(
      onTap: onTap,
      onLongPress: onMenu,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Row(
          children: [
            AppGap.h16,
            SizedBox(
              width: scale.scale(_moveColumn),
              child: Row(
                children: [
                  Flexible(
                    child: MoveText(number: prefix, san: m.san),
                  ),
                  if (icon != null)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: Tooltip(
                        message: tip,
                        child: Icon(icon, size: AppSizes.iconSm, color: color),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: scale.scale(_shareColumn),
              child: Text(context.fmtPercent(m.score.games / math.max(1, total)), style: small),
            ),
            SizedBox(
              width: scale.scale(_gamesColumn),
              child: Text('${m.score.games}', style: small),
            ),
            Expanded(child: ScoreBar(score: m.score)),
            IconButton(
              tooltip: l.more,
              onPressed: onMenu,
              icon: const Icon(AppIcons.moreVertical, size: AppSizes.iconMd),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wins / draws / losses of the user as one bar (green, grey, red): the
/// shared [ResultBar] for a [Score].
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.score});
  final Score score;

  @override
  Widget build(BuildContext context) =>
      ResultBar.score(context, wins: score.wins, draws: score.draws, losses: score.losses);
}
