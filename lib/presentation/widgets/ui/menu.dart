import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';

/// One row of a menu (D-081): an icon, a few words, 48 high. Every popup
/// menu of the app is built from these, so they all look the same; the
/// card itself (shape, shadow, colours) comes from the theme.
PopupMenuItem<T> appMenuItem<T>({
  required T value,
  required String label,
  IconData? icon,
  bool enabled = true,

  /// Deletes or discards something: shown in the error colour.
  bool destructive = false,

  /// The current choice of a list of options: marked with a check.
  bool selected = false,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    height: AppSizes.tapTarget,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final color = !enabled
            ? cs.onSurface.withValues(alpha: AppOpacity.disabled)
            : destructive
            ? cs.error
            : cs.onSurface;
        return Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: AppSizes.iconMd, color: destructive || !enabled ? color : cs.onSurfaceVariant),
              AppGap.h12,
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.body.copyWith(color: color),
              ),
            ),
            if (selected) ...[AppGap.h12, Icon(AppIcons.check, size: AppSizes.iconMd, color: cs.onSurface)],
          ],
        );
      },
    ),
  );
}

/// A thin line between groups of a menu.
PopupMenuEntry<T> appMenuDivider<T>() => const PopupMenuDivider(height: AppSpacing.sm + AppSizes.hairline);

/// Opens a menu at a point of the screen (a long press on a card or a row).
Future<T?> showAppMenu<T>(BuildContext context, {required Offset at, required List<PopupMenuEntry<T>> items}) {
  final screen = Offset.zero & MediaQuery.sizeOf(context);
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(at & Size.zero, screen),
    constraints: appMenuConstraints,
    items: items,
  );
}

/// Wide enough for an icon and three or four words, never the whole screen.
const appMenuConstraints = BoxConstraints(minWidth: 200, maxWidth: 280);
