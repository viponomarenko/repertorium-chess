import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'basics.dart';

/// Title of a bottom sheet, under its handle.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppInsets.sheetTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (subtitle != null) ...[AppGap.v4, Text(subtitle!, style: context.tt.meta)],
        ],
      ),
    );
  }
}

/// Shows [builder] over the screen: a sheet from the bottom on a phone,
/// a card in the middle of a wide screen, where a strip along the bottom
/// edge is far from both the eyes and the hands (D-084). Closes by a tap
/// outside, a swipe down (the sheet) or Escape (a keyboard).
///
/// [backgroundColor] replaces the sheet's own white: a menu lies on the
/// page grey so that its white groups stand out (D-114).
Future<T?> showAppModal<T>(BuildContext context, {required WidgetBuilder builder, Color? backgroundColor}) {
  if (!isWide(context)) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: backgroundColor,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => Dialog(
      backgroundColor: backgroundColor,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      constraints: const BoxConstraints(maxWidth: AppSizes.sheetCardWidth),
      child: PageScope(
        width: 0,
        // The room the handle takes on a sheet.
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
          child: MediaQuery.removePadding(context: ctx, removeTop: true, removeBottom: true, child: builder(ctx)),
        ),
      ),
    ),
  );
}

/// The app's sheet: over the navigation bar, with a title, as tall as its
/// content needs (scrolling when that is more than the screen), clear of
/// the keyboard and the home indicator.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required WidgetBuilder builder,

  /// False for content that scrolls by itself (a long list): it then gets
  /// the remaining height instead of being wrapped into a scroll view.
  bool scrollable = true,
}) {
  return showAppModal<T>(
    context,
    builder: (ctx) {
      final body = builder(ctx);
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) SheetHeader(title, subtitle: subtitle),
              Flexible(child: scrollable ? SingleChildScrollView(child: body) : body),
            ],
          ),
        ),
      );
    },
  );
}
