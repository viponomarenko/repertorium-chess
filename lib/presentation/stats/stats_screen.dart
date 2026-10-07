import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../domain/training/training_engine.dart';
import '../training/training_args.dart';
import 'stats_view.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, this.repertoireId});
  final int? repertoireId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.statsTitle)),
      body: StatsView(
        repertoireId: repertoireId,
        onTrainProblem: (p) => context.push(
          '/train',
          extra: TrainingArgs(
            repertoireIds: [p.repertoireId],
            mode: TrainingMode.problems,
            problemKeys: {
              p.repertoireId: [p.key],
            },
          ),
        ),
      ),
    );
  }
}
