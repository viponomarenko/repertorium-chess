import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../core/now.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../app/providers.dart';
import '../repertoire/repertoire_browser.dart' show pathToText;
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';

class StatsData {
  const StatsData({
    required this.forecast,
    required this.retention7,
    required this.retention30,
    required this.retention90,
    required this.activity,
    required this.problems,
    required this.streak,
    this.problemPaths = const {},
  });
  final Map<(int, PositionKey), String> problemPaths;
  final List<DayCount> forecast;
  final (int, int) retention7;
  final (int, int) retention30;
  final (int, int) retention90;
  final List<DayCount> activity;
  final List<ProblemPosition> problems;
  final int streak;
}

final statsProvider = FutureProvider.autoDispose.family<StatsData, int?>((ref, repId) async {
  ref.watch(refreshTickProvider);
  final repo = ref.watch(repertoireRepositoryProvider);
  final now = appNow();
  return StatsData(
    forecast: await repo.forecast(days: 30, repId: repId),
    retention7: await repo.retention(now.subtract(const Duration(days: 7)), repId: repId),
    retention30: await repo.retention(now.subtract(const Duration(days: 30)), repId: repId),
    retention90: await repo.retention(now.subtract(const Duration(days: 90)), repId: repId),
    activity: await repo.activityByDay(days: 30, repId: repId),
    problems: await repo.problemPositions(repId: repId, limit: 10),
    streak: await repo.streak(),
    problemPaths: await _problemPaths(repo, await repo.problemPositions(repId: repId, limit: 10)),
  );
});

/// Move sequence to each problem position, so the list says *where* the
/// mistakes happen.
Future<Map<(int, PositionKey), String>> _problemPaths(RepertoireRepository repo, List<ProblemPosition> ps) async {
  final out = <(int, PositionKey), String>{};
  final graphs = <int, RepertoireGraph>{};
  for (final p in ps) {
    final g = graphs[p.repertoireId] ??= await repo.loadGraph(p.repertoireId);
    final path = g.pathFromRoot(p.key);
    if (path != null && path.isNotEmpty) out[(p.repertoireId, p.key)] = pathToText(path, g);
  }
  return out;
}

/// Statistics (F-STAT-01..04). Charts: single-series bars in the theme's
/// primary color, recessive axes, tap a bar for its value; every chart has
/// an accessible summary.
class StatsView extends ConsumerWidget {
  const StatsView({super.key, this.repertoireId, this.summary, this.onTrainProblem});
  final int? repertoireId;
  final RepertoireSummary? summary;
  final void Function(ProblemPosition p)? onTrainProblem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final data = ref.watch(statsProvider(repertoireId));
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final list = repertoireId == null ? reps : reps.where((r) => r.row.id == repertoireId).toList();
    final positions = list.fold<int>(0, (a, r) => a + r.positions);
    final cards = list.fold<int>(0, (a, r) => a + r.cards);
    final learned = list.fold<int>(0, (a, r) => a + r.learned);
    final due = list.fold<int>(0, (a, r) => a + r.due);

    String pct((int, int) r) => r.$1 == 0 ? '-' : context.fmtPercent(r.$2 / r.$1);

    return data.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorState(
        message: l.somethingWentWrong,
        details: e,
        onRetry: () => ref.invalidate(statsProvider(repertoireId)),
      ),
      data: (d) {
        final f7 = d.forecast.take(8).fold<int>(0, (a, x) => a + x.count);
        final f30 = d.forecast.fold<int>(0, (a, x) => a + x.count);
        return AppPage(
          children: [
            SectionCard(
              child: Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.lg,
                children: [
                  StatTile(value: context.fmtInt(positions), label: l.statPositions),
                  StatTile(value: context.fmtInt(cards), label: l.statCards),
                  StatTile(value: context.fmtInt(learned), label: l.statLearned),
                  StatTile(value: context.fmtInt(due), label: l.statDueToday),
                  StatTile(value: context.fmtInt(d.streak), label: l.statStreak(d.streak)),
                ],
              ),
            ),
            AppGap.v12,
            SectionCard(
              title: l.forecastTitle,
              subtitle: l.forecastSummary(f7, f30),
              child: BarChart(values: d.forecast, height: _forecastHeight),
            ),
            AppGap.v12,
            SectionCard(
              title: l.retentionTitle,
              subtitle: l.retentionHint,
              child: Wrap(
                spacing: AppSpacing.xl,
                runSpacing: AppSpacing.md,
                children: [
                  StatTile(value: pct(d.retention7), label: l.days7(d.retention7.$1)),
                  StatTile(value: pct(d.retention30), label: l.days30(d.retention30.$1)),
                  StatTile(value: pct(d.retention90), label: l.days90(d.retention90.$1)),
                ],
              ),
            ),
            AppGap.v12,
            SectionCard(
              title: l.activityTitle,
              child: BarChart(values: _fillDays(d.activity, 30), height: _activityHeight),
            ),
            if (d.problems.isNotEmpty) ...[
              AppGap.v12,
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.card,
                        AppSpacing.card,
                        AppSpacing.card,
                        AppSpacing.xs,
                      ),
                      child: Semantics(
                        header: true,
                        child: Text(l.weakestPositions, style: theme.textTheme.titleLarge),
                      ),
                    ),
                    for (final p in d.problems)
                      ListTile(
                        leading: AppAvatar(text: context.fmtInt(p.errors), tone: Tone.error),
                        title: MovesText(
                          d.problemPaths[(p.repertoireId, p.key)] ?? _repName(reps, p.repertoireId),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          repertoireId == null
                              ? '${_repName(reps, p.repertoireId)} · ${l.mistakesLast30(p.errors)}'
                              : l.mistakesLast30(p.errors),
                        ),
                        trailing: onTrainProblem == null ? null : const Icon(AppIcons.play),
                        onTap: onTrainProblem == null ? null : () => onTrainProblem!(p),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Heights of the two charts: the forecast is the one to read.
  static const double _forecastHeight = 120;
  static const double _activityHeight = 80;

  static String _repName(List<RepertoireSummary> reps, int id) {
    for (final r in reps) {
      if (r.row.id == id) return r.row.name;
    }
    return '#$id';
  }

  static List<DayCount> _fillDays(List<DayCount> days, int n) {
    final map = {for (final d in days) d.day: d.count};
    final today = appNow();
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final d = DateTime(today.year, today.month, today.day - i);
          return DayCount(d, map[d] ?? 0);
        }(),
    ];
  }
}

/// Minimal single-series bar chart: thin bars with rounded tops on a
/// recessive baseline; tap/long-press shows the value.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, this.height = 100});
  final List<DayCount> values;
  final double height;

  /// The shortest bar of a day that has anything: still visible.
  static const double _minBar = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.MMMd(locale);
    final maxV = values.fold<int>(0, (a, v) => math.max(a, v.count));
    final summary = values.where((v) => v.count > 0).map((v) => '${fmt.format(v.day)}: ${v.count}').join(', ');
    return Semantics(
      label: summary.isEmpty ? '0' : summary,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final v in values)
                  Expanded(
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message: '${fmt.format(v.day)}: ${v.count}',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.hairline),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          // The bars grow to their value, as on the Today screen.
                          child: AnimatedFraction(
                            value: maxV == 0 ? 0 : v.count / maxV,
                            emphasis: true,
                            builder: (_, f) => Container(
                              height: v.count == 0 ? 0 : math.max(_minBar, height * f),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xs)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: AppSizes.hairline),
          AppGap.v4,
          // Three equal columns: fits any width and text size.
          Row(
            children: [
              Expanded(
                child: Text(
                  values.isEmpty ? '' : fmt.format(values.first.day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
              Expanded(
                child: Text(
                  context.l10n.chartMax(context.fmtInt(maxV)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.tabular.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: Text(
                  values.isEmpty ? '' : fmt.format(values.last.day),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
