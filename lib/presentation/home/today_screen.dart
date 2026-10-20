import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../../core/now.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/training/training_engine.dart';
import '../app/leave_guard.dart';
import '../app/providers.dart';
import '../repertoire/create_repertoire_dialog.dart';
import '../repertoire/repertoire_screen.dart' show repertoireMenuItems;
import '../theme/app_icons.dart';
import '../training/mode_sheet.dart';
import '../training/training_args.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';
import 'day_plan.dart';

final introducedTodayProvider = FutureProvider<int>((ref) {
  ref.watch(refreshTickProvider);
  final fsrs = ref.watch(fsrsProvider);
  return ref.watch(repertoireRepositoryProvider).introducedSince(fsrs.dayStart(appNow()));
});

final reviewedTodayProvider = FutureProvider<int>((ref) {
  ref.watch(refreshTickProvider);
  final fsrs = ref.watch(fsrsProvider);
  return ref.watch(repertoireRepositoryProvider).reviewsSince(fsrs.dayStart(appNow()));
});

final problemCountProvider = FutureProvider<List<ProblemPosition>>((ref) {
  ref.watch(refreshTickProvider);
  return ref.watch(repertoireRepositoryProvider).problemPositions(limit: 20);
});

final nextDueProvider = FutureProvider<DateTime?>((ref) async {
  ref.watch(refreshTickProvider);
  final next = await ref.watch(repertoireRepositoryProvider).nextDue();
  // Refresh Today when that moment comes, so "next review at 14:30" turns
  // into a Review button instead of staying on screen at 15:00.
  if (next != null) {
    final wait = next.difference(DateTime.now());
    if (wait > Duration.zero && wait < const Duration(hours: 24)) {
      final t = Timer(wait + const Duration(seconds: 1), () => ref.read(refreshTickProvider.notifier).bump());
      ref.onDispose(t.cancel);
    }
  }
  return next;
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reps = ref.watch(repertoiresProvider);
    return Scaffold(
      appBar: PageBar(
        // In line with the dashboard under it.
        width: _Dashboard.widthFor(PageScope.widthOf(context)),
        bar: AppBar(
          title: const Text(AppInfo.name),
          actions: [
            IconButton(
              tooltip: l.statsTitle,
              icon: const Icon(AppIcons.stats),
              onPressed: () => context.push('/stats'),
            ),
            IconButton(
              tooltip: l.settingsTitle,
              icon: const Icon(AppIcons.settings),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
      body: reps.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(onRetry: () => ref.invalidate(repertoiresProvider)),
        data: (list) => list.isEmpty ? const _Welcome() : _Dashboard(list),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // For newcomers a ready-made repertoire is the fastest way to start.
    return EmptyState(
      icon: AppIcons.learn,
      title: l.welcomeTitle,
      message: l.welcomeMessage,
      // One way to start; the other two are there, but quieter (D-070).
      actions: [
        FilledButton.icon(
          style: AppButtonSize.large,
          onPressed: () => showStarterPicker(context, learnNow: true),
          icon: const Icon(AppIcons.starter),
          label: Text(l.startWithStarter),
        ),
        TextButton.icon(
          onPressed: () => showCreateRepertoire(context, openEditor: true),
          icon: const Icon(AppIcons.add),
          label: Text(l.createRepertoire),
        ),
        TextButton.icon(
          onPressed: () => context.push('/import'),
          icon: const Icon(AppIcons.openFile),
          label: Text(l.importPgn),
        ),
      ],
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard(this.reps);
  final List<RepertoireSummary> reps;

  /// The dashboard reads best a little narrower than a full page.
  static const double _dashboardWidth = 640;

  /// The width of the dashboard on a page this wide.
  static double widthFor(double page) => page >= AppBreakpoints.twoColumns ? AppSizes.dashboardWidth : _dashboardWidth;

  /// Letter spacing of the capitals on the main button.
  static const double _capsSpacing = 0.8;

  /// "Other" beside the main button: its height, a snug width.
  static const _otherButton = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, AppSizes.controlMd)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.xl)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    // Wait for the first numbers instead of flashing zeros ("0 of 10",
    // "No streak yet") for a moment on a cold start.
    final waiting = <AsyncValue<Object?>>[
      ref.watch(introducedTodayProvider),
      ref.watch(reviewedTodayProvider),
      ref.watch(todayCountProvider),
      ref.watch(streakProvider),
      ref.watch(weekActivityProvider),
      ref.watch(problemCountProvider),
    ].any((v) => v.isLoading && !v.hasValue);
    if (waiting) return const LoadingView();
    final day = DayPlan.of(ref, reps);
    final reviewLeft = day.reviewLeft;
    final totalDue = day.totalDue;
    final dueCapped = day.dueCapped;
    final totalNew = day.totalNew;
    final newLeft = day.newLeft;
    final newAvailable = day.newAvailable;
    final today = ref.watch(todayCountProvider).value ?? 0;
    final streak = ref.watch(streakProvider).value ?? 0;
    final week = ref.watch(weekActivityProvider).value ?? const <int>[];
    final problems = day.problems;
    final nextDue = ref.watch(nextDueProvider).value;
    final problemsByRep = day.problemsByRep;
    final stages = day.stages;
    final trainButton = stages.isEmpty
        ? null
        : FilledButton.icon(
            style: AppButtonSize.wide,
            onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
            icon: const Icon(AppIcons.play),
            // The one action of the day, set in capitals (D-089).
            label: Text(l.trainNow.toUpperCase(), style: const TextStyle(letterSpacing: _capsSpacing)),
          );

    String? status;
    if (dueCapped == 0 && newAvailable == 0) {
      if (totalDue > 0 && reviewLeft == 0) {
        status = l.reviewLimitReached;
      } else if (totalNew > 0 && newLeft == 0) {
        status = l.newLimitReached;
      } else if (nextDue != null) {
        status = l.nextReviewAt(context.fmtDateTime(nextDue));
      } else {
        status = l.allDone;
      }
    }

    // What today's session holds, said once (D-116): under the big figure
    // instead of "N more to the goal", which the figure already says.
    final plan = trainButton == null
        ? null
        : [
            if (dueCapped > 0) l.stageReviewCount(dueCapped),
            if (problems.isNotEmpty) l.stageProblemsCount(problems.length),
            if (newAvailable > 0) l.stageNewCount(newAvailable),
          ].join(' · ');
    final hasModes = reps.any((r) => r.cards > 0);
    void openModes() => showModeSheet(context, ref, reps: reps);

    final card = Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GoalHeader(done: today, goal: settings.dailyGoal, plan: plan),
            AppGap.v16,
            if (trainButton != null) ...[
              // The other modes stand right of the main button, a quiet
              // pill of the same height (D-089).
              Row(
                children: [
                  Expanded(child: trainButton),
                  if (hasModes) ...[
                    AppGap.h8,
                    FilledButton(
                      style: _otherButton.merge(
                        FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      onPressed: openModes,
                      child: Text(l.otherShort),
                    ),
                  ],
                ],
              ),
            ],
            if (status != null) ...[
              // Only problem moves left: the note goes under the button.
              if (trainButton != null) AppGap.v12,
              InfoStrip(icon: AppIcons.ok, text: status),
            ],
            if (dueCapped == 0 && newAvailable == 0 && reps.any((r) => r.learned > 0)) ...[
              AppGap.v8,
              // Still one filled action on the screen when the day's
              // plan is done.
              FilledButton.icon(
                style: AppButtonSize.wide,
                onPressed: () => context.push(
                  '/train',
                  extra: TrainingArgs(
                    repertoireIds: [
                      for (final r in reps)
                        if (r.learned > 0) r.row.id,
                    ],
                    mode: TrainingMode.drill,
                    maxLines: 5,
                  ),
                ),
                icon: const Icon(AppIcons.drill),
                label: Text(l.extraPractice),
              ),
            ],
            if (trainButton == null && hasModes)
              Center(
                child: TextButton(onPressed: openModes, child: Text(l.otherModes)),
              ),
            // Edge to edge across the card, between the plan and the week.
            AppGap.v12,
            const _CardDivider(),
            AppGap.v12,
            _StreakWeek(streak: streak, week: week, goal: settings.dailyGoal),
          ],
        ),
      ),
    );
    final repertoires = [
      SectionHeader(
        l.navRepertoires,
        // Inside the page margin already: in line with the text in cards.
        padding: const EdgeInsets.only(left: AppSpacing.card, top: AppSpacing.xl, bottom: AppSpacing.sm),
        trailing: TextButton.icon(
          onPressed: () => showCreateRepertoire(context, openEditor: true),
          icon: const Icon(AppIcons.add),
          label: Text(l.create),
        ),
      ),
      for (final r in reps) ...[
        RepertoireCard(
          summary: r,
          reviewLimit: reviewLeft,
          newLimit: newLeft,
          problemKeys: problemsByRep[r.row.id] ?? const [],
        ),
        AppGap.v12,
      ],
    ];
    // The iOS spinner on an iPhone (D-118).
    return RefreshIndicator.adaptive(
      onRefresh: () async => ref.read(refreshTickProvider.notifier).bump(),
      child: LayoutBuilder(
        builder: (context, c) {
          // Room for two columns (a tablet): the plan of the day stays in
          // sight at the side while the list of repertoires scrolls (D-084).
          if (c.maxWidth >= AppBreakpoints.twoColumns) {
            return ListView(
              padding: AppInsets.page.inPage(context, width: AppSizes.dashboardWidth),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: AppSizes.dashboardSide, child: card),
                    AppGap.h24,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: repertoires),
                    ),
                  ],
                ),
              ],
            );
          }
          return ListView(
            padding: AppInsets.page.inPage(context, width: _dashboardWidth),
            children: [card, ...repertoires],
          );
        },
      ),
    );
  }
}

/// The top of the "Today" card (D-093): the date as a quiet caption, the
/// answers so far as the screen's one big figure with the goal beside it,
/// and a line saying what is left, marked by a warm dot; the segmented
/// goal ring beside them.
class _GoalHeader extends StatelessWidget {
  const _GoalHeader({required this.done, required this.goal, this.plan});
  final int done;
  final int goal;

  /// What today's session holds ("20 new"), when there is a session.
  final String? plan;

  /// The dot before the line under the figure.
  static const double _dot = 8;
  static const double _dotGap = 6;
  static const double _dateGap = 6;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reached = done >= goal;
    final date = DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(appNow());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.overline),
              const SizedBox(height: _dateGap),
              // The figure reads "12 / 20"; a screen reader hears the words.
              // With large text or beside the ring on a narrow phone the
              // figure shrinks to fit instead of running off the card.
              Semantics(
                label: l.goalProgress(done, goal),
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$done', style: context.tt.hero),
                      AppGap.h4,
                      Text('/ $goal', style: theme.textTheme.titleLarge?.copyWith(color: cs.onSurfaceVariant).tabular),
                    ],
                  ),
                ),
              ),
              AppGap.v8,
              Row(
                children: [
                  Container(
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(color: reached ? cs.success : cs.flame, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: _dotGap),
                  Flexible(
                    child: Text(reached ? l.goalDone : (plan ?? l.goalLeft(goal - done)), style: context.tt.title),
                  ),
                ],
              ),
            ],
          ),
        ),
        AppGap.h16,
        // The lines beside it say the same in words.
        ExcludeSemantics(
          child: _GoalRing(done: done, goal: goal),
        ),
      ],
    );
  }
}

/// The daily goal as a ring of one segment per answer (D-093): grey
/// segments fill in the warm colour from the top, clockwise, around a soft
/// disc with a target. Past [_segmentedMax] answers the segments would be
/// crumbs, so the ring is one arc. Once the goal is reached it closes in
/// green around a trophy.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.done, required this.goal});
  final int done;
  final int goal;

  static const double _size = 92;
  static const double _stroke = 9;
  static const double _disc = 56;
  static const double _icon = 26;
  static const double _inset = 5;

  /// The most segments the ring draws.
  static const int _segmentedMax = 40;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = goal <= 0 ? 1.0 : (done / goal).clamp(0.0, 1.0);
    final reached = v >= 1;
    return SizedBox.square(
      dimension: _size,
      child: AnimatedFraction(
        value: v,
        emphasis: true,
        builder: (context, value) => CustomPaint(
          painter: _RingPainter(
            value: value,
            color: reached ? cs.success : cs.flame,
            track: cs.surfaceContainerHigh,
            stroke: _stroke,
            segments: reached || goal <= 1 || goal > _segmentedMax ? 0 : goal,
          ),
          child: Center(
            child: reached
                ? PopIn(
                    trigger: reached,
                    child: Container(
                      width: _size - 2 * (_stroke + _inset),
                      height: _size - 2 * (_stroke + _inset),
                      decoration: BoxDecoration(color: cs.successContainer, shape: BoxShape.circle),
                      child: Icon(AppIcons.trophy, size: AppSizes.iconLg, color: cs.success),
                    ),
                  )
                : Container(
                    width: _disc,
                    height: _disc,
                    decoration: BoxDecoration(color: cs.flameContainer, shape: BoxShape.circle),
                    child: Icon(AppIcons.goal, size: _icon, color: cs.flame),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The track and the fill of a ring, starting at the top, clockwise. With
/// [segments] the ring is cut into that many pieces with a small gap and
/// flat ends, filled one by one (the last one in part); without, it is one
/// arc with round ends.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
    this.segments = 0,
  });
  final double value;
  final Color color;
  final Color track;
  final double stroke;
  final int segments;

  /// The gap between segments, along the ring.
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const top = -math.pi / 2;
    if (segments <= 0) {
      line.strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, 2 * math.pi, false, line..color = track);
      if (value > 0) canvas.drawArc(rect, top, 2 * math.pi * value, false, line..color = color);
      return;
    }
    line.strokeCap = StrokeCap.butt;
    final step = 2 * math.pi / segments;
    final gap = _gap / (rect.width / 2);
    final arc = step - gap;
    final filled = value * segments;
    for (var i = 0; i < segments; i++) {
      final start = top + i * step + gap / 2;
      canvas.drawArc(rect, start, arc, false, line..color = track);
      final part = (filled - i).clamp(0.0, 1.0);
      if (part > 0) canvas.drawArc(rect, start, arc * part, false, line..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke ||
      old.segments != segments;
}

/// The streak and this week as a chain (D-093): the flame and "N days in a
/// row" with the week's answers on the right, then seven days, oldest on
/// the left. A met goal is a full warm circle with a check, some practice a
/// white circle with a warm arc toward the goal and the count inside, no
/// practice a dashed outline; the days of the streak stand on one soft warm
/// capsule. Today's name is in a black pill.
class _StreakWeek extends StatelessWidget {
  const _StreakWeek({required this.streak, required this.week, required this.goal});
  final int streak;
  final List<int> week;
  final int goal;

  static const double _day = 32;
  static const double _dayStroke = 3;
  static const double _chain = 38;
  static const double _rowGap = 14;
  static const double _nameGap = 6;
  static const double _todayPillHeight = 20;
  static const double _todayPillPadding = 7;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = appNow();
    final days = [for (var i = week.length - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    String dayName(DateTime d) {
      final n = DateFormat.E(locale).format(d);
      // Two letters: one would not tell П/С days apart.
      return n.length <= 2 ? n : n.substring(0, 2);
    }

    final total = week.fold<int>(0, (a, b) => a + b);
    final header = Row(
      children: [
        ExcludeSemantics(
          child: Icon(AppIcons.streak, size: AppSizes.iconLg, color: streak > 0 ? cs.flame : cs.onSurfaceVariant),
        ),
        AppGap.h8,
        Expanded(child: Text(l.streakDays(streak), style: context.tt.title)),
        // On a narrow phone or with large text it wraps instead of
        // pushing the row past the card.
        if (week.isNotEmpty) ...[
          AppGap.h8,
          Flexible(
            child: Text(l.weekAnswersTotal(total), style: context.tt.meta, textAlign: TextAlign.end),
          ),
        ],
      ],
    );
    if (week.isEmpty) return header;
    // Nothing yet this week and no streak: one quiet line instead of
    // "0 answers" and seven empty circles (D-116).
    if (streak == 0 && total == 0) {
      return Row(
        children: [
          ExcludeSemantics(
            child: Icon(AppIcons.streak, size: AppSizes.iconLg, color: cs.onSurfaceVariant),
          ),
          AppGap.h8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.streakDays(0), style: context.tt.title),
                AppGap.v2,
                Text(l.streakStartHint, style: context.tt.meta),
              ],
            ),
          ),
        ],
      );
    }

    Widget day(int i) {
      final count = week[i];
      if (goal > 0 && count >= goal || goal <= 0 && count > 0) {
        return Container(
          width: _day,
          height: _day,
          decoration: BoxDecoration(color: cs.flame, shape: BoxShape.circle),
          child: Icon(
            AppIcons.check,
            size: AppSizes.iconSm,
            color: cs.brightness == Brightness.light ? cs.onPrimary : cs.surface,
          ),
        );
      }
      if (count > 0) {
        return SizedBox.square(
          dimension: _day,
          child: AnimatedFraction(
            value: count / goal,
            emphasis: true,
            builder: (context, f) => CustomPaint(
              painter: _DayRingPainter(
                value: f,
                fill: cs.surfaceContainerLow,
                track: cs.flameTrack,
                color: cs.flame,
                stroke: _dayStroke,
              ),
              child: Center(
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1,
                  child: Text('$count', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurface).tabular),
                ),
              ),
            ),
          ),
        );
      }
      return SizedBox.square(
        dimension: _day,
        child: CustomPaint(painter: _DashedCirclePainter(color: cs.outline)),
      );
    }

    final chain = streakChain(week);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: _rowGap),
        Semantics(
          label:
              '${l.weekActivity([for (var i = 0; i < week.length; i++) '${dayName(days[i])} ${week[i]}'].join(', '))}; '
              '${l.streakDays(streak)}',
          excludeSemantics: true,
          child: Column(
            children: [
              SizedBox(
                height: _chain,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final slot = c.maxWidth / week.length;
                    return Stack(
                      children: [
                        if (chain != null)
                          Positioned(
                            left: slot * (chain.$1 + 0.5) - _chain / 2,
                            width: slot * (chain.$2 - chain.$1) + _chain,
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: cs.flameContainer, borderRadius: AppRadius.full),
                            ),
                          ),
                        Row(
                          children: [for (var i = 0; i < week.length; i++) Expanded(child: Center(child: day(i)))],
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: _nameGap),
              Row(
                children: [
                  for (var i = 0; i < week.length; i++)
                    Expanded(
                      child: Center(
                        child: MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.2,
                          child: i == week.length - 1
                              ? Container(
                                  height: _todayPillHeight,
                                  padding: const EdgeInsets.symmetric(horizontal: _todayPillPadding),
                                  decoration: BoxDecoration(color: cs.onSurface, borderRadius: AppRadius.full),
                                  child: Center(
                                    widthFactor: 1,
                                    child: Text(
                                      dayName(days[i]),
                                      style: theme.textTheme.labelSmall?.copyWith(color: cs.surface),
                                    ),
                                  ),
                                )
                              : SizedBox(
                                  height: _todayPillHeight,
                                  child: Center(child: Text(dayName(days[i]), style: context.tt.meta)),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The days of the current streak within [week] (oldest first, today
/// last) as (first, last) indices, or null: days in a row with practice
/// that end today, or yesterday while today has none yet - as `streak()`
/// counts them.
@visibleForTesting
(int, int)? streakChain(List<int> week) {
  if (week.isEmpty) return null;
  var end = week.length - 1;
  if (week[end] <= 0) end--;
  if (end < 0 || week[end] <= 0) return null;
  var start = end;
  while (start > 0 && week[start - 1] > 0) {
    start--;
  }
  return (start, end);
}

/// A day with practice below the goal: a white disc, a warm track and the
/// warm arc of the day's share of the goal, round ends, from the top.
class _DayRingPainter extends CustomPainter {
  const _DayRingPainter({
    required this.value,
    required this.fill,
    required this.track,
    required this.color,
    required this.stroke,
  });
  final double value;
  final Color fill;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawOval(rect, Paint()..color = fill);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(rect, line..color = track);
    if (value > 0) {
      line.strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, line..color = color);
    }
  }

  @override
  bool shouldRepaint(_DayRingPainter old) =>
      old.value != value || old.fill != fill || old.track != track || old.color != color || old.stroke != stroke;
}

/// A day without practice: a dashed outline.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});
  final Color color;

  static const double _stroke = 1.5;
  static const int _dashes = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = color;
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * step, step / 2, false, line);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

/// A hairline across the whole card, past its padding.
class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AppSizes.hairline,
    child: LayoutBuilder(
      builder: (context, c) => OverflowBox(
        maxWidth: c.maxWidth + 2 * AppSpacing.card,
        minWidth: c.maxWidth + 2 * AppSpacing.card,
        child: ColoredBox(color: Theme.of(context).colorScheme.outlineVariant, child: const SizedBox.expand()),
      ),
    ),
  );
}

class RepertoireCard extends StatelessWidget {
  const RepertoireCard({
    super.key,
    required this.summary,
    this.reviewLimit,
    this.newLimit,
    this.problemKeys = const [],
  });
  final RepertoireSummary summary;

  /// New moves left for today (the button must not promise more).
  final int? newLimit;

  /// This repertoire's moves with frequent mistakes.
  final List<String> problemKeys;

  /// Reviews left for today (to show the same number as the main button).
  final int? reviewLimit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = summary;
    final learnedFrac = r.cards == 0 ? 0.0 : r.learned / r.cards;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: RepertoireInkWell(
        summary: r,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
          child: Row(
            children: [
              SideBadge(side: r.color),
              AppGap.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MovesText(
                      r.row.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppGap.v4,
                    Text(l.repertoireCounts(r.learned, r.cards), style: context.tt.meta),
                    AppGap.v8,
                    AppProgressBar(value: learnedFrac),
                  ],
                ),
              ),
              AppGap.h8,
              RepertoireTrainControl(
                summary: r,
                reviewLimit: reviewLimit,
                newLimit: newLimit,
                problemKeys: problemKeys,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A repertoire's card surface: a tap opens it, a long press opens its menu
/// where the finger is (rename, export, delete…); the action runs on its
/// screen.
class RepertoireInkWell extends StatefulWidget {
  const RepertoireInkWell({super.key, required this.summary, required this.child});
  final RepertoireSummary summary;
  final Widget child;

  @override
  State<RepertoireInkWell> createState() => _RepertoireInkWellState();
}

class _RepertoireInkWellState extends State<RepertoireInkWell> {
  Offset? _pressedAt;

  @override
  Widget build(BuildContext context) {
    final id = widget.summary.row.id;
    return InkWell(
      onTap: () async {
        // Another repertoire may be open in its tab with moves not added yet.
        if (await LeaveGuard.canLeave() && context.mounted) context.go('/repertoires/$id');
      },
      onTapDown: (d) => _pressedAt = d.globalPosition,
      onLongPress: () async {
        Haptics.selection();
        final at = _pressedAt ?? (Offset.zero & MediaQuery.sizeOf(context)).center;
        final l = context.l10n;
        final r = widget.summary;
        final action = await showAppMenu<String>(
          context,
          at: at,
          title: r.row.name,
          subtitle: l.repertoireCounts(r.learned, r.cards),
          items: repertoireMenuItems(context),
        );
        if (action == null || !context.mounted) return;
        if (await LeaveGuard.canLeave() && context.mounted) context.go('/repertoires/$id?action=$action');
      },
      child: widget.child,
    );
  }
}

/// The training control of a repertoire card: a pill with the play mark
/// and the number due, a round play button when only new moves are left,
/// or a check when today is done.
class RepertoireTrainControl extends StatelessWidget {
  /// The review button: a compact pill (40 high, 48 to tap) with the play
  /// mark and the count.
  static const _dueButton = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, AppSizes.controlSm)),
    padding: WidgetStatePropertyAll(EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.lg)),
    tapTargetSize: MaterialTapTargetSize.padded,
  );

  const RepertoireTrainControl({
    super.key,
    required this.summary,
    this.reviewLimit,
    this.newLimit,
    this.problemKeys = const [],
  });
  final RepertoireSummary summary;
  final int? reviewLimit;
  final int? newLimit;
  final List<String> problemKeys;

  /// Moves due and new moves within today's limits.
  static (int due, int fresh) counts(RepertoireSummary r, {int? reviewLimit, int? newLimit}) => (
    reviewLimit == null || r.due < reviewLimit ? r.due : reviewLimit,
    newLimit == null || r.newCards < newLimit ? r.newCards : newLimit,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = summary;
    final (due, fresh) = counts(r, reviewLimit: reviewLimit, newLimit: newLimit);
    // The same session as the main button, for this repertoire only.
    final id = r.row.id;
    final stages = [
      if (due > 0) TrainingStage(mode: TrainingMode.review, repertoireIds: [id]),
      if (problemKeys.isNotEmpty)
        TrainingStage(mode: TrainingMode.problems, repertoireIds: [id], problemKeys: {id: problemKeys}),
      if (fresh > 0) TrainingStage(mode: TrainingMode.learn, repertoireIds: [id]),
    ];
    // Moves waiting for review sit in the button that trains them, in
    // ink, not in an alarm-red badge over it (D-088).
    if (stages.isNotEmpty && due > 0) {
      return Tooltip(
        message: l.trainDueCount(due),
        excludeFromSemantics: true,
        child: Semantics(
          label: l.trainDueCount(due),
          button: true,
          excludeSemantics: true,
          child: FilledButton.icon(
            // The same soft grey as the round play button.
            style: _dueButton.merge(
              FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
            icon: const Icon(AppIcons.play, size: AppSizes.iconSm),
            label: Text('$due', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
      );
    }
    if (stages.isNotEmpty) {
      return IconButton.filledTonal(
        tooltip: l.trainNow,
        onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
        icon: const Icon(AppIcons.play),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Icon(AppIcons.ok, semanticLabel: l.allDoneShort),
    );
  }
}
