import 'dart:math' as math;

import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
    activity: await repo.activityByDay(days: _ActivityCalendar.span, repId: repId),
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

/// Statistics (F-STAT-01..04), D-089 and D-094: the learned share as the
/// hero figure with three tiles, the forecast as a dot plot (tap a day for
/// its number in the card's caption), retention as three half-ring gauges
/// with a trend note, and the last five weeks as a calendar in the goal's
/// colour. Ink for counts, the warm colour only where the daily goal and
/// the streak are concerned; every chart has an accessible summary.
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

    return data.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorState(
        message: l.somethingWentWrong,
        details: e,
        onRetry: () => ref.invalidate(statsProvider(repertoireId)),
      ),
      data: (d) {
        final f7 = d.forecast.take(8).fold<int>(0, (a, x) => a + x.count);
        final goal = ref.watch(settingsProvider.select((s) => s.dailyGoal));
        return AppPage(
          children: [
            SectionCard(
              child: _Overview(
                learned: learned,
                cards: cards,
                positions: positions,
                due: due,
                streak: d.streak,
                repertoires: repertoireId == null ? list : const [],
              ),
            ),
            AppGap.v12,
            _ForecastCard(values: d.forecast, week: f7),
            AppGap.v12,
            SectionCard(
              title: l.retentionTitle,
              subtitle: l.retentionHint,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Gauge(
                          period: l.retentionPeriod7,
                          retention: d.retention7,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      AppGap.h8,
                      Expanded(
                        child: _Gauge(
                          period: l.retentionPeriod30,
                          retention: d.retention30,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      AppGap.h8,
                      Expanded(
                        child: _Gauge(
                          period: l.retentionPeriod90,
                          retention: d.retention90,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (retentionTrend(d.retention7, d.retention90) case final trend?) ...[
                    AppGap.v12,
                    InfoStrip(
                      icon: AppIcons.stats,
                      tone: trend > 0 ? Tone.success : Tone.warning,
                      text: trend > 0 ? l.retentionTrendUp(trend) : l.retentionTrendDown(trend.abs()),
                    ),
                  ],
                ],
              ),
            ),
            AppGap.v12,
            _ActivityCalendar(days: d.activity, goal: goal),
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

  static String _repName(List<RepertoireSummary> reps, int id) {
    for (final r in reps) {
      if (r.row.id == id) return r.row.name;
    }
    return '#$id';
  }
}

/// The headline (D-094): "LEARNED", the share as the screen's hero figure,
/// "53 of 73 moves", per-repertoire pills when the overall statistics cover
/// two or three repertoires, a thick bar, then three tiles - positions, due
/// and the streak on a warm tile.
Side _sideOf(RepertoireSummary r) => r.row.color == 'black' ? Side.black : Side.white;

class _Overview extends StatelessWidget {
  const _Overview({
    required this.learned,
    required this.cards,
    required this.positions,
    required this.due,
    required this.streak,
    this.repertoires = const [],
  });
  final int learned;
  final int cards;
  final int positions;
  final int due;
  final int streak;

  /// Shown as pills only when there are 2-3 of them.
  final List<RepertoireSummary> repertoires;

  static const double _bar = 10;
  static const double _pill = 28;
  static const double _pillBadge = 20;
  static const double _pillGap = 6;
  static const double _tileIcon = 18;
  static const double _captionGap = 6;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final share = cards == 0 ? 0.0 : learned / cards;
    Widget pill(RepertoireSummary r) => Semantics(
      label: '${_sideOf(r) == Side.white ? l.white : l.black}: ${l.repertoireCounts(r.learned, r.cards)}',
      excludeSemantics: true,
      child: Container(
        height: _pill,
        padding: const EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.md),
        decoration: BoxDecoration(color: cs.surface, borderRadius: AppRadius.full),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SideBadge(side: _sideOf(r), size: _pillBadge),
            const SizedBox(width: _pillGap),
            Text('${r.learned} / ${r.cards}', style: theme.textTheme.labelMedium?.tabular),
          ],
        ),
      ),
    );
    Widget tile(IconData icon, String value, String label, {bool warm = false}) => Expanded(
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: warm ? cs.flameContainer : cs.surface, borderRadius: AppRadius.mdAll),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: _tileIcon, color: warm ? cs.flame : cs.onSurface),
              AppGap.v8,
              Text(value, style: context.tt.value),
              Text(label, style: context.tt.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
    final pills = repertoires.length >= 2 && repertoires.length <= 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                label: '${l.statLearnedCaption}: ${context.fmtPercent(share)}, ${l.learnedOfTotal(learned, cards)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.statLearnedCaption.toUpperCase(), style: context.tt.overline),
                    AppGap.v4,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(context.fmtPercent(share), style: context.tt.hero),
                    ),
                    const SizedBox(height: _captionGap),
                    Text(l.learnedOfTotal(learned, cards), style: context.tt.title),
                  ],
                ),
              ),
            ),
            if (pills) ...[
              AppGap.h12,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, r) in repertoires.indexed) ...[if (i > 0) const SizedBox(height: _pillGap), pill(r)],
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md + AppSpacing.xxs),
        AppProgressBar(value: share, height: _bar),
        AppGap.v16,
        // One height for the three tiles, whichever label wraps (D-094).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(AppIcons.repertoire, context.fmtInt(positions), l.statPositions),
              AppGap.h8,
              tile(AppIcons.again, context.fmtInt(due), l.statDueToday),
              AppGap.h8,
              tile(AppIcons.streak, context.fmtInt(streak), l.statStreak(streak), warm: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Reviews due per day for the next 30 days as a dot plot (D-094): a stem
/// from zero and a dot at the count; the next seven days solid on a soft
/// band, later days hollow, empty days a small dot on the baseline; today's
/// dot larger with its number, the busiest of the week numbered too. A tap
/// (or a drag) picks a day: its date and number go to the caption, the
/// rest fade and a guide marks it (D-089).
class _ForecastCard extends StatefulWidget {
  const _ForecastCard({required this.values, required this.week});
  final List<DayCount> values;

  /// Reviews in the next 7 days (the figure in the card's corner).
  final int week;

  @override
  State<_ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<_ForecastCard> {
  static const double _height = 144;

  int? _picked;

  void _pick(Offset at, double width) {
    final n = widget.values.length;
    if (n == 0) return;
    final i = _ForecastPainter.indexAt(at.dx, width, n);
    if (i != _picked) setState(() => _picked = i);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.MMMd(locale);
    final values = widget.values;
    final total = values.fold<int>(0, (a, v) => a + v.count);
    final today = values.isEmpty ? 0 : values.first.count;
    final avg = values.isEmpty ? 0 : total / values.length;
    final picked = _picked == null || _picked! >= values.length ? null : values[_picked!];
    final caption = picked == null
        ? l.forecastSummaryAvg(today, context.fmtDecimal(avg))
        : '${fmt.format(picked.day)} · ${context.fmtInt(picked.count)}';
    final summary = values.where((v) => v.count > 0).map((v) => '${fmt.format(v.day)}: ${v.count}').join(', ');
    return SectionCard(
      title: l.forecastTitle,
      subtitle: caption,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(context.fmtInt(widget.week), style: theme.textTheme.headlineSmall?.tabular),
          Text(l.forecastNext7Short, style: context.tt.meta),
        ],
      ),
      child: Semantics(
        label: summary.isEmpty ? '0' : summary,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _pick(d.localPosition, c.maxWidth),
                onHorizontalDragUpdate: (d) => _pick(d.localPosition, c.maxWidth),
                child: SizedBox(
                  height: _height,
                  child: CustomPaint(
                    size: Size(c.maxWidth, _height),
                    painter: _ForecastPainter(
                      values: values,
                      picked: _picked,
                      cs: theme.colorScheme,
                      labelStyle: context.tt.meta,
                      numberStyle: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurface).tabular,
                      todayLabel: l.todayShort,
                      todayStyle: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurface),
                      dateOf: fmt.format,
                      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3),
                    ),
                  ),
                ),
              ),
            ),
            AppGap.v12,
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                _LegendDot(filled: true, label: l.forecastLegendWeek),
                _LegendDot(filled: false, label: l.forecastLegendLater),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.filled, required this.label});
  final bool filled;
  final String label;

  static const double _dot = 8;
  static const double _ring = 1.5;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _dot,
          height: _dot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? cs.onSurface : null,
            border: filled ? null : Border.all(color: cs.onSurfaceVariant, width: _ring),
          ),
        ),
        const SizedBox(width: _gap),
        Flexible(child: Text(label, style: context.tt.meta)),
      ],
    );
  }
}

/// Draws [_ForecastCard]'s plot: value labels and gridlines on the left,
/// the band of the next seven days, stems and dots, and the dates under.
class _ForecastPainter extends CustomPainter {
  _ForecastPainter({
    required this.values,
    required this.picked,
    required this.cs,
    required this.labelStyle,
    required this.numberStyle,
    required this.todayLabel,
    required this.todayStyle,
    required this.dateOf,
    required this.textScaler,
  });
  final List<DayCount> values;
  final int? picked;
  final ColorScheme cs;
  final TextStyle labelStyle;
  final TextStyle numberStyle;
  final String todayLabel;
  final TextStyle todayStyle;
  final String Function(DateTime) dateOf;
  final TextScaler textScaler;

  /// The value labels' column, the room above the top value for numbers,
  /// the axis labels' row, the near days (today and the next seven).
  static const double _labels = 18;
  static const double _top = 26;
  static const double _axis = 26;
  static const int _near = 8;
  static const double _band = 10;
  static const double _stem = 2;
  static const double _dot = 3.5;
  static const double _hollow = 3.25;
  static const double _hollowRing = 1.5;
  static const double _emptyDot = 2;
  static const double _todayDot = 5.5;
  static const double _todayRing = 2;
  static const double _stemAlpha = 0.22;
  static const int _minMax = 3;

  /// The x of day [i] of [n] in a plot [width] wide.
  static double xOf(int i, double width, int n) {
    final step = n <= 1 ? 0.0 : (width - _labels - _todayDot * 2) / (n - 1);
    return _labels + _todayDot + i * step;
  }

  static int indexAt(double x, double width, int n) {
    if (n <= 1) return 0;
    final step = (width - _labels - _todayDot * 2) / (n - 1);
    return ((x - _labels - _todayDot) / step).round().clamp(0, n - 1);
  }

  TextPainter _text(String s, TextStyle st) => TextPainter(
    text: TextSpan(text: s, style: st),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final maxRaw = values.fold<int>(0, (a, v) => math.max(a, v.count));
    final maxV = math.max(_minMax, maxRaw);
    final base = size.height - _axis;
    double yOf(num v) => base - (base - _top) * v / maxV;
    final grid = Paint()
      ..color = cs.outlineVariant
      ..strokeWidth = AppSizes.hairline;
    // Gridlines and their values: 0, a third, two thirds, the top.
    for (var k = 0; k <= 3; k++) {
      final v = (maxV * k / 3).round();
      final y = yOf(maxV * k / 3);
      canvas.drawLine(Offset(_labels, y), Offset(size.width, y), k == 0 ? (Paint()..color = cs.outline) : grid);
      final t = _text('$v', labelStyle);
      t.paint(canvas, Offset(0, y - t.height / 2));
    }
    // The soft band behind the next seven days.
    final near = math.min(_near, n) - 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          xOf(0, size.width, n) - _band,
          _top - _band,
          xOf(near, size.width, n) + _band,
          base + AppSpacing.xs,
        ),
        const Radius.circular(_band),
      ),
      Paint()..color = cs.surface,
    );
    final dim = picked != null;
    Color faded(Color c, int i) => dim && i != picked ? c.withValues(alpha: c.a * AppOpacity.muted) : c;
    var peak = 0;
    for (var i = 1; i < math.min(_near, n); i++) {
      if (values[i].count > values[peak].count) peak = i;
    }
    for (var i = 0; i < n; i++) {
      final x = xOf(i, size.width, n);
      final v = values[i].count;
      final soon = i < _near;
      if (v <= 0) {
        canvas.drawCircle(Offset(x, base), _emptyDot, Paint()..color = faded(cs.outline, i));
        continue;
      }
      final y = yOf(v);
      canvas.drawLine(
        Offset(x, base),
        Offset(x, y),
        Paint()
          ..strokeWidth = _stem
          ..strokeCap = StrokeCap.round
          ..color = faded(soon ? cs.onSurface.withValues(alpha: _stemAlpha) : cs.outlineVariant, i),
      );
      if (i == 0) {
        canvas.drawCircle(Offset(x, y), _todayDot + _todayRing, Paint()..color = cs.surfaceContainerLow);
        canvas.drawCircle(Offset(x, y), _todayDot, Paint()..color = faded(cs.onSurface, i));
      } else if (soon) {
        canvas.drawCircle(Offset(x, y), _dot, Paint()..color = faded(cs.onSurface, i));
      } else {
        canvas.drawCircle(Offset(x, y), _hollow, Paint()..color = cs.surfaceContainerLow);
        canvas.drawCircle(
          Offset(x, y),
          _hollow,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _hollowRing
            ..color = faded(cs.onSurfaceVariant, i),
        );
      }
      // Numbers: today, and the busiest of the near days.
      if (i == 0 || (i == peak && values[peak].count > values[0].count)) {
        final t = _text('$v', numberStyle);
        t.paint(canvas, Offset(x - t.width / 2, y - (i == 0 ? _todayDot : _dot) - t.height - AppSpacing.xxs));
      }
    }
    if (picked != null && picked! < n) {
      final x = xOf(picked!, size.width, n);
      canvas.drawLine(
        Offset(x, _top - _band),
        Offset(x, base),
        Paint()
          ..color = cs.outline
          ..strokeWidth = AppSizes.hairline,
      );
    }
    // Dates: "today" on the left, then every seven days, the last one on
    // the right.
    final axisY = base + AppSpacing.sm;
    final today = _text(todayLabel, todayStyle);
    today.paint(canvas, Offset(xOf(0, size.width, n) - _todayDot, axisY));
    var lastRight = xOf(0, size.width, n) - _todayDot + today.width;
    for (var i = _near; i < n - 1; i += 7) {
      final t = _text(dateOf(values[i].day), labelStyle);
      final left = xOf(i, size.width, n) - t.width / 2;
      if (left < lastRight + AppSpacing.sm) continue;
      t.paint(canvas, Offset(left, axisY));
      lastRight = left + t.width;
    }
    if (n > 1) {
      final last = _text(dateOf(values[n - 1].day), labelStyle);
      final left = size.width - last.width;
      if (left > lastRight + AppSpacing.sm) last.paint(canvas, Offset(left, axisY));
    }
  }

  @override
  bool shouldRepaint(_ForecastPainter old) => old.values != values || old.picked != picked || old.cs != cs;
}

/// The change of retention this week against the 90-day average, in
/// percentage points, when it says something (D-094): at least
/// [minAnswers] answers this week and a difference of [minPoints] or more.
@visibleForTesting
int? retentionTrend((int, int) week, (int, int) quarter, {int minAnswers = 20, int minPoints = 3}) {
  if (week.$1 < minAnswers || quarter.$1 == 0) return null;
  final d = ((week.$2 / week.$1 - quarter.$2 / quarter.$1) * 100).round();
  return d.abs() >= minPoints ? d : null;
}

/// Retention over a period as a half-ring gauge (D-094): the share on a
/// quiet track, the percentage under the arc, the period and the number of
/// answers below; with no answers the arc stays empty and reads "-".
class _Gauge extends StatelessWidget {
  const _Gauge({required this.period, required this.retention, required this.color});
  final String period;
  final (int, int) retention;
  final Color color;

  static const double _width = 96;
  static const double _height = 56;
  static const double _stroke = 9;
  static const double _labelGap = 6;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final empty = retention.$1 == 0;
    final share = empty ? 0.0 : retention.$2 / retention.$1;
    final value = empty ? '-' : context.fmtPercent(share);
    return Semantics(
      label: '$period: $value, ${l.answersCount(retention.$1)}',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            width: _width,
            height: _height,
            child: AnimatedFraction(
              value: share,
              emphasis: true,
              builder: (context, f) => CustomPaint(
                painter: _GaugePainter(value: f, color: color, track: cs.surface, stroke: _stroke),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.2,
                    child: Text(value, style: context.tt.value),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: _labelGap),
          Text(period, style: Theme.of(context).textTheme.labelMedium, textAlign: TextAlign.center),
          Text(l.answersCount(retention.$1), style: context.tt.meta, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value, required this.color, required this.track, required this.stroke});
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  /// The arc's radius and how far its ends sit above the bottom.
  static const double _radius = 40;
  static const double _ends = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - _ends);
    final rect = Rect.fromCircle(center: center, radius: _radius);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, line..color = track);
    if (value > 0) canvas.drawArc(rect, math.pi, math.pi * value.clamp(0.0, 1.0), false, line..color = color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color || old.track != track || old.stroke != stroke;
}

/// The last five weeks as a calendar (Monday first): a day is a rounded
/// cell with its date, grey without practice, a pale warm tone below the
/// daily goal and the full warm colour when the goal was met (D-089);
/// today is ringed inside, the days still to come of this week are dashed
/// outlines (D-094). A tap puts the day's date and answers in the caption.
class _ActivityCalendar extends StatefulWidget {
  const _ActivityCalendar({required this.days, required this.goal});
  final List<DayCount> days;
  final int goal;

  /// Days of history the calendar can show (five weeks).
  static const int span = 35;

  @override
  State<_ActivityCalendar> createState() => _ActivityCalendarState();
}

class _ActivityCalendarState extends State<_ActivityCalendar> {
  /// Gap between days, their corner radius and height, the legend swatch.
  static const double _gap = AppSpacing.xs;
  static const double _radius = 8;
  static const double _legendSwatch = 12;
  static const double _cell = 32;
  static const double _todayRing = 2;
  static const double _pickedRing = 1.5;

  /// The warm tone of a day below the goal: from a little practice to
  /// almost there; the legend shows the middle of that range.
  static const double _belowGoalFrom = 0.25;
  static const double _belowGoalTo = 0.7;
  static const double _belowGoalLegend = 0.45;

  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final fmt = DateFormat.MMMd(locale);
    final map = {for (final d in widget.days) d.day: d.count};
    final now = appNow();
    final today = DateTime(now.year, now.month, now.day);
    // Five rows of Monday…Sunday, the last one holding today.
    final lastMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final start = DateTime(lastMonday.year, lastMonday.month, lastMonday.day - 28);
    final trained = widget.days.where((d) => d.count > 0).length;
    final total = widget.days.fold<int>(0, (a, d) => a + d.count);
    final pickedCount = _picked == null ? null : map[_picked] ?? 0;
    final caption = _picked == null
        ? l.activitySummary(trained, total)
        : '${fmt.format(_picked!)} · ${context.fmtInt(pickedCount!)}';

    Color fill(int count) {
      if (count <= 0) return cs.surfaceContainerHigh;
      if (widget.goal <= 0 || count >= widget.goal) return cs.flame;
      final f = count / widget.goal;
      return cs.flame.withValues(alpha: _belowGoalFrom + (_belowGoalTo - _belowGoalFrom) * f);
    }

    Widget swatch(Color c) => Container(
      width: _legendSwatch,
      height: _legendSwatch,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(_radius / 2)),
    );

    Widget cell(DateTime day) {
      final future = day.isAfter(today);
      final count = map[day] ?? 0;
      final isToday = day == today;
      final picked = day == _picked;
      final number = MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: Text(
          '${day.day}',
          style:
              (count > 0 && !future
                      ? theme.textTheme.labelSmall?.copyWith(color: cs.onSurface)
                      : theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))
                  ?.tabular,
        ),
      );
      if (future) {
        return CustomPaint(
          painter: _DashedRectPainter(color: cs.outline, radius: _radius),
          child: Center(child: number),
        );
      }
      return GestureDetector(
        onTap: () => setState(() => _picked = picked ? null : day),
        child: AnimatedContainer(
          duration: AppMotion.of(context).fast,
          decoration: BoxDecoration(
            color: fill(count),
            borderRadius: BorderRadius.circular(_radius),
            border: isToday || picked
                ? Border.all(color: cs.onSurface, width: isToday ? _todayRing : _pickedRing)
                : null,
          ),
          child: Center(child: number),
        ),
      );
    }

    final weekdays = [for (var i = 0; i < 7; i++) DateFormat.E(locale).format(DateTime(2024, 1, 1 + i))];
    return SectionCard(
      title: l.activityTitle,
      subtitle: caption,
      child: Semantics(
        label: l.activitySummary(trained, total),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      weekdays[i].length <= 2 ? weekdays[i] : weekdays[i].substring(0, 2),
                      textAlign: TextAlign.center,
                      style: context.tt.meta,
                    ),
                  ),
              ],
            ),
            AppGap.v4,
            for (var w = 0; w < 5; w++)
              Padding(
                padding: EdgeInsets.only(top: w == 0 ? 0 : _gap),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                          child: SizedBox(
                            height: _cell,
                            child: cell(DateTime(start.year, start.month, start.day + w * 7 + i)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            AppGap.v12,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    swatch(cs.surfaceContainerHigh),
                    AppGap.h4,
                    Text('0', style: context.tt.meta),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    swatch(cs.flame.withValues(alpha: _belowGoalLegend)),
                    AppGap.h4,
                    Text(l.legendBelowGoal, style: context.tt.meta),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    swatch(cs.flame),
                    AppGap.h4,
                    Text(l.legendGoal, style: context.tt.meta),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A day still to come: a dashed rounded outline.
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  static const double _stroke = 1.5;
  static const double _dash = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(_stroke / 2), Radius.circular(radius)));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash * 2) {
        canvas.drawPath(metric.extractPath(d, d + _dash), line);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color || old.radius != radius;
}
