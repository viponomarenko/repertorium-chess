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

/// "Modes": one of the four training modes over [reps], for those
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
  final modes = [
    appMenuItem(
      value: TrainingMode.review,
      icon: AppIcons.again,
      label: l.modeReview,
      subtitle: l.modeReviewHint(due),
      enabled: due > 0,
    ),
    appMenuItem(
      value: TrainingMode.problems,
      icon: AppIcons.warning,
      label: l.modeProblems,
      subtitle: l.modeProblemsHint(problems.length),
      enabled: problems.isNotEmpty,
    ),
    appMenuItem(
      value: TrainingMode.learn,
      icon: AppIcons.learn,
      label: l.modeLearn,
      subtitle: fresh > newLeft ? '${l.modeLearnHint(fresh)} · ${l.todayUpTo(newLeft)}' : l.modeLearnHint(fresh),
      // Not offered once today's limit of new moves is used up.
      enabled: fresh > 0 && newLeft > 0,
    ),
    appMenuItem(
      value: TrainingMode.drill,
      icon: AppIcons.drill,
      label: l.modeDrill,
      // Off, it says when it opens rather than what it does.
      subtitle: reps.any((r) => r.learned > 0) ? l.modeDrillHint : l.modeDrillLocked,
      enabled: reps.any((r) => r.learned > 0),
    ),
  ];
  // The menu sheet of the app (D-114): what can be trained now first, the
  // rest below it under its own caption, each saying why it is off.
  final open = [
    for (final m in modes)
      if (m.enabled) m,
  ];
  final closed = [
    for (final m in modes)
      if (!m.enabled) m,
  ];
  final mode = await showAppMenu<TrainingMode>(
    context,
    title: l.modesTitle,
    items: [
      ...open,
      if (closed.isNotEmpty) ...[appMenuDivider(l.modesUnavailable), ...closed],
    ],
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
