import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';

/// Pieces of a collection on a wide page (D-104): games grouped by event,
/// one row per game with its result, players, opening and length.

/// A PGN tag value that says something ("?" and "" say nothing).
String _clean(String s) => s.isEmpty || s == '?' ? '' : s;

/// Games in runs of the same event, in the order given.
List<(String event, List<GameRow> games)> groupByEvent(List<GameRow> games) {
  final out = <(String, List<GameRow>)>[];
  for (final g in games) {
    final e = _clean(g.event);
    if (out.isNotEmpty && out.last.$1 == e) {
      out.last.$2.add(g);
    } else {
      out.add((e, [g]));
    }
  }
  return out;
}

/// The date of a PGN game for people: "28 трав. 2024", a month or a year
/// when the rest is unknown, or nothing.
String gameDate(BuildContext context, String pgnDate) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  final p = pgnDate.split('.');
  final y = p.isNotEmpty ? int.tryParse(p[0]) : null;
  if (y == null) return '';
  final m = p.length > 1 ? int.tryParse(p[1]) : null;
  if (m == null || m < 1 || m > 12) return '$y';
  final d = p.length > 2 ? int.tryParse(p[2]) : null;
  if (d == null || d < 1 || d > 31) return _noYearMark(DateFormat.yMMM(tag).format(DateTime(y, m)));
  return _noYearMark(DateFormat.yMMMd(tag).format(DateTime(y, m, d)));
}

/// "2 лист. 1858" rather than "2 лист. 1858 р.": the column is narrow and
/// the year speaks for itself.
String _noYearMark(String s) => s.replaceFirst(RegExp(r'\s*р\.$'), '');

/// The month and year of an event, for its caption ("травень 2024").
String eventMonth(BuildContext context, List<GameRow> games) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  for (final g in games) {
    final p = g.date.split('.');
    final y = p.isNotEmpty ? int.tryParse(p[0]) : null;
    final m = p.length > 1 ? int.tryParse(p[1]) : null;
    if (y != null && m != null && m >= 1 && m <= 12) return DateFormat('LLLL y', tag).format(DateTime(y, m));
    if (y != null) return '$y';
  }
  return '';
}

/// One event: its caption and its games in a card.
class EventGroup extends StatelessWidget {
  const EventGroup({
    super.key,
    required this.event,
    required this.games,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
  });
  final String event;
  final List<GameRow> games;
  final bool selecting;
  final Set<int> selected;
  final void Function(GameRow) onOpen;
  final void Function(GameRow) onToggle;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final month = eventMonth(context, games);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.xl, AppSpacing.card, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    (event.isEmpty ? l.untitledGame : event).toUpperCase(),
                    style: context.tt.overline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              AppGap.h8,
              Text([if (month.isNotEmpty) month, l.gamesCount(games.length)].join(' · '), style: context.tt.meta),
            ],
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < games.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: AppSizes.hairline,
                    thickness: AppSizes.hairline,
                    indent: selecting ? _GameRow.checkIndent : AppSpacing.card,
                    color: cs.outlineVariant,
                  ),
                _GameRow(
                  game: games[i],
                  selecting: selecting,
                  selected: selected.contains(games[i].id),
                  onOpen: () => onOpen(games[i]),
                  onToggle: () => onToggle(games[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.game,
    required this.selecting,
    required this.selected,
    required this.onOpen,
    required this.onToggle,
  });
  final GameRow game;
  final bool selecting;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  /// Where the divider starts under a row with a checkbox.
  static const double checkIndent = 52;

  static const double _minHeight = 64;
  static const double _chipWidth = 44;
  static const double _chipHeight = 32;
  static const double _dot = 10;
  static const double _lengthWidth = 76;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final r = game.result;
    final whiteWon = r == '1-0';
    final blackWon = r == '0-1';
    Widget player(String name, {required bool white, required bool won, required bool lost}) {
      final style = won
          ? theme.textTheme.titleMedium
          : theme.textTheme.bodyMedium?.copyWith(color: lost ? cs.onSurfaceVariant : null);
      return Row(
        children: [
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(
              color: white ? cs.sideWhite : cs.sideBlack,
              shape: BoxShape.circle,
              border: white ? Border.all(color: cs.sideDraw) : null,
            ),
          ),
          AppGap.h8,
          Expanded(
            child: Text(_clean(name).isEmpty ? '?' : name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    }

    final (chipBg, chipFg, chipBorder) = switch (r) {
      '1-0' => (cs.sideWhite, cs.onSideWhite, cs.outline),
      '0-1' => (cs.sideBlack, cs.onSideBlack, null),
      '1/2-1/2' => (cs.secondaryContainer, cs.onSecondaryContainer, null),
      _ => (cs.surfaceContainerLow, cs.onSurfaceVariant, cs.outline),
    };
    final date = gameDate(context, game.date);
    return Material(
      color: selected ? cs.surface : Colors.transparent,
      child: InkWell(
        onTap: selecting ? onToggle : onOpen,
        onLongPress: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                if (selecting) ...[
                  SizedBox(
                    width: AppSizes.iconLg,
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onToggle(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  AppGap.h12,
                ],
                Container(
                  width: _chipWidth,
                  height: _chipHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: AppRadius.smAll,
                    border: chipBorder == null ? null : Border.all(color: chipBorder),
                  ),
                  child: Text(
                    r == '1/2-1/2' ? '½-½' : r,
                    style: theme.textTheme.labelMedium?.copyWith(color: chipFg).tabular,
                  ),
                ),
                AppGap.h12,
                Expanded(
                  flex: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      player(game.white, white: true, won: whiteWon, lost: blackWon),
                      AppGap.v2,
                      player(game.black, white: false, won: blackWon, lost: whiteWon),
                    ],
                  ),
                ),
                AppGap.h12,
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (game.eco.isNotEmpty) Text(game.eco, style: theme.textTheme.titleMedium?.tabular),
                      if (game.opening.isNotEmpty)
                        Text(game.opening, style: context.tt.meta, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                AppGap.h12,
                SizedBox(
                  width: _lengthWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // Whole moves, as players count them (not half-moves).
                        l.fullMovesCount((game.plyCount + 1) ~/ 2),
                        style: theme.textTheme.bodyMedium?.tabular,
                        maxLines: 1,
                      ),
                      if (date.isNotEmpty) Text(date, style: context.tt.meta, maxLines: 1, softWrap: false),
                    ],
                  ),
                ),
                AppGap.h8,
                SizedBox(
                  width: AppSizes.iconLg,
                  child: game.issuesJson.isNotEmpty
                      ? Tooltip(
                          message: l.gameHasErrors,
                          child: Icon(AppIcons.warning, color: cs.error, size: AppSizes.iconMd),
                        )
                      : const ListChevron(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The actions on the selected games, in a dark bar along the bottom
/// (D-104). It sits under the list, not over it (D-087).
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onSelectAll,
    required this.onToRepertoire,
    required this.onMove,
    required this.onExport,
    required this.onDelete,
  });
  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onToRepertoire;
  final VoidCallback onMove;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final on = cs.onInverseSurface;
    final any = count > 0;
    return Material(
      color: cs.inverseSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.selectedCount(count),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: on),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: on),
                onPressed: onSelectAll,
                icon: const Icon(AppIcons.selectAll, size: AppSizes.iconMd),
                label: Text(l.all),
              ),
              AppGap.h4,
              FilledButton.icon(
                style: AppButtonSize.compact.merge(
                  FilledButton.styleFrom(
                    backgroundColor: on,
                    foregroundColor: cs.inverseSurface,
                    disabledBackgroundColor: on.withValues(alpha: AppOpacity.disabled),
                  ),
                ),
                onPressed: any ? onToRepertoire : null,
                icon: const Icon(AppIcons.addToRepertoire, size: AppSizes.iconMd),
                label: Text(l.toRepertoireShort),
              ),
              AppGap.h4,
              IconButton(
                color: on,
                tooltip: l.moveTo,
                onPressed: any ? onMove : null,
                icon: const Icon(AppIcons.moveTo),
              ),
              IconButton(
                color: on,
                tooltip: l.exportPgn,
                onPressed: any ? onExport : null,
                icon: const Icon(AppIcons.share),
              ),
              IconButton(
                color: cs.errorOnInverse,
                tooltip: l.delete,
                onPressed: any ? onDelete : null,
                icon: const Icon(AppIcons.delete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
