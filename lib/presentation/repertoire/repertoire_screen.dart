import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../../data/engine/engine_check.dart';
import '../../data/engine/engine_service.dart';
import '../../data/import/pgn_import_service.dart';
import '../../data/lichess/explorer_service.dart';
import '../../data/lichess/lichess_client.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/pgn_writer.dart';
import '../../domain/repertoire/repertoire_export.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../../domain/training/opponent_strategy.dart';
import '../../domain/training/training_engine.dart';
import '../accounts/accounts_providers.dart';
import '../app/leave_guard.dart';
import '../app/providers.dart';
import '../home/today_screen.dart';
import '../library/import_flow.dart';
import '../stats/stats_view.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/common.dart';
import '../widgets/engine_panel.dart';
import '../widgets/errors.dart';
import '../widgets/explorer_panel.dart';
import '../widgets/export_sheet.dart';
import '../widgets/san_text.dart';
import 'import_wizard_screen.dart';
import 'repertoire_browser.dart';
import 'repertoire_controller.dart';

/// The side badge beside the name in the app bar (smaller than in a list).
const _titleBadge = 28.0;

/// The actions of a repertoire: the "more" menu of its screen and the menu
/// a long press on its card opens (the card then runs the chosen action on
/// the repertoire's screen, see [RepertoireScreen.action]).
List<PopupMenuEntry<String>> repertoireMenuItems(BuildContext context) {
  final l = context.l10n;
  return [
    appMenuItem(value: 'rename', icon: AppIcons.edit, label: l.rename),
    appMenuItem(value: 'options', icon: AppIcons.options, label: l.repertoireSettings),
    appMenuItem(value: 'importLib', icon: AppIcons.library, label: l.importFromLibrary),
    appMenuItem(value: 'importFile', icon: AppIcons.openFile, label: l.importFromFile),
    appMenuDivider(),
    appMenuItem(value: 'export', icon: AppIcons.share, label: l.exportPgn),
    appMenuItem(value: 'lichess', icon: AppIcons.cloudUpload, label: l.exportToLichess),
    appMenuDivider(),
    appMenuItem(value: 'weights', icon: AppIcons.weight, label: l.fillWeights),
    appMenuItem(value: 'engine', icon: AppIcons.engine, label: l.checkWithEngine),
    appMenuDivider(),
    appMenuItem(value: 'delete', icon: AppIcons.delete, label: l.deleteRepertoire, destructive: true),
  ];
}

class RepertoireScreen extends ConsumerStatefulWidget {
  const RepertoireScreen({
    super.key,
    required this.id,
    this.initialKey,
    this.startFen,
    this.playUci,
    this.edit = false,
    this.standalone = false,
    this.action,
  });
  final int id;
  final String? initialKey;

  /// Open at this position (when its key is not known to the caller).
  final String? startFen;

  /// A move to play and add right away (e.g. an uncovered opponent move).
  final String? playUci;

  /// Start in the editing mode: moves played on the board go straight
  /// into the repertoire (D-067; this used to be a separate "line editor").
  final bool edit;

  /// Pushed over another screen to edit one place (from a report): "Done"
  /// goes back there instead of returning to the viewing mode.
  final bool standalone;

  /// An action of [repertoireMenuItems] to run as soon as the repertoire
  /// is loaded (chosen from the menu of its card).
  final String? action;

  @override
  ConsumerState<RepertoireScreen> createState() => _RepertoireScreenState();
}

class _RepertoireScreenState extends ConsumerState<RepertoireScreen> with SingleTickerProviderStateMixin {
  late final RepertoireController _c;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  Set<PositionKey> _errorKeys = {};
  late bool _editing = widget.edit;
  bool _explorer = true;
  bool _engine = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_tabChanged);
    _c = RepertoireController(widget.id, ref.read(repertoireRepositoryProvider));
    _c.addListener(_changed);
    LeaveGuard.set(_canLeave);
    unawaited(_init());
    unawaited(_loadErrors());
    // Reload when the repertoire was changed elsewhere (line editor,
    // import, training), unless the signal is our own or moves are pending.
    _refreshSub = ref.listenManual(refreshTickProvider, (_, _) {
      if (_ownBump || !mounted || _c.pending.isNotEmpty) return;
      unawaited(_c.load());
      unawaited(_loadErrors());
    });
  }

  late final ProviderSubscription<int> _refreshSub;
  bool _ownBump = false;

  Future<void> _init() async {
    await _c.load(at: widget.initialKey ?? (widget.startFen == null ? null : normalizeFenToKey(widget.startFen!)));
    if (widget.playUci != null && _c.loaded && mounted) _playAndAdd(widget.playUci!);
    if (widget.action != null && _c.loaded && mounted) await _menu(widget.action!);
  }

  /// Plays a move and adds it to the repertoire at once (editing has no
  /// separate "add" step).
  void _playAndAdd(String uci) {
    final m = parseUciMove(_c.position, uci);
    if (m == null) return;
    _c.playOnBoard(m);
    if (_c.pending.isNotEmpty && mounted) unawaited(commitPendingInteractive(context, _c, quiet: true));
  }

  /// Opens [k] on the Positions tab in the editing mode, optionally playing
  /// a move there (the Problems tab: fill a gap, answer an uncovered move).
  Future<void> _editAt(PositionKey k, {String? play}) async {
    if (!await confirmLeavePending(context, _c) || !mounted) return;
    _c.jumpTo(k);
    _tabs.animateTo(0);
    setState(() => _editing = true);
    if (play != null) _playAndAdd(play);
  }

  void _doneEditing() {
    if (widget.standalone) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      setState(() => _editing = false);
    }
  }

  /// Asked before the screen is replaced without a pop (see [LeaveGuard]).
  Future<bool> _canLeave() async => !mounted || _c.pending.isEmpty || await confirmDiscardPending(context, _c);

  Future<void> _loadErrors() async {
    final p = await ref.read(repertoireRepositoryProvider).problemPositions(repId: widget.id, limit: 100);
    if (mounted) {
      setState(
        () => _errorKeys = {
          for (final x in p)
            if (x.errors >= 2) x.key,
        },
      );
    }
  }

  int _seenRevision = 0;

  void _tabChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    if (mounted) setState(() {});
    // Other screens care only about saved changes, not about navigation.
    if (_c.saves != _seenRevision) {
      _seenRevision = _c.saves;
      _ownBump = true;
      try {
        ref.read(refreshTickProvider.notifier).bump();
      } finally {
        _ownBump = false;
      }
    }
  }

  @override
  void dispose() {
    LeaveGuard.clear(_canLeave);
    _refreshSub.close();
    _c.removeListener(_changed);
    _c.dispose();
    _tabs.removeListener(_tabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Set<PositionKey> _problemKeys(RepertoireGraph g) => {
    for (final p in g.positions.values)
      if (p.conflictDeferred || p.engineFlag.isNotEmpty || g.isGap(p.key)) p.key,
    ..._errorKeys.where(g.positions.containsKey),
  };

  Future<void> _openInBrowser(PositionKey k) async {
    if (!await confirmLeavePending(context, _c)) return;
    _c.jumpTo(k);
    _tabs.animateTo(0);
  }

  // ------------------------------------------------------------ actions

  Future<void> _train() async {
    if (!await confirmLeavePending(context, _c) || !mounted) return;
    final l = context.l10n;
    final g = _c.graph!;
    final fsrs = ref.read(fsrsProvider);
    final now = DateTime.now();
    final due = g.cards.entries.where((e) => g.isTrainable(e.key) && fsrs.isDue(e.value.srs, now)).length;
    final fresh = g.cards.entries.where((e) => g.isTrainable(e.key) && e.value.srs.isNew).length;
    // The same daily cap as on Today, so the numbers agree.
    final introduced = await ref.read(introducedTodayProvider.future);
    if (!mounted) return;
    final newLeft = (ref.read(settingsProvider).newPerDay - introduced).clamp(0, 100000);
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
            leading: const Icon(AppIcons.learn),
            title: Text(l.modeLearn),
            subtitle: Text(
              fresh > newLeft ? '${l.modeLearnHint(fresh)} · ${l.todayUpTo(newLeft)}' : l.modeLearnHint(fresh),
            ),
            enabled: fresh > 0,
            onTap: () => Navigator.pop(ctx, TrainingMode.learn),
          ),
          ListTile(
            leading: const Icon(AppIcons.drill),
            title: Text(l.modeDrill),
            subtitle: Text(l.modeDrillHint),
            enabled: g.cards.isNotEmpty,
            onTap: () => Navigator.pop(ctx, TrainingMode.drill),
          ),
          ListTile(
            leading: const Icon(AppIcons.warning),
            title: Text(l.modeProblems),
            subtitle: Text(l.modeProblemsHint(_errorKeys.length)),
            enabled: _errorKeys.isNotEmpty,
            onTap: () => Navigator.pop(ctx, TrainingMode.problems),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    final problems = mode == TrainingMode.problems
        ? await ref.read(repertoireRepositoryProvider).problemPositions(repId: widget.id)
        : const <ProblemPosition>[];
    if (!mounted) return;
    await context.push(
      '/train',
      extra: TrainingArgs(
        repertoireIds: [widget.id],
        mode: mode,
        problemKeys: {
          widget.id: [for (final p in problems) p.key],
        },
      ),
    );
    await _c.load();
    await _loadErrors();
  }

  Future<void> _export() async {
    final l = context.l10n;
    final mode = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.exportPgn),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'comment'),
            child: ListTile(title: Text(l.transpositionsAsComments), subtitle: Text(l.transpositionsAsCommentsHint)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'expand'),
            child: ListTile(title: Text(l.transpositionsExpanded), subtitle: Text(l.transpositionsExpandedHint)),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    unawaited(ref.read(settingsProvider.notifier).update((x) => x.copyWith(transpositionMode: mode)));
    final text = exportRepertoirePgn(_c.graph!, _c.row!.name, mode, l);
    await showExportSheet(context, text: text, baseName: _c.row!.name);
  }

  /// Splits the repertoire into chapters by the opponent's first choice
  /// (Lichess studies are limited to 64 chapters).
  List<String> _chapters() {
    final l = context.l10n;
    final g = _c.graph!;
    final game = repertoireToGame(g, name: _c.row!.name, transpositionLabel: l.transposesTo);
    // Find the first opponent position with several moves.
    var node = game.root;
    while (node.children.length == 1 && node.position.turn == g.color) {
      node = node.children.first;
    }
    if (node.children.length <= 1) return [gameToPgn(game)];
    final out = <String>[];
    for (final child in node.children) {
      final g2 = ChessGame(root: GameNode.root(game.root.position));
      g2.headers.addAll(game.headers);
      g2.headers['Event'] = '${_c.row!.name}: ${child.san}';
      g2.root.comments.addAll(game.root.comments);
      // Copy the line to the child and its subtree.
      var target = g2.root;
      for (final n in child.line) {
        final m = parseUciMove(target.position, n.uci!)!;
        target = target.addMove(m);
        target.comments.addAll(n.comments);
      }
      void copy(GameNode from, GameNode to) {
        for (final c in from.children) {
          final m = parseUciMove(to.position, c.uci!)!;
          final nn = to.addMove(m)
            ..comments.addAll(c.comments)
            ..nags.addAll(c.nags);
          copy(c, nn);
        }
      }

      copy(child, target);
      out.add(gameToPgn(g2));
    }
    return out;
  }

  /// Shows that a Lichess login is needed, with a direct link.
  void _needLichess(String text) {
    final l = context.l10n;
    showSnack(
      context,
      text,
      action: SnackBarAction(label: l.connect, onPressed: () => context.push('/accounts')),
    );
  }

  Future<void> _exportToLichess() async {
    final l = context.l10n;
    final accounts = ref.read(accountsServiceProvider);
    try {
      if (await accounts.account('lichess') == null) {
        if (mounted) _needLichess(l.connectLichessFirst);
        return;
      }
      await accounts.ensureLichessWrite();
    } catch (e) {
      if (mounted) showSnack(context, l.loginFailed(friendlyError(e, l)));
      return;
    }
    if (!mounted) return;
    final client = ref.read(lichessClientProvider);
    final loading = showProgress(context, l.loadingStudies);
    List<StudyMeta> studies;
    try {
      final acc = await accounts.account('lichess');
      studies = await client.studiesByUser(acc!.username).toList();
    } catch (e) {
      loading.close();
      if (mounted) showSnack(context, _lichessError(e));
      return;
    }
    loading.close();
    if (!mounted) return;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.chooseStudy),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: ListTile(leading: const Icon(AppIcons.add), title: Text(l.newPrivateStudy)),
          ),
          for (final s in studies.take(50))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, s.id), child: Text(s.name)),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final chapters = _chapters();
    final h = showProgress(context, l.exportingToLichess);
    try {
      var studyId = chosen;
      var existing = 0;
      if (studyId.isEmpty) {
        studyId = await client.createStudy(_c.row!.name);
        existing = 1; // the new study has one empty chapter
      } else {
        existing = await client.studyChapterCount(studyId);
      }
      final free = kLichessMaxChapters - existing;
      if (free <= 0) {
        h.close();
        if (mounted) showSnack(context, l.studyFull);
        return;
      }
      if (chapters.length > free) {
        h.close();
        if (!mounted) return;
        final ok = await confirm(
          context,
          title: l.tooManyChapters,
          message: l.tooManyChaptersMessage(chapters.length, free),
        );
        if (!ok) return;
      }
      final pgn = chapters.take(free).join('\n\n');
      final r = await client.importPgnToStudy(studyId, pgn, orientation: _c.graph!.color.name);
      h.close();
      if (!mounted) return;
      showSnack(context, r.error == null ? l.exportedChapters(r.chapters) : l.exportedWithErrors(r.chapters, r.error!));
    } catch (e) {
      h.close();
      if (mounted) showSnack(context, _lichessError(e));
    }
  }

  String _lichessError(Object e) {
    final l = context.l10n;
    if (e is LichessException) {
      if (e.isUnauthorized) return l.lichessSessionExpired;
      if (e.isRateLimited) return l.lichessRateLimited;
      return l.lichessError(e.message);
    }
    return l.networkError;
  }

  Future<void> _fillWeights() async {
    final l = context.l10n;
    if (!(await ref.read(accountsServiceProvider).hasLichessToken())) {
      if (mounted) _needLichess(l.explorerNeedsLogin);
      return;
    }
    if (!mounted) return;
    final s = ref.read(settingsProvider);
    var cancelled = false;
    final h = showProgress(context, l.fillingWeights, onCancel: () => cancelled = true);
    final batch = ExplorerBatch(ref.read(explorerServiceProvider));
    Object? error;
    try {
      await for (final p in batch.fillWeights(
        _c.graph!,
        ExplorerQuery(
          db: s.explorerSource == 'mine' ? 'lichess' : s.explorerSource,
          speeds: s.explorerSpeeds,
          ratings: s.explorerRatings,
        ),
        cancelled: () => cancelled,
      )) {
        h.progress = p.total == 0 ? 1 : p.done / p.total;
        h.message = l.fillingWeightsProgress(p.done, p.total);
        if (p.error != null) error = p.error;
      }
    } catch (e) {
      error = e;
    } finally {
      h.close();
    }
    await _c.save();
    if (mounted) showSnack(context, error == null ? l.weightsFilled : _lichessError(error));
  }

  Future<void> _engineCheck() async {
    final l = context.l10n;
    final s = ref.read(settingsProvider);
    var cancelled = false;
    final engine = ref.read(engineServiceProvider);
    final h = showProgress(
      context,
      l.engineChecking,
      onCancel: () {
        cancelled = true;
        unawaited(engine.stop());
      },
    );
    var flagged = 0;
    Object? error;
    try {
      await for (final p in checkRepertoire(
        _c.graph!,
        engine,
        thresholdCp: s.engineCheckThresholdCp,
        cancelled: () => cancelled,
      )) {
        h.progress = p.total == 0 ? 1 : p.done / p.total;
        h.message = l.engineCheckingProgress(p.done, p.total, p.flagged);
        flagged = p.flagged;
      }
    } on EngineCancelled {
      cancelled = true;
    } catch (e) {
      error = e;
    } finally {
      h.close();
    }
    await _c.save();
    if (!mounted || cancelled) return;
    if (error != null) {
      showSnack(context, l.engineError);
      return;
    }
    showSnack(context, l.engineCheckDone(flagged));
    if (flagged > 0) _tabs.animateTo(1);
  }

  Future<void> _options() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RepertoireSettingsPage(id: widget.id, row: _c.row!),
      ),
    );
    if (saved == true) await _c.load();
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final trained = _c.graph!.cards.values.where((c) => !c.srs.isNew).length;
    final ok = await confirm(
      context,
      title: l.deleteRepertoireQ(_c.row!.name),
      // The training history is mentioned only when there is one.
      message: trained == 0
          ? l.deleteRepertoireNoHistory(_c.graph!.positions.length)
          : l.deleteRepertoireMessage(_c.graph!.positions.length, trained),
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(repertoireRepositoryProvider);
    final refresh = ref.read(refreshTickProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final snapshot = await repo.snapshot(widget.id);
    await repo.delete(widget.id);
    // Today's cards (problem positions, counters) must forget it at once.
    refresh.bump();
    if (!mounted) return;
    context.go('/repertoires');
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.repertoireDeleted),
          action: snapshot == null
              ? null
              : SnackBarAction(
                  label: l.undo,
                  onPressed: () => unawaited(repo.restoreSnapshot(snapshot).then((_) => refresh.bump())),
                ),
        ),
      );
  }

  Future<void> _rename() async {
    final l = context.l10n;
    final name = await promptText(context, title: l.rename, initial: _c.row!.name, label: l.name);
    if (name == null || name.trim().isEmpty || name.trim() == _c.row!.name) return;
    await ref.read(repertoireRepositoryProvider).update(widget.id, name: name.trim());
    await _c.load();
  }

  Future<void> _importFromLibrary() async {
    final l = context.l10n;
    final cols = ref.read(collectionsProvider).value ?? const [];
    if (cols.isEmpty) {
      await context.push('/import');
      return;
    }
    final colId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.chooseCollection),
        children: [
          for (final c in cols)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c.row.id),
              child: Text('${c.row.name} (${c.gameCount})'),
            ),
        ],
      ),
    );
    if (colId == null || !mounted) return;
    final rows = await ref.read(libraryRepositoryProvider).gamesOf(colId);
    if (!mounted) return;
    await context.push(
      '/rep-import',
      extra: RepImportRequest(
        games: [for (final r in rows) parseStoredGame(r.pgn)],
        targetRepertoireId: widget.id,
        sourceLabel: cols.firstWhere((c) => c.row.id == colId).row.name,
      ),
    );
    await _c.load();
  }

  Future<void> _menu(String v) async {
    switch (v) {
      case 'options':
        await _options();
      case 'rename':
        await _rename();
      case 'importLib':
        await _importFromLibrary();
      case 'importFile':
        await context.push('/import', extra: ImportInput(targetRepertoireId: widget.id));
        await _c.load();
      case 'export':
        await _export();
      case 'lichess':
        await _exportToLichess();
      case 'weights':
        await _fillWeights();
      case 'engine':
        await _engineCheck();
      case 'delete':
        await _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_c.error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.repertoireNotFound)),
      );
    }
    if (!_c.loaded) return const Scaffold(body: LoadingView());
    final g = _c.graph!;
    final row = _c.row!;
    final problems = _problemKeys(g);
    final summary = (ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[])
        .where((r) => r.row.id == widget.id)
        .firstOrNull;
    return PopScope(
      canPop: _c.pending.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscardPending(context, _c) && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              SideBadge(side: g.color, size: _titleBadge),
              AppGap.h8,
              // Two lines before cutting the name ("Білі: осно…").
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MovesText(
                      row.name,
                      maxLines: _editing ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.15),
                    ),
                    if (_editing)
                      Text(l.editingMode, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.meta),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Editing: the helpers for choosing moves and the way out.
            if (_editing) ...[
              IconButton(
                tooltip: l.openingExplorer,
                isSelected: _explorer,
                onPressed: () => setState(() => _explorer = !_explorer),
                icon: const Icon(AppIcons.explorer),
              ),
              IconButton(
                tooltip: l.engine,
                isSelected: _engine,
                onPressed: () => setState(() => _engine = !_engine),
                icon: const Icon(AppIcons.engine),
              ),
              // An icon, not a word: with two toggles beside it the bar must
              // also fit at twice the text size.
              IconButton.filled(
                tooltip: l.done,
                onPressed: _doneEditing,
                // Explicit colours: the themed icon colour made the check
                // invisible on the filled circle.
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(AppIcons.check),
              ),
              AppGap.h8,
            ],
            // Training sits with the other repertoire actions (a floating
            // button covered the content under the board).
            if (!_editing && g.cards.isNotEmpty)
              IconButton(tooltip: l.train, onPressed: _train, icon: const Icon(AppIcons.play)),
            if (!_editing)
              IconButton(
                tooltip: l.editRepertoire,
                onPressed: () => setState(() => _editing = true),
                icon: const Icon(AppIcons.builder),
              ),
            if (!_editing)
              PopupMenuButton<String>(
                constraints: appMenuConstraints,
                icon: const Icon(AppIcons.more),
                tooltip: l.more,
                onSelected: _menu,
                itemBuilder: repertoireMenuItems,
              ),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.tabPositions),
              Tab(
                // The count sits after the word, not on top of its last letter.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.tabProblems),
                    if (problems.isNotEmpty) ...[AppGap.h4, Badge(label: Text('${problems.length}'))],
                  ],
                ),
              ),
              Tab(text: l.tabStats),
            ],
          ),
        ),
        body: IndexedStack(
          index: _tabs.index,
          children: [
            RepertoireBrowser(
              c: _c,
              enableTree: true,
              problemKeys: problems,
              builderMode: _editing,
              onAddedInView: () => setState(() => _editing = true),
              extraPanels: [
                if (_editing && _engine)
                  Card(
                    margin: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.md),
                    child: EnginePanel(
                      fen: _c.position.fen,
                      onAddLine: (moves) =>
                          playAndAddLine(context, _c, moves, alreadyMessage: context.l10n.lineAlreadyInRepertoire),
                    ),
                  ),
                if (_editing && _explorer)
                  Card(
                    margin: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.md, bottom: AppSpacing.xl),
                    child: ExplorerPanel(
                      fen: _c.position.fen,
                      highlightUcis: _c.inRepertoire ? {for (final m in _c.graph!.movesFrom(_c.key)) m.uci} : const {},
                      onPlay: _playAndAdd,
                    ),
                  ),
              ],
            ),
            SafeArea(
              top: false,
              child: _ProblemsTab(c: _c, errorKeys: _errorKeys, onOpen: _openInBrowser, onEdit: _editAt),
            ),
            SafeArea(
              top: false,
              child: StatsView(
                repertoireId: widget.id,
                summary: summary,
                onTrainProblem: (p) => context.push(
                  '/train',
                  extra: TrainingArgs(
                    repertoireIds: [widget.id],
                    mode: TrainingMode.problems,
                    problemKeys: {
                      widget.id: [p.key],
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String strategyName(OpponentStrategy s, AppLocalizations l) => switch (s) {
  OpponentStrategy.dueFirst => l.strategyDueFirst,
  OpponentStrategy.weighted => l.strategyWeighted,
  OpponentStrategy.uniform => l.strategyUniform,
  OpponentStrategy.leastLearned => l.strategyLeastLearned,
};

String strategyHint(OpponentStrategy s, AppLocalizations l) => switch (s) {
  OpponentStrategy.dueFirst => l.strategyDueFirstHint,
  OpponentStrategy.weighted => l.strategyWeightedHint,
  OpponentStrategy.uniform => l.strategyUniformHint,
  OpponentStrategy.leastLearned => l.strategyLeastLearnedHint,
};

class _ProblemsTab extends ConsumerStatefulWidget {
  const _ProblemsTab({required this.c, required this.errorKeys, required this.onOpen, required this.onEdit});
  final RepertoireController c;
  final Set<PositionKey> errorKeys;
  final void Function(PositionKey) onOpen;

  /// Opens the position for editing, optionally with a move to add.
  final Future<void> Function(PositionKey, {String? play}) onEdit;

  @override
  ConsumerState<_ProblemsTab> createState() => _ProblemsTabState();
}

class _ProblemsTabState extends ConsumerState<_ProblemsTab> {
  List<CoverageGap>? _coverage;
  bool _running = false;
  bool _cancel = false;
  double _progress = 0;

  Future<void> _runCoverage() async {
    final l = context.l10n;
    if (!(await ref.read(accountsServiceProvider).hasLichessToken())) {
      if (mounted) showSnack(context, l.explorerNeedsLogin);
      return;
    }
    final s = ref.read(settingsProvider);
    setState(() {
      _running = true;
      _cancel = false;
      _coverage = [];
    });
    // Whatever happens to the network, the tab must leave the running
    // state: a failure used to leave the progress bar and a dead Stop.
    try {
      await for (final (p, gaps) in ExplorerBatch(ref.read(explorerServiceProvider)).coverage(
        widget.c.graph!,
        ExplorerQuery(
          db: s.explorerSource == 'mine' ? 'lichess' : s.explorerSource,
          speeds: s.explorerSpeeds,
          ratings: s.explorerRatings,
        ),
        minShare: s.gapCoveragePercent / 100,
        cancelled: () => _cancel || !mounted,
      )) {
        if (!mounted) return;
        setState(() {
          _progress = p.total == 0 ? 1 : p.done / p.total;
          _coverage = gaps;
        });
        if (p.error != null) showSnack(context, l.coverageFailed);
      }
    } catch (_) {
      if (mounted) showSnack(context, l.coverageFailed);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _where(PositionKey k) {
    final g = widget.c.graph!;
    final path = g.pathFromRoot(k);
    return path == null || path.isEmpty ? context.l10n.start : pathToText(path, g);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final g = widget.c.graph!;
    final deferred = g.positions.values.where((p) => p.conflictDeferred).toList();
    final gaps = g.positions.keys.where(g.isGap).toList();
    final flagged = g.positions.values.where((p) => p.engineFlag.isNotEmpty).toList();
    final errors = widget.errorKeys.where(g.positions.containsKey).toList();

    Widget section(String title, String hint, IconData icon, Color color, List<Widget> items) => Card(
      margin: const EdgeInsets.only(left: AppSpacing.page, top: AppSpacing.cardGap, right: AppSpacing.page),
      child: AppExpansionTile(
        initiallyExpanded: items.isNotEmpty && items.length <= 5,
        leading: Icon(icon, color: color),
        title: Text('$title (${items.length})'),
        subtitle: Text(hint),
        children: items.isEmpty ? [ListTile(title: Text(l.nothingHere))] : items,
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
      children: [
        section(l.deferredConflicts, l.deferredConflictsHint, AppIcons.variations, theme.colorScheme.error, [
          for (final p in deferred)
            ListTile(
              title: MovesText(_where(p.key)),
              trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
              onTap: () => widget.onOpen(p.key),
            ),
        ]),
        section(l.gaps, l.gapsHint, AppIcons.help, theme.colorScheme.tertiary, [
          for (final k in gaps.take(200))
            ListTile(
              title: MovesText(_where(k)),
              trailing: IconButton(
                tooltip: l.editRepertoire,
                icon: const Icon(AppIcons.builder),
                onPressed: () => widget.onEdit(k),
              ),
              onTap: () => widget.onOpen(k),
            ),
        ]),
        section(l.frequentMistakes, l.frequentMistakesHint, AppIcons.warning, theme.colorScheme.error, [
          for (final k in errors)
            ListTile(
              title: MovesText(_where(k)),
              trailing: IconButton(
                tooltip: l.trainThisPosition,
                icon: const Icon(AppIcons.play),
                onPressed: () => context.push(
                  '/train',
                  extra: TrainingArgs(
                    repertoireIds: [widget.c.id],
                    mode: TrainingMode.problems,
                    problemKeys: {
                      widget.c.id: [k],
                    },
                  ),
                ),
              ),
              onTap: () => widget.onOpen(k),
            ),
        ]),
        section(l.engineFlags, l.engineFlagsHint, AppIcons.engine, theme.colorScheme.secondary, [
          for (final p in flagged)
            ListTile(
              title: MovesText(_where(p.key)),
              subtitle: () {
                final f = EngineFlag.decode(p.engineFlag);
                return f == null ? null : MovesText(l.engineFlagHint(f.bestSan, f.depth));
              }(),
              onTap: () => widget.onOpen(p.key),
            ),
        ]),
        Card(
          margin: const EdgeInsets.only(left: AppSpacing.page, top: AppSpacing.cardGap, right: AppSpacing.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: Icon(AppIcons.coverage, color: theme.colorScheme.primary),
                title: Text(l.coverageTitle),
                subtitle: Text(l.coverageHint(ref.watch(settingsProvider).gapCoveragePercent)),
              ),
              // Under the text, not beside it: a long hint never squeezes
              // the button, and it stays a full-width finger target.
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.card, right: AppSpacing.card, bottom: AppSpacing.md),
                child: _running
                    ? OutlinedButton.icon(
                        style: AppButtonSize.wide,
                        onPressed: () => setState(() => _cancel = true),
                        icon: const Icon(AppIcons.stop),
                        label: Text(l.stop),
                      )
                    : FilledButton.tonalIcon(
                        style: AppButtonSize.wide,
                        onPressed: _runCoverage,
                        icon: const Icon(AppIcons.search),
                        label: Text(l.check),
                      ),
              ),
              if (_running) LinearProgressIndicator(value: _progress),
              for (final gap in _coverage ?? const <CoverageGap>[])
                ListTile(
                  title: MovesText('${_where(gap.key)} → ${gap.san}'),
                  subtitle: Text(l.coverageItem((gap.share * 100).toStringAsFixed(1), gap.games)),
                  trailing: IconButton(
                    tooltip: l.addToRepertoire,
                    icon: const Icon(AppIcons.add),
                    onPressed: () => widget.onEdit(gap.key, play: gap.uci),
                  ),
                ),
              if (_coverage != null && _coverage!.isEmpty && !_running) ListTile(title: Text(l.coverageNone)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Opens the repertoire detail (used by other screens).
void openRepertoire(BuildContext context, int id, {PositionKey? key}) =>
    context.go(key == null ? '/repertoires/$id' : '/repertoires/$id?key=${Uri.encodeQueryComponent(key)}');

Side colorOf(RepertoireRow r) => r.color == 'black' ? Side.black : Side.white;

/// Repertoire name, description and training options (full screen, so
/// typed text is not lost by an accidental tap outside).
class RepertoireSettingsPage extends ConsumerStatefulWidget {
  const RepertoireSettingsPage({super.key, required this.id, required this.row});
  final int id;
  final RepertoireRow row;

  @override
  ConsumerState<RepertoireSettingsPage> createState() => _RepertoireSettingsPageState();
}

class _RepertoireSettingsPageState extends ConsumerState<RepertoireSettingsPage> {
  late final _name = TextEditingController(text: widget.row.name);
  late final _desc = TextEditingController(text: widget.row.description);
  late OpponentStrategy _strategy;
  late bool _accept;

  @override
  void initState() {
    super.initState();
    final opts = RepertoireOptions.decode(widget.row.optionsJson);
    _strategy = opts.strategy ?? ref.read(settingsProvider).defaultStrategy;
    _accept = opts.acceptAlternatives ?? ref.read(settingsProvider).acceptAlternatives;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(repertoireRepositoryProvider)
        .update(
          widget.id,
          name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          description: _desc.text,
          options: RepertoireOptions(strategy: _strategy, acceptAlternatives: _accept),
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.repertoireSettings),
        actions: [TextButton(onPressed: _save, child: Text(l.save))],
      ),
      body: AppPage(
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.name),
          ),
          AppGap.v12,
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: InputDecoration(labelText: l.description),
          ),
          AppGap.v24,
          Text(l.opponentStrategy, style: context.tt.title),
          RadioGroup<OpponentStrategy>(
            groupValue: _strategy,
            onChanged: (v) => setState(() => _strategy = v!),
            child: Column(
              children: [
                for (final st in OpponentStrategy.values)
                  RadioListTile<OpponentStrategy>(
                    value: st,
                    title: Text(strategyName(st, l)),
                    subtitle: Text(strategyHint(st, l)),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _accept,
            onChanged: (v) => setState(() => _accept = v),
            title: Text(l.acceptAlternatives),
            subtitle: Text(l.acceptAlternativesHint),
          ),
        ],
      ),
    );
  }
}

/// Asks what to do with explored moves that were not added yet.
Future<bool> confirmDiscardPending(BuildContext context, RepertoireController c) async {
  final l = context.l10n;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.pendingMovesQ),
      content: MovesText(l.pendingMovesMessage(c.pending.map((p) => p.$2).join(' '))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.stay)),
        TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(l.discard)),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'add'), child: Text(l.addToRepertoire)),
      ],
    ),
  );
  if (choice == 'discard') {
    c.pending.clear();
    return true;
  }
  if (choice == 'add') {
    final outcome = await c.commitPending(policy: OwnMovePolicy.asAlternative);
    return outcome != AddMoveOutcome.needsDecision;
  }
  return false;
}
