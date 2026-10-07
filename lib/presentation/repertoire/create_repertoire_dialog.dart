import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../data/starter/starter_service.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/pgn/pgn_parser.dart';
import '../../domain/training/training_engine.dart';
import '../app/providers.dart';
import '../training/training_args.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/san_text.dart';

/// Parses "1.e4 c5 2.Nf3" or a FEN into a position. Null if invalid.
Position? parseStartSpec(String text) {
  final t = text.trim();
  if (t.isEmpty) return Chess.initial;
  final fromFen = tryPositionFromFen(t);
  if (fromFen != null && t.contains('/')) return fromFen;
  final g = PgnParser.parseOne('$t *');
  if (g.issues.isNotEmpty) return null;
  final line = g.mainline;
  return line.isEmpty ? null : line.last.position;
}

/// Result of the sheet when the user asked for a ready-made repertoire.
const _kTakeStarter = -1;

/// Creates a repertoire. With [openEditor] the line editor opens right
/// away, so an empty repertoire is never a dead end.
Future<void> showCreateRepertoire(
  BuildContext context, {
  String? fen,
  Side? color,
  String? name,
  bool openEditor = true,
}) async {
  // A bottom sheet, not a dialog: room for the board preview, the keyboard
  // and a big "Create" button in thumb reach.
  final id = await showAppSheet<int>(
    context,
    title: context.l10n.createRepertoire,
    // The form scrolls by itself, above its pinned button.
    scrollable: false,
    builder: (_) => _CreateRepertoireDialog(initialFen: fen, initialColor: color, initialName: name),
  );
  if (id == null || !context.mounted) return;
  // "Or take a ready-made one" in the sheet.
  if (id == _kTakeStarter) return showStarterPicker(context);
  // A new repertoire opens ready for its first moves.
  context.go(openEditor ? '/repertoires/$id?edit=1' : '/repertoires/$id');
}

class _CreateRepertoireDialog extends ConsumerStatefulWidget {
  const _CreateRepertoireDialog({this.initialFen, this.initialColor, this.initialName});
  final String? initialFen;
  final Side? initialColor;
  final String? initialName;

  @override
  ConsumerState<_CreateRepertoireDialog> createState() => _CreateRepertoireDialogState();
}

class _CreateRepertoireDialogState extends ConsumerState<_CreateRepertoireDialog> {
  late final _name = TextEditingController(text: widget.initialName ?? '');
  late final _start = TextEditingController(text: widget.initialFen ?? '');
  late Side _color = widget.initialColor ?? Side.white;
  Position? _pos = Chess.initial;
  bool _busy = false;

  /// Side of the board that previews the start position.
  static const double _previewBoard = 200;

  @override
  void initState() {
    super.initState();
    _pos = parseStartSpec(_start.text);
  }

  @override
  void dispose() {
    _name.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final l = context.l10n;
    final name = _name.text.trim().isEmpty
        ? (_color == Side.white ? l.defaultRepNameWhite : l.defaultRepNameBlack)
        : _name.text.trim();
    if (_pos == null) return;
    setState(() => _busy = true);
    try {
      final id = await ref.read(repertoireRepositoryProvider).create(name: name, color: _color, rootFen: _pos!.fen);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, context.l10n.somethingWentWrong);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // The sheet itself keeps clear of the keyboard and the home indicator.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: AppSpacing.page, right: AppSpacing.page, bottom: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Room for the floating label of the first field.
                AppGap.v8,
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l.nameOptional, hintText: l.repNameHint),
                ),
                AppGap.v16,
                Text(l.iPlayAs, style: context.tt.title),
                AppGap.v8,
                ChoiceSegments<Side>(
                  options: [
                    ChoiceOption(
                      Side.white,
                      l.white,
                      icon: const PieceIcon(PieceKind.whiteKing, size: AppSizes.iconMd),
                    ),
                    ChoiceOption(
                      Side.black,
                      l.black,
                      icon: const PieceIcon(PieceKind.blackKing, size: AppSizes.iconMd),
                    ),
                  ],
                  selected: _color,
                  onChanged: (v) => setState(() => _color = v),
                ),
                AppGap.v16,
                TextField(
                  controller: _start,
                  style: context.tt.mono,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l.startPositionOptional,
                    hintText: '1. e4 c5',
                    helperText: l.startPositionHelp,
                    errorText: _pos == null ? l.invalidMovesOrFen : null,
                    helperMaxLines: 3,
                  ),
                  onChanged: (v) => setState(() => _pos = parseStartSpec(v)),
                ),
                AppGap.v12,
                if (_pos != null)
                  Center(
                    child: MiniBoard(fen: _pos!.fen, orientation: _color, size: _previewBoard),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.xs),
          child: FilledButton(
            style: AppButtonSize.large,
            onPressed: _busy || _pos == null ? null : _create,
            child: Text(l.create),
          ),
        ),
        // The other way to get a repertoire lives here too, not behind
        // an icon in the list's bar. Not offered when the sheet was
        // opened for a particular position or opening.
        if (widget.initialFen == null && widget.initialName == null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, _kTakeStarter),
              child: Text(l.orTakeStarter),
            ),
          )
        else
          AppGap.v8,
      ],
    );
  }
}

final starterListProvider = FutureProvider<List<StarterRepertoire>>(
  (ref) => StarterService(ref.watch(repertoireRepositoryProvider)).list(),
);

/// [learnNow]: after installing, start the first lesson right away (the
/// first run) instead of opening the repertoire.
Future<void> showStarterPicker(BuildContext context, {bool learnNow = false}) async {
  final l = context.l10n;
  await showAppSheet<void>(
    context,
    title: l.installStarter,
    subtitle: l.starterHint,
    builder: (_) => _StarterSheet(learnNow: learnNow),
  );
}

class _StarterSheet extends ConsumerStatefulWidget {
  const _StarterSheet({this.learnNow = false});
  final bool learnNow;

  @override
  ConsumerState<_StarterSheet> createState() => _StarterSheetState();
}

class _StarterSheetState extends ConsumerState<_StarterSheet> {
  String? _installing;

  Future<void> _install(StarterRepertoire s) async {
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _installing = s.id);
    int id;
    try {
      id = await StarterService(ref.read(repertoireRepositoryProvider)).install(s, lang);
    } catch (e) {
      if (mounted) {
        setState(() => _installing = null);
        showSnack(context, context.l10n.somethingWentWrong);
      }
      return;
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    Navigator.pop(context);
    showSnack(context, context.l10n.starterInstalled(s.name(lang)));
    if (widget.learnNow) {
      // The first run: straight into the first lesson, then Today (D-070).
      router.go('/today');
      unawaited(
        router.push(
          '/train',
          extra: TrainingArgs(repertoireIds: [id], mode: TrainingMode.learn),
        ),
      );
    } else {
      router.go('/repertoires/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final list = ref.watch(starterListProvider);
    return Padding(
      padding: AppInsets.sheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...list.when(
            loading: () => [const LoadingView()],
            error: (e, _) => [
              ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(starterListProvider)),
            ],
            data: (items) => [
              for (final (i, s) in items.indexed) ...[
                if (i > 0) AppGap.v12,
                Card(
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.name(lang), style: context.tt.title),
                        AppGap.v8,
                        Text(s.description(lang)),
                        AppGap.v12,
                        FilledButton.tonal(
                          onPressed: _installing == null ? () => _install(s) : null,
                          child: _installing == s.id
                              ? Semantics(label: l.saving, child: const InlineSpinner())
                              : Text(l.install),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
