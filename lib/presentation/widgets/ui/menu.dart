import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import 'sheets.dart';

/// One menu of the app (D-081, D-112, D-114): a sheet from the bottom (a
/// card on a tablet) on the page grey, with a title saying what it is
/// about, the most used actions as a row of tiles, the rest in white
/// rounded groups of finger-sized rows, a destructive action in a group of
/// its own. Every "more" button and every long-press menu is built from
/// these entries.
sealed class AppMenuEntry<T> {
  const AppMenuEntry();
}

/// An action of a menu: an icon, a few words.
class AppMenuAction<T> extends AppMenuEntry<T> {
  const AppMenuAction({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
    this.selected = false,
    this.tile = false,
  });

  final T value;
  final String label;
  final IconData? icon;

  /// A second line: what the action does or why it is off now.
  final String? subtitle;
  final bool enabled;

  /// Deletes or discards something: shown in the error colour.
  final bool destructive;

  /// The current choice of a list of options: marked with a check.
  final bool selected;

  /// One of the few most used actions: a tile in a row at the top
  /// (icon over the label) instead of a row of a group.
  final bool tile;
}

/// Where one group ends and the next begins, optionally with a caption.
class AppMenuBreak<T> extends AppMenuEntry<T> {
  const AppMenuBreak([this.caption]);
  final String? caption;
}

AppMenuAction<T> appMenuItem<T>({
  required T value,
  required String label,
  IconData? icon,
  String? subtitle,
  bool enabled = true,
  bool destructive = false,
  bool selected = false,
}) => AppMenuAction<T>(
  value: value,
  label: label,
  icon: icon,
  subtitle: subtitle,
  enabled: enabled,
  destructive: destructive,
  selected: selected,
);

/// A quick action shown as a tile; the tiles given one after another form
/// one row (best two to four).
AppMenuAction<T> appMenuTile<T>({required T value, required String label, required IconData icon, bool enabled = true}) =>
    AppMenuAction<T>(value: value, label: label, icon: icon, enabled: enabled, tile: true);

/// Starts a new group, with a small caption above it when given.
AppMenuBreak<T> appMenuDivider<T>([String? caption]) => AppMenuBreak<T>(caption);

/// Opens the menu sheet and returns the chosen value (null when closed).
/// [at] - where a long press was - is kept for callers; the sheet always
/// comes up from the bottom, within reach of the thumb.
Future<T?> showAppMenu<T>(
  BuildContext context, {
  Offset? at,
  String? title,
  String? subtitle,
  required List<AppMenuEntry<T>> items,
}) {
  return showAppModal<T>(
    context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (ctx) => AppMenuSheet<T>(title: title, subtitle: subtitle, items: items),
  );
}

/// The sheet of a menu (see [showAppMenu]).
class AppMenuSheet<T> extends StatelessWidget {
  const AppMenuSheet({super.key, this.title, this.subtitle, required this.items});

  final String? title;
  final String? subtitle;
  final List<AppMenuEntry<T>> items;

  /// The actions split at the breaks and where tiles end, empty groups
  /// left out.
  List<(String?, List<AppMenuAction<T>>)> _groups() {
    final out = <(String?, List<AppMenuAction<T>>)>[];
    String? caption;
    var run = <AppMenuAction<T>>[];
    void flush() {
      if (run.isNotEmpty) out.add((caption, run));
      run = [];
      caption = null;
    }

    for (final e in items) {
      switch (e) {
        case AppMenuBreak(caption: final c):
          flush();
          caption = c;
        case AppMenuAction():
          if (run.isNotEmpty && run.last.tile != e.tile) flush();
          run.add(e);
      }
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              // In line with the text of the rows below.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title!, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (subtitle != null) ...[AppGap.v2, Text(subtitle!, style: context.tt.meta)],
                  ],
                ),
              ),
              AppGap.v16,
            ],
            for (final (i, (caption, actions)) in _groups().indexed) ...[
              if (i > 0) AppGap.v12,
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.xs),
                  child: Text(caption.toUpperCase(), style: context.tt.overline),
                ),
              if (actions.first.tile) _TileRow<T>(actions: actions) else _Group<T>(actions: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// The white of a group or a tile on the grey of the sheet.
Color _groupColor(ColorScheme cs) => cs.surfaceContainerLow;

class _Group<T> extends StatelessWidget {
  const _Group({required this.actions});
  final List<AppMenuAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: _groupColor(cs),
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, a) in actions.indexed) ...[
            if (i > 0) const Divider(height: AppSizes.hairline, indent: AppSpacing.lg + AppSizes.iconMd + AppSpacing.lg),
            _Row<T>(action: a),
          ],
        ],
      ),
    );
  }
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.action});
  final AppMenuAction<T> action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = action;
    final color = !a.enabled
        ? cs.onSurface.withValues(alpha: AppOpacity.disabled)
        : a.destructive
        ? cs.error
        : cs.onSurface;
    return InkWell(
      onTap: a.enabled ? () => Navigator.of(context).pop(a.value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.tapTarget),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: a.subtitle == null ? AppSpacing.xs : AppSpacing.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppSizes.iconMd,
                child: a.icon == null ? null : Icon(a.icon, size: AppSizes.iconMd, color: color),
              ),
              AppGap.h16,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      a.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (a.subtitle == null ? context.tt.body : context.tt.title).copyWith(color: color),
                    ),
                    if (a.subtitle != null) ...[
                      AppGap.v2,
                      Text(
                        a.subtitle!,
                        style: context.tt.meta.copyWith(
                          color: a.enabled ? null : cs.onSurfaceVariant.withValues(alpha: AppOpacity.disabled),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (a.selected) ...[AppGap.h12, Icon(AppIcons.check, size: AppSizes.iconMd, color: cs.onSurface)],
            ],
          ),
        ),
      ),
    );
  }
}

/// The quick actions: equal white tiles in one row, the icon over a
/// label of up to two lines.
class _TileRow<T> extends StatelessWidget {
  const _TileRow({required this.actions});
  final List<AppMenuAction<T>> actions;

  /// A tile is never lower than this: icon, two lines of label.
  static const double _minHeight = 76;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, a) in actions.indexed) ...[
            if (i > 0) AppGap.h8,
            Expanded(
              child: Material(
                color: _groupColor(cs),
                borderRadius: AppRadius.mdAll,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: a.enabled ? () => Navigator.of(context).pop(a.value) : null,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: _minHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.md),
                      // Icons in one line, labels hanging under them.
                      child: Column(
                        children: [
                          Icon(
                            a.icon,
                            size: AppSizes.iconLg,
                            color: a.enabled ? cs.onSurface : cs.onSurface.withValues(alpha: AppOpacity.disabled),
                          ),
                          AppGap.v8,
                          Text(
                            a.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: a.enabled ? cs.onSurface : cs.onSurface.withValues(alpha: AppOpacity.disabled),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A button that opens a menu sheet: the "more" button of a screen or any
/// [child] (a filter pill). Same names as [PopupMenuButton] for its
/// parameters, so screens read the same.
class AppMenuButton<T> extends StatelessWidget {
  const AppMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.tooltip,
    this.child,
    this.title,
    this.subtitle,
    this.enabled = true,
  });

  final List<AppMenuEntry<T>> Function(BuildContext context) itemBuilder;

  /// False greys the button out (nothing to act on yet).
  final bool enabled;
  final ValueChanged<T> onSelected;
  final Widget? icon;
  final String? tooltip;

  /// Instead of an icon button: this widget, tappable.
  final Widget? child;

  /// A heading for the sheet (what the menu is about).
  final String? title;
  final String? subtitle;

  Future<void> _open(BuildContext context) async {
    final v = await showAppMenu<T>(context, title: title, subtitle: subtitle, items: itemBuilder(context));
    if (v != null) onSelected(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = child;
    if (c != null) {
      final button = InkWell(customBorder: const StadiumBorder(), onTap: enabled ? () => _open(context) : null, child: c);
      return tooltip == null ? button : Tooltip(message: tooltip, child: button);
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? () => _open(context) : null,
      icon: icon ?? const Icon(AppIcons.more),
    );
  }
}
