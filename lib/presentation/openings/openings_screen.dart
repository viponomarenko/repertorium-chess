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
      appBar: AppBar(title: Text(l.openingsTitle)),
      body: book.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(openingBookProvider)),
        data: (b) {
          final results = b.search(_q, limit: 300);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.sm),
                child: TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(AppIcons.search), hintText: l.openingsSearchHint),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final o = results[i];
                    return ListTile(
                      leading: AppAvatar(text: o.eco),
                      title: Text(o.name),
                      subtitle: MovesText(_moves(o), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(o),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _moves(OpeningInfo o) {
    final sb = StringBuffer();
    for (var i = 0; i < o.moves.length; i++) {
      if (i.isEven) sb.write('${i ~/ 2 + 1}. ');
      sb.write('${o.moves[i]} ');
    }
    return sb.toString().trim();
  }

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
