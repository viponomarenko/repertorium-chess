import 'dart:async';

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
      appBar: AppBar(
        title: const Text(AppInfo.name),
        actions: [
          IconButton(tooltip: l.statsTitle, icon: const Icon(AppIcons.stats), onPressed: () => context.push('/stats')),
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(AppIcons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
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
    final introduced = ref.watch(introducedTodayProvider).value ?? 0;
    final reviewedToday = ref.watch(reviewedTodayProvider).value ?? 0;
    final reviewLeft = (settings.reviewsPerDay - reviewedToday).clamp(0, 100000);
    final totalDue = reps.fold<int>(0, (a, r) => a + r.due);
    final dueCapped = totalDue < reviewLeft ? totalDue : reviewLeft;
    final totalNew = reps.fold<int>(0, (a, r) => a + r.newCards);
    final newLeft = (settings.newPerDay - introduced).clamp(0, 100000);
    final newAvailable = totalNew < newLeft ? totalNew : newLeft;
    final today = ref.watch(todayCountProvider).value ?? 0;
    final streak = ref.watch(streakProvider).value ?? 0;
    final week = ref.watch(weekActivityProvider).value ?? const <int>[];
    final problems = ref.watch(problemCountProvider).value ?? const [];
    final nextDue = ref.watch(nextDueProvider).value;

    final problemsByRep = <int, List<String>>{};
    for (final p in problems) {
      (problemsByRep[p.repertoireId] ??= []).add(p.key);
    }
    // One session, in the order that matters: what is due, then the moves
    // that keep going wrong, then new ones up to the daily limit (D-065).
    final stages = [
      if (dueCapped > 0)
        TrainingStage(
          mode: TrainingMode.review,
          repertoireIds: [
            for (final r in reps)
              if (r.due > 0) r.row.id,
          ],
        ),
      if (problemsByRep.isNotEmpty)
        TrainingStage(
          mode: TrainingMode.problems,
          repertoireIds: problemsByRep.keys.toList(),
          problemKeys: problemsByRep,
        ),
      if (newAvailable > 0)
        TrainingStage(
          mode: TrainingMode.learn,
          repertoireIds: [
            for (final r in reps)
              if (r.newCards > 0) r.row.id,
          ],
        ),
    ];
    final trainButton = stages.isEmpty
        ? null
        : FilledButton.icon(
            style: AppButtonSize.large,
            onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
            icon: const Icon(AppIcons.play),
            label: Text(l.trainNow),
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

    return RefreshIndicator(
      onRefresh: () async => ref.read(refreshTickProvider.notifier).bump(),
      child: MaxWidth(
        width: _dashboardWidth,
        child: ListView(
          padding: AppInsets.page,
          children: [
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GoalHeader(done: today, goal: settings.dailyGoal),
                    AppGap.v16,
                    ?trainButton,
                    if (trainButton != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          [
                            if (dueCapped > 0) l.stageReviewCount(dueCapped),
                            if (problems.isNotEmpty) l.stageProblemsCount(problems.length),
                            if (newAvailable > 0) l.stageNewCount(newAvailable),
                          ].join(' · '),
                          textAlign: TextAlign.center,
                          style: context.tt.meta,
                        ),
                      ),
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
                        style: AppButtonSize.large,
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
                    if (reps.any((r) => r.cards > 0))
                      Center(
                        child: TextButton(
                          onPressed: () => showModeSheet(context, ref, reps: reps),
                          child: Text(l.otherModes),
                        ),
                      ),
                    AppGap.v8,
                    _StreakWeek(streak: streak, week: week, goal: settings.dailyGoal),
                  ],
                ),
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}

/// The top of the "Today" card: the date as a quiet caption, the state of
/// the daily goal as the headline, the numbers under it, and the goal ring
/// beside them. One statement instead of a title, a status line, a ring and
/// its label (D-082).
class _GoalHeader extends StatelessWidget {
  const _GoalHeader({required this.done, required this.goal});
  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final reached = done >= goal;
    final date = DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(appNow());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.overline),
              AppGap.v4,
              Text(
                reached ? l.goalDone : l.goalLeft(goal - done),
                // In ink: the ring carries the colour.
                style: theme.textTheme.headlineSmall,
              ),
              AppGap.v4,
              Text(l.goalProgress(done, goal), style: context.tt.meta.tabular),
            ],
          ),
        ),
        AppGap.h16,
        // The line above says the same in words.
        ExcludeSemantics(
          child: _GoalRing(done: done, goal: goal),
        ),
      ],
    );
  }
}

/// The daily goal as a ring: thin, filling in the warm colour; once the
/// goal is reached it closes in green around a trophy on a soft disc.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.done, required this.goal});
  final int done;
  final int goal;

  /// Diameter of the ring, the thickness of its line and the gap between
  /// the line and the disc inside.
  static const double _size = 72;
  static const double _stroke = 6;
  static const double _inset = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final v = goal <= 0 ? 1.0 : (done / goal).clamp(0.0, 1.0);
    final reached = v >= 1;
    final color = reached ? cs.success : cs.flame;
    return SizedBox.square(
      dimension: _size,
      child: AnimatedFraction(
        value: v,
        emphasis: true,
        builder: (context, value) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: _stroke,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: AppOpacity.faint),
              ),
            ),
            if (reached)
              PopIn(
                trigger: reached,
                child: Container(
                  width: _size - 2 * (_stroke + _inset),
                  height: _size - 2 * (_stroke + _inset),
                  decoration: BoxDecoration(color: cs.successContainer, shape: BoxShape.circle),
                  child: Icon(AppIcons.trophy, size: AppSizes.iconLg, color: cs.success),
                ),
              )
            else
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.2,
                child: Text('$done', style: theme.textTheme.titleLarge?.tabular.copyWith(height: 1)),
              ),
          ],
        ),
      ),
    );
  }
}

/// The streak (a flame, coloured once there is one) and this week as seven
/// small bars: full flame colour on days the goal was met, pale on days
/// with some practice, a dot on empty days; today's label is bold.
class _StreakWeek extends StatelessWidget {
  const _StreakWeek({required this.streak, required this.week, required this.goal});
  final int streak;
  final List<int> week;
  final int goal;

  /// A day's bar: its width, its height from some practice to the goal,
  /// and the mark of an empty day.
  static const double _barWidth = 12;
  static const double _barMin = 6;
  static const double _barMax = 28;
  static const double _dotHeight = 4;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final today = appNow();
    final days = [for (var i = week.length - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    String dayName(DateTime d) => DateFormat.E(locale).format(d);
    final streakLabel = Row(
      children: [
        ExcludeSemantics(
          child: Icon(AppIcons.streak, size: AppSizes.iconLg, color: streak > 0 ? cs.flame : cs.onSurfaceVariant),
        ),
        AppGap.h8,
        Flexible(child: Text(l.streakDays(streak), style: theme.textTheme.titleSmall)),
      ],
    );
    final chart = week.isEmpty
        ? null
        : Semantics(
            label: l.weekActivity([for (var i = 0; i < week.length; i++) '${dayName(days[i])} ${week[i]}'].join(', ')),
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < week.length; i++)
                  Padding(
                    padding: i == 0 ? EdgeInsets.zero : const EdgeInsets.only(left: AppSpacing.sm),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedFraction(
                          value: goal <= 0 ? 0 : week[i] / goal,
                          emphasis: true,
                          builder: (context, f) => Container(
                            width: _barWidth,
                            height: week[i] == 0 ? _dotHeight : _barMin + (_barMax - _barMin) * f,
                            decoration: BoxDecoration(
                              color: week[i] == 0
                                  ? cs.surfaceContainerHighest
                                  : (week[i] >= goal ? cs.flame : cs.flame.withValues(alpha: AppOpacity.muted)),
                              borderRadius: AppRadius.full,
                            ),
                          ),
                        ),
                        AppGap.v4,
                        MediaQuery.withClampedTextScaling(
                          maxScaleFactor: 1.2,
                          child: Text(
                            // Two letters: one would not tell П/С days apart.
                            dayName(days[i]).length <= 2 ? dayName(days[i]) : dayName(days[i]).substring(0, 2),
                            // Same size; today in the heavier of the two weights.
                            style: i == week.length - 1
                                ? theme.textTheme.labelSmall?.copyWith(color: cs.onSurface)
                                : theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
    // Side by side when there is room; on a narrow phone or with large
    // text the week goes under the streak.
    return LayoutBuilder(
      builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (chart == null) return streakLabel;
        if (c.maxWidth >= 300 && scale <= 1.3) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: streakLabel),
              AppGap.h8,
              chart,
            ],
          );
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [streakLabel, AppGap.v12, chart]);
      },
    );
  }
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
    final due = reviewLimit == null || r.due < reviewLimit! ? r.due : reviewLimit!;
    final fresh = newLimit == null || r.newCards < newLimit! ? r.newCards : newLimit!;
    final learnedFrac = r.cards == 0 ? 0.0 : r.learned / r.cards;
    // The same session as the main button, for this repertoire only.
    final id = r.row.id;
    final stages = [
      if (due > 0) TrainingStage(mode: TrainingMode.review, repertoireIds: [id]),
      if (problemKeys.isNotEmpty)
        TrainingStage(mode: TrainingMode.problems, repertoireIds: [id], problemKeys: {id: problemKeys}),
      if (fresh > 0) TrainingStage(mode: TrainingMode.learn, repertoireIds: [id]),
    ];
    Offset? pressedAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          // Another repertoire may be open in its tab with moves not added yet.
          if (await LeaveGuard.canLeave() && context.mounted) context.go('/repertoires/${r.row.id}');
        },
        // A long press opens the repertoire's own menu (rename, export,
        // delete…) where the finger is; the action runs on its screen.
        onTapDown: (d) => pressedAt = d.globalPosition,
        onLongPress: () async {
          Haptics.selection();
          final at = pressedAt ?? (Offset.zero & MediaQuery.sizeOf(context)).center;
          final action = await showAppMenu<String>(context, at: at, items: repertoireMenuItems(context));
          if (action == null || !context.mounted) return;
          if (await LeaveGuard.canLeave() && context.mounted) context.go('/repertoires/${r.row.id}?action=$action');
        },
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
              if (stages.isNotEmpty)
                Badge(
                  isLabelVisible: due > 0,
                  label: Text('$due'),
                  child: IconButton.filledTonal(
                    tooltip: l.trainNow,
                    onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
                    icon: const Icon(AppIcons.play),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Icon(AppIcons.ok, semanticLabel: l.allDoneShort),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
