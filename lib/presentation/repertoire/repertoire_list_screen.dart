import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../app/providers.dart';
import '../home/day_plan.dart';
import '../home/today_screen.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/common.dart';
import 'create_repertoire_dialog.dart';
import 'repertoire_grid_card.dart';

class RepertoireListScreen extends ConsumerStatefulWidget {
  const RepertoireListScreen({super.key});

  @override
  ConsumerState<RepertoireListScreen> createState() => _RepertoireListScreenState();
}

class _RepertoireListScreenState extends ConsumerState<RepertoireListScreen> {
  /// The side shown on a wide page; null: both.
  Side? _side;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reps = ref.watch(repertoiresProvider);
    // A tablet gets the overview and the grid (D-104); a phone keeps its
    // list, which works well as it is.
    final wide = isWideLayout(context);
    final hasAny = !(reps.value?.isEmpty ?? true);
    return Scaffold(
      appBar: PageBar(
        width: wide ? AppSizes.dashboardWidth : AppSizes.maxContentWidth,
        bar: AppBar(
          title: Text(l.navRepertoires),
          actions: [
            // Creating a repertoire sits in the bar with the other actions:
            // no button floating over the list. An empty list has its own
            // big button in the middle, so there is no duplicate here.
            if (hasAny && wide)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Tooltip(
                  message: l.createRepertoire,
                  // Outlined: the black action of this page is "Train all".
                  child: OutlinedButton.icon(
                    style: AppButtonSize.compact,
                    onPressed: () => showCreateRepertoire(context),
                    icon: const Icon(AppIcons.add, size: AppSizes.iconMd),
                    label: Text(l.create),
                  ),
                ),
              )
            else if (hasAny)
              // The same quiet "+ Create" as above the list on Today: the
              // black of this page belongs to the cards' Train (D-120).
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Tooltip(
                  message: l.createRepertoire,
                  child: TextButton.icon(
                    onPressed: () => showCreateRepertoire(context),
                    icon: const Icon(AppIcons.add),
                    label: Text(l.create),
                  ),
                ),
              ),
          ],
        ),
      ),
      body: reps.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(repertoiresProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: AppIcons.repertoire,
                title: l.noRepertoires,
                message: l.noRepertoiresHint,
                actions: [
                  FilledButton.icon(
                    onPressed: () => showCreateRepertoire(context),
                    icon: const Icon(AppIcons.add),
                    label: Text(l.createRepertoire),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showStarterPicker(context),
                    icon: const Icon(AppIcons.starter),
                    label: Text(l.installStarter),
                  ),
                ],
              )
            : wide
            ? _wide(list)
            : ListView(
                padding: AppInsets.page.inPage(context),
                children: [
                  for (final (i, r) in list.indexed) ...[if (i > 0) AppGap.v12, RepertoireCard(summary: r)],
                  if (_missingSide(list) case final side?) ...[AppGap.v24, _OtherSide(side)],
                ],
              ),
      ),
    );
  }

  /// The side no repertoire covers yet, when all are of one colour.
  static Side? _missingSide(List<RepertoireSummary> list) {
    if (list.isEmpty) return null;
    final first = list.first.color;
    return list.every((r) => r.color == first) ? first.opposite : null;
  }

  Widget _wide(List<RepertoireSummary> list) {
    final l = context.l10n;
    final plan = DayPlan.of(ref, list);
    final whites = list.where((r) => r.color == Side.white).length;
    final shown = _side == null ? list : list.where((r) => r.color == _side).toList();
    // The side filter only when there is something to tell apart.
    final filters = whites > 0 && whites < list.length;
    return ListView(
      padding: AppInsets.page.inPage(context, width: AppSizes.dashboardWidth),
      children: [
        _Summary(plan),
        if (filters) ...[
          AppGap.v16,
          ChipRow(
            children: [
              CountChip(
                label: l.all,
                count: list.length,
                selected: _side == null,
                onTap: () => setState(() => _side = null),
              ),
              CountChip(
                label: l.asWhite,
                count: whites,
                selected: _side == Side.white,
                onTap: () => setState(() => _side = _side == Side.white ? null : Side.white),
              ),
              CountChip(
                label: l.asBlack,
                count: list.length - whites,
                selected: _side == Side.black,
                onTap: () => setState(() => _side = _side == Side.black ? null : Side.black),
              ),
            ],
          ),
        ],
        AppGap.v16,
        CardGrid(
          children: [
            for (final r in shown)
              RepertoireGridCard(
                summary: r,
                // The cards promise no more than "Train all" does.
                reviewLimit: plan.reviewLeft,
                newLimit: plan.newLeft,
                problemKeys: plan.problemsByRep[r.row.id] ?? const [],
              ),
          ],
        ),
      ],
    );
  }
}

/// What all the repertoires have for today, with the one button that
/// trains it: the same session as the main button of Today.
class _Summary extends StatelessWidget {
  const _Summary(this.plan);
  final DayPlan plan;

  /// The main button of the page: as high as the main action, snug.
  static const _trainButton = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, AppSizes.controlLg)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.xl)),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final stages = plan.stages;
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.repSummaryIn(plan.reps.length).toUpperCase(), style: context.tt.overline),
                  AppGap.v4,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${plan.dueCapped}', style: context.tt.hero.tabular),
                      AppGap.h8,
                      Flexible(child: Text(l.dueToday, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                  AppGap.v4,
                  Text(l.repSummaryLine(plan.newAvailable, plan.totalLearned, plan.totalCards), style: context.tt.meta),
                ],
              ),
            ),
            if (stages.isNotEmpty) ...[
              AppGap.h16,
              FilledButton.icon(
                style: _trainButton,
                onPressed: () => context.push('/train', extra: TrainingArgs.staged(stages)),
                icon: const Icon(AppIcons.drill),
                label: Text(l.trainAll),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Under the list when every repertoire is for one side: a quiet card that
/// offers the other one (D-120).
class _OtherSide extends StatelessWidget {
  const _OtherSide(this.side);
  final Side side;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(side == Side.white ? l.defaultRepNameWhite : l.defaultRepNameBlack, style: context.tt.title),
            AppGap.v4,
            Text(l.repertoireOtherSideHint, style: context.tt.meta),
            AppGap.v12,
            OutlinedButton.icon(
              onPressed: () => showCreateRepertoire(context, color: side),
              icon: const Icon(AppIcons.add),
              label: Text(l.create),
            ),
          ],
        ),
      ),
    );
  }
}
