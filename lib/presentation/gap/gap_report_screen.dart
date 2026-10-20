import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../data/sync/gap_service.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/gap/gap_analysis.dart';
import '../../domain/stats/opening_tree.dart';
import '../../domain/training/training_engine.dart';
import '../accounts/accounts_providers.dart';
import '../accounts/game_meta.dart';
import '../accounts/imported_game_args.dart';
import '../app/providers.dart';
import '../repertoire/create_repertoire_dialog.dart';
import '../stats/my_openings_providers.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/san_text.dart';

final _gapEventsProvider = StreamProvider.autoDispose<List<GapRow>>(
  (ref) => ref.watch(gapServiceProvider).watchEvents(),
);

class _Group {
  _Group(this.repertoireId, this.type, this.key, this.fen, this.playedSan, this.playedUci, this.expectedSan, this.ply);
  final int repertoireId;
  final GapType type;
  final String key;
  final String fen;
  final String playedSan;
  final String playedUci;
  final String expectedSan;

  /// Ply of the move in the game (1 – White's first move).
  final int ply;
  final List<GapRow> rows = [];

  /// White's very first move differs from the repertoire: perhaps another
  /// opening altogether (1.b3 against a 1.e4 one), so a new repertoire is
  /// offered too. Black's first move answers the opponent's: the
  /// repertoire has an answer there, it is an ordinary deviation (D-099).
  bool get firstMove => type == GapType.userDeviation && ply == 1;

  /// The moves of the first game up to and with the move in question
  /// ("1. e4 Nc6").
  late final String line = lineUpTo(rows.first.game.pgn, ply, fallback: playedSan);

  /// The position after the move and the move itself: the cards differ
  /// even when every move was the first one.
  late final (String, Move?) after = () {
    final pos = tryPositionFromFen(fen);
    final m = pos == null ? null : parseUciMove(pos, playedUci);
    return m == null ? (fen, null) : (pos!.play(m).fen, m);
  }();
}

/// "1. e4 Nc6": the first [ply] moves of a game in SAN ([fallback] when
/// the game does not start from the initial position).
String lineUpTo(String pgn, int ply, {String fallback = ''}) {
  final ucis = firstPlies(pgn, max: ply);
  if (ucis.length < ply) return fallback;
  Position pos = Chess.initial;
  final sb = StringBuffer();
  for (final (i, uci) in ucis.indexed) {
    final m = parseUciMove(pos, uci);
    if (m == null) return fallback;
    final (next, san) = pos.makeSan(m);
    if (sb.isNotEmpty) sb.write(' ');
    if (i.isEven) sb.write('${i ~/ 2 + 1}. ');
    sb.write(san);
    pos = next;
  }
  return sb.toString();
}

/// Report "where my games left the repertoire" (F-GAP-02, F-GAP-03).
class GapReportScreen extends ConsumerStatefulWidget {
  const GapReportScreen({super.key, this.embedded = false, this.onTab});

  /// Shown as a tab of the "My games" screen: no app bar of its own.
  final bool embedded;
  final void Function(int tab)? onTab;

  @override
  ConsumerState<GapReportScreen> createState() => _GapReportScreenState();
}

class _GapReportScreenState extends ConsumerState<GapReportScreen> {
  /// Line height of the two-line app bar title.
  static const double _titleLineHeight = 1.15;

  /// The repertoire shown (-1: all) and the period in days (0: all time).
  int _rep = -1;
  int _days = 0;

  /// A comparison started by the screen itself is running.
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCompare());
  }

  /// Games not compared yet (downloaded before, or the comparison failed)
  /// are compared on opening: the report has no "Compare" step.
  Future<void> _autoCompare() async {
    final games = await ref.read(importedGamesProvider.future);
    if (!mounted || games.isEmpty || games.every((g) => g.analyzedAt != null)) return;
    setState(() => _running = true);
    try {
      await ref.read(gapServiceProvider).analyzeAll();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, context.l10n));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  List<_Group> _group(List<GapRow> rows) {
    final since = _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));
    final map = <String, _Group>{};
    for (final r in rows) {
      final e = r.event;
      final type = GapType.fromName(e.type);
      if (_rep != -1 && r.repertoireId != _rep) continue;
      if (since != null && r.game.playedAt.isBefore(since)) continue;
      final k = '${r.repertoireId}|${e.type}|${e.positionKey}|${e.playedUci}';
      map
          .putIfAbsent(
            k,
            () => _Group(r.repertoireId, type, e.positionKey, e.fen, e.playedSan, e.playedUci, e.expectedSan, e.ply),
          )
          .rows
          .add(r);
    }
    final list = map.values.toList()..sort((a, b) => b.rows.length.compareTo(a.rows.length));
    return list;
  }

  Future<void> _rerun() async {
    final l = context.l10n;
    final h = showProgress(context, l.analyzingGames);
    try {
      final summary = await ref.read(gapServiceProvider).analyzeAll();
      h.close();
      if (!mounted) return;
      setState(() {});
      showSnack(context, l.analysisDone(summary.events));
    } catch (e) {
      h.close();
      if (mounted) showSnack(context, friendlyError(e, context.l10n));
    }
  }

  void _toGames() => widget.onTab != null ? widget.onTab!(0) : context.push('/my-games');

  /// No events: say why — no games, games not compared yet, or compared
  /// and nothing left the repertoire (often: games never reach it).
  Widget _empty(BuildContext context) {
    final l = context.l10n;
    final games = ref.watch(importedGamesProvider).value ?? const [];
    final summary = ref.read(gapServiceProvider).lastSummary;
    if (games.isEmpty) {
      return EmptyState(
        icon: AppIcons.gaps,
        title: l.noGapsYet,
        message: l.noGapsYetHint,
        actions: [FilledButton(onPressed: _toGames, child: Text(l.myGames))],
      );
    }
    if (_running) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const InlineSpinner(),
            AppGap.v12,
            Text(l.analyzingGames, style: context.tt.meta),
          ],
        ),
      );
    }
    if (summary == null && games.every((g) => g.analyzedAt == null)) {
      return EmptyState(
        icon: AppIcons.gaps,
        title: l.gapsNotAnalyzedTitle,
        message: l.gapsNotAnalyzedHint(games.length),
        actions: [FilledButton(onPressed: _rerun, child: Text(l.compareNow))],
      );
    }
    return EmptyState(
      icon: AppIcons.gaps,
      title: l.gapsNoneTitle,
      message: summary == null
          ? l.gapsAnalyzedHint
          : summary.reached == 0
          ? l.gapsNoneReached(summary.games)
          : l.gapsAllInBook(summary.games, summary.reached),
      actions: [OutlinedButton(onPressed: _toGames, child: Text(l.myGames))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = ref.watch(_gapEventsProvider);
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    return Scaffold(
      appBar: widget.embedded
          ? null
          : PageBar(
              bar: AppBar(
                // Long in Ukrainian: two lines instead of "Мої партії та реп…".
                title: Text(
                  l.gapsTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(height: _titleLineHeight),
                ),
                actions: [
                  IconButton(
                    tooltip: l.myOpeningsTitle,
                    onPressed: () => context.push('/my-openings'),
                    icon: const Icon(AppIcons.myOpenings),
                  ),
                  IconButton(
                    tooltip: l.myGames,
                    onPressed: () => context.push('/my-games'),
                    icon: const Icon(AppIcons.myGames),
                  ),
                  IconButton(tooltip: l.reanalyze, onPressed: _rerun, icon: const Icon(AppIcons.refresh)),
                ],
              ),
            ),
      body: rows.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(_gapEventsProvider)),
        data: (all) {
          if (all.isEmpty) return _empty(context);
          final groups = _group(all);
          final habit = _habit(groups, reps);
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.listBottom).inPage(context),
            children: [
              if (_running) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.sm, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          FilterPill<int>(
                            label: reps.where((r) => r.row.id == _rep).firstOrNull?.row.name ?? l.allRepertoires,
                            items: [(-1, l.allRepertoires), for (final r in reps) (r.row.id, r.row.name)],
                            onSelected: (v) => setState(() => _rep = v),
                          ),
                          FilterPill<int>(
                            label: _days == 0 ? l.allTime : l.lastDays(_days),
                            items: [(0, l.allTime), (30, l.lastDays(30)), (90, l.lastDays(90)), (365, l.lastDays(365))],
                            onSelected: (v) => setState(() => _days = v),
                          ),
                        ],
                      ),
                    ),
                    IconButton(tooltip: l.reanalyze, onPressed: _rerun, icon: const Icon(AppIcons.refresh)),
                  ],
                ),
              ),
              if (groups.isEmpty) EmptyState(icon: AppIcons.search, title: l.nothingFound),
              // What the user plays instead of the repertoire most of the
              // time comes first, on its own (D-099).
              if (habit != null) ...[
                AppGap.v8,
                _GroupCard(group: habit.$1, repName: _repName(habit.$1, reps), share: (habit.$2, habit.$3)),
              ],
              // Sections by what happened and what to do about it (D-069);
              // a line that ended is not a mistake and stays folded.
              ..._section(l.gapSectionForgot, [
                for (final g in groups)
                  if (g.type == GapType.userDeviation && g != habit?.$1) g,
              ], reps),
              ..._section(l.gapSectionNovelty, [
                for (final g in groups)
                  if (g.type == GapType.opponentNovelty) g,
              ], reps),
              ..._section(
                l.gapSectionEnd,
                [
                  for (final g in groups)
                    if (g.type == GapType.endOfBook) g,
                ],
                reps,
                folded: true,
              ),
            ],
          );
        },
      ),
    );
  }

  /// The repertoire's name on a card, when there is more than one.
  String? _repName(_Group g, List<RepertoireSummary> reps) =>
      reps.length < 2 ? null : reps.where((r) => r.row.id == g.repertoireId).firstOrNull?.row.name;

  /// The most frequent deviation when it is a habit rather than a slip: at
  /// least 5 games and a quarter of the games of that colour. With the
  /// games of that colour in the period.
  (_Group, int, Side)? _habit(List<_Group> groups, List<RepertoireSummary> reps) {
    final top = groups.where((g) => g.type == GapType.userDeviation).firstOrNull;
    if (top == null || top.rows.length < _habitMinGames) return null;
    final side =
        reps.where((r) => r.row.id == top.repertoireId).firstOrNull?.color ??
        (top.rows.first.game.userColor == 'black' ? Side.black : Side.white);
    final since = _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));
    final games = ref.watch(importedGamesProvider).value ?? const [];
    final total = games.where((g) => g.userColor == side.name && (since == null || !g.playedAt.isBefore(since))).length;
    if (total == 0 || top.rows.length < total * _habitShare) return null;
    return (top, total, side);
  }

  static const int _habitMinGames = 5;
  static const double _habitShare = 0.25;
}

extension on _GapReportScreenState {
  List<Widget> _section(String title, List<_Group> groups, List<RepertoireSummary> reps, {bool folded = false}) {
    if (groups.isEmpty) return const [];
    final games = groups.fold<int>(0, (a, g) => a + g.rows.length);
    final cards = [
      for (final (i, g) in groups.indexed) ...[if (i > 0) AppGap.v12, _GroupCard(group: g, repName: _repName(g, reps))],
    ];
    final l = context.l10n;
    if (!folded) return [SectionHeader('$title · ${l.gamesCountShort(games)}'), ...cards];
    return [
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: AppExpansionTile(title: Text(title), subtitle: Text(l.gamesCountShort(games)), children: cards),
      ),
    ];
  }
}

String gapTypeName(GapType t, AppLocalizations l) => switch (t) {
  GapType.userDeviation => l.gapUserDeviation,
  GapType.opponentNovelty => l.gapOpponentNovelty,
  GapType.endOfBook => l.gapEndOfBook,
};

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group, required this.repName, this.share});
  final _Group group;

  /// Shown when the user has more than one repertoire.
  final String? repName;

  /// The habit card on top: games of the colour and the colour.
  final (int, Side)? share;

  /// Side of the position's board in a card.
  static const double _boardSize = 88;

  Future<void> _train(BuildContext context, WidgetRef ref) async {
    final g = group;
    final learned = await ref.read(repertoireRepositoryProvider).markAgain(g.repertoireId, g.key);
    if (!context.mounted) return;
    await context.push(
      '/train',
      // A move that was never learned is shown first (Learn from this
      // position), not quizzed.
      extra: learned
          ? TrainingArgs(
              repertoireIds: [g.repertoireId],
              mode: TrainingMode.problems,
              problemKeys: {
                g.repertoireId: [g.key],
              },
            )
          : TrainingArgs(repertoireIds: [g.repertoireId], mode: TrainingMode.learn, startKey: g.key),
    );
  }

  /// Opens the repertoire at the position and plays [uci] there, which
  /// adds it: the user's own move, or the opponent's to answer.
  void _build(BuildContext context) =>
      context.push('/build/${group.repertoireId}?key=${Uri.encodeQueryComponent(group.key)}&play=${group.playedUci}');

  Future<void> _hide(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final svc = ref.read(gapServiceProvider);
    final ids = [for (final r in group.rows) r.event.id];
    await svc.dismiss(ids);
    if (!context.mounted) return;
    showSnack(
      context,
      l.gapDismissed,
      action: SnackBarAction(label: l.undo, onPressed: () => svc.dismiss(ids, dismissed: false)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tt = context.tt;
    final g = group;
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final rep = reps.where((r) => r.row.id == g.repertoireId).firstOrNull;
    final (icon, tone) = switch (g.type) {
      GapType.userDeviation => (AppIcons.error, Tone.error),
      GapType.opponentNovelty => (AppIcons.help, Tone.warning),
      GapType.endOfBook => (AppIcons.flag, Tone.neutral),
    };
    final (afterFen, move) = g.after;
    final habit = share;
    final count = g.rows.length;
    final deviation = g.type == GapType.userDeviation;
    final menu = AppMenuButton<String>(
      icon: const Icon(AppIcons.more),
      tooltip: l.more,
      onSelected: (v) {
        switch (v) {
          case 'add':
            _build(context);
          case 'create':
            unawaited(showCreateRepertoire(context, openEditor: true));
          case 'games':
            _showGames(context, ref);
          default:
            unawaited(_hide(context, ref));
        }
      },
      itemBuilder: (_) => [
        if (deviation && habit == null) appMenuItem(value: 'add', label: l.gapAddMyMove(g.playedSan)),
        if (g.firstMove) appMenuItem(value: 'create', label: l.createRepertoire),
        if (habit != null) appMenuItem(value: 'games', label: l.gamesN(count)),
        appMenuItem(value: 'hide', label: l.dismiss),
      ],
    );
    return Padding(
      padding: AppInsets.pageH,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (habit != null) ...[Text(l.gapHabitTitle, style: tt.title), AppGap.v12],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniBoard(
                  fen: afterFen,
                  lastMove: move,
                  orientation: rep?.color ?? (g.rows.first.game.userColor == 'black' ? Side.black : Side.white),
                  size: _boardSize,
                ),
                AppGap.h12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (habit == null) StatusLine(icon: icon, text: gapTypeName(g.type, l), tone: tone),
                      MovesText(g.line, style: tt.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                      AppGap.v4,
                      MovesText(switch (g.type) {
                        GapType.userDeviation => l.gapExpected(g.expectedSan),
                        GapType.opponentNovelty => l.gapNotInRepertoire,
                        GapType.endOfBook => l.gapLineEnded,
                      }),
                      AppGap.v4,
                      Text(
                        [
                          if (habit != null)
                            l.gapHabitShare(
                              count,
                              habit.$1,
                              habit.$2 == Side.white ? l.inSentenceAsWhite : l.inSentenceAsBlack,
                            )
                          else
                            l.gamesCountShort(count),
                          ?repName,
                        ].join(' · '),
                        style: tt.meta,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppGap.v8,
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (deviation)
                        FilledButton.tonal(
                          style: AppButtonSize.compact,
                          onPressed: () => _train(context, ref),
                          child: MovesText(l.gapLearnMove(g.expectedSan)),
                        )
                      else
                        FilledButton.tonal(
                          style: AppButtonSize.compact,
                          onPressed: () => _build(context),
                          child: Text(g.type == GapType.opponentNovelty ? l.prepareAnswer : l.extendLine),
                        ),
                      if (habit != null)
                        OutlinedButton(
                          style: AppButtonSize.compact,
                          onPressed: () => _build(context),
                          child: MovesText(l.gapAddMove(g.playedSan)),
                        )
                      else
                        OutlinedButton(
                          style: AppButtonSize.compact,
                          onPressed: () => _showGames(context, ref),
                          child: Text(l.gamesN(count)),
                        ),
                    ],
                  ),
                ),
                menu,
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGames(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final df = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    showAppSheet<void>(
      context,
      scrollable: false,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          for (final r in group.rows)
            ListTile(
              title: Text(l.vsOpponent(r.game.opponent)),
              subtitle: Text(
                '${df.format(r.game.playedAt)} · ${r.game.provider == 'lichess' ? 'Lichess' : 'Chess.com'}',
              ),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  '/analysis',
                  extra: importedGameArgs(
                    context,
                    r.game,
                    meta: ref.read(gameMetaProvider).value?[r.game.id],
                    exit: (r.event.ply, r.event.playedSan),
                    order: [for (final x in group.rows) x.game.id],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
