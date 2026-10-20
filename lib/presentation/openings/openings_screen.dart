import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/openings/opening_book.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../repertoire/create_repertoire_dialog.dart';
import '../theme/app_icons.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';
import 'opening_picker.dart';

/// Catalog of opening names / ECO codes (F-THEORY-02).
class OpeningsScreen extends ConsumerStatefulWidget {
  const OpeningsScreen({super.key});

  @override
  ConsumerState<OpeningsScreen> createState() => _OpeningsScreenState();
}

class _OpeningsScreenState extends ConsumerState<OpeningsScreen> {
  /// Side of the board in the sheet of an opening.
  static const double _boardSize = 240;

  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final book = ref.watch(openingBookProvider);
    return Scaffold(
      appBar: PageBar(bar: AppBar(title: Text(l.openingsTitle))),
      body: book.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(openingBookProvider)),
        data: (b) {
          final searching = _q.trim().isNotEmpty;
          final results = searching ? b.search(_q, limit: 300) : const <OpeningInfo>[];
          final families = searching ? const <String, List<OpeningFamily>>{} : b.familiesByLetter();
          final popular = searching ? const <OpeningInfo>[] : popularOpenings(b);
          final groups = {'A': l.ecoGroupA, 'B': l.ecoGroupB, 'C': l.ecoGroupC, 'D': l.ecoGroupD, 'E': l.ecoGroupE};
          Widget tile(OpeningInfo o) => OpeningTile(opening: o, onTap: () => _open(o));
          final pad = EdgeInsets.zero.inPage(context);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.sm,
                ).inPage(context),
                child: TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(AppIcons.search), hintText: l.openingsSearchHint),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                // Searching: the matches in one list. Otherwise the
                // openings people play most, then the catalog by ECO
                // letter, each family folded into one row (D-119).
                child: CustomScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (searching)
                      SliverPadding(
                        padding: pad,
                        sliver: SliverList.builder(itemCount: results.length, itemBuilder: (_, i) => tile(results[i])),
                      )
                    else ...[
                      SliverPadding(
                        padding: pad,
                        sliver: SliverToBoxAdapter(child: SectionHeader(l.popularOpenings)),
                      ),
                      SliverPadding(
                        padding: pad,
                        sliver: SliverList.builder(itemCount: popular.length, itemBuilder: (_, i) => tile(popular[i])),
                      ),
                      for (final MapEntry(key: letter, value: name) in groups.entries)
                        if (families[letter] case final list?) ...[
                          SliverPadding(
                            padding: pad,
                            sliver: SliverToBoxAdapter(child: SectionHeader('$letter · $name')),
                          ),
                          SliverPadding(
                            padding: pad,
                            sliver: SliverList.builder(
                              itemCount: list.length,
                              itemBuilder: (_, i) => _FamilyTile(family: list[i], tile: tile),
                            ),
                          ),
                        ],
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.listBottom)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _moves(OpeningInfo o) => openingMovesText(o);

  Future<void> _open(OpeningInfo o) async {
    final l = context.l10n;
    final game = PgnParser.parseOne('${_moves(o)} *');
    final fen = game.mainline.isEmpty ? kInitialFen : game.mainline.last.fen;
    await showAppSheet<void>(
      context,
      title: '${o.eco} ${o.name}',
      builder: (ctx) => Padding(
        padding: AppInsets.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MovesText(_moves(o), textAlign: TextAlign.center),
            AppGap.v12,
            MiniBoard(fen: fen, size: _boardSize),
            AppGap.v16,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.push(
                      '/analysis',
                      extra: GameScreenArgs(pgn: '${_moves(o)} *', initialPath: List.filled(o.moves.length, 0)),
                    );
                  },
                  icon: const Icon(AppIcons.explorer),
                  label: Text(l.exploreOpening),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // The opening is usually named after the side that made
                    // its last move (e.g. the Sicilian is Black's choice).
                    showCreateRepertoire(
                      context,
                      fen: _moves(o),
                      name: o.name,
                      color: o.moves.length.isOdd ? Side.white : Side.black,
                    );
                  },
                  icon: const Icon(AppIcons.repertoire),
                  label: Text(l.createRepertoireFromHere),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A family of the catalog folded into one row: its name, codes and the
/// number of lines; open, its lines (D-119).
class _FamilyTile extends StatelessWidget {
  const _FamilyTile({required this.family, required this.tile});
  final OpeningFamily family;
  final Widget Function(OpeningInfo) tile;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // A family of one line needs no folding.
    if (family.lines.length == 1) return tile(family.lines.single);
    return AppExpansionTile(
      leading: AppAvatar(text: family.firstEco),
      title: Text(family.name),
      subtitle: Text('${family.ecoRange} · ${l.openingVariations(family.lines.length)}', style: context.tt.meta),
      children: [for (final o in family.lines) tile(o)],
    );
  }
}
