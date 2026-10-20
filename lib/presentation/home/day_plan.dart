import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/repertoire_repository.dart';
import '../../domain/training/training_engine.dart';
import '../app/providers.dart';
import '../training/training_args.dart';
import 'today_screen.dart' show introducedTodayProvider, problemCountProvider, reviewedTodayProvider;

/// Today's training across all repertoires: what is left within the daily
/// limits and the one session that trains it. Shared by the main button of
/// Today and "Train all" of Repertoires, so both start the same session.
class DayPlan {
  DayPlan._(this.reps, this.reviewLeft, this.newLeft, this.problems);

  final List<RepertoireSummary> reps;

  /// Reviews and new moves still allowed today.
  final int reviewLeft;
  final int newLeft;

  /// This app's positions with frequent mistakes.
  final List<ProblemPosition> problems;

  static DayPlan of(WidgetRef ref, List<RepertoireSummary> reps) {
    final settings = ref.watch(settingsProvider);
    final introduced = ref.watch(introducedTodayProvider).value ?? 0;
    final reviewedToday = ref.watch(reviewedTodayProvider).value ?? 0;
    return DayPlan._(
      reps,
      (settings.reviewsPerDay - reviewedToday).clamp(0, 100000),
      (settings.newPerDay - introduced).clamp(0, 100000),
      ref.watch(problemCountProvider).value ?? const [],
    );
  }

  late final int totalDue = reps.fold<int>(0, (a, r) => a + r.due);
  late final int dueCapped = totalDue < reviewLeft ? totalDue : reviewLeft;
  late final int totalNew = reps.fold<int>(0, (a, r) => a + r.newCards);
  late final int newAvailable = totalNew < newLeft ? totalNew : newLeft;
  late final int totalCards = reps.fold<int>(0, (a, r) => a + r.cards);
  late final int totalLearned = reps.fold<int>(0, (a, r) => a + r.learned);

  late final Map<int, List<String>> problemsByRep = () {
    final m = <int, List<String>>{};
    for (final p in problems) {
      (m[p.repertoireId] ??= []).add(p.key);
    }
    return m;
  }();

  /// One session, in the order that matters: what is due, then the moves
  /// that keep going wrong, then new ones up to the daily limit (D-065).
  late final List<TrainingStage> stages = [
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
}
