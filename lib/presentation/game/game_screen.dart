import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/sound_service.dart';
import '../../data/import/pgn_import_service.dart';
import '../../data/repositories/library_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_writer.dart';
import '../app/providers.dart';
import '../repertoire/import_wizard_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/board_layout.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/engine_panel.dart';
import '../widgets/explorer_panel.dart';
import '../widgets/export_sheet.dart';
import '../widgets/notation_view.dart';
import '../widgets/san_text.dart';
import '../widgets/spoken.dart';
import 'game_controller.dart';
import 'headers_sheet.dart';

class GameScreenArgs {
  const GameScreenArgs({
    this.collectionId,
    this.fen,
    this.siblings = const [],
    this.pgn,
    this.initialPath,
    this.orientation,
    this.lineFor,
  });

  /// For a new game: where to save it.
  final int? collectionId;

  /// Starting position of a new game / analysis board.
  final String? fen;

  /// Ids of games in the list (previous / next game).
  final List<int> siblings;

  /// Open this PGN (unsaved analysis).
  final String? pgn;
  final List<int>? initialPath;

  /// Board orientation (else from the game's `Orientation` header).
  final Side? orientation;

  /// Opened from a repertoire (its name): a pinned bar adds the analysed
  /// line to it, and the screen pops with the line as standard UCI moves
  /// from [fen] (`List<String>`).
  final String? lineFor;
}

/// "12... Nf6 13. Bg5" for moves from the start of an analysis.
String nodesToText(List<GameNode> nodes) {
  final sb = StringBuffer();
  for (var i = 0; i < nodes.length; i++) {
    final p = nodes[i].parent!.position;
    if (sb.isNotEmpty) sb.write(' ');
    if (p.turn == Side.white) {
      sb.write('${p.fullmoves}. ${nodes[i].san}');
    } else {
      sb.write(i == 0 ? '${p.fullmoves}... ${nodes[i].san}' : nodes[i].san);
    }
  }
  return sb.toString();
}

final _gameLoaderProvider = FutureProvider.autoDispose.family<ChessGame?, int>((ref, id) async {
  final row = await ref.watch(libraryRepositoryProvider).game(id);
  return row == null ? null : parseStoredGame(row.pgn);
});

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key, required this.gameId, this.args = const GameScreenArgs()});
  final int? gameId;
  final GameScreenArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gameId == null) {
      ChessGame game;
      if (args.pgn != null) {
        game = parseStoredGame(args.pgn!);
      } else {
        game = ChessGame.fromFen(args.fen ?? kInitialFen);
      }
      return _GameView(key: ValueKey('new-${args.fen}-${args.pgn.hashCode}'), game: game, gameId: null, args: args);
    }
    final g = ref.watch(_gameLoaderProvider(gameId!));
    return g.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: context.l10n.somethingWentWrong, details: e),
      ),
      data: (game) => game == null
          ? Scaffold(
              appBar: AppBar(),
              body: Center(child: Text(context.l10n.gameNotFound)),
            )
          : _GameView(key: ValueKey(gameId), game: game, gameId: gameId, args: args),
    );
  }
}

class _GameView extends ConsumerStatefulWidget {
  const _GameView({super.key, required this.game, required this.gameId, required this.args});
  final ChessGame game;
  final int? gameId;
  final GameScreenArgs args;

  @override
  ConsumerState<_GameView> createState() => _GameViewState();
}

class _GameViewState extends ConsumerState<_GameView> {
  late GameController _c;
  int? _gameId;
  Side _orientation = Side.white;
  bool _engine = false;
  bool _explorer = false;
  bool _drawMode = false;
  VariationsMode _variations = VariationsMode.auto;

  ShapeColor _drawColor = ShapeColor.green;
  String? _bestMove;
  final _enginePanelKey = GlobalKey();
  Square? _drawStart;
  Square? _drawHover;
  bool _swipeAllowed = false;
  final _focus = FocusNode();

  /// Read once: the pending autosave may run from dispose(), when `ref`
  /// can no longer be used.
  late final LibraryRepository _library;

  @override
  void initState() {
    super.initState();
    _gameId = widget.gameId;
    _library = ref.read(libraryRepositoryProvider);
    _c = GameController(game: widget.game, onSave: _gameId == null ? null : _save);
    _c.addListener(_onChange);
    final orient = widget.game.headers['Orientation'];
    if (orient == 'black') _orientation = Side.black;
    if (widget.args.orientation != null) _orientation = widget.args.orientation!;
    if (widget.args.initialPath != null) _c.goToPath(widget.args.initialPath!);
  }

  Future<void> _save(ChessGame g) async {
    if (_gameId != null) await _library.saveGame(_gameId!, g);
  }

  void _onChange() => setState(() {});

  Future<bool> _flushBeforeLeave({bool quiet = false}) async {
    try {
      await _c.flush();
      return true;
    } catch (_) {
      if (mounted && !quiet) showSnack(context, context.l10n.saveFailed);
      return false;
    }
  }

  /// Saving failed on the way out: retry, take the PGN along, or leave
  /// without the last changes. Returns 'leave' or null.
  Future<String?> _confirmLeaveUnsaved() async {
    final l = context.l10n;
    while (mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.unsavedChanges),
          content: Text(l.saveFailedLeave),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'copy'), child: Text(l.copyPgn)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'leave'), child: Text(l.leaveWithoutSaving)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'retry'), child: Text(l.retry)),
          ],
        ),
      );
      if (choice == 'copy') {
        await Clipboard.setData(ClipboardData(text: gameToPgn(_c.game)));
        if (mounted) showSnack(context, l.copied);
        continue;
      }
      if (choice == 'retry') {
        if (await _flushBeforeLeave(quiet: true)) return 'leave';
        continue;
      }
      return choice;
    }
    return null;
  }

  @override
  void dispose() {
    _c.removeListener(_onChange);
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _announce(GameNode n) {
    if (n.san == null) return;
    final l = context.l10n;
    SemanticsService.sendAnnouncement(View.of(context), spokenSan(n.san!, l), Directionality.of(context));
  }

  void _playSound(GameNode n) {
    final san = n.san ?? '';
    ref.read(soundServiceProvider).play(san.contains('x') ? GameSound.capture : GameSound.move);
  }

  void _onMove(Move move) {
    final n = _c.playMove(move);
    _playSound(n);
    _announce(n);
  }

  void _forward() {
    if (!_c.canForward) return;
    _c.forward();
    _playSound(_c.current);
    _announce(_c.current);
  }

  void _back() => _c.back();

  Future<void> _chooseVariation() async {
    final l = context.l10n;
    final children = _c.current.children;
    if (children.length < 2) return _forward();
    final idx = await showAppSheet<int>(
      context,
      title: l.chooseVariation,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++)
            ListTile(
              leading: AppAvatar(text: '${i + 1}'),
              title: MovesText(moveLabel(children[i], forceNumber: true)),
              subtitle: children[i].commentText.isEmpty
                  ? null
                  : MovesText(children[i].commentText, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(ctx, i),
            ),
        ],
      ),
    );
    if (idx != null) {
      _c.forward(idx);
      _playSound(_c.current);
    }
  }

  // ------------------------------------------------------------ drawing

  Square? _squareAt(Offset local, double size) {
    final sq = size / 8;
    final fx = (local.dx / sq).floor();
    final fy = (local.dy / sq).floor();
    if (fx < 0 || fx > 7 || fy < 0 || fy > 7) return null;
    final file = _orientation == Side.white ? fx : 7 - fx;
    final rank = _orientation == Side.white ? 7 - fy : fy;
    return Square(rank * 8 + file);
  }

  // ------------------------------------------------------------ actions

  Future<void> _editComment(GameNode n, {bool before = false}) async {
    final l = context.l10n;
    final initial = before
        ? n.startCommentText
        : (n.isRoot ? _c.game.root.comments.map((c) => c.text).join(' ') : n.commentText);
    final text = await promptText(
      context,
      title: before ? l.commentBefore : (n.isRoot ? l.gameComment : l.commentAfter),
      initial: initial,
      maxLines: 6,
    );
    if (text != null) _c.setComment(n, text, before: before);
  }

  Future<void> _nagPicker(GameNode n) async {
    final l = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      // Taller than the default 9/16 of the screen on smaller phones.
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget chip(int nag) {
            final selected = n.nags.contains(nag);
            return FilterChip(
              // Only the size: the colour comes from the chip theme (white
              // on the black selected chip), else the symbol disappears.
              label: Text(nagSymbol(nag), style: TextStyle(fontSize: Theme.of(ctx).textTheme.titleMedium?.fontSize)),
              selected: selected,
              tooltip: nagName(nag, l),
              onSelected: (_) {
                _c.toggleNag(n, nag);
                setSheet(() {});
              },
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: AppInsets.sheet,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MovesText(l.annotateMove(n.san ?? ''), style: Theme.of(ctx).textTheme.titleLarge),
                  AppGap.v12,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final x in [1, 2, 3, 4, 5, 6]) chip(x),
                    ],
                  ),
                  AppGap.v12,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final x in [10, 13, 14, 15, 16, 17, 18, 19]) chip(x),
                    ],
                  ),
                  AppGap.v12,
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final x in [7, 22, 32, 36, 40, 44, 132, 138, 140, 146]) chip(x),
                    ],
                  ),
                  AppGap.v8,
                  TextButton(
                    onPressed: () {
                      _c.clearNags(n);
                      Navigator.pop(ctx);
                    },
                    child: Text(l.clearAnnotations),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _nodeMenu(GameNode n) async {
    final l = context.l10n;
    final isVariation = n.parent != null && n.parent!.children.first != n;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: MovesText(moveLabel(n, forceNumber: true), style: Theme.of(ctx).textTheme.titleLarge)),
              if (isVariation) ...[
                ListTile(
                  leading: const Icon(AppIcons.up),
                  title: Text(l.promoteVariation),
                  onTap: () {
                    Navigator.pop(ctx);
                    _c.promote(n);
                  },
                ),
                ListTile(
                  leading: const Icon(AppIcons.promote),
                  title: Text(l.makeMainline),
                  onTap: () {
                    Navigator.pop(ctx);
                    _c.makeMainline(n);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(AppIcons.comment),
                title: Text(l.commentAfter),
                onTap: () {
                  Navigator.pop(ctx);
                  _editComment(n);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.commentBefore),
                title: Text(l.commentBefore),
                onTap: () {
                  Navigator.pop(ctx);
                  _editComment(n, before: true);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.annotate),
                title: Text(l.annotate),
                onTap: () {
                  Navigator.pop(ctx);
                  _nagPicker(n);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.addToRepertoire),
                title: Text(l.addSubtreeToRepertoire),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToRepertoire(start: n);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.cut),
                title: Text(l.deleteAfter),
                enabled: n.children.isNotEmpty,
                onTap: () {
                  Navigator.pop(ctx);
                  _c.deleteAfter(n);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.delete, color: Theme.of(ctx).colorScheme.error),
                title: Text(isVariation ? l.deleteVariation : l.deleteFromHere),
                onTap: () {
                  Navigator.pop(ctx);
                  _c.deleteNode(n);
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.copy),
                title: Text(l.copyFen),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: n.fen));
                  showSnack(context, l.copied);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _forLine => widget.args.lineFor != null;

  /// Moves from the start to the current one: what the bar adds to the
  /// repertoire (a null move ends it; it cannot be in a repertoire).
  List<GameNode> get _lineToAdd => _c.current.line.takeWhile((n) => !n.isNullMove).toList();

  /// Back to the repertoire with the line; it adds the moves there.
  void _returnLine() => context.pop(<String>[for (final n in _lineToAdd) n.uci!]);

  /// [lineOnly]: just the line through the current move (no side
  /// variations); [start]: the subtree from that move; else the game.
  Future<void> _addToRepertoire({GameNode? start, bool lineOnly = false}) async {
    await context.push(
      '/rep-import',
      extra: RepImportRequest(
        games: [if (lineOnly) _c.game.lineThrough(_c.current) else _c.game],
        startNode: start,
        sourceLabel: _title(context),
        defaultColor: _orientation,
      ),
    );
  }

  /// Returns true when the game was saved (false if the user cancelled).
  Future<bool> _saveToLibrary() async {
    if (_gameId != null) return _flushBeforeLeave();
    final l = context.l10n;
    final repo = _library;
    final cols = await repo.watchCollections().first;
    if (!mounted) return false;
    // "My analyses" is created once and reused afterwards. It is found by
    // its source, not by its name: the name depends on the app language
    // (and older versions knew it only by the name, in either language).
    final existing = cols
        .where((c) => c.row.source == 'analysis' || c.row.name == 'My analyses' || c.row.name == 'Мої аналізи')
        .map((c) => c.row.id)
        .firstOrNull;
    int? target = widget.args.collectionId;
    target ??= await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.saveTo),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              try {
                final id = existing ?? await repo.createCollection(l.myAnalyses, source: 'analysis');
                if (ctx.mounted) Navigator.pop(ctx, id);
              } catch (_) {
                if (ctx.mounted) showSnack(ctx, l.saveFailed);
              }
            },
            child: ListTile(
              leading: Icon(existing == null ? AppIcons.newCollection : AppIcons.folder),
              title: Text(existing == null ? l.newCollectionNamed(l.myAnalyses) : l.myAnalyses),
            ),
          ),
          for (final c in cols.where((c) => c.row.id != existing))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c.row.id),
              child: ListTile(leading: const Icon(AppIcons.folder), title: Text(c.row.name)),
            ),
        ],
      ),
    );
    if (target == null) return false;
    int id;
    try {
      id = await repo.createGame(target, _c.game);
    } catch (_) {
      if (mounted) showSnack(context, l.saveFailed);
      return false;
    }
    if (!mounted) return true;
    setState(() {
      _gameId = id;
      // Keep the same controller (undo history stays); from now on edits
      // are autosaved into the new game.
      _c.onSave = _save;
    });
    if (!await _flushBeforeLeave() || !mounted) return false;
    showSnack(context, l.saved);
    return true;
  }

  String _title(BuildContext context) {
    final l = context.l10n;
    final h = _c.game.headers;
    String clean(String? s) => (s == null || s == '?') ? '' : s;
    final players = playersLine(h['White'], h['Black']);
    if (players.isNotEmpty) return players;
    final e = clean(h['Event']);
    if (e.isNotEmpty) return e;
    return _gameId == null ? l.analysisBoard : l.untitledGame;
  }

  Future<void> _menu(String v) async {
    final l = context.l10n;
    switch (v) {
      case 'prevGame':
        await _openSibling(-1);
      case 'nextGame':
        await _openSibling(1);
      case 'headers':
        final h = await showHeadersEditor(context, _c.game.headers);
        if (h != null) _c.setHeaders(h);
      case 'comment':
        await _editComment(_c.game.root);
      case 'export':
        // Export remains a recovery path even if writing to the library fails.
        if (!mounted) return;
        await showExportSheet(context, text: gameToPgn(_c.game), baseName: _title(context));
      case 'fen':
        await Clipboard.setData(ClipboardData(text: _c.position.fen));
        if (mounted) showSnack(context, l.copied);
      case 'editor':
        final fen = await context.push<String>(
          '/position-editor?pick=1&fen=${Uri.encodeQueryComponent(_c.position.fen)}',
        );
        if (fen != null && mounted) unawaited(context.push('/analysis', extra: GameScreenArgs(fen: fen)));
      case 'save':
        await _saveToLibrary();
      case 'delete':
        final ok = await confirm(context, title: l.deleteGameQ, confirmLabel: l.delete, destructive: true);
        if (ok && _gameId != null) {
          await ref.read(libraryRepositoryProvider).deleteGames([_gameId!]);
          if (mounted) context.pop();
        }
    }
  }

  Future<void> _openSibling(int delta) async {
    final sib = widget.args.siblings;
    final i = sib.indexOf(_gameId ?? -1);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= sib.length) return;
    if (!await _flushBeforeLeave() || !mounted) return;
    context.pushReplacement('/game/${sib[j]}', extra: widget.args);
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sib = widget.args.siblings;
    final sibIndex = sib.indexOf(_gameId ?? -1);
    final unsavedAnalysis = _gameId == null && _c.canUndo;

    return PopScope(
      canPop: _forLine ? _lineToAdd.isEmpty : !unsavedAnalysis && !_c.dirty && !_c.saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_forLine) {
          final choice = await _confirmLeaveLine();
          if (choice == 'add') _returnLine();
          if (choice == 'discard' && context.mounted) context.pop();
          return;
        }
        if (_gameId != null) {
          if (await _flushBeforeLeave(quiet: true)) {
            if (context.mounted) context.pop();
            return;
          }
          // Saving keeps failing: do not trap the user on this screen.
          if (!context.mounted) return;
          final choice = await _confirmLeaveUnsaved();
          if (choice == 'leave' && context.mounted) Navigator.of(context).pop();
          return;
        }
        final choice = await _confirmLeaveAnalysis();
        // Leave only when it was really saved (the collection picker can be
        // cancelled) or explicitly discarded.
        final leave = choice == 'discard' || (choice == 'save' && await _saveToLibrary());
        if (leave && context.mounted) context.pop();
      },
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _NavIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowRight): _NavIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _NavIntent(-100),
          SingleActivator(LogicalKeyboardKey.arrowDown): _NavIntent(100),
        },
        child: Actions(
          actions: {
            _NavIntent: CallbackAction<_NavIntent>(
              onInvoke: (i) {
                switch (i.delta) {
                  case -1:
                    _back();
                  case 1:
                    _forward();
                  case -100:
                    _c.toStart();
                  case 100:
                    _c.toEnd();
                }
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _focus,
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                toolbarHeight: _gameId == null
                    ? null
                    : kToolbarHeight * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _gameId == null && _title(context) == l.analysisBoard ? l.analysisShort : _title(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_gameId != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _c.saveError != null
                              ? l.saveFailed
                              : _c.saving
                              ? l.saving
                              : _c.dirty
                              ? l.unsavedChanges
                              : l.saved,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.meta.copyWith(
                            color: _c.saveError != null ? Theme.of(context).colorScheme.error : null,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (_c.saveError != null)
                    IconButton(
                      tooltip: l.retry,
                      icon: const Icon(AppIcons.save),
                      onPressed: _c.saving ? null : _flushBeforeLeave,
                    ),
                  if (!_wide)
                    IconButton(
                      tooltip: ref.watch(settingsProvider).boardScale < 0.99 ? l.normalBoard : l.readingMode,
                      isSelected: ref.watch(settingsProvider).boardScale < 0.99,
                      onPressed: () => toggleReadingBoard(ref),
                      icon: const Icon(AppIcons.readingMode),
                    ),
                  if (unsavedAnalysis && !_forLine)
                    IconButton(tooltip: l.saveToLibrary, onPressed: _saveToLibrary, icon: const Icon(AppIcons.save)),
                  PopupMenuButton<String>(
                    constraints: appMenuConstraints,
                    icon: const Icon(AppIcons.more),
                    tooltip: l.more,
                    onSelected: _menu,
                    itemBuilder: (_) => [
                      if (sib.length > 1) ...[
                        appMenuItem(
                          value: 'prevGame',
                          icon: AppIcons.previousGame,
                          label: l.previousGame,
                          enabled: sibIndex > 0,
                        ),
                        appMenuItem(
                          value: 'nextGame',
                          icon: AppIcons.nextGame,
                          label: l.nextGame,
                          enabled: sibIndex >= 0 && sibIndex < sib.length - 1,
                        ),
                        appMenuDivider(),
                      ],
                      if (_gameId == null) appMenuItem(value: 'save', icon: AppIcons.save, label: l.saveToLibrary),
                      appMenuItem(value: 'headers', icon: AppIcons.info, label: l.gameInfo),
                      appMenuItem(value: 'comment', icon: AppIcons.gameComment, label: l.gameComment),
                      appMenuItem(value: 'export', icon: AppIcons.share, label: l.exportPgn),
                      appMenuItem(value: 'fen', icon: AppIcons.copy, label: l.copyFen),
                      appMenuItem(value: 'editor', icon: AppIcons.editPosition, label: l.editPosition),
                      if (_gameId != null) ...[
                        appMenuDivider(),
                        appMenuItem(value: 'delete', icon: AppIcons.delete, label: l.deleteGame, destructive: true),
                      ],
                    ],
                  ),
                ],
              ),
              body: SafeArea(
                // The board keeps the size the user chose with the grip on
                // every screen (D-052); open panels share the room below it.
                child: BoardLayout(
                  board: _board(context),
                  below: (context, g) {
                    _wide = g.wide;
                    return _side(context);
                  },
                ),
              ),
              bottomNavigationBar: _forLine
                  ? Column(mainAxisSize: MainAxisSize.min, children: [_lineBar(context), _actionBar(context)])
                  : _actionBar(context),
            ),
          ),
        ),
      ),
    );
  }

  bool _wide = false;

  Future<String?> _confirmLeaveLine() {
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.addLineQ),
        content: MovesText(nodesToText(_lineToAdd)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(l.dontAdd)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'add'), child: Text(l.addShort)),
        ],
      ),
    );
  }

  /// Pinned above the tool bar when opened from a repertoire: shows which
  /// moves will go into the line and adds them in one tap.
  Widget _lineBar(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final nodes = _lineToAdd;
    return Material(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.toLineOf(widget.args.lineFor!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.title.copyWith(color: cs.onSecondaryContainer),
                  ),
                  if (nodes.isEmpty)
                    Text(
                      l.analysisLineHint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.meta.copyWith(color: cs.onSecondaryContainer),
                    )
                  else
                    MoveLineText(nodesToText(nodes), maxLines: 2, color: cs.onSecondaryContainer),
                ],
              ),
            ),
            AppGap.h8,
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget)),
              onPressed: nodes.isEmpty ? null : _returnLine,
              icon: const Icon(AppIcons.add),
              label: Text(l.addShort),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _confirmLeaveAnalysis() {
    final l = context.l10n;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.leaveAnalysisQ),
        content: Text(l.leaveAnalysisMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(l.discard)),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(l.save)),
        ],
      ),
    );
  }

  Widget _board(BuildContext context) {
    final l = context.l10n;
    final shapes = <Shape>{
      for (final s in _c.currentShapes) BoardAppearance.toShape(s),
      if (_engine && _bestMove != null && !_drawMode) ..._engineArrow(),
      if (_drawStart != null && _drawHover != null && _drawHover != _drawStart)
        Arrow(color: BoardAppearance.shapeColor(_drawColor), orig: _drawStart!, dest: _drawHover!),
    };
    return LayoutBuilder(
      builder: (context, c) {
        final boardSize = c.maxWidth;
        Widget board = BoardView(
          position: _c.position,
          orientation: _orientation,
          lastMove: _c.lastMove,
          playerSide: _drawMode ? PlayerSide.none : PlayerSide.both,
          onMove: _onMove,
          shapes: shapes,
          semanticsLabel: l.boardLabel,
        );
        if (_drawMode) {
          board = Stack(
            children: [
              board,
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => setState(() {
                    _drawStart = _squareAt(d.localPosition, boardSize);
                    _drawHover = _drawStart;
                  }),
                  onPanUpdate: (d) => setState(() => _drawHover = _squareAt(d.localPosition, boardSize)),
                  onPanEnd: (_) {
                    final a = _drawStart;
                    final b = _drawHover;
                    setState(() {
                      _drawStart = null;
                      _drawHover = null;
                    });
                    if (a != null && b != null) {
                      _c.toggleShape(BoardShape(_drawColor, a, a == b ? null : b));
                    }
                  },
                  onTapUp: (d) {
                    final sq = _squareAt(d.localPosition, boardSize);
                    if (sq != null) _c.toggleShape(BoardShape(_drawColor, sq));
                  },
                ),
              ),
            ],
          );
        } else {
          board = GestureDetector(
            onHorizontalDragStart: (d) {
              final sq = _squareAt(d.localPosition, boardSize);
              final piece = sq == null ? null : _c.position.board.pieceAt(sq);
              _swipeAllowed = piece == null || piece.color != _c.position.turn;
            },
            onHorizontalDragEnd: (d) {
              if (!_swipeAllowed) return;
              final v = d.primaryVelocity ?? 0;
              if (v < -300) _forward();
              if (v > 300) _back();
            },
            child: board,
          );
        }
        return SizedBox.square(dimension: boardSize, child: board);
      },
    );
  }

  Iterable<Shape> _engineArrow() sync* {
    final m = parseUciMove(_c.position, _bestMove!);
    if (m is NormalMove) {
      final std = NormalMove.fromUci(standardUci(_c.position, m));
      yield Arrow(color: BoardColors.engineMove, orig: std.from, dest: std.to, scale: 0.8);
    }
  }

  void _toggleEngine() => setState(() {
    _engine = !_engine;
    if (!_engine) _bestMove = null;
    // On phones one analysis panel at a time keeps the notation visible.
    if (_engine && !_wide) _explorer = false;
  });

  void _toggleExplorer() => setState(() {
    _explorer = !_explorer;
    if (_explorer && !_wide) {
      _engine = false;
      _bestMove = null;
    }
  });

  Widget _side(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cur = _c.current;
    final book = ref.watch(openingBookProvider).value;
    final opening = book?.deepest([_c.game.root.key, for (final n in cur.line) n.key]);
    final comment = cur.isRoot
        ? _c.game.root.comments.map((c) => c.text).where((t) => t.isNotEmpty).join(' ')
        : cur.commentText;
    final notation = NotationView(
      game: _c.game,
      current: cur,
      revision: _c.revision,
      variations: _variations,
      onSelect: (n) {
        _c.goTo(n);
        _announce(n);
      },
      onLongPress: (n, _) => _nodeMenu(n),
    );
    return LayoutBuilder(
      builder: (context, box) {
        // Rows around the notation, approximately (they grow with the text).
        final t = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
        final fixed =
            (opening != null ? _openingRow * t : 0) +
            (comment.isNotEmpty ? _commentRow * t : 0) +
            (cur.children.length > 1 ? _variationRowHeight * t : 0) +
            (_drawMode ? _drawBarHeight : 0) +
            (_c.game.issues.isNotEmpty ? _issuesRow * t : 0);
        // What the engine / explorer may take, leaving two notation rows.
        final room = box.maxHeight - fixed - _notationMin;
        // Too little room under a big board: the panels take their natural
        // height and the whole column scrolls (pull the grip up for more);
        // nothing is cut off.
        final tight = (_engine || _explorer) && room < _panelMin * t;
        final double? panelMax = tight ? null : room;
        final column = Column(
          children: [
            if (opening != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxs),
                child: Text(
                  '${opening.eco} · ${opening.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.meta,
                ),
              ),
            if (_engine)
              Appear(
                child: Material(
                  key: const ValueKey('game-engine-panel'),
                  color: theme.colorScheme.surfaceContainerLow,
                  child: EnginePanel(
                    key: _enginePanelKey,
                    fen: _c.position.fen,
                    compact: !_wide,
                    maxHeight: panelMax,
                    onAddLine: (moves) => _c.addLine(_c.current, moves),
                    onBestMove: (m) {
                      if (m != _bestMove && mounted) setState(() => _bestMove = m);
                    },
                  ),
                ),
              ),
            if (_explorer)
              Material(
                key: const ValueKey('game-explorer-panel'),
                color: theme.colorScheme.surfaceContainerLow,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: _wide
                        ? math.min(_explorerMaxWide, panelMax ?? _explorerMaxWide)
                        : panelMax ?? double.infinity,
                  ),
                  child: SingleChildScrollView(
                    child: ExplorerPanel(
                      fen: _c.position.fen,
                      highlightUcis: {
                        for (final n in _c.current.children)
                          if (n.uci != null) n.uci!,
                      },
                      onPlay: (uci) {
                        final m = parseUciMove(_c.position, uci);
                        if (m != null) _onMove(m);
                      },
                    ),
                  ),
                ),
              ),
            if (_c.game.issues.isNotEmpty)
              Container(
                width: double.infinity,
                color: theme.colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(AppIcons.warning, color: theme.colorScheme.onErrorContainer),
                    AppGap.h8,
                    Expanded(
                      child: Text(
                        // A game saved earlier with its unread moves kept:
                        // no line number to quote any more, one plain sentence.
                        _c.game.issues.first.message == 'Unread moves are kept in a comment'
                            ? l.gameUnreadKept
                            : l.gameParseIssues(
                                '${l.line} ${_c.game.issues.first.line}: '
                                '${localizedIssue(l, _c.game.issues.first.message)}'
                                '${_c.game.issues.first.token == null ? '' : ' (${_c.game.issues.first.token})'}',
                              ),
                        style: context.tt.meta.copyWith(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            if (tight)
              // As tall as its moves, up to two rows (it scrolls inside):
              // a short game must not leave a hole under one row of moves.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity, maxHeight: _notationMin),
                child: notation,
              )
            else
              Expanded(child: notation),
            if (cur.children.length > 1) _variationRow(context),
            // Only a comment that exists takes a row; an empty one is added
            // from "Actions" (a hint row cost 48 points under every move).
            if (comment.isNotEmpty)
              InkWell(
                onTap: () => _editComment(cur),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: AppSizes.moveRow),
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MovesText(
                          comment.isEmpty ? l.addCommentHint : comment,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.comment,
                        ),
                      ),
                      Icon(AppIcons.edit, size: AppSizes.iconMd, semanticLabel: l.commentAfter),
                    ],
                  ),
                ),
              ),
            if (_drawMode) _drawBar(context),
          ],
        );
        return tight ? SingleChildScrollView(child: column) : column;
      },
    );
  }

  /// Two rows of notation stay visible under the analysis panels.
  static const _notationMin = 2 * AppSizes.moveRow + 2 * AppSpacing.xxs;

  /// The engine's score row, bar, caption and its best line (two lines of
  /// text), at 100 % text size.
  static const _panelMin = 132.0;

  // Heights of the rows around the notation at 100 % text size, for the
  // estimate in [_side] (they grow with the text).
  static const _openingRow = 20.0;
  static const _commentRow = 72.0;
  static const _variationRowHeight = AppSizes.controlLg;
  static const _drawBarHeight = 64.0;
  static const _issuesRow = AppSizes.controlLg;

  /// The explorer beside the board on a tablet: no taller than this.
  static const _explorerMaxWide = 320.0;

  // A colour of the drawing bar: the dot, the area a finger hits and its
  // ink splash.
  static const _swatch = 36.0;
  static const _swatchTap = 52.0;
  static const _swatchSplash = 28.0;
  static const _swatchSelectedBorder = 3.0;

  /// "Next:" chips when the current move has several continuations.
  Widget _variationRow(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final children = _c.current.children;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Row(
          children: [
            Text(l.nextLabel, style: context.tt.meta),
            AppGap.h8,
            for (var i = 0; i < children.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ActionChip(
                  avatar: i == 0 ? const Icon(AppIcons.forward, size: AppSizes.iconSm) : null,
                  label: MoveLineText(moveLabel(children[i], forceNumber: true)),
                  onPressed: () {
                    _c.forward(i);
                    _playSound(_c.current);
                    _announce(_c.current);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawBar(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final names = {
      ShapeColor.green: l.colorGreen,
      ShapeColor.red: l.colorRed,
      ShapeColor.blue: l.colorBlue,
      ShapeColor.yellow: l.colorYellow,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      // Colours scroll on a narrow phone; "Clear" and "Done" stay pinned
      // on screen, clear of the edge.
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
              child: Row(
                children: [
                  for (final c in ShapeColor.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Semantics(
                        button: true,
                        selected: _drawColor == c,
                        label: '${l.drawColor} ${names[c]}',
                        child: InkResponse(
                          onTap: () => setState(() => _drawColor = c),
                          radius: _swatchSplash,
                          child: SizedBox.square(
                            dimension: _swatchTap,
                            child: Center(
                              child: Container(
                                width: _swatch,
                                height: _swatch,
                                decoration: BoxDecoration(
                                  // The arrows are translucent; the swatch is not.
                                  color: BoardAppearance.shapeColor(c).withAlpha(0xFF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    width: _drawColor == c ? _swatchSelectedBorder : AppSizes.hairline,
                                    color: cs.onSurface,
                                  ),
                                ),
                                child: _drawColor == c ? Icon(AppIcons.check, color: cs.onSideBlack) : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(tooltip: l.clearShapes, onPressed: _c.clearShapes, icon: const Icon(AppIcons.clearShapes)),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconButton(
              tooltip: l.done,
              onPressed: () => setState(() => _drawMode = false),
              icon: const Icon(AppIcons.check),
            ),
          ),
        ],
      ),
    );
  }

  /// "1. e4 e5 2. Nf3 Nc6 … 12. Qh4" for the line through the current move.
  String _lineSummary() {
    final line = _c.game.lineThrough(_c.current).mainline;
    if (line.isEmpty) return '';
    final head = nodesToText(line.take(4).toList());
    return line.length > 4 ? '$head … ${moveLabel(line.last, forceNumber: true)}' : head;
  }

  bool get _hasVariations =>
      _c.game.root.descendants().any((n) => n.children.length > 1) || _c.game.root.children.length > 1;

  /// Everything that is not navigation: big rows in a bottom sheet.
  Future<void> _actionsSheet() async {
    final l = context.l10n;
    final cur = _c.current;
    await showAppSheet<void>(
      context,
      builder: (ctx) {
        Widget item(IconData icon, String title, VoidCallback? onTap) => ListTile(
          minTileHeight: AppSizes.controlLg,
          leading: Icon(icon),
          title: Text(title),
          enabled: onTap != null,
          onTap: onTap == null
              ? null
              : () {
                  Navigator.pop(ctx);
                  onTap();
                },
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppButtonSize.large,
                      onPressed: _c.canUndo
                          ? () {
                              Navigator.pop(ctx);
                              _c.undo();
                            }
                          : null,
                      icon: const Icon(AppIcons.undo),
                      label: Text(l.undo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  AppGap.h12,
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppButtonSize.large,
                      onPressed: _c.canRedo
                          ? () {
                              Navigator.pop(ctx);
                              _c.redo();
                            }
                          : null,
                      icon: const Icon(AppIcons.redo),
                      label: Text(l.redo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
            // Reading a file to learn from it: the lines go to a
            // repertoire from here (thumb reach), three sizes.
            if (!_forLine && _c.game.root.children.isNotEmpty) ...[
              SectionHeader(
                l.toRepertoireSection,
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.lg, AppSpacing.page, AppSpacing.sm),
              ),
              ListTile(
                minTileHeight: AppSizes.controlLg,
                leading: const Icon(AppIcons.addToRepertoire),
                title: Text(l.addThisLine),
                subtitle: MovesText(_lineSummary(), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToRepertoire(lineOnly: true);
                },
              ),
              if (!cur.isRoot && cur.subtreeSize > 0 && cur.descendants().any((n) => n.children.length > 1))
                item(AppIcons.variations, l.addFromHereWithVariations, () => _addToRepertoire(start: cur)),
              item(AppIcons.document, l.addWholeGame, _addToRepertoire),
              const Divider(height: AppSpacing.lg),
            ],
            if (cur.children.length > 1) item(AppIcons.variations, l.nextMoveVariations, _chooseVariation),
            if (_hasVariations) ...[
              if (_variations != VariationsMode.expanded)
                item(
                  AppIcons.expandAll,
                  l.expandAllVariations,
                  () => setState(() => _variations = VariationsMode.expanded),
                ),
              if (_variations != VariationsMode.collapsed)
                item(
                  AppIcons.collapseAll,
                  l.collapseAllVariations,
                  () => setState(() => _variations = VariationsMode.collapsed),
                ),
            ],
            item(AppIcons.draw, l.drawMode, () => setState(() => _drawMode = !_drawMode)),
            item(AppIcons.annotate, l.annotate, cur.isRoot ? null : () => _nagPicker(cur)),
            item(AppIcons.comment, l.commentAfter, cur.isRoot ? null : () => _editComment(cur)),
            item(AppIcons.more, l.moveActions, cur.isRoot ? null : () => _nodeMenu(cur)),
            item(AppIcons.flip, l.flipBoard, () => setState(() => _orientation = _orientation.opposite)),
            item(AppIcons.toStart, l.toStart, _c.canBack ? _c.toStart : null),
            item(AppIcons.toEnd, l.toEnd, _c.canForward ? _c.toEnd : null),
          ],
        );
      },
    );
  }

  /// One bottom bar within thumb reach: big buttons with labels (D-035).
  Widget _actionBar(BuildContext context) {
    final l = context.l10n;
    final cur = _c.current;
    return ThumbBar(
      children: [
        Expanded(
          flex: 4,
          child: BarButton(icon: AppIcons.engine, label: l.navEngine, selected: _engine, onTap: _toggleEngine),
        ),
        Expanded(
          flex: 4,
          child: BarButton(icon: AppIcons.explorer, label: l.navExplorer, selected: _explorer, onTap: _toggleExplorer),
        ),
        Expanded(
          flex: 4,
          child: BarButton(icon: AppIcons.options, label: l.navActions, onTap: _actionsSheet),
        ),
        Expanded(
          flex: 5,
          child: BarButton(
            icon: AppIcons.chevronLeft,
            label: l.navBack,
            onTap: _c.canBack ? _back : null,
            onLongPress: _c.canBack ? _c.toStart : null,
          ),
        ),
        Expanded(
          flex: 5,
          child: BarButton(
            icon: AppIcons.chevronRight,
            label: l.navNext,
            onTap: _c.canForward ? _forward : null,
            onLongPress: _c.canForward ? _c.toEnd : null,
            badge: cur.children.length > 1 ? Text('${cur.children.length}') : null,
          ),
        ),
      ],
    );
  }
}

class _NavIntent extends Intent {
  const _NavIntent(this.delta);
  final int delta;
}

String nagName(int nag, AppLocalizations l) => switch (nag) {
  1 => l.nagGood,
  2 => l.nagMistake,
  3 => l.nagBrilliant,
  4 => l.nagBlunder,
  5 => l.nagInteresting,
  6 => l.nagDubious,
  7 => l.nagOnlyMove,
  10 => l.nagEqual,
  13 => l.nagUnclear,
  14 => l.nagWhiteSlightly,
  15 => l.nagBlackSlightly,
  16 => l.nagWhiteModerate,
  17 => l.nagBlackModerate,
  18 => l.nagWhiteDecisive,
  19 => l.nagBlackDecisive,
  22 => l.nagZugzwang,
  32 => l.nagDevelopment,
  36 => l.nagInitiative,
  40 => l.nagAttack,
  44 => l.nagCompensation,
  132 => l.nagCounterplay,
  138 => l.nagTimeTrouble,
  140 => l.nagWithIdea,
  146 => l.nagNovelty,
  _ => nagSymbol(nag).isEmpty ? '\$$nag' : nagSymbol(nag),
};
