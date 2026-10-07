import '../../domain/chess/chess_utils.dart';
import '../../domain/training/training_engine.dart';

/// One part of a session: a mode and the repertoires it runs over.
class TrainingStage {
  const TrainingStage({required this.mode, required this.repertoireIds, this.problemKeys = const {}});
  final TrainingMode mode;
  final List<int> repertoireIds;

  /// Problem positions per repertoire (F-TRN-04).
  final Map<int, List<PositionKey>> problemKeys;
}

/// Arguments for the training screen. Several repertoires are trained one
/// after another (e.g. "Review everything due").
class TrainingArgs {
  const TrainingArgs({
    required this.repertoireIds,
    required this.mode,
    this.startKey,
    this.problemKeys = const {},
    this.maxLines,
    this.maxMinutes,
  }) : stages = null;

  /// A session of several parts played one after another: what is due,
  /// then frequent mistakes, then new moves (the "Train" button, D-065).
  TrainingArgs.staged(List<TrainingStage> this.stages, {this.maxLines, this.maxMinutes})
    : repertoireIds = stages.first.repertoireIds,
      mode = stages.first.mode,
      problemKeys = stages.first.problemKeys,
      startKey = null;

  /// Null for a plain single-mode session.
  final List<TrainingStage>? stages;

  List<TrainingStage> get allStages =>
      stages ?? [TrainingStage(mode: mode, repertoireIds: repertoireIds, problemKeys: problemKeys)];

  /// Every repertoire of the session, each once.
  List<int> get allRepertoireIds => {for (final st in allStages) ...st.repertoireIds}.toList();

  final List<int> repertoireIds;
  final TrainingMode mode;

  /// Subtree root (only with a single repertoire), F-TRN-05.
  final PositionKey? startKey;

  /// Problem positions per repertoire (F-TRN-04).
  final Map<int, List<PositionKey>> problemKeys;
  final int? maxLines;
  final int? maxMinutes;
}
