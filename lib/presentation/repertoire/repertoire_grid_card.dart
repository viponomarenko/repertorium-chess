import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../app/providers.dart';
import '../home/today_screen.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';

/// A repertoire in the grid of a wide Repertoires page (D-104): its side
/// and training control, the name, the first moves of its main line, then
/// the progress and what is left today.
class RepertoireGridCard extends ConsumerWidget {
  const RepertoireGridCard({
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

  /// Room for two lines of a name, so the cards of a row line up.
  static const double _nameMinHeight = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = summary;
    final learnedFrac = r.cards == 0 ? 0.0 : r.learned / r.cards;
    final (due, fresh) = RepertoireTrainControl.counts(r, reviewLimit: reviewLimit, newLimit: newLimit);
    final status = due > 0
        ? l.repStatusDue(due, fresh)
        : fresh > 0
        ? l.repStatusNew(fresh)
        : l.repStatusDone;
    final first = ref.watch(firstMovesProvider(r.row.id)).value;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: RepertoireInkWell(
        summary: r,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SideBadge(side: r.color),
                      const Spacer(),
                      RepertoireTrainControl(
                        summary: r,
                        reviewLimit: reviewLimit,
                        newLimit: newLimit,
                        problemKeys: problemKeys,
                      ),
                    ],
                  ),
                  AppGap.v8,
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _nameMinHeight),
                      child: MovesText(
                        r.row.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (first != null && first.sans.isNotEmpty) ...[
                    AppGap.v8,
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: FirstMovesLine(first),
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            const CardHairline(),
            Padding(
              padding: AppInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(context.fmtPercent(learnedFrac), style: context.tt.value.tabular),
                      AppGap.h8,
                      Expanded(
                        child: Text(
                          l.learnedOfTotal(r.learned, r.cards),
                          style: context.tt.meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  AppGap.v8,
                  AppProgressBar(value: learnedFrac),
                  AppGap.v8,
                  Text(status, style: context.tt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1. e4 e5 2. Nf3 Nc6 3. Bb5" with grey move numbers, on one line.
class FirstMovesLine extends ConsumerWidget {
  const FirstMovesLine(this.moves, {super.key});
  final FirstMoves moves;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(notationFormatterProvider);
    final tt = context.tt;
    final numberStyle = tt.moveNumber.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final spans = <InlineSpan>[];
    var number = moves.moveNumber;
    var white = moves.whiteFirst;
    for (var i = 0; i < moves.sans.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' ', style: numberStyle));
      if (white) {
        spans.add(TextSpan(text: '$number. ', style: numberStyle));
      } else if (i == 0) {
        spans.add(TextSpan(text: '$number… ', style: numberStyle));
      }
      spans.addAll(f.spans(moves.sans[i], tt.moveMain));
      if (!white) number++;
      white = !white;
    }
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      semanticsLabel: [for (final s in moves.sans) f.text(s)].join(' '),
    );
  }
}
