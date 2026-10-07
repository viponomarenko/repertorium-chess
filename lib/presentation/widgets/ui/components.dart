import 'package:dartchess/dartchess.dart' show PieceKind, Side;
import 'package:flutter/material.dart';

import '../../../core/haptics.dart';
import '../../../core/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../san_text.dart';
import 'basics.dart';
import 'menu.dart';
import 'motion.dart';

/// The body of a scrolling screen: the page margins, a readable width on
/// tablets and room under the last item.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.children,
    this.padding = AppInsets.page,
    this.maxWidth = AppSizes.maxContentWidth,
    this.controller,
  });
  final List<Widget> children;
  final EdgeInsets padding;
  final double maxWidth;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => MaxWidth(
    width: maxWidth,
    child: ListView(controller: controller, padding: padding, children: children),
  );
}

/// A card with an optional heading: the unit of a dashboard or a form.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    required this.child,
    this.padding = AppInsets.card,
  });
  final String? title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (leading != null) ...[leading!, AppGap.h8],
                  Expanded(
                    child: Semantics(header: true, child: Text(title!, style: theme.textTheme.titleLarge)),
                  ),
                  ?trailing,
                ],
              ),
              if (subtitle != null) ...[AppGap.v4, Text(subtitle!, style: context.tt.meta)],
              AppGap.v12,
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// What a message is about; picks the colours of [InfoStrip] and
/// [StatusLine].
enum Tone { neutral, success, warning, error }

extension on Tone {
  (Color bg, Color fg) container(ColorScheme cs) => switch (this) {
    Tone.neutral => (cs.surfaceContainerHigh, cs.onSurface),
    Tone.success => (cs.successContainer, cs.onSuccessContainer),
    Tone.warning => (cs.warningContainer, cs.onWarningContainer),
    Tone.error => (cs.errorContainer, cs.onErrorContainer),
  };

  Color accent(ColorScheme cs) => switch (this) {
    Tone.neutral => cs.onSurfaceVariant,
    Tone.success => cs.success,
    Tone.warning => cs.warning,
    Tone.error => cs.error,
  };
}

/// A tonal strip with a message: a note, a warning, an error, with an
/// optional action at the end.
class InfoStrip extends StatelessWidget {
  const InfoStrip({
    super.key,
    this.icon,
    this.title,
    required this.text,
    this.tone = Tone.neutral,
    this.action,
    this.square = false,
  });
  final IconData? icon;
  final String? title;
  final String text;
  final Tone tone;
  final Widget? action;

  /// Edge to edge under the board: no rounded corners.
  final bool square;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.container(Theme.of(context).colorScheme);
    final tt = context.tt;
    return Material(
      color: bg,
      shape: square ? const RoundedRectangleBorder() : AppRadius.mdShape,
      child: Padding(
        padding: AppInsets.strip,
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: AppSizes.iconMd, color: fg), AppGap.h12],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) Text(title!, style: tt.title.copyWith(color: fg)),
                  Text(text, style: tt.body.copyWith(color: fg)),
                ],
              ),
            ),
            if (action != null) ...[AppGap.h8, action!],
          ],
        ),
      ),
    );
  }
}

/// One line of status: a small icon and a few words.
class StatusLine extends StatelessWidget {
  const StatusLine({super.key, required this.icon, required this.text, this.tone = Tone.neutral, this.strong = false});
  final IconData icon;
  final String text;
  final Tone tone;

  /// A result rather than a remark: the text of a title, in the tone's colour.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final color = tone.accent(Theme.of(context).colorScheme);
    final tt = context.tt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: strong ? AppSizes.iconMd : AppSizes.iconSm, color: color),
        strong ? AppGap.h8 : AppGap.h4,
        Flexible(
          child: Text(
            text,
            style: strong ? tt.title.copyWith(color: color) : tt.meta.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The one way to wait for content: a spinner in the middle.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(AppSpacing.xxl), child: CircularProgressIndicator()),
  );
}

/// A small spinner inside a button or a row.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSizes.iconMd,
    child: CircularProgressIndicator(strokeWidth: AppSpacing.xxs, color: color),
  );
}

/// A round badge at the start of a list row: an icon or a couple of
/// characters on a quiet background.
class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.icon, this.text, this.tone = Tone.neutral, this.size = AppSizes.avatar})
    : assert(icon != null || text != null);
  final IconData? icon;
  final String? text;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = tone == Tone.neutral ? (cs.surfaceContainerHighest, cs.onSurface) : tone.container(cs);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: icon != null
          ? Icon(icon, size: AppSizes.iconMd, color: fg)
          : Text(text!, maxLines: 1, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg).tabular),
    );
  }
}

/// The side a repertoire or a game is played for: a king on its colour.
class SideBadge extends StatelessWidget {
  const SideBadge({super.key, required this.side, this.size = AppSizes.avatar});
  final Side side;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final white = side == Side.white;
    return Semantics(
      label: white ? l.white : l.black,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: white ? cs.sideWhite : cs.sideBlack,
          shape: BoxShape.circle,
          border: Border.all(color: cs.outline),
        ),
        alignment: Alignment.center,
        child: PieceIcon(white ? PieceKind.whiteKing : PieceKind.blackKing, size: size * 0.7),
      ),
    );
  }
}

/// A thin progress bar that glides to its value.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({super.key, required this.value, this.color, this.height = AppSizes.bar});

  /// 0…1.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return AnimatedFraction(
      value: value,
      builder: (_, v) => ClipRRect(
        borderRadius: AppRadius.full,
        child: LinearProgressIndicator(value: v, minHeight: height, color: color),
      ),
    );
  }
}

/// One part of a [ResultBar].
class ResultSegment {
  const ResultSegment(this.count, this.color, this.onColor);
  final int count;
  final Color color;
  final Color onColor;
}

/// Shares of a whole as one bar: wins, draws and losses. Thin by default;
/// [labelled] makes it tall enough to carry the percentages.
class ResultBar extends StatelessWidget {
  const ResultBar({super.key, required this.segments, required this.semanticLabel, this.labelled = false});
  final List<ResultSegment> segments;
  final String semanticLabel;
  final bool labelled;

  /// The user's own score: won, drawn, lost.
  factory ResultBar.score(
    BuildContext context, {
    Key? key,
    required int wins,
    required int draws,
    required int losses,
  }) {
    final cs = Theme.of(context).colorScheme;
    final n = wins + draws + losses;
    int pct(int x) => n == 0 ? 0 : (x * 100 / n).round();
    return ResultBar(
      key: key,
      semanticLabel: '+${pct(wins)}% =${pct(draws)}% −${pct(losses)}%',
      segments: [
        ResultSegment(wins, cs.win, cs.onPrimary),
        ResultSegment(draws, cs.draw, cs.onSurface),
        ResultSegment(losses, cs.loss, cs.onError),
      ],
    );
  }

  /// Results by side in a database: White wins, draws, Black wins.
  factory ResultBar.sides(
    BuildContext context, {
    Key? key,
    required int white,
    required int draws,
    required int black,
  }) {
    final cs = Theme.of(context).colorScheme;
    final n = white + draws + black;
    int pct(int x) => n == 0 ? 0 : (x * 100 / n).round();
    return ResultBar(
      key: key,
      labelled: true,
      semanticLabel: '${pct(white)}% / ${pct(draws)}% / ${pct(black)}%',
      segments: [
        ResultSegment(white, cs.sideWhite, cs.onSideWhite),
        ResultSegment(draws, cs.sideDraw, cs.onSideWhite),
        ResultSegment(black, cs.sideBlack, cs.onSideBlack),
      ],
    );
  }

  static const double labelledHeight = 18;

  @override
  Widget build(BuildContext context) {
    final height = labelled ? labelledHeight : AppSizes.bar;
    final total = segments.fold<int>(0, (s, e) => s + e.count);
    if (total == 0) return SizedBox(height: height);
    final label = Theme.of(context).textTheme.labelSmall?.tabular;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: labelled ? AppRadius.xsAll : AppRadius.full,
        child: SizedBox(
          height: height,
          // Stretch: an empty coloured box would otherwise be 0 high.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in segments)
                if (s.count > 0)
                  Expanded(
                    flex: s.count,
                    child: ColoredBox(
                      color: s.color,
                      child: labelled && s.count * 100 / total >= 14
                          ? Center(
                              child: Text(
                                '${(s.count * 100 / total).round()}%',
                                maxLines: 1,
                                softWrap: false,
                                style: label?.copyWith(color: s.onColor),
                              ),
                            )
                          : null,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A choice between two or three views shown as small pills, the selected
/// one inverted. 32 high on screen; each pill takes taps over 48.
class PillSwitch extends StatelessWidget {
  const PillSwitch({super.key, required this.labels, required this.selected, required this.onChanged});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  static const double pillHeight = 32;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = AppMotion.of(context);
    Widget pill(int i) {
      final on = selected == i;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!on) Haptics.selection();
            onChanged(i);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.tapTarget, minWidth: AppSizes.tapTarget),
            child: Center(
              widthFactor: 1,
              child: AnimatedContainer(
                duration: m.fast,
                curve: AppMotion.standard,
                constraints: const BoxConstraints(minHeight: pillHeight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm - 2),
                decoration: BoxDecoration(
                  color: on ? cs.primary : cs.primary.withValues(alpha: 0),
                  borderRadius: AppRadius.full,
                ),
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.control.copyWith(color: on ? cs.onPrimary : cs.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // On a narrow screen with a large text size the words are cut, not
    // scaled: the pills keep their 48 tap height.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (var i = 0; i < labels.length; i++) Flexible(child: pill(i))],
      ),
    );
  }
}

/// A filter shown as an outlined pill with its current value; a tap opens
/// the choices.
class FilterPill<T> extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.items, required this.onSelected});
  final String label;
  final List<(T, String)> items;
  final ValueChanged<T> onSelected;

  static const double maxLabelWidth = 200;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuButton<T>(
      constraints: appMenuConstraints,
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [for (final (v, t) in items) appMenuItem(value: v, label: t)],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: AppRadius.full,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.control),
                ),
                AppGap.h4,
                const Icon(AppIcons.expand, size: AppSizes.iconSm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tool with an icon and a word on one line, 48 high: the actions of a
/// position under the board, the secondary actions of a sheet.
class ToolButton extends StatelessWidget {
  const ToolButton({super.key, required this.icon, required this.label, required this.onTap, this.tooltip});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// The full name when the label is a short form of it.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = onTap == null ? cs.onSurface.withValues(alpha: AppOpacity.disabled) : cs.onSurface;
    final button = OutlinedButton(
      onPressed: onTap,
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size.fromHeight(AppSizes.controlMd)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
        shape: WidgetStatePropertyAll(AppRadius.mdShape),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: fg),
          AppGap.h8,
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.tt.control.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}

/// A row that leads somewhere: icon, name, a line of explanation, chevron.
class NavTile extends StatelessWidget {
  const NavTile({super.key, required this.icon, required this.title, this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
    onTap: onTap,
  );
}
