import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/lichess/explorer_service.dart';
import '../../data/lichess/lichess_client.dart';
import '../../domain/chess/chess_utils.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../stats/my_openings_providers.dart';
import '../stats/my_openings_screen.dart' show ScoreBar;
import '../theme/app_icons.dart';
import 'common.dart';
import 'errors.dart';
import 'san_text.dart';

typedef _ExplorerArgs = ({String fen, String db});

final explorerLookupProvider = FutureProvider.autoDispose.family<ExplorerResult, _ExplorerArgs>((ref, a) {
  final s = ref.read(settingsProvider);
  final q = ExplorerQuery(db: a.db, speeds: s.explorerSpeeds, ratings: s.explorerRatings);
  return ref.read(explorerServiceProvider).lookup(a.fen, q);
});

/// Lichess Opening Explorer panel (F-LI-09): moves, number of games and
/// W/D/L. Requires a Lichess login (the API needs a token since 2026).
class ExplorerPanel extends ConsumerStatefulWidget {
  const ExplorerPanel({super.key, required this.fen, this.onPlay, this.highlightUcis = const {}});
  final String fen;
  final void Function(String uci)? onPlay;

  /// Moves already in the repertoire (shown with a check mark).
  final Set<String> highlightUcis;

  @override
  ConsumerState<ExplorerPanel> createState() => _ExplorerPanelState();
}

class _ExplorerPanelState extends ConsumerState<ExplorerPanel> {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final logged = ref.watch(lichessLoggedInProvider).value ?? false;
    final db = ref.watch(settingsProvider.select((s) => s.explorerSource));
    final sources = ChoiceSegments<String>(
      options: [
        ChoiceOption('masters', l.masters),
        const ChoiceOption('lichess', 'Lichess'),
        ChoiceOption('mine', l.explorerMine),
      ],
      selected: db,
      onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(explorerSource: v)),
    );
    // The user's own games: local, no login needed.
    if (db == 'mine') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0), child: sources),
          _MinePanel(fen: widget.fen, onPlay: widget.onPlay, highlightUcis: widget.highlightUcis),
        ],
      );
    }
    if (!logged) {
      // Text first, the action as a full-width button below: fits any
      // width and text size.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            sources,
            AppGap.v8,
            // One quiet line: the user's own moves matter more than an
            // invitation to log in.
            // Wraps under the text on a narrow screen or with large type.
            // Closed once, it stays closed: the sources above still say
            // where the explorer is.
            if (!ref.watch(settingsProvider.select((s) => s.explorerLoginHintHidden)))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The text and its action wrap together; the close button
                  // keeps its corner (it used to drop onto a line of its own).
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l.explorerNeedsLogin, style: context.tt.meta),
                        TextButton(onPressed: () => context.push('/accounts'), child: Text(l.connect)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l.dontShowAgain,
                    onPressed: () =>
                        ref.read(settingsProvider.notifier).update((x) => x.copyWith(explorerLoginHintHidden: true)),
                    icon: const Icon(AppIcons.close, size: AppSizes.iconMd),
                  ),
                ],
              ),
          ],
        ),
      );
    }
    final res = ref.watch(explorerLookupProvider((fen: widget.fen, db: db)));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          // The panel is opened by the "Explorer" button, so no title here:
          // just the database choice, full width.
          child: sources,
        ),
        res.when(
          loading: () => const Padding(
            padding: AppInsets.card,
            child: Center(child: InlineSpinner()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(AppIcons.error),
            title: Text(e is LichessException && e.isUnauthorized ? l.lichessSessionExpired : l.explorerError),
            subtitle: Text(friendlyError(e, l), maxLines: 2),
            trailing: IconButton(
              tooltip: l.retry,
              icon: const Icon(AppIcons.refresh),
              onPressed: () => ref.invalidate(explorerLookupProvider((fen: widget.fen, db: db))),
            ),
          ),
          data: (r) {
            if (r.moves.isEmpty) {
              return Padding(padding: AppInsets.card, child: Text(l.explorerNoGames));
            }
            final total = r.total == 0 ? 1 : r.total;
            // Column widths follow the text scale (T-21).
            final scale = MediaQuery.textScalerOf(context);
            final numStyle = context.tt.meta.tabular;
            return Column(
              children: [
                for (final m in r.moves.take(12))
                  InkWell(
                    onTap: widget.onPlay == null ? null : () => widget.onPlay!(m.uci),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          SizedBox(
                            width: scale.scale(72),
                            child: Row(
                              children: [
                                Flexible(child: MovesText(m.san, maxLines: 1, style: context.tt.moveMain)),
                                if (widget.highlightUcis.contains(m.uci))
                                  Padding(
                                    padding: const EdgeInsets.only(left: AppSpacing.xxs),
                                    child: Icon(
                                      AppIcons.okFilled,
                                      size: AppSizes.iconSm,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: scale.scale(52),
                            child: Text(context.fmtPercent(m.total / total), style: numStyle),
                          ),
                          SizedBox(
                            width: scale.scale(60),
                            child: Text(context.fmtCompact(m.total), style: numStyle),
                          ),
                          Expanded(
                            child: ResultBar.sides(context, white: m.white, draws: m.draws, black: m.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (r.openingName != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text('${r.eco ?? ''} ${r.openingName}', style: context.tt.meta),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Moves played in this position in the user's own games (both colours),
/// with how they scored for the user.
class _MinePanel extends ConsumerWidget {
  const _MinePanel({required this.fen, required this.onPlay, required this.highlightUcis});
  final String fen;
  final void Function(String uci)? onPlay;
  final Set<String> highlightUcis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tree = ref.watch(myOpeningTreeProvider(const MyGamesFilter()));
    return tree.when(
      loading: () => const Padding(
        padding: AppInsets.card,
        child: Center(child: InlineSpinner()),
      ),
      error: (e, _) => ListTile(leading: const Icon(AppIcons.error), title: Text(l.somethingWentWrong)),
      data: (t) {
        final stat = t.at(normalizeFenToKey(fen));
        if (stat == null || stat.moves.isEmpty) {
          return Padding(
            padding: AppInsets.card,
            child: Text(t.totalGames == 0 ? l.myOpeningsEmptyHint : l.explorerMineEmpty),
          );
        }
        final scale = MediaQuery.textScalerOf(context);
        final numStyle = context.tt.meta.tabular;
        final total = stat.score.games == 0 ? 1 : stat.score.games;
        return Column(
          children: [
            for (final m in stat.sortedMoves.take(12))
              InkWell(
                onTap: onPlay == null ? null : () => onPlay!(m.uci),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(
                        width: scale.scale(72),
                        child: Row(
                          children: [
                            Flexible(child: MovesText(m.san, maxLines: 1, style: context.tt.moveMain)),
                            if (highlightUcis.contains(m.uci))
                              Padding(
                                padding: const EdgeInsets.only(left: AppSpacing.xxs),
                                child: Icon(AppIcons.okFilled, size: AppSizes.iconSm, color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: scale.scale(52),
                        child: Text(context.fmtPercent(m.score.games / total), style: numStyle),
                      ),
                      SizedBox(
                        width: scale.scale(44),
                        child: Text('${m.score.games}', style: numStyle),
                      ),
                      Expanded(child: ScoreBar(score: m.score)),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
