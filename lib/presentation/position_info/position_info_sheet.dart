import 'dart:async';

import 'package:dartchess/dartchess.dart' hide PgnComment;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n.dart';
import '../../data/engine/engine_service.dart';
import '../../data/repositories/repertoire_repository.dart';
import '../../domain/chess/chess_utils.dart';
import '../../domain/openings/position_text_book.dart';
import '../../domain/position_info/engine_words.dart';
import '../../domain/position_info/pawn_features.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/comment_editor.dart';
import '../widgets/engine_panel.dart';
import '../widgets/san_text.dart';
import '../widgets/ui/ui.dart';

/// What "About this position" is opened for.
class PositionInfoArgs {
  const PositionInfoArgs({required this.fen, required this.lineKeys, this.engineAllowed = true, this.liveEval});

  final String fen;

  /// Position keys from the start of the line to this position (the last
  /// one is this position): the opening is the deepest named one.
  final List<PositionKey> lineKeys;

  /// False hides the engine block (training without the engine).
  final bool engineAllowed;

  /// An evaluation the screen already has for [fen] (its engine panel).
  final EngineEval? liveEval;
}

/// The least depth of a screen's own evaluation that the panel keeps
/// instead of asking the engine again.
const int kLiveEvalDepth = 16;

/// "About this position" (D-105): the user's comment from their
/// repertoires, the opening, and the engine in words. Empty blocks are not
/// shown.
Future<void> showPositionInfo(BuildContext context, PositionInfoArgs args) {
  return showAppSheet<void>(
    context,
    title: context.l10n.aboutPosition,
    builder: (_) => PositionInfoView(args: args),
  );
}

class PositionInfoView extends ConsumerStatefulWidget {
  const PositionInfoView({super.key, required this.args});
  final PositionInfoArgs args;

  @override
  ConsumerState<PositionInfoView> createState() => _PositionInfoViewState();
}

class _PositionInfoViewState extends ConsumerState<PositionInfoView> {
  late final PositionKey _key = keyFromFen(widget.args.fen);
  late final Position? _pos = tryPositionFromFen(widget.args.fen);
  late final EngineService _engine = ref.read(engineServiceProvider);
  late final RepertoireRepository _repo = ref.read(repertoireRepositoryProvider);

  List<PositionCommentRef>? _comments;
  EngineEval? _eval;
  EngineEval? _threat;
  String? _threatFen;
  bool _running = false;
  bool _engineFailed = false;

  bool get _engineShown => widget.args.engineAllowed && _pos != null && !_pos.isGameOver;

  @override
  void initState() {
    super.initState();
    unawaited(_loadComments());
    final live = widget.args.liveEval;
    if (_engineShown && live != null && live.fen == widget.args.fen && live.lines.isNotEmpty) {
      // The screen's engine was on: show its evaluation at once and finish
      // what it lacks (more lines, depth, the threat) without a tap.
      _eval = live;
      final enough = live.lines.length >= 2 && live.depth >= kLiveEvalDepth;
      unawaited(_analyze(threatOnly: enough));
    }
  }

  @override
  void dispose() {
    if (_running) unawaited(_engine.stop());
    super.dispose();
  }

  Future<void> _loadComments() async {
    final c = await _repo.positionComments(_key);
    if (mounted) setState(() => _comments = c);
  }

  Future<void> _edit(PositionCommentRef r) async {
    final l = context.l10n;
    final t = await showCommentEditor(
      context,
      title: l.positionComment,
      initial: r.comment,
      fen: widget.args.fen,
      subtitle: r.repertoireName,
    );
    if (t == null || !mounted) return;
    await _repo.setPositionComment(r.repertoireId, _key, t.trim());
    await _loadComments();
  }

  Future<void> _analyze({bool threatOnly = false}) async {
    setState(() {
      _running = true;
      _engineFailed = false;
    });
    try {
      if (!threatOnly) {
        final e = await _mainEval();
        if (!mounted) return;
        // A deeper evaluation stays unless the new one brings more lines.
        final old = _eval;
        if (e != null && (old == null || e.lines.length > old.lines.length || e.depth >= old.depth)) {
          setState(() => _eval = e);
        }
      }
      final tf = threatFen(widget.args.fen);
      if (tf != null) {
        final t = await _engine.evaluate(tf, depth: 12);
        if (!mounted) return;
        setState(() {
          _threat = t;
          _threatFen = tf;
        });
      }
    } on EngineCancelled {
      // Closing the sheet or the app going to the background.
    } catch (_) {
      if (mounted) setState(() => _engineFailed = true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Three lines for the position: from the Lichess cloud first when the
  /// user prefers it (deeper, no battery), else from the device.
  Future<EngineEval?> _mainEval() async {
    final fen = widget.args.fen;
    if (ref.read(settingsProvider).engineCloudFirst) {
      try {
        final c = await ref.read(lichessClientProvider).cloudEval(fen, multiPv: 3);
        if (c != null && c.lines.isNotEmpty) {
          return EngineEval(
            fen: fen,
            depth: c.depth,
            done: true,
            lines: [for (final (i, x) in c.lines.indexed) PvLine(multipv: i + 1, moves: x.moves, cp: x.cp, mate: x.mate)],
          );
        }
      } catch (_) {
        // Offline or no cloud answer: the device engine.
      }
    }
    if (!mounted) return null;
    return _engine.evaluate(fen, depth: 16, multiPv: 3);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final book = ref.watch(openingBookProvider).value;
    final opening = book?.deepest(widget.args.lineKeys);
    final text = ref.watch(positionTextsProvider).value?.deepest(widget.args.lineKeys);
    final structureBlock = _structureBlock(context);
    final comments = _comments;
    final blocks = <Widget>[
      if (comments != null && comments.isNotEmpty) _commentBlock(context, comments),
      if (opening != null || text != null)
        _Block(
          title: l.aboutOpening,
          children: [
            if (opening != null) Text('${opening.eco} ${opening.name}', style: Theme.of(context).textTheme.bodyLarge),
            if (text != null) ...[
              if (opening != null) AppGap.v8,
              _OpeningText(text: text, current: text.key == _key),
            ],
          ],
        ),
      ?structureBlock,
    ];
    final knownNothing = comments != null && blocks.isEmpty;
    return Padding(
      padding: AppInsets.sheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (knownNothing) Text(l.aboutEmptyHint, style: context.tt.comment),
          ...blocks,
          if (_engineShown) _engineBlock(context),
        ],
      ),
    );
  }

  /// The pawn structure and the small features (D-107); null when the
  /// position has neither. Structures whose texts nobody has read yet are
  /// shown only in debug builds.
  Widget? _structureBlock(BuildContext context) {
    final pos = _pos;
    if (pos == null) return null;
    final l = context.l10n;
    final theme = Theme.of(context);
    final catalog = ref.watch(structuresProvider).value;
    final match = catalog?.detect(pos.board, include: (s) => s.reviewed || kDebugMode);
    final features = pawnFeatures(pos.board);
    if (match == null && features.isEmpty) return null;
    final lang = Localizations.localeOf(context).languageCode;
    return _Block(
      title: l.aboutStructure,
      children: [
        if (match != null) ...[
          Text(
            match.side == Side.white
                ? l.structureWhite(match.structure.name.of(lang))
                : l.structureBlack(match.structure.name.of(lang)),
            style: theme.textTheme.titleMedium,
          ),
          AppGap.v4,
          MovesText(match.structure.text.of(lang), style: theme.textTheme.bodyLarge),
          AppGap.v4,
          Text(match.structure.reviewed ? l.structureSource : l.structureNotReviewed, style: context.tt.meta),
          if (features.isNotEmpty) AppGap.v8,
        ],
        for (final f in features)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: MovesText('• ${_feature(l, f)}', style: theme.textTheme.bodyLarge),
          ),
      ],
    );
  }

  String _feature(AppLocalizations l, PawnFeature f) {
    final white = f.side == Side.white;
    final squares = f.squares.map((s) => s.name).join(', ');
    final n = f.squares.length;
    return switch (f.kind) {
      PawnFeatureKind.passed => white ? l.featPassedWhite(n, squares) : l.featPassedBlack(n, squares),
      PawnFeatureKind.isolated => white ? l.featIsolatedWhite(n, squares) : l.featIsolatedBlack(n, squares),
      PawnFeatureKind.backward => white ? l.featBackwardWhite(n, squares) : l.featBackwardBlack(n, squares),
      PawnFeatureKind.doubled => white ? l.featDoubledWhite(squares) : l.featDoubledBlack(squares),
      PawnFeatureKind.openFile => l.featOpenFile(f.file!.name),
      PawnFeatureKind.halfOpenFile => white ? l.featHalfOpenWhite(f.file!.name) : l.featHalfOpenBlack(f.file!.name),
      PawnFeatureKind.oppositeCastling => l.featOppositeCastling,
      PawnFeatureKind.weakShelter => white ? l.featWeakShelterWhite : l.featWeakShelterBlack,
    };
  }

  Widget _commentBlock(BuildContext context, List<PositionCommentRef> refs) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final named = refs.length > 1;
    return _Block(
      title: l.aboutMyComment,
      children: [
        for (final r in refs)
          InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => _edit(r),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (named) Text(l.aboutInRepertoire(r.repertoireName), style: context.tt.meta),
                          r.comment.isEmpty
                              ? Text(l.addPositionComment, style: context.tt.comment)
                              : MovesText(r.comment, style: theme.textTheme.bodyLarge),
                        ],
                      ),
                    ),
                    AppGap.h8,
                    Icon(AppIcons.comment, size: AppSizes.iconSm, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _engineBlock(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final eval = _eval;
    if (eval == null) {
      return _Block(
        title: l.aboutEngine,
        children: [
          if (_engineFailed) ...[Text(l.engineError, style: context.tt.comment), AppGap.v8],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: _running ? null : _analyze,
              icon: _running ? const InlineSpinner() : const Icon(AppIcons.engine),
              label: Text(l.aboutAnalyze),
            ),
          ),
        ],
      );
    }
    final fen = widget.args.fen;
    final lines = [
      for (final p in eval.lines) ScoredLine(moves: p.moves, cp: p.cp, mate: p.mate),
    ];
    final threatBest = _threat?.best;
    final x = explain(
      fen,
      lines,
      threatPositionFen: _threatFen,
      threatBest: threatBest == null ? null : ScoredLine(moves: threatBest.moves, cp: threatBest.cp, mate: threatBest.mate),
    );
    if (x == null) return const SizedBox.shrink();
    final facts = <String>[
      if (x.bestSan != null) _bestMove(l, x),
      if (x.onlyMove) l.onlyMoveHere,
      if (x.threat != null)
        x.threat!.mateIn != null ? l.threatMate(x.threat!.san, x.threat!.mateIn!) : l.threatIs(x.threat!.san),
    ];
    return _Block(
      title: l.aboutEngine,
      children: [
        Text(_verdict(l, x.verdict), style: theme.textTheme.titleMedium),
        AppGap.v4,
        for (final f in facts)
          Padding(padding: const EdgeInsets.only(top: AppSpacing.xxs), child: MovesText(f, style: theme.textTheme.bodyLarge)),
        if (_running) ...[AppGap.v8, const Align(alignment: AlignmentDirectional.centerStart, child: InlineSpinner())],
        AppGap.v8,
        for (final p in eval.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSizes.evalColumn,
                  child: Text(formatScore(context, p), style: theme.textTheme.titleSmall?.tabular),
                ),
                Expanded(child: MovesText(uciLineToSan(fen, p.moves, max: 8).join(' '), style: context.tt.meta)),
              ],
            ),
          ),
        AppGap.v4,
        Text(l.engineDepth(eval.depth), style: context.tt.meta),
      ],
    );
  }

  String _bestMove(AppLocalizations l, EngineExplanation x) {
    final kind = switch (x.bestKind) {
      MoveKind.mate => l.kindMate,
      MoveKind.promotion => l.kindPromotion,
      MoveKind.winsMaterial => l.kindWinsMaterial,
      MoveKind.castling => l.kindCastling,
      MoveKind.check => l.kindCheck,
      MoveKind.capture => l.kindCapture,
      MoveKind.quiet || null => null,
    };
    final move = l.bestMoveIs(x.bestSan!);
    return kind == null ? move : '$move · $kind';
  }

  String _verdict(AppLocalizations l, EvalVerdict v) {
    final white = v.side == Side.white;
    if (v.mateIn != null) return white ? l.verdictMateWhite(v.mateIn!) : l.verdictMateBlack(v.mateIn!);
    return switch (v.advantage) {
      Advantage.equal => l.verdictEqual,
      Advantage.slight => white ? l.verdictSlightWhite : l.verdictSlightBlack,
      Advantage.clear => white ? l.verdictClearWhite : l.verdictClearBlack,
      Advantage.decisive => white ? l.verdictDecisiveWhite : l.verdictDecisiveBlack,
    };
  }
}

/// A Wikibooks text (D-106): the translation in Ukrainian (the original a
/// tap away), folded when long, with its source and licence under it and,
/// when it is about an earlier position of the line, which one.
class _OpeningText extends StatefulWidget {
  const _OpeningText({required this.text, required this.current});
  final PositionText text;

  /// The text is about this very position, not an earlier one.
  final bool current;

  @override
  State<_OpeningText> createState() => _OpeningTextState();
}

class _OpeningTextState extends State<_OpeningText> {
  /// Lines shown before "Read more".
  static const int _folded = 8;

  bool _original = false;
  bool _expanded = false;

  /// The text of an earlier position, opened from its link row.
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final t = widget.text;
    final ukrainian = Localizations.localeOf(context).languageCode == 'uk';
    final translated = ukrainian && t.uk != null;
    final showUk = translated && !_original;
    final body = showUk ? t.uk! : t.en;
    final source = showUk
        ? (t.reviewed ? l.wikibooksReviewed : l.wikibooksMachine)
        : (ukrainian ? l.wikibooksOriginal : 'Wikibooks · CC BY-SA 4.0');
    final style = theme.textTheme.bodyLarge;
    final long = body.length > 600;
    // An explanation belongs to its position only (D-113): for an earlier
    // position of the line the panel says which one and opens it on a tap.
    final link = widget.current
        ? null
        : InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => setState(() => _opened = !_opened),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
              child: Row(
                children: [
                  Icon(AppIcons.openings, size: AppSizes.iconSm, color: theme.colorScheme.onSurfaceVariant),
                  AppGap.h8,
                  Expanded(child: MovesText(l.textForPositionAfter(t.lastMove), style: context.tt.meta)),
                  Icon(_opened ? AppIcons.collapse : AppIcons.expand, size: AppSizes.iconSm),
                ],
              ),
            ),
          );
    if (link != null && !_opened) return link;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?link,
        MovesText(
          body,
          style: style,
          maxLines: long && !_expanded ? _folded : null,
          overflow: long && !_expanded ? TextOverflow.ellipsis : null,
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            if (long)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? l.textReadLess : l.textReadMore),
              ),
            if (translated)
              TextButton(
                onPressed: () => setState(() => _original = !_original),
                child: Text(_original ? l.textShowTranslation : l.textShowOriginal),
              ),
          ],
        ),
        InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: () => launchUrl(t.url, mode: LaunchMode.externalApplication),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
            child: Row(
              children: [
                Expanded(child: Text(source, style: context.tt.meta)),
                Icon(AppIcons.externalLink, size: AppSizes.iconSm, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One block of the panel: a small caption and its content.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(title, padding: AppInsets.blockHeader),
        ...children,
      ],
    );
  }
}
