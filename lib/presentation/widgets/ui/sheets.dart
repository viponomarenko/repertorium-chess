import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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

/// The app's bottom sheet: over the navigation bar, with a handle, as tall
/// as its content needs (scrolling when that is more than the screen),
/// clear of the keyboard and the home indicator.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  String? subtitle,
  required WidgetBuilder builder,

  /// False for content that scrolls by itself (a long list): it then gets
  /// the remaining height instead of being wrapped into a scroll view.
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
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
