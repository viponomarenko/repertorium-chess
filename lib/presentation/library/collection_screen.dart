import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../../data/import/pgn_import_service.dart';
import '../../data/repositories/library_repository.dart';
import '../../domain/pgn/pgn_model.dart';
import '../app/app.dart' show scaffoldMessengerKey;
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../repertoire/import_wizard_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/export_sheet.dart';
import 'import_flow.dart';

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _search = TextEditingController();
  GameFilter _filter = const GameFilter();
  bool _searching = false;
  final Set<int> _selected = {};
  bool _selectMode = false;

  void _endSelection() => setState(() {
    _selected.clear();
    _selectMode = false;
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _export(List<GameRow> all, String name) async {
    final repo = ref.read(libraryRepositoryProvider);
    final text = _selected.isEmpty
        ? await repo.exportPgn(collectionId: widget.id)
        : await repo.exportPgn(gameIds: all.where((g) => _selected.contains(g.id)).map((g) => g.id).toList());
    if (!mounted) return;
    await showExportSheet(context, text: text, baseName: name);
  }

  Future<void> _toRepertoire(List<GameRow> all, String name) async {
    final rows = _selected.isEmpty ? all : all.where((g) => _selected.contains(g.id)).toList();
    final games = [for (final r in rows) parseStoredGame(r.pgn)];
    await context.push(
      '/rep-import',
      extra: RepImportRequest(games: games, sourceLabel: name),
    );
  }

  /// Deletes right away; the snackbar offers to undo (no confirmation
  /// dialog in the way).
  Future<void> _delete() async {
    final l = context.l10n;
    final repo = ref.read(libraryRepositoryProvider);
    final rows = await repo.deleteGames(_selected.toList());
    if (!mounted) return;
    _endSelection();
    showSnack(
      context,
      l.gamesDeleted(rows.length),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          try {
            await repo.restoreGames(rows);
          } catch (_) {
            // The collection was deleted in the meantime.
            final m = scaffoldMessengerKey.currentState;
            if (m != null && m.mounted) m.showSnackBar(SnackBar(content: Text(l.undoFailed)));
          }
        },
      ),
    );
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _search.clear();
    _filter = GameFilter(result: _filter.result);
  });

  Future<void> _move() async {
    final l = context.l10n;
    // Asked now, not taken from a cached value: a collection created a
    // moment ago (a saved analysis) must be in the list.
    final repo = ref.read(libraryRepositoryProvider);
    final cols = await repo.watchCollections().first;
    if (!mounted) return;
    // -1: a new collection (also the only choice when there is no other).
    var target = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.moveTo),
        children: [
          for (final c in cols.where((c) => c.row.id != widget.id))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c.row.id), child: Text(c.row.name)),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, -1),
            child: Row(
              children: [
                const Icon(AppIcons.add, size: AppSizes.iconMd),
                AppGap.h8,
                Text(l.newCollection),
              ],
            ),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    if (target == -1) {
      final name = await promptText(context, title: l.newCollection, label: l.collectionName);
      if (name == null || name.trim().isEmpty) return;
      target = await repo.createCollection(name.trim());
    }
    await repo.moveGames(_selected.toList(), target);
    _endSelection();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.watch(libraryRepositoryProvider);
    return StreamBuilder<CollectionRow?>(
      stream: repo.watchCollection(widget.id),
      builder: (context, snap) {
        final col = snap.data;
        final name = col?.name ?? '';
        return StreamBuilder<List<GameRow>>(
          stream: repo.watchGames(widget.id, filter: _filter),
          builder: (context, gs) {
            final games = gs.data ?? const <GameRow>[];
            final selecting = _selectMode || _selected.isNotEmpty;
            return PopScope(
              // Back first closes the selection or the search.
              canPop: !selecting && !_searching,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (selecting) {
                  _endSelection();
                } else {
                  _closeSearch();
                }
              },
              child: Scaffold(
                appBar: selecting
                    ? AppBar(
                        leading: IconButton(
                          tooltip: l.cancel,
                          icon: const Icon(AppIcons.close),
                          onPressed: _endSelection,
                        ),
                        title: Text(l.selectedCount(_selected.length)),
                        actions: [
                          IconButton(
                            tooltip: l.selectAll,
                            icon: const Icon(AppIcons.selectAll),
                            onPressed: () => setState(() => _selected.addAll(games.map((g) => g.id))),
                          ),
                          IconButton(
                            tooltip: l.delete,
                            icon: const Icon(AppIcons.delete),
                            onPressed: _selected.isEmpty ? null : _delete,
                          ),
                          PopupMenuButton<String>(
                            constraints: appMenuConstraints,
                            icon: const Icon(AppIcons.more),
                            tooltip: l.more,
                            enabled: _selected.isNotEmpty,
                            onSelected: (v) async {
                              switch (v) {
                                case 'export':
                                  await _export(games, name);
                                case 'rep':
                                  await _toRepertoire(games, name);
                                case 'move':
                                  await _move();
                              }
                            },
                            itemBuilder: (_) => [
                              appMenuItem(value: 'export', icon: AppIcons.share, label: l.exportPgn),
                              appMenuItem(value: 'rep', icon: AppIcons.addToRepertoire, label: l.addToRepertoire),
                              appMenuItem(value: 'move', icon: AppIcons.moveTo, label: l.moveTo),
                            ],
                          ),
                        ],
                      )
                    : AppBar(
                        title: _searching
                            ? TextField(
                                controller: _search,
                                autofocus: true,
                                decoration: InputDecoration(hintText: l.searchGamesHint, border: InputBorder.none),
                                onChanged: (v) => setState(() {
                                  _filter = GameFilter(query: v, result: _filter.result);
                                  _selected.clear();
                                }),
                              )
                            : Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        actions: [
                          IconButton(
                            tooltip: _searching ? l.closeSearch : l.search,
                            icon: Icon(_searching ? AppIcons.close : AppIcons.search),
                            onPressed: _searching ? _closeSearch : () => setState(() => _searching = true),
                          ),
                          PopupMenuButton<String>(
                            constraints: appMenuConstraints,
                            icon: const Icon(AppIcons.more),
                            tooltip: l.more,
                            onSelected: (v) async {
                              switch (v) {
                                case 'new':
                                  await context.push('/game/new', extra: GameScreenArgs(collectionId: widget.id));
                                case 'newFen':
                                  final fen = await context.push<String>('/position-editor?pick=1');
                                  if (fen != null && context.mounted) {
                                    await context.push(
                                      '/game/new',
                                      extra: GameScreenArgs(collectionId: widget.id, fen: fen),
                                    );
                                  }
                                case 'import':
                                  await context.push('/import', extra: ImportInput(targetCollectionId: widget.id));
                                case 'export':
                                  await _export(games, name);
                                case 'rep':
                                  await _toRepertoire(games, name);
                                case 'select':
                                  setState(() => _selectMode = true);
                              }
                            },
                            itemBuilder: (_) => [
                              appMenuItem(
                                value: 'select',
                                icon: AppIcons.select,
                                label: l.select,
                                enabled: games.isNotEmpty,
                              ),
                              appMenuItem(value: 'new', icon: AppIcons.add, label: l.newGame),
                              appMenuItem(value: 'newFen', icon: AppIcons.editPosition, label: l.newGameFromPosition),
                              appMenuItem(value: 'import', icon: AppIcons.openFile, label: l.importHere),
                              appMenuItem(value: 'export', icon: AppIcons.share, label: l.exportPgn),
                              appMenuItem(value: 'rep', icon: AppIcons.addToRepertoire, label: l.addToRepertoire),
                            ],
                          ),
                        ],
                      ),
                body: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page, vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          for (final r in const ['1-0', '0-1', '1/2-1/2', '*'])
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.sm),
                              child: FilterChip(
                                label: Text(r == '1/2-1/2' ? '½-½' : r),
                                selected: _filter.result == r,
                                onSelected: (s) => setState(() {
                                  // A new filter hides games: forget the selection.
                                  _filter = GameFilter(query: _filter.query, result: s ? r : null);
                                  _selected.clear();
                                }),
                              ),
                            ),
                          Text(l.gamesCount(games.length), style: context.tt.meta),
                        ],
                      ),
                    ),
                    Expanded(
                      // Nothing has arrived yet: wait, do not say "no games".
                      child: !gs.hasData && !gs.hasError
                          ? const LoadingView()
                          : games.isEmpty
                          ? EmptyState(
                              icon: AppIcons.search,
                              title: _filter.isEmpty ? l.noGames : l.nothingFound,
                              actions: [
                                if (_filter.isEmpty)
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.push('/game/new', extra: GameScreenArgs(collectionId: widget.id)),
                                    icon: const Icon(AppIcons.add),
                                    label: Text(l.newGame),
                                  ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: games.length,
                              itemBuilder: (context, i) => _GameTile(
                                game: games[i],
                                selected: _selected.contains(games[i].id),
                                selecting: selecting,
                                onToggle: () => setState(() {
                                  if (!_selected.remove(games[i].id)) _selected.add(games[i].id);
                                }),
                                onOpen: () => context.push(
                                  '/game/${games[i].id}',
                                  extra: GameScreenArgs(siblings: games.map((g) => g.id).toList()),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({
    required this.game,
    required this.selected,
    required this.selecting,
    required this.onToggle,
    required this.onOpen,
  });
  final GameRow game;
  final bool selected;
  final bool selecting;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    String clean(String s) => s.isEmpty || s == '?' ? '' : s;
    final players = playersLine(game.white, game.black);
    final title = players.isNotEmpty ? players : (clean(game.event).isEmpty ? l.untitledGame : game.event);
    final details = [
      if (clean(game.event).isNotEmpty && title != game.event) game.event,
      if (clean(game.date).isNotEmpty && !game.date.startsWith('????')) game.date.replaceAll('.??', ''),
      if (game.eco.isNotEmpty) game.eco,
      if (game.opening.isNotEmpty) game.opening,
    ].join(' · ');
    final hasIssues = game.issuesJson.isNotEmpty;
    return ListTile(
      selected: selected,
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onToggle())
          : AppAvatar(text: game.result == '1/2-1/2' ? '½' : game.result),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        // Whole moves, as players count them (not half-moves).
        [details, l.fullMovesCount((game.plyCount + 1) ~/ 2)].where((s) => s.isNotEmpty).join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: hasIssues
          ? Tooltip(
              message: l.gameHasErrors,
              child: Icon(AppIcons.warning, color: theme.colorScheme.error),
            )
          : null,
      onTap: selecting ? onToggle : onOpen,
      onLongPress: onToggle,
    );
  }
}
