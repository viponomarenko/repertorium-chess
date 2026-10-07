import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/training/training_engine.dart';
import '../app/providers.dart';
import '../home/today_screen.dart' show introducedTodayProvider, problemCountProvider;
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import 'training_args.dart';

/// "Other modes": one of the four training modes over [reps], for those
/// who want something other than the daily session (D-065).
Future<void> showModeSheet(BuildContext context, WidgetRef ref, {required List<RepertoireSummary> reps}) async {
  final l = context.l10n;
  final ids = {for (final r in reps) r.row.id};
  final due = reps.fold<int>(0, (a, r) => a + r.due);
  final fresh = reps.fold<int>(0, (a, r) => a + r.newCards);
  final introduced = ref.read(introducedTodayProvider).value ?? 0;
  final newLeft = (ref.read(settingsProvider).newPerDay - introduced).clamp(0, 100000);
  final problems = [
    for (final p in ref.read(problemCountProvider).value ?? const <ProblemPosition>[])
      if (ids.contains(p.repertoireId)) p,
  ];
  final mode = await showAppSheet<TrainingMode>(
    context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(AppIcons.again),
          title: Text(l.modeReview),
          subtitle: Text(l.modeReviewHint(due)),
          enabled: due > 0,
          onTap: () => Navigator.pop(ctx, TrainingMode.review),
        ),
        ListTile(
          leading: const Icon(AppIcons.warning),
          title: Text(l.modeProblems),
          subtitle: Text(l.modeProblemsHint(problems.length)),
          enabled: problems.isNotEmpty,
          onTap: () => Navigator.pop(ctx, TrainingMode.problems),
        ),
        ListTile(
          leading: const Icon(AppIcons.learn),
          title: Text(l.modeLearn),
          subtitle: Text(
            fresh > newLeft ? '${l.modeLearnHint(fresh)} · ${l.todayUpTo(newLeft)}' : l.modeLearnHint(fresh),
          ),
          // Not offered once today's limit of new moves is used up.
          enabled: fresh > 0 && newLeft > 0,
          onTap: () => Navigator.pop(ctx, TrainingMode.learn),
        ),
        ListTile(
          leading: const Icon(AppIcons.drill),
          title: Text(l.modeDrill),
          subtitle: Text(l.modeDrillHint),
          enabled: reps.any((r) => r.learned > 0),
          onTap: () => Navigator.pop(ctx, TrainingMode.drill),
        ),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  final byRep = <int, List<String>>{};
  for (final p in problems) {
    (byRep[p.repertoireId] ??= []).add(p.key);
  }
  final repIds = switch (mode) {
    TrainingMode.review => [
      for (final r in reps)
        if (r.due > 0) r.row.id,
    ],
    TrainingMode.learn => [
      for (final r in reps)
        if (r.newCards > 0) r.row.id,
    ],
    TrainingMode.drill => [
      for (final r in reps)
        if (r.learned > 0) r.row.id,
    ],
    TrainingMode.problems => byRep.keys.toList(),
  };
  await context.push(
    '/train',
    extra: TrainingArgs(
      repertoireIds: repIds,
      mode: mode,
      problemKeys: mode == TrainingMode.problems ? byRep : const {},
    ),
  );
}
