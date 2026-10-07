import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../data/sync/gap_service.dart';
import '../../domain/gap/gap_analysis.dart';
import '../../domain/training/training_engine.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
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

  /// The user's very first move differs from the repertoire: another
  /// opening altogether, not a forgotten move (1.b3 against a 1.e4 one).
  bool get otherOpening => type == GapType.userDeviation && ply <= 2;
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

  int? _rep;
  int _days = 0;

  List<_Group> _group(List<GapRow> rows) {
    final since = _days == 0 ? null : DateTime.now().subtract(Duration(days: _days));
    final map = <String, _Group>{};
    for (final r in rows) {
      final e = r.event;
      final type = GapType.fromName(e.type);
      if (_rep != null && r.repertoireId != _rep) continue;
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
          : AppBar(
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
      body: rows.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(_gapEventsProvider)),
        data: (all) {
          if (all.isEmpty) return _empty(context);
          final groups = _group(all);
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.page, top: AppSpacing.sm, right: AppSpacing.page),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int?>(
                        icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
                        isExpanded: true,
                        value: _rep,
                        items: [
                          DropdownMenuItem(value: null, child: Text(l.allRepertoires)),
                          for (final r in reps)
                            DropdownMenuItem(
                              value: r.row.id,
                              child: Text(r.row.name, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() => _rep = v),
                      ),
                    ),
                    AppGap.h12,
                    DropdownButton<int>(
                      icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
                      value: _days,
                      items: [
                        DropdownMenuItem(value: 0, child: Text(l.allTime)),
                        DropdownMenuItem(value: 30, child: Text(l.lastDays(30))),
                        DropdownMenuItem(value: 90, child: Text(l.lastDays(90))),
                        DropdownMenuItem(value: 365, child: Text(l.lastDays(365))),
                      ],
                      onChanged: (v) => setState(() => _days = v ?? 0),
                    ),
                    IconButton(tooltip: l.reanalyze, onPressed: _rerun, icon: const Icon(AppIcons.refresh)),
                  ],
                ),
              ),
              if (groups.isEmpty) EmptyState(icon: AppIcons.search, title: l.nothingFound),
              // Sections by what happened and what to do about it (D-069);
              // the two that are not mistakes stay folded.
              ..._section(l.gapSectionForgot, [
                for (final g in groups)
                  if (g.type == GapType.userDeviation && !g.otherOpening) g,
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
              ..._section(
                l.gapSectionOther,
                [
                  for (final g in groups)
                    if (g.otherOpening) g,
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
}

extension on _GapReportScreenState {
  List<Widget> _section(String title, List<_Group> groups, List<RepertoireSummary> reps, {bool folded = false}) {
    if (groups.isEmpty) return const [];
    final games = groups.fold<int>(0, (a, g) => a + g.rows.length);
    final cards = [
      for (final (i, g) in groups.indexed) ...[
        if (i > 0) AppGap.v12,
        _GroupCard(group: g, repName: reps.where((r) => r.row.id == g.repertoireId).firstOrNull?.row.name ?? ''),
      ],
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
  const _GroupCard({required this.group, required this.repName});
  final _Group group;
  final String repName;

  /// Side of the position's board in a card.
  static const double _boardSize = 120;

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
    final first = g.rows.first;
    return Padding(
      padding: AppInsets.pageH,
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MiniBoard(
                  fen: g.fen,
                  orientation: rep?.color ?? (first.game.userColor == 'black' ? Side.black : Side.white),
                  size: _boardSize,
                ),
                AppGap.h12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusLine(
                        icon: icon,
                        text: g.otherOpening ? l.gapOtherOpening : gapTypeName(g.type, l),
                        tone: tone,
                        strong: true,
                      ),
                      AppGap.v4,
                      Text(repName, style: tt.meta),
                      AppGap.v4,
                      MovesText(switch (g.type) {
                        GapType.userDeviation when g.otherOpening => l.gapOtherText(g.playedSan),
                        GapType.userDeviation => l.gapUserText(g.playedSan, g.expectedSan),
                        GapType.opponentNovelty => l.gapOpponentText(g.playedSan),
                        GapType.endOfBook => l.gapEndText(g.playedSan),
                      }),
                      AppGap.v4,
                      Text(l.happenedInGames(g.rows.length), style: tt.title),
                    ],
                  ),
                ),
              ],
            ),
            AppGap.v8,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (g.otherOpening)
                  FilledButton.tonalIcon(
                    onPressed: () => showCreateRepertoire(context, openEditor: true),
                    icon: const Icon(AppIcons.add),
                    label: Text(l.createRepertoire),
                  )
                else if (g.type == GapType.userDeviation)
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      final learned = await ref.read(repertoireRepositoryProvider).markAgain(g.repertoireId, g.key);
                      if (!context.mounted) return;
                      await context.push(
                        '/train',
                        // A move that was never learned is shown first
                        // (Learn from this position), not quizzed.
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
                    },
                    icon: const Icon(AppIcons.drill),
                    label: Text(l.trainThisPosition),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: () => context.push(
                      '/build/${g.repertoireId}?key=${Uri.encodeQueryComponent(g.key)}&play=${g.playedUci}',
                    ),
                    icon: const Icon(AppIcons.add),
                    label: Text(g.type == GapType.opponentNovelty ? l.prepareAnswer : l.extendLine),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _showGames(context),
                  icon: const Icon(AppIcons.list),
                  label: Text(l.gamesN(g.rows.length)),
                ),
                TextButton(
                  onPressed: () async {
                    final svc = ref.read(gapServiceProvider);
                    final ids = [for (final r in g.rows) r.event.id];
                    await svc.dismiss(ids);
                    if (!context.mounted) return;
                    showSnack(
                      context,
                      l.gapDismissed,
                      action: SnackBarAction(label: l.undo, onPressed: () => svc.dismiss(ids, dismissed: false)),
                    );
                  },
                  child: Text(l.dismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGames(BuildContext context) {
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
                  extra: GameScreenArgs(pgn: r.game.pgn, initialPath: List.filled(r.event.ply - 1, 0)),
                );
              },
            ),
        ],
      ),
    );
  }
}
