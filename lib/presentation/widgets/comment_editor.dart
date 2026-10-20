import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../domain/chess/chess_utils.dart';
import '../theme/app_icons.dart';
import 'board_view.dart';
import 'notation_view.dart';
import 'san_text.dart';
import 'ui/ui.dart';

/// The signs a commentator types most, as NAG codes, in one row a phone
/// can hold: move marks, then White better and Black better.
const _main = [1, 2, 5, 6, 16, 17];

/// The full set (Informator / PGN), in three groups: the move, the
/// position, ideas and circumstances.
const _moveSigns = [3, 1, 5, 6, 2, 4, 7];
const _positionSigns = [18, 16, 14, 10, 15, 17, 19, 13];
const _ideaSigns = [36, 40, 132, 32, 44, 140, 22, 138, 146];

/// Move marks (!, ?, !?, ?!, □) and the novelty sign follow the move with
/// no space; the rest are words of their own.
bool _sticks(int nag) => nag <= 7 || nag == 146;

/// "2. Nf3" / "2... Nc6" for [san] played in [fenBefore].
String? numberedSan(String fenBefore, String san) {
  final p = tryPositionFromFen(fenBefore);
  if (p == null) return null;
  return p.turn == Side.white ? '${p.fullmoves}. $san' : '${p.fullmoves}... $san';
}

/// Edits a comment (D-110): a sheet with the position in miniature, where
/// it is ("After 2. Nf3", the opening), a roomy text field and a row of
/// chess signs to insert. Returns the new text (empty to delete), or null
/// when cancelled.
Future<String?> showCommentEditor(
  BuildContext context, {
  required String title,
  String initial = '',
  String? fen,
  Side orientation = Side.white,
  String? subtitle,
}) {
  return showAppModal<String>(
    context,
    builder: (_) =>
        CommentEditor(title: title, initial: initial, fen: fen, orientation: orientation, subtitle: subtitle),
  );
}

class CommentEditor extends StatefulWidget {
  const CommentEditor({
    super.key,
    required this.title,
    this.initial = '',
    this.fen,
    this.orientation = Side.white,
    this.subtitle,
  });

  final String title;
  final String initial;
  final String? fen;
  final Side orientation;
  final String? subtitle;

  @override
  State<CommentEditor> createState() => _CommentEditorState();
}

class _CommentEditorState extends State<CommentEditor> {
  late final _text = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  /// The full set of signs is open.
  bool _allSigns = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Puts [nag]'s sign at the cursor: a move mark right after the move, an
  /// evaluation as a word of its own.
  void _insert(int nag) {
    final sign = nagSymbol(nag);
    final v = _text.value;
    final at = v.selection.isValid ? v.selection.start : v.text.length;
    final end = v.selection.isValid ? v.selection.end : v.text.length;
    final before = v.text.substring(0, at);
    final after = v.text.substring(end);
    final lead = _sticks(nag) || before.isEmpty || before.endsWith(' ') ? '' : ' ';
    final trail = _sticks(nag) || after.startsWith(' ') ? '' : ' ';
    final inserted = '$lead$sign$trail';
    _text.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: at + inserted.length),
    );
    _focus.requestFocus();
  }

  /// A small key for [nag]'s sign inside a finger-sized target.
  Widget _key(BuildContext context, int nag) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Tooltip(
      message: nagName(nag, context.l10n),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _insert(nag),
        child: SizedBox(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          child: Center(
            child: Container(
              width: AppSizes.symbolKey,
              height: AppSizes.symbolKey,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: AppRadius.smAll),
              child: FittedBox(
                child: Text(nagSymbol(nag), style: theme.textTheme.titleMedium?.copyWith(color: cs.onSurface)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Opens or closes the full set.
  Widget _toggle(BuildContext context) {
    final l = context.l10n;
    return IconButton(
      tooltip: _allSigns ? l.signsLess : l.signsMore,
      onPressed: () => setState(() => _allSigns = !_allSigns),
      icon: Icon(_allSigns ? AppIcons.collapse : AppIcons.more),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fen = widget.fen;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppInsets.sheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // The chess hint: the position the comment is about.
                  if (fen != null) ...[
                    ExcludeSemantics(
                      child: MiniBoard(fen: fen, orientation: widget.orientation, size: AppSizes.commentBoard),
                    ),
                    AppGap.h16,
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.comment, size: AppSizes.iconMd, color: cs.onSurface),
                            AppGap.h8,
                            Expanded(
                              child: Semantics(
                                header: true,
                                child: Text(widget.title, style: theme.textTheme.titleLarge),
                              ),
                            ),
                          ],
                        ),
                        if (widget.subtitle != null) ...[
                          AppGap.v4,
                          MovesText(widget.subtitle!, style: context.tt.meta, maxLines: 2),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              AppGap.v16,
              TextField(
                controller: _text,
                focusNode: _focus,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: context.tt.comment.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: l.commentHint,
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  contentPadding: AppInsets.card,
                  border: const OutlineInputBorder(borderRadius: AppRadius.mdAll, borderSide: BorderSide.none),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide(color: cs.onSurface, width: AppSizes.hairline),
                  ),
                ),
              ),
              AppGap.v8,
              // Signs a commentator needs, a tap away from the keyboard: the
              // usual ones in a row, all of them one tap further.
              if (_allSigns) ...[
                for (final (caption, signs) in [
                  (l.signsMove, _moveSigns),
                  (l.signsPosition, _positionSigns),
                  (l.signsIdeas, _ideaSigns),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(caption.toUpperCase(), style: context.tt.overline),
                  ),
                  Wrap(
                    children: [
                      for (final nag in signs) _key(context, nag),
                      // Closing sits after the last sign, not on a row of
                      // its own.
                      if (signs == _ideaSigns) _toggle(context),
                    ],
                  ),
                ],
              ] else
                Wrap(children: [for (final nag in _main) _key(context, nag), _toggle(context)]),
              AppGap.v16,
              Row(
                children: [
                  // Deleting is rare: a quiet icon, not a third word.
                  if (widget.initial.isNotEmpty)
                    IconButton(
                      tooltip: l.delete,
                      onPressed: () => Navigator.of(context).pop(''),
                      icon: const Icon(AppIcons.delete),
                    ),
                  Expanded(
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: AppSpacing.sm,
                      overflowSpacing: AppSpacing.sm,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
                          child: Text(l.save),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
