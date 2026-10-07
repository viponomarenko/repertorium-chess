import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/repertoire/repertoire_export.dart';
import '../../domain/repertoire/repertoire_graph.dart';
import '../../domain/repertoire/repertoire_import.dart';
import '../../domain/training/training_engine.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/san_text.dart';
import 'repertoire_browser.dart' show pathToText;

/// Request to import documents into a repertoire (F-REP-03).
class RepImportRequest {
  const RepImportRequest({
    required this.games,
    this.startNode,
    this.targetRepertoireId,
    this.sourceLabel = '',
    this.defaultColor,
    this.savedToLibrary = false,
  });

  /// The games were saved to the library on the way here: leaving the
  /// wizard does not undo that, and the dialog must not say otherwise.
  final bool savedToLibrary;
  final List<ChessGame> games;

  /// Import only the subtree starting at this node (of games.first).
  final GameNode? startNode;
  final int? targetRepertoireId;
  final String sourceLabel;

  /// Colour for a new repertoire (e.g. the board orientation in analysis).
  final Side? defaultColor;
}

class ImportWizardScreen extends ConsumerStatefulWidget {
  const ImportWizardScreen({super.key, required this.request});
  final RepImportRequest request;

  @override
  ConsumerState<ImportWizardScreen> createState() => _ImportWizardScreenState();
}

class _ImportWizardScreenState extends ConsumerState<ImportWizardScreen> {
  int? _targetId;
  final _newName = TextEditingController();
  Side _newColor = Side.white;
  late final Set<int> _selected = {for (var i = 0; i < widget.request.games.length; i++) i};
  RepImportOptions _opts = const RepImportOptions();
  final Map<int, RepertoireGraph> _graphs = {};
  ImportResult? _preview;
  Timer? _debounce;
  bool _busy = false;

  /// Side of the board on a conflict card.
  static const double _conflictBoard = 140;

  // Conflict stage.
  RepertoireGraph? _working;
  List<ImportConflict> _conflicts = [];
  final Map<PositionKey, ConflictResolution> _resolutions = {};

  @override
  void initState() {
    super.initState();
    // Explicit target, else where the last lines went (if it still exists).
    final last = ref.read(lastImportTargetProvider);
    final reps = ref.read(repertoiresProvider).value ?? const <RepertoireSummary>[];
    _targetId = widget.request.targetRepertoireId ?? (reps.any((r) => r.row.id == last) ? last : null);
    final g0 = widget.request.games.isEmpty ? null : widget.request.games.first;
    final orient = g0?.headers['Orientation'];
    if (widget.request.defaultColor != null) {
      _newColor = widget.request.defaultColor!;
    } else if (orient == 'black') {
      _newColor = Side.black;
    }
    _newName.text = widget.request.sourceLabel;
    if (widget.request.games.any(
      (g) => g.headers.containsKey('StudyName') || g.headers['Site']?.contains('lichess.org/study') == true,
    )) {
      _opts = _opts.copyWith(source: 'lichess-study');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePreview());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _newName.dispose();
    super.dispose();
  }

  List<ImportSource> get _sources {
    if (widget.request.startNode != null) return [ImportSource(widget.request.startNode!)];
    return [
      for (var i = 0; i < widget.request.games.length; i++)
        if (_selected.contains(i)) ImportSource.game(widget.request.games[i]),
    ];
  }

  /// Start position of a new repertoire: the common starting position of
  /// the sources (a game from a custom position), otherwise the initial one.
  String get _newRootFen {
    String rootOf(GameNode n) {
      var x = n;
      while (x.parent != null) {
        x = x.parent!;
      }
      return x.position.fen;
    }

    final fens = {for (final src in _sources) normalizeFenToKey(rootOf(src.start))};
    if (fens.length == 1 && _sources.isNotEmpty) return rootOf(_sources.first.start);
    return kInitialFen;
  }

  /// Created on the first save attempt; a retry reuses it (no duplicates).
  int? _createdId;

  Future<RepertoireGraph> _baseGraph() async {
    if (_targetId == null) {
      final fen = _newRootFen;
      return RepertoireGraph(color: _newColor, rootKey: normalizeFenToKey(fen), rootFen: positionFromFen(fen).fen);
    }
    return _graphs[_targetId!] ??= await ref.read(repertoireRepositoryProvider).loadGraph(_targetId!);
  }

  void _schedulePreview() {
    _debounce?.cancel();
    final gen = ++_previewGen;
    setState(() => _preview = null);
    _debounce = Timer(AppTiming.inputDebounce, () => _runPreview(gen));
  }

  int _previewGen = 0;

  Future<void> _runPreview(int gen) async {
    try {
      final base = await _baseGraph();
      if (!mounted || gen != _previewGen) return;
      final r = importIntoRepertoire(base.clone(), _sources, _opts);
      setState(() => _preview = r);
    } catch (e) {
      if (mounted && gen == _previewGen) _failed(e);
    }
  }

  /// Builds the result in memory; nothing is written (and no new
  /// repertoire is created) until the user confirms.
  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final graph = (await _baseGraph()).clone();
      final r = importIntoRepertoire(graph, _sources, _opts);
      if (!r.reachedRepertoire) {
        if (mounted) {
          setState(() => _busy = false);
          showSnack(context, context.l10n.nothingToImport);
        }
        return;
      }
      if (r.conflicts.isEmpty) return await _save(graph, r);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _working = graph;
        _conflicts = r.conflicts;
        _resolutions.clear();
      });
    } catch (e) {
      _failed(e);
    }
  }

  Future<void> _finishConflicts() async {
    final g = _working!;
    setState(() => _busy = true);
    try {
      for (final c in _conflicts) {
        final r = _resolutions[c.key];
        if (r != null) resolveConflict(g, c, r);
      }
      await _save(g, _preview);
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object e) {
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, context.l10n.importFailed(friendlyError(e, context.l10n)));
  }

  Future<void> _save(RepertoireGraph graph, ImportResult? r) async {
    final repo = ref.read(repertoireRepositoryProvider);
    final l = context.l10n;
    final id =
        _targetId ??
        (_createdId ??= await repo.create(
          name: _newName.text.trim().isEmpty
              ? (_newColor == Side.white ? l.defaultRepNameWhite : l.defaultRepNameBlack)
              : _newName.text.trim(),
          color: _newColor,
          rootFen: graph.positions[graph.rootKey]!.fen,
        ));
    await repo.saveGraph(id, graph);
    ref.read(refreshTickProvider.notifier).bump();
    ref.read(lastImportTargetProvider.notifier).set(id);
    if (!mounted) return;
    // Back to where the import started (e.g. an unsaved analysis stays
    // open); the snackbar opens the repertoire.
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.importDone(r?.stats.newMoves ?? 0)),
        // New moves: learn them right away (then back to the file);
        // otherwise open the repertoire.
        action: (r?.stats.newMoves ?? 0) > 0
            ? SnackBarAction(
                label: l.learnNow,
                onPressed: () => router.push(
                  '/train',
                  extra: TrainingArgs(repertoireIds: [id], mode: TrainingMode.learn),
                ),
              )
            : (_targetId == widget.request.targetRepertoireId && _targetId != null
                  ? null
                  : SnackBarAction(label: l.openAction, onPressed: () => router.go('/repertoires/$id'))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: _working == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await confirm(
          context,
          title: l.leaveImportQ,
          message: widget.request.savedToLibrary ? l.leaveImportSavedMessage : l.leaveImportMessage,
          confirmLabel: l.leaveImportConfirm,
          cancelLabel: l.leaveImportStay,
          destructive: true,
        );
        if (ok && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_working == null ? l.addToRepertoire : l.resolveConflicts)),
        body: _working == null ? _optionsView(context) : _conflictsView(context),
        bottomNavigationBar: _working == null ? _bottomBar(context) : null,
      ),
    );
  }

  bool get _canImport => !_busy && _preview != null && _preview!.reachedRepertoire && _sources.isNotEmpty;

  /// Always-visible summary of what will happen plus the main action.
  Widget _bottomBar(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = _preview;
    return StickyActionBar(
      top: p == null
          ? const LinearProgressIndicator()
          : Text(
              p.reachedRepertoire ? l.previewShort(p.stats.newMoves, p.conflicts.length) : l.nothingToImport,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.tabular.copyWith(
                color: p.reachedRepertoire ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
              ),
            ),
      // The bar is a column: a plain full-width button (Expanded here
      // stretched it over the whole screen).
      children: [
        FilledButton.icon(
          style: AppButtonSize.large,
          onPressed: _canImport ? _import : null,
          icon: _busy ? const InlineSpinner() : const Icon(AppIcons.importToRepertoire),
          label: Text(l.importAction),
        ),
      ],
    );
  }

  Widget _optionsView(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final games = widget.request.games;
    final p = _preview;
    return MaxWidth(
      child: ListView(
        padding: AppInsets.page,
        children: [
          Text(l.targetRepertoire, style: context.tt.title),
          AppGap.v8,
          DropdownButtonFormField<int?>(
            icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
            initialValue: _targetId,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: null, child: Text(l.newRepertoire)),
              for (final r in reps)
                DropdownMenuItem(
                  value: r.row.id,
                  child: Text(
                    '${r.row.name} (${r.color == Side.white ? l.white : l.black})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => _targetId = v);
              _schedulePreview();
            },
          ),
          if (_targetId == null) ...[
            AppGap.v12,
            TextField(
              controller: _newName,
              decoration: InputDecoration(labelText: l.name),
            ),
            AppGap.v12,
            ChoiceSegments<Side>(
              options: [ChoiceOption(Side.white, l.iPlayWhite), ChoiceOption(Side.black, l.iPlayBlack)],
              selected: _newColor,
              onChanged: (v) {
                setState(() => _newColor = v);
                _schedulePreview();
              },
            ),
          ],
          AppGap.v16,
          if (widget.request.startNode != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.repertoire),
              title: MovesText(l.subtreeFrom(formatLine(widget.request.startNode!.line))),
            )
          else if (games.length > 1)
            AppExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.gamesSelected(_selected.length, games.length)),
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _selected.addAll(List.generate(games.length, (i) => i));
                        _schedulePreview();
                      },
                      child: Text(l.selectAll),
                    ),
                    TextButton(
                      onPressed: () {
                        _selected.clear();
                        _schedulePreview();
                      },
                      child: Text(l.selectNone),
                    ),
                  ],
                ),
                for (var i = 0; i < games.length && i < 500; i++)
                  CheckboxListTile(
                    value: _selected.contains(i),
                    title: Text(_gameTitle(games[i], i, l)),
                    onChanged: (v) {
                      setState(() => v == true ? _selected.add(i) : _selected.remove(i));
                      _schedulePreview();
                    },
                  ),
              ],
            ),
          // The usual choices are already made; they open on demand (D-068).
          AppExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.importOptions),
            subtitle: Text(l.importOptionsHint),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppGap.v8,
                  Text(l.ownMoves, style: context.tt.title),
                  RadioGroup<bool>(
                    groupValue: _opts.ownAllVariations,
                    onChanged: (v) {
                      setState(() => _opts = _opts.copyWith(ownAllVariations: v));
                      _schedulePreview();
                    },
                    child: Column(
                      children: [
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: false,
                          title: Text(l.mainLineOnly),
                          subtitle: Text(l.ownMainOnlyHint),
                        ),
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          title: Text(l.allVariations),
                          subtitle: Text(l.ownAllHint),
                        ),
                      ],
                    ),
                  ),
                  Text(l.opponentMovesTitle, style: context.tt.title),
                  RadioGroup<bool>(
                    groupValue: _opts.opponentAllVariations,
                    onChanged: (v) {
                      setState(() => _opts = _opts.copyWith(opponentAllVariations: v));
                      _schedulePreview();
                    },
                    child: Column(
                      children: [
                        RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: true, title: Text(l.allVariations)),
                        RadioListTile<bool>(contentPadding: EdgeInsets.zero, value: false, title: Text(l.mainLineOnly)),
                      ],
                    ),
                  ),
                  AppGap.v8,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _opts.maxPly != null,
                    title: Text(l.limitDepth),
                    subtitle: Text(
                      _opts.maxPly == null ? l.maxDepthUnlimited : l.maxDepthPlies((_opts.maxPly! + 1) ~/ 2),
                    ),
                    onChanged: (v) {
                      setState(() => _opts = v ? _opts.copyWith(maxPly: 20) : _opts.copyWith(clearMaxPly: true));
                      _schedulePreview();
                    },
                  ),
                  if (_opts.maxPly != null)
                    Slider(
                      value: _opts.maxPly!.toDouble(),
                      min: 2,
                      max: 60,
                      divisions: 29,
                      label: '${_opts.maxPly}',
                      onChanged: (v) {
                        setState(() => _opts = _opts.copyWith(maxPly: v.round()));
                        _schedulePreview();
                      },
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _opts.includeComments,
                    title: Text(l.transferComments),
                    onChanged: (v) {
                      setState(() => _opts = _opts.copyWith(includeComments: v));
                      _schedulePreview();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _opts.includeShapes,
                    title: Text(l.transferArrows),
                    onChanged: (v) {
                      setState(() => _opts = _opts.copyWith(includeShapes: v));
                      _schedulePreview();
                    },
                  ),
                ],
              ),
            ],
          ),
          AppGap.v24,
          Text(l.preview, style: context.tt.title),
          AppGap.v8,
          if (p == null)
            const LinearProgressIndicator()
          else ...[
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                StatTile(value: context.fmtInt(p.stats.newPositions), label: l.newPositions),
                StatTile(value: context.fmtInt(p.stats.newMoves), label: l.newMoves),
                StatTile(value: context.fmtInt(p.stats.matchedMoves), label: l.matchedMoves),
                StatTile(
                  value: context.fmtInt(p.conflicts.length),
                  label: l.conflicts,
                  color: p.conflicts.isEmpty ? null : theme.colorScheme.error,
                ),
              ],
            ),
            if (!p.reachedRepertoire) ...[
              AppGap.v12,
              InfoStrip(icon: AppIcons.error, text: l.nothingToImport, tone: Tone.error),
            ],
            if (p.stats.commentCollisions > 0) ...[
              AppGap.v12,
              Text(l.commentCollisions(p.stats.commentCollisions)),
              AppGap.v8,
              ChoiceSegments<CommentPolicy>(
                options: [
                  ChoiceOption(CommentPolicy.keepOld, l.keepOld),
                  ChoiceOption(CommentPolicy.replace, l.replace),
                  ChoiceOption(CommentPolicy.merge, l.merge),
                ],
                selected: _opts.commentPolicy,
                onChanged: (v) => setState(() => _opts = _opts.copyWith(commentPolicy: v)),
              ),
            ],
            if (p.conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Text(l.conflictsWillBeShown, style: context.tt.meta),
              ),
          ],
        ],
      ),
    );
  }

  String _gameTitle(ChessGame g, int i, AppLocalizations l) {
    final h = g.headers;
    final chapter = h['ChapterName'];
    if (chapter != null) return chapter;
    final players = playersLine(h['White'], h['Black']);
    if (players.isNotEmpty) return players;
    return h['Event'] ?? l.gameN(i + 1);
  }

  Widget _conflictsView(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final g = _working!;
    final unresolved = _conflicts.where((c) => !_resolutions.containsKey(c.key)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
          child: Text(l.conflictsExplanation, style: theme.textTheme.bodyMedium),
        ),
        Padding(
          padding: AppInsets.pageH,
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  for (final c in _conflicts) {
                    _resolutions[c.key] = ConflictResolution.choose(c.key, c.candidates.keys.first);
                  }
                }),
                child: Text(l.keepAllCurrent),
              ),
              OutlinedButton(
                onPressed: () => setState(() {
                  for (final c in _conflicts) {
                    _resolutions[c.key] = ConflictResolution.defer(c.key);
                  }
                }),
                child: Text(l.deferAll),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.listBottom),
            itemCount: _conflicts.length,
            separatorBuilder: (_, _) => AppGap.v12,
            itemBuilder: (context, i) {
              final c = _conflicts[i];
              final r = _resolutions[c.key];
              final path = g.pathFromRoot(c.key) ?? const [];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: AppInsets.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MovesText(path.isEmpty ? l.start : pathToText(path, g), style: context.tt.title),
                      AppGap.v8,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MiniBoard(fen: c.fen, orientation: g.color, size: _conflictBoard),
                          AppGap.h12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(l.chooseMainMove),
                                for (final e in c.candidates.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                                    child: ChoiceChip(
                                      label: MovesText(e.value),
                                      selected: r != null && !r.defer && r.mainUci == e.key,
                                      onSelected: (_) => setState(
                                        () => _resolutions[c.key] = ConflictResolution.choose(
                                          c.key,
                                          e.key,
                                          others: r?.others ?? ConflictOthers.alternative,
                                        ),
                                      ),
                                    ),
                                  ),
                                AppGap.v4,
                                ChoiceChip(
                                  label: Text(l.defer),
                                  selected: r?.defer ?? false,
                                  onSelected: (_) =>
                                      setState(() => _resolutions[c.key] = ConflictResolution.defer(c.key)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (r != null && !r.defer)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: r.others == ConflictOthers.delete,
                          title: Text(l.deleteOtherCandidates),
                          subtitle: Text(l.deleteOtherCandidatesHint),
                          onChanged: (v) => setState(
                            () => _resolutions[c.key] = ConflictResolution.choose(
                              c.key,
                              r.mainUci!,
                              others: v ? ConflictOthers.delete : ConflictOthers.alternative,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        StickyActionBar(
          children: [
            FilledButton(
              style: AppButtonSize.large,
              onPressed: unresolved == 0 && !_busy ? _finishConflicts : null,
              child: Text(unresolved == 0 ? l.finishImport : l.unresolvedLeft(unresolved)),
            ),
          ],
        ),
      ],
    );
  }
}
