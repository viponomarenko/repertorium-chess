import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/l10n.dart';
import '../../data/import/pgn_import_service.dart';
import '../../data/lichess/lichess_client.dart';
import '../../data/repositories/library_repository.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/pgn/pgn_model.dart';
import '../../domain/pgn/text_encoding.dart';
import '../../domain/repertoire/repertoire_import.dart';
import '../../domain/training/training_engine.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../game/game_screen.dart';
import '../repertoire/import_wizard_screen.dart';
import '../settings/backup_screen.dart';
import '../theme/app_icons.dart';
import '../training/training_args.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';

/// What to import. Empty = let the user choose a source.
class ImportInput {
  const ImportInput({this.bytes, this.text, this.fileName, this.url, this.targetCollectionId, this.targetRepertoireId});
  final Uint8List? bytes;
  final String? text;
  final String? fileName;
  final String? url;
  final int? targetCollectionId;

  /// Started from a repertoire: adding to it is the primary action.
  final int? targetRepertoireId;

  bool get isEmpty => bytes == null && (text == null || text!.trim().isEmpty) && url == null;
}

bool _isZip(Uint8List b) => b.length > 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] == 0x03 && b[3] == 0x04;

class ImportFlowScreen extends ConsumerStatefulWidget {
  const ImportFlowScreen({super.key, required this.input});
  final ImportInput input;

  @override
  ConsumerState<ImportFlowScreen> createState() => _ImportFlowScreenState();
}

class _ImportFlowScreenState extends ConsumerState<ImportFlowScreen> {
  Uint8List? _bytes;
  String? _text;
  String _name = '';
  String _sourceKind = 'file';
  ParseReport? _report;
  bool _parsing = false;
  double? _progress;
  ParseJob? _job;
  TextEncodingKind? _forced;
  String? _error;
  int? _targetCollection;
  final _collectionName = TextEditingController();
  bool _saving = false;
  bool _showEncoding = false;

  /// The name this screen put into the field itself: the next source
  /// replaces it, a name typed by the user stays.
  String _autoName = '';

  /// The collection created by a save that then failed: a retry fills it
  /// instead of creating a second one.
  int? _createdId;

  @override
  void initState() {
    super.initState();
    _targetCollection = widget.input.targetCollectionId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start(widget.input));
  }

  @override
  void dispose() {
    _job?.cancel();
    _collectionName.dispose();
    super.dispose();
  }

  Future<void> _start(ImportInput input) async {
    if (input.isEmpty) return;
    if (input.url != null) return _fromUrl(input.url!);
    if (input.bytes != null) {
      if (_isZip(input.bytes!) || (input.fileName ?? '').toLowerCase().endsWith('.tabiya')) {
        if (!mounted) return;
        context.pushReplacement('/backup', extra: BackupRestoreRequest(input.bytes!));
        return;
      }
      _bytes = input.bytes;
      _text = null;
      _name = _stripExt(input.fileName ?? '');
      _sourceKind = 'file';
      return _parse();
    }
    final text = input.text!.trim();
    final kind = detectChessText(text);
    if (kind == ChessTextKind.lichessUrl || kind == ChessTextKind.url) return _fromUrl(text);
    _text = text;
    _bytes = null;
    _sourceKind = 'clipboard';
    _name = '';
    return _parse();
  }

  String _stripExt(String n) => n.replaceAll(RegExp(r'\.(pgn|epd|fen|txt)$', caseSensitive: false), '');

  /// Bumped by every new request and by Cancel: late answers of an older
  /// request are ignored.
  int _gen = 0;

  Future<void> _parse() async {
    final gen = ++_gen;
    setState(() {
      _parsing = true;
      _progress = null;
      _report = null;
      _error = null;
    });
    final job = ref.read(pgnImportServiceProvider).parse(bytes: _bytes, text: _text, forcedEncoding: _forced);
    _job = job;
    final sub = job.progress.listen((p) {
      if (mounted) setState(() => _progress = p);
    });
    try {
      final r = await job.result;
      if (!mounted || gen != _gen) return;
      if (r.cancelled) {
        // Back to choosing a source, not "no games found".
        setState(() {
          _report = null;
          _parsing = false;
        });
        return;
      }
      setState(() {
        _report = r;
        _parsing = false;
        if (_collectionName.text.isEmpty || _collectionName.text == _autoName) {
          _autoName = _name.isNotEmpty && _name.trim() != '?' ? _name : _defaultName(r);
          _collectionName.text = _autoName;
        }
        _learnPlanned = false;
        _learnTargetId = null;
      });
      unawaited(_planLearn());
    } catch (e) {
      if (mounted && gen == _gen) {
        setState(() {
          _parsing = false;
          _error = context.l10n.downloadFailed(friendlyError(e, context.l10n));
        });
      }
    } finally {
      await sub.cancel();
      if (gen == _gen) _job = null;
    }
  }

  String _defaultName(ParseReport r) {
    final l = context.l10n;
    if (r.games.length == 1) {
      final t = r.games.first.title;
      if (t.trim().isNotEmpty && t != '? - ?' && t.trim() != '?') return t;
    }
    return l.importedOn(MaterialLocalizations.of(context).formatShortDate(DateTime.now()));
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final f = files.first;
    final bytes = await f.xFile.readAsBytes();
    await _start(ImportInput(bytes: bytes, fileName: f.name, targetCollectionId: _targetCollection));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      // iOS may deny programmatic paste: let the user paste via the menu.
      if (!mounted) return;
      showSnack(context, context.l10n.clipboardEmpty);
      await _typeText();
      return;
    }
    await _start(ImportInput(text: text));
  }

  Future<void> _typeText() async {
    final l = context.l10n;
    final text = await promptText(
      context,
      title: l.pastePgnOrFen,
      initial: _text ?? '',
      maxLines: 10,
      confirmLabel: l.importAction,
      hint: '1. e4 e5 2. Nf3 ...',
      mono: true,
    );
    if (text != null && text.trim().isNotEmpty) await _start(ImportInput(text: text));
  }

  Future<void> _askUrl() async {
    final l = context.l10n;
    final url = await promptText(
      context,
      title: l.importByLink,
      hint: 'https://lichess.org/study/...',
      keyboardType: TextInputType.url,
      confirmLabel: l.importAction,
    );
    if (url != null && url.trim().isNotEmpty) await _fromUrl(url.trim());
  }

  Future<void> _fromUrl(String url) async {
    final l = context.l10n;
    final gen = ++_gen;
    setState(() {
      _parsing = true;
      _error = null;
      _report = null;
    });
    try {
      final li = LichessUrl.parse(url);
      String text;
      if (li != null) {
        final client = ref.read(lichessClientProvider);
        switch (li.kind) {
          case LichessUrlKind.study:
            text = await client.studyPgn(li.id);
          case LichessUrlKind.chapter:
            text = await client.studyPgn(li.id, chapterId: li.chapterId);
          case LichessUrlKind.game:
            text = await client.gamePgn(li.id);
        }
        _sourceKind = 'lichess';
        final first = RegExp(r'\[(?:StudyName|Event) "([^"]*)"\]').firstMatch(text)?.group(1);
        _name = first ?? 'Lichess ${li.id}';
      } else {
        final uri = Uri.tryParse(url);
        if (uri == null || !uri.hasScheme) throw FormatException(l.invalidLink);
        final res = await http
            .get(uri, headers: {'User-Agent': ref.read(userAgentProvider)})
            .timeout(const Duration(seconds: 30));
        if (!mounted || gen != _gen) return;
        if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
        _bytes = res.bodyBytes;
        _text = null;
        _sourceKind = 'file';
        _name = _stripExt(Uri.decodeComponent(uri.pathSegments.isEmpty ? uri.host : uri.pathSegments.last));
        return await _parse();
      }
      if (!mounted || gen != _gen) return;
      _text = text;
      _bytes = null;
      return await _parse();
    } on LichessException catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _parsing = false;
        _error = e.isNotFound ? l.lichessNotFound : (e.isUnauthorized ? l.lichessPrivate : e.message);
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _parsing = false;
        _error = l.downloadFailed(friendlyError(e, l));
      });
    }
  }

  /// Games of the last save that were already in the collection.
  int _skipped = 0;

  Future<int> _saveToLibrary() async {
    final repo = ref.read(libraryRepositoryProvider);
    final savingText = context.l10n.saving;
    final name = _collectionName.text.trim().isEmpty ? _defaultName(_report!) : _collectionName.text.trim();
    var games = _report!.games;
    var colId = _targetCollection ?? _createdId;
    // The same file opened again: its games go to the collection that
    // already has them, not to a twin with the same name.
    if (colId == null) {
      final same = await repo.collectionNamed(name);
      if (same != null) {
        final have = await repo.pgnKeys(same.id);
        if (games.every((g) => have.contains(LibraryRepository.pgnKey(g.pgn)))) colId = same.id;
      }
    }
    _skipped = 0;
    if (colId != null) {
      final have = await repo.pgnKeys(colId);
      final fresh = [
        for (final g in games)
          if (!have.contains(LibraryRepository.pgnKey(g.pgn))) g,
      ];
      _skipped = games.length - fresh.length;
      games = fresh;
    } else {
      colId = await repo.createCollection(name, source: _sourceKind, sourceRef: _name);
      _createdId = colId;
    }
    if (!mounted) return colId;
    if (games.isNotEmpty) {
      final h = showProgress(context, savingText);
      try {
        await repo.addGames(colId, games, onProgress: (p) => h.progress = p);
      } finally {
        h.close();
      }
    }
    _createdId = null;
    if (mounted && _skipped > 0) showSnack(context, context.l10n.gamesAlreadyThere(_skipped));
    return colId;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    int colId;
    try {
      colId = await _saveToLibrary();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, context.l10n.somethingWentWrong);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    final report = _report!;
    if (report.games.length == 1) {
      final games = await ref.read(libraryRepositoryProvider).gamesOf(colId);
      if (!mounted) return;
      // The game itself (it may be an older one when this was a duplicate).
      final key = LibraryRepository.pgnKey(report.games.single.pgn);
      final game = games.lastWhere((g) => LibraryRepository.pgnKey(g.pgn) == key, orElse: () => games.last);
      context.pushReplacement('/game/${game.id}');
    } else {
      context.pop();
      context.go('/library/$colId');
    }
  }

  Future<void> _toRepertoire({required bool alsoSave}) async {
    if (_saving) return;
    if (alsoSave) {
      setState(() => _saving = true);
      try {
        await _saveToLibrary();
      } catch (_) {
        if (mounted) {
          setState(() => _saving = false);
          showSnack(context, context.l10n.somethingWentWrong);
        }
        return;
      }
    }
    if (!mounted) return;
    final games = [for (final g in _report!.games) parseStoredGame(g.pgn)];
    context.pushReplacement(
      '/rep-import',
      extra: RepImportRequest(
        games: games,
        sourceLabel: _collectionName.text,
        targetRepertoireId: widget.input.targetRepertoireId,
        savedToLibrary: alsoSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: _report == null && !_parsing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) _backToSources();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.importTitle),
          leading: _report != null || _parsing ? BackButton(onPressed: _saving ? null : _backToSources) : null,
          actions: [
            if (_report != null && _text != null)
              IconButton(
                tooltip: l.editImportText,
                icon: const Icon(AppIcons.typeMove),
                onPressed: _saving ? null : _typeText,
              ),
          ],
        ),
        body: _parsing
            ? _ParsingView(
                progress: _progress,
                onCancel: () {
                  _gen++;
                  _job?.cancel();
                  setState(() => _parsing = false);
                },
              )
            : _report != null
            ? _result(context)
            : _sources(context),
      ),
    );
  }

  void _backToSources() {
    _gen++;
    _job?.cancel();
    setState(() {
      _report = null;
      _parsing = false;
      _error = null;
      _createdId = null;
    });
  }

  Widget _sources(BuildContext context) {
    final l = context.l10n;
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) =>
        ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(sub), onTap: onTap);
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.listBottom),
      children: [
        if (_error != null) ...[
          Padding(
            padding: AppInsets.pageH,
            child: InfoStrip(icon: AppIcons.error, text: _error!, tone: Tone.error),
          ),
          AppGap.v12,
        ],
        SettingsGroup(
          children: [
            tile(AppIcons.openFile, l.fromFile, l.fromFileHint, _pickFile),
            // One tile for text: what is on the clipboard, or a field to type
            // or paste into when it is empty.
            tile(AppIcons.paste, l.pasteText, l.pasteTextHint, _paste),
            tile(AppIcons.link, l.importByLink, l.importByLinkHint, _askUrl),
          ],
        ),
        AppGap.v12,
        Center(
          child: TextButton.icon(
            onPressed: () =>
                context.pushReplacement('/game/new', extra: GameScreenArgs(collectionId: _targetCollection)),
            icon: const Icon(AppIcons.newGame),
            label: Text(l.newGame),
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final r = _report!;
    final errors = r.games.where((g) => g.issues.isNotEmpty).toList();
    final cols = ref.watch(collectionsProvider).value ?? const [];
    if (r.games.isEmpty) {
      return EmptyState(
        icon: AppIcons.search,
        title: l.noGamesFound,
        message: l.noGamesFoundHint,
        actions: [
          if (_bytes != null) _encodingPicker(context),
          OutlinedButton(onPressed: () => setState(() => _report = null), child: Text(l.back)),
        ],
      );
    }
    final forRepertoire = widget.input.targetRepertoireId != null;
    final reps = ref.watch(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final learnName = reps.where((x) => x.row.id == _learnTargetId).map((x) => x.row.name).firstOrNull;
    final readName = _targetCollection == null
        ? (_collectionName.text.trim().isEmpty ? _defaultName(r) : _collectionName.text.trim())
        : (cols.where((c) => c.row.id == _targetCollection).map((c) => c.row.name).firstOrNull ?? '');
    // One question: what are these games for? (D-068)
    final readChoice = _ChoiceTile(
      key: const ValueKey('import-read'),
      icon: AppIcons.library,
      title: l.importRead,
      subtitle: l.importReadTo(readName),
      primary: !forRepertoire,
      enabled: !_saving,
      onTap: _save,
      onChange: () => _chooseCollection(cols),
    );
    final learnChoice = _ChoiceTile(
      key: const ValueKey('import-learn'),
      icon: AppIcons.learn,
      title: l.importLearn,
      subtitle: !_learnPlanned
          ? l.importLearnChecking
          : learnName == null
          ? l.importLearnChoose
          : l.importLearnTo(learnName),
      primary: forRepertoire,
      enabled: !_saving,
      onTap: _learn,
      onChange: () => _toRepertoire(alsoSave: false),
    );
    return Column(
      children: [
        Expanded(
          child: MaxWidth(
            child: ListView(
              padding: AppInsets.page,
              children: [
                SectionCard(
                  title: l.foundGames(r.games.length),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errors.isEmpty)
                        StatusLine(icon: AppIcons.okFilled, text: l.noErrors, tone: Tone.success)
                      else
                        // Nothing is thrown away: say where the rest went.
                        StatusLine(
                          icon: AppIcons.warning,
                          text: '${l.gamesWithErrors(errors.length)} ${l.unreadMovesKept}',
                          tone: Tone.error,
                        ),
                      if (_bytes != null) ...[
                        // A sample of the file's text, so a wrong encoding
                        // shows before saving, next to the way to fix it.
                        if (_preview(r) case final p?) ...[
                          AppGap.v8,
                          Text(
                            p,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                        AppGap.v4,
                        _showEncoding
                            ? _encodingPicker(context)
                            : TextButton(
                                onPressed: () => setState(() => _showEncoding = true),
                                child: Text(l.textLooksWrong),
                              ),
                      ],
                    ],
                  ),
                ),
                if (errors.isNotEmpty)
                  AppExpansionTile(
                    leading: Icon(AppIcons.warning, color: theme.colorScheme.error),
                    title: Text(l.problemsList),
                    subtitle: Text(l.problemsListHint),
                    children: [
                      for (final g in errors.take(200))
                        ListTile(
                          title: Text(
                            '${l.gameN(r.games.indexOf(g) + 1)}: '
                            '${const {'', '?', '? - ?'}.contains(g.title.trim()) ? l.untitledGame : g.title}',
                          ),
                          subtitle: Text(g.issues.map((i) => '${l.line} ${localizedIssue(l, i)}').join('\n')),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        StickyActionBar(
          children: forRepertoire ? [learnChoice, AppGap.v8, readChoice] : [readChoice, AppGap.v8, learnChoice],
        ),
      ],
    );
  }

  /// The repertoire "Learn" adds to without asking, or null when the user
  /// has to choose (the wizard opens then). See [_planLearn].
  int? _learnTargetId;
  bool _learnPlanned = false;
  int _planGen = 0;

  /// Finds the repertoire these games belong to (D-073). A repertoire fits
  /// when the lines continue it: they start with moves it already has (or
  /// it is still empty) and nothing in them contradicts its own moves. A
  /// Sicilian does not belong in "Black against 1.d4" just because that is
  /// the only repertoire. The repertoire the import was started from is
  /// taken as asked; among several that fit, the one used last wins, then
  /// the one sharing the most moves.
  Future<void> _planLearn() async {
    final gen = ++_planGen;
    final report = _report;
    if (report == null) return;
    int? best;
    try {
      final repo = ref.read(repertoireRepositoryProvider);
      final reps = await repo.watchSummaries().first;
      final asked = widget.input.targetRepertoireId;
      if (asked != null && reps.any((r) => r.row.id == asked)) {
        best = asked;
      } else {
        final sources = [for (final g in report.games) ImportSource.game(parseStoredGame(g.pgn))];
        final last = ref.read(lastImportTargetProvider);
        var bestScore = -1;
        for (final r in reps) {
          final graph = await repo.loadGraph(r.row.id);
          final empty = graph.moveCount == 0;
          final res = importIntoRepertoire(graph, sources, const RepImportOptions());
          final fits = res.reachedRepertoire && res.conflicts.isEmpty && (empty || res.stats.matchedMoves > 0);
          if (!fits) continue;
          final score = res.stats.matchedMoves + (r.row.id == last ? 1000000 : 0);
          if (score > bestScore) {
            bestScore = score;
            best = r.row.id;
          }
        }
      }
    } catch (_) {
      best = null;
    }
    if (!mounted || gen != _planGen) return;
    setState(() {
      _learnTargetId = best;
      _learnPlanned = true;
    });
  }

  /// "Learn": the games go into the repertoire with the usual options. The
  /// wizard opens only when there is something to decide - no target yet,
  /// or the new moves conflict with the repertoire's own.
  Future<void> _learn() async {
    if (_saving) return;
    final l = context.l10n;
    if (!_learnPlanned) await _planLearn();
    if (!mounted) return;
    final reps = ref.read(repertoiresProvider).value ?? const <RepertoireSummary>[];
    final target = _learnTargetId;
    if (target == null || !reps.any((x) => x.row.id == target)) return _toRepertoire(alsoSave: false);
    setState(() => _saving = true);
    try {
      final repo = ref.read(repertoireRepositoryProvider);
      final graph = await repo.loadGraph(target);
      // Counted the way the repertoire counts: the user's own moves to
      // learn, not every half-move of both sides.
      final ownBefore = graph.cards.length;
      final games = [for (final g in _report!.games) parseStoredGame(g.pgn)];
      final r = importIntoRepertoire(graph, [for (final g in games) ImportSource.game(g)], const RepImportOptions());
      if (!mounted) return;
      if (!r.reachedRepertoire || r.conflicts.isNotEmpty) {
        setState(() => _saving = false);
        await _toRepertoire(alsoSave: false);
        return;
      }
      if (r.stats.newMoves == 0) {
        setState(() => _saving = false);
        showSnack(context, l.importDone(0));
        return;
      }
      await repo.saveGraph(target, graph);
      ref.read(refreshTickProvider.notifier).bump();
      ref.read(lastImportTargetProvider.notifier).set(target);
      if (!mounted) return;
      setState(() => _saving = false);
      final name = reps.firstWhere((x) => x.row.id == target).row.name;
      final learnNow = await showAppSheet<bool>(
        context,
        title: l.movesAddedTo(graph.cards.length - ownBefore, name),
        builder: (ctx) => Padding(
          padding: AppInsets.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                style: AppButtonSize.large,
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(AppIcons.learn),
                label: Text(l.learnNowLong),
              ),
              AppGap.v8,
              OutlinedButton(
                style: AppButtonSize.wide,
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l.done),
              ),
            ],
          ),
        ),
      );
      if (!mounted) return;
      if (learnNow ?? false) {
        context.pushReplacement(
          '/train',
          extra: TrainingArgs(repertoireIds: [target], mode: TrainingMode.learn),
        );
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, l.importFailed(friendlyError(e, l)));
    }
  }

  /// "Change" on the Read choice: another collection, or another name for
  /// the new one.
  Future<void> _chooseCollection(List<CollectionSummary> cols) async {
    final l = context.l10n;
    await showAppSheet<void>(
      context,
      title: l.saveTo,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: AppInsets.sheet,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Room for the floating label of the field.
              AppGap.v8,
              DropdownButtonFormField<int?>(
                icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
                initialValue: _targetCollection,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.collection),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.newCollection)),
                  for (final c in cols)
                    DropdownMenuItem(
                      value: c.row.id,
                      child: Text(c.row.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => set(() => _targetCollection = v),
              ),
              if (_targetCollection == null) ...[
                AppGap.v12,
                TextField(
                  controller: _collectionName,
                  decoration: InputDecoration(labelText: l.collectionName),
                ),
              ],
              AppGap.v16,
              FilledButton(style: AppButtonSize.large, onPressed: () => Navigator.pop(ctx), child: Text(l.done)),
            ],
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// A sample of the file's text: "White - Black · Event" of the first
  /// game that has them, and the first comment with non-Latin letters –
  /// where a wrong encoding shows best.
  String? _preview(ParseReport r) {
    String clean(String? v) => v == null || v == '?' ? '' : v.trim();
    final out = <String>[];
    for (final g in r.games.take(20)) {
      final names = playersLine(g.headers['White'], g.headers['Black']);
      final parts = [names, clean(g.headers['Event'])].where((x) => x.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        out.add(parts.join(' · '));
        break;
      }
    }
    final comment = RegExp(r'\{([^}]*[^\x00-\x7F][^}]*)\}');
    for (final g in r.games.take(50)) {
      final m = comment.firstMatch(g.pgn);
      if (m == null) continue;
      final text = m.group(1)!.replaceAll(RegExp(r'\[%[^\]]*\]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      out.add('«${text.length > 90 ? '${text.substring(0, 90)}…' : text}»');
      break;
    }
    return out.isEmpty ? null : out.join('\n');
  }

  Widget _encodingPicker(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.encoding, style: context.tt.title),
        DropdownButton<TextEncodingKind>(
          isExpanded: true,
          itemHeight: null,
          icon: const Icon(AppIcons.expand, size: AppSizes.iconMd),
          value: _forced ?? _report?.encoding ?? TextEncodingKind.utf8,
          items: [for (final e in TextEncodingKind.values) DropdownMenuItem(value: e, child: Text(e.label))],
          onChanged: (v) {
            setState(() => _forced = v);
            unawaited(_parse());
          },
        ),
      ],
    );
  }
}

class _ParsingView extends StatelessWidget {
  const _ParsingView({required this.progress, required this.onCancel});
  final double? progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.reading, style: context.tt.title),
            AppGap.v16,
            LinearProgressIndicator(value: progress),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(context.l10n.percentValue((progress! * 100).round())),
              ),
            AppGap.v16,
            TextButton(onPressed: onCancel, child: Text(l.cancel)),
          ],
        ),
      ),
    );
  }
}

/// One of the two answers to "what are these games for": a big tappable
/// card, with a quiet "Change" for where exactly they go.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.enabled,
    required this.onTap,
    required this.onChange,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final fg = primary ? cs.onPrimary : cs.onSurface;
    final card = Material(
      color: primary ? cs.primary : cs.surfaceContainerHigh,
      shape: AppRadius.lgShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          // Less on the right: the icon button brings its own padding.
          padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon, color: fg),
              AppGap.h12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: context.tt.title.copyWith(color: fg)),
                    Text(
                      subtitle,
                      // Two lines at most: at the largest text on a small
                      // phone the two choices must leave room for the list.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.meta.copyWith(color: primary ? fg : cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // An icon keeps room for the words at large text sizes.
              IconButton(
                tooltip: l.change,
                onPressed: enabled ? onChange : null,
                color: fg,
                icon: const Icon(AppIcons.edit, size: AppSizes.iconMd),
              ),
            ],
          ),
        ),
      ),
    );
    // While saving the choices do nothing: show that.
    return enabled ? card : Opacity(opacity: AppOpacity.disabled, child: card);
  }
}
