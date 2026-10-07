import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import 'sheets.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actions = const []});

  final IconData icon;
  final String title;
  final String? message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSizes.iconHero, color: theme.colorScheme.onSurfaceVariant),
            AppGap.v16,
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              AppGap.v8,
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actions.isNotEmpty) ...[
              AppGap.v24,
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The main action of a list screen, in its app bar: a filled pill with an
/// icon and a word, easy to see and to hit (a bare "+" icon was neither).
class AppBarAction extends StatelessWidget {
  const AppBarAction({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs, right: AppSpacing.md),
      child: Tooltip(
        message: tooltip,
        child: FilledButton.icon(
          // 40 high to sit in the bar; the tap area is still 48.
          style: AppButtonSize.compact,
          onPressed: onPressed,
          icon: Icon(icon, size: AppSizes.iconMd),
          label: Text(label),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing, this.padding = AppInsets.sectionHeader});
  final String text;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              // Stoic-style caption: small, tracked, upper case, grey.
              child: Text(text.toUpperCase(), style: context.tt.overline),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel ?? l.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l.ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? label,
  int maxLines = 1,
  String? confirmLabel,
  TextInputType? keyboardType,

  /// Raw FEN/PGN input: monospace font, no autocorrect (T-06).
  bool mono = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _PromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      label: label,
      maxLines: maxLines,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      mono: mono,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    this.hint,
    this.label,
    required this.maxLines,
    this.confirmLabel,
    this.keyboardType,
    this.mono = false,
  });
  final bool mono;
  final String title;
  final String initial;
  final String? hint;
  final String? label;
  final int maxLines;
  final String? confirmLabel;
  final TextInputType? keyboardType;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLines: widget.maxLines,
        minLines: 1,
        keyboardType: widget.keyboardType ?? (widget.maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        style: widget.mono ? context.tt.mono : null,
        autocorrect: !widget.mono,
        enableSuggestions: !widget.mono,
        decoration: InputDecoration(hintText: widget.hint, labelText: widget.label),
        onSubmitted: widget.maxLines == 1 ? (v) => Navigator.pop(context, v) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _c.text), child: Text(widget.confirmLabel ?? l.save)),
      ],
    );
  }
}

void showSnack(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}

/// Modal progress with optional cancel. Returns a handle to update/close it.
class ProgressHandle {
  ProgressHandle._(this._progress, this._message, this._close);
  final ValueNotifier<double?> _progress;
  final ValueNotifier<String> _message;
  final void Function() _close;
  bool _closed = false;

  set progress(double? v) => _progress.value = v;
  set message(String v) => _message.value = v;

  void close() {
    if (_closed) return;
    _closed = true;
    _close();
  }
}

ProgressHandle showProgress(BuildContext context, String message, {VoidCallback? onCancel}) {
  final progress = ValueNotifier<double?>(null);
  final msg = ValueNotifier<String>(message);
  final nav = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder(valueListenable: msg, builder: (_, m, _) => Text(m)),
              AppGap.v16,
              ValueListenableBuilder(
                valueListenable: progress,
                builder: (_, p, _) => LinearProgressIndicator(value: p),
              ),
            ],
          ),
          actions: [
            if (onCancel != null)
              TextButton(
                onPressed: () {
                  onCancel();
                },
                child: Text(ctx.l10n.cancel),
              ),
          ],
        ),
      ),
    ).then((_) => open = false),
  );
  return ProgressHandle._(progress, msg, () {
    if (open) nav.pop();
  });
}

/// Responsive helper: wide layouts (tablets, landscape).
bool isWide(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= 700 || (size.width > size.height && size.width >= 560);
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.icon});
  final String value;
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppSizes.iconMd, color: color ?? theme.colorScheme.onSurface),
                AppGap.h4,
              ],
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color).tabular),
            ],
          ),
          Text(label, style: context.tt.meta),
        ],
      ),
    );
  }
}

/// Human error state with a retry action (instead of raw exceptions).
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, this.onRetry, this.details});
  final String? message;
  final VoidCallback? onRetry;

  /// Technical details, shown small (optional).
  final Object? details;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EmptyState(
      icon: AppIcons.error,
      title: message ?? l.somethingWentWrong,
      message: details == null ? null : '$details',
      actions: [if (onRetry != null) FilledButton.tonal(onPressed: onRetry, child: Text(l.retry))],
    );
  }
}

/// A primary action area pinned to the bottom of forms and wizards, so the
/// main button is always visible (consistent placement).
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.children, this.top});
  final List<Widget> children;

  /// Optional summary line above the buttons.
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.actionBar,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (top != null) ...[top!, AppGap.v8],
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Limits the width of content on tablets.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.width = AppSizes.maxContentWidth});
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

/// One option of [ChoiceSegments].
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final Widget? icon;
}

/// Single choice among a few options. A segmented button while every label
/// fits on one line; without the check mark if only that helps; otherwise
/// (long translations, large system text) wrapping chips, so a word is
/// never broken inside a segment (T-20, T-21).
class ChoiceSegments<T> extends StatelessWidget {
  const ChoiceSegments({super.key, required this.options, required this.selected, required this.onChanged});
  final List<ChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  // Material 3 segment metrics: 12 + 12 padding, 1 px borders, 18 px icon
  // with an 8 px gap; a few pixels of slack for rounding.
  static const _padding = 24.0 + 2 + 4;
  static const _iconSpace = 18.0 + 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double width(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    // Natural width: every segment as wide as the widest label with a check
    // mark. Reported as the intrinsic size, because dialogs (AlertDialog uses
    // IntrinsicWidth) ask for it and LayoutBuilder cannot answer.
    final widest = options.fold<double>(0, (m, o) => math.max(m, width(o.label)));
    final natural = options.length * (widest + _padding + _iconSpace);
    final height = scaler.scale(AppSizes.controlMd);
    return _FixedIntrinsics(
      width: natural,
      height: height,
      child: LayoutBuilder(
        builder: (context, cons) {
          final segment = cons.maxWidth / options.length;
          bool fits({required bool check}) =>
              options.every((o) => width(o.label) + _padding + (check || o.icon != null ? _iconSpace : 0) <= segment);
          final withCheck = fits(check: true);
          if (withCheck || fits(check: false)) {
            return SegmentedButton<T>(
              showSelectedIcon: withCheck,
              segments: [
                for (final o in options)
                  ButtonSegment(value: o.value, icon: o.icon, label: Text(o.label, maxLines: 1, softWrap: false)),
              ],
              selected: {selected},
              onSelectionChanged: (s) => onChanged(s.first),
            );
          }
          return Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final o in options)
                ChoiceChip(
                  avatar: o.icon,
                  label: Text(o.label),
                  selected: o.value == selected,
                  onSelected: (_) => onChanged(o.value),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Answers intrinsic-size queries with fixed values instead of asking the
/// child (for children such as LayoutBuilder that cannot compute them).
class _FixedIntrinsics extends SingleChildRenderObjectWidget {
  const _FixedIntrinsics({required this.width, required this.height, super.child});
  final double width;
  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFixedIntrinsics(width, height);

  @override
  void updateRenderObject(BuildContext context, _RenderFixedIntrinsics renderObject) {
    renderObject
      ..fixedWidth = width
      ..fixedHeight = height;
  }
}

class _RenderFixedIntrinsics extends RenderProxyBox {
  _RenderFixedIntrinsics(this._width, this._height);
  double _width;
  double _height;

  set fixedWidth(double v) {
    if (v == _width) return;
    _width = v;
    markNeedsLayout();
  }

  set fixedHeight(double v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _width;
  @override
  double computeMaxIntrinsicWidth(double height) => _width;
  @override
  double computeMinIntrinsicHeight(double width) => _height;
  @override
  double computeMaxIntrinsicHeight(double width) => _height;
}

/// iOS-style inset group: a white rounded card with thin separators.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(indent: AppSpacing.card, endIndent: 0));
      items.add(children[i]);
    }
    return Padding(
      padding: AppInsets.pageH,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
      ),
    );
  }
}

/// Wraps the rows between [SectionHeader]s into [SettingsGroup] cards
/// (spacers stay outside), so a long settings list reads as groups.
List<Widget> groupIntoCards(List<Widget> children) {
  final out = <Widget>[];
  var run = <Widget>[];
  void flush() {
    if (run.isEmpty) return;
    out.add(SettingsGroup(children: run));
    run = [];
  }

  for (final w in children) {
    if (w is SectionHeader) {
      flush();
      out.add(w);
    } else if (w is SizedBox) {
      flush();
      out.add(w);
    } else {
      run.add(w);
    }
  }
  flush();
  return out;
}

/// A setting with a few choices, made for fingers: the row shows the name
/// and the current value (wrapping, never overflowing), a tap opens a
/// sheet with big rows. Replaces a trailing dropdown, which overflows on
/// narrow screens and with large text.
class ChoiceTile<T> extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
    this.leading,
    this.hint,
  });
  final String title;
  final T value;
  final List<ChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final Widget? leading;

  /// Extra explanation under the value.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = options.where((o) => o.value == value).map((o) => o.label).firstOrNull ?? '$value';
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: Text(
        hint == null ? current : '$current\n$hint',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
      onTap: () async {
        final picked = await showModalBottomSheet<ChoiceOption<T>>(
          context: context,
          useRootNavigator: true,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetHeader(title),
                  for (final o in options)
                    ListTile(
                      minTileHeight: AppSizes.controlLg,
                      leading: o.icon,
                      title: Text(o.label),
                      trailing: o.value == value ? const Icon(AppIcons.check) : null,
                      selected: o.value == value,
                      onTap: () => Navigator.pop(ctx, o),
                    ),
                  AppGap.v8,
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked.value);
      },
    );
  }
}

/// A big bottom-bar button (≥ 56 dp) with an icon and a label; when
/// selected it becomes a black rounded square (white in dark mode). Used by
/// the main navigation and the analysis tool bar (D-035).
class BarButton extends StatelessWidget {
  const BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectedIcon,
    this.badge,
  });
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = onTap == null
        ? cs.onSurfaceVariant.withValues(alpha: AppOpacity.muted)
        : (selected ? cs.onPrimary : cs.onSurface);
    Widget iconW = Icon(selected ? (selectedIcon ?? icon) : icon, size: AppSizes.iconLg, color: fg);
    if (badge != null) iconW = Badge(label: badge, child: iconW);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs, vertical: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        // The selection fills in smoothly; the ink stays inside its shape.
        child: AnimatedContainer(
          duration: AppMotion.of(context).base,
          curve: AppMotion.standard,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.primary.withValues(alpha: 0),
            borderRadius: AppRadius.mdAll,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.barButton),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconW,
                    AppGap.v2,
                    // A long label at a large text size shrinks to fit and
                    // keeps a margin inside the selection shape.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar within thumb reach holding [BarButton]s (already wrapped in
/// Expanded by the caller).
class ThumbBar extends StatelessWidget {
  const ThumbBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        child: Row(children: children),
      ),
    ),
  );
}

/// [ExpansionTile] with the app's chevron (Bootstrap), turning when open.
class AppExpansionTile extends StatefulWidget {
  const AppExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.initiallyExpanded = false,
    this.tilePadding,
    this.children = const [],
  });
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final bool initiallyExpanded;
  final EdgeInsetsGeometry? tilePadding;
  final List<Widget> children;

  @override
  State<AppExpansionTile> createState() => _AppExpansionTileState();
}

class _AppExpansionTileState extends State<AppExpansionTile> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: widget.title,
    subtitle: widget.subtitle,
    leading: widget.leading,
    initiallyExpanded: widget.initiallyExpanded,
    tilePadding: widget.tilePadding,
    onExpansionChanged: (v) => setState(() => _open = v),
    trailing: AnimatedRotation(
      turns: _open ? 0.5 : 0,
      duration: AppMotion.of(context).base,
      curve: AppMotion.standard,
      child: const Icon(AppIcons.expand, size: AppSizes.iconMd),
    ),
    children: widget.children,
  );
}
