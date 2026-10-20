import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';

/// Cards in columns on a wide page (D-104): as many columns as fit cards of
/// [minCardWidth], at most [maxColumns]; the cards of a row are as tall as
/// the tallest, so their edges line up.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minCardWidth = AppSizes.gridCardMin, this.maxColumns = 2});
  final List<Widget> children;
  final double minCardWidth;
  final int maxColumns;

  /// How many columns a grid this wide gets.
  static int columnsFor(double width, {double minCardWidth = AppSizes.gridCardMin, int maxColumns = 2}) {
    var n = ((width + AppSpacing.cardGap) / (minCardWidth + AppSpacing.cardGap)).floor();
    if (n > maxColumns) n = maxColumns;
    return n < 1 ? 1 : n;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final n = columnsFor(c.maxWidth, minCardWidth: minCardWidth, maxColumns: maxColumns);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var start = 0; start < children.length; start += n) ...[
            if (start > 0) const SizedBox(height: AppSpacing.cardGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + n; i++) ...[
                    if (i > start) const SizedBox(width: AppSpacing.cardGap),
                    Expanded(child: i < children.length ? children[i] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// A hairline across a card, from edge to edge.
class CardHairline extends StatelessWidget {
  const CardHairline({super.key});

  @override
  Widget build(BuildContext context) => Divider(
    height: AppSizes.hairline,
    thickness: AppSizes.hairline,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

/// A filter pill with a count after its word: "Усі 5".
class CountChip extends StatelessWidget {
  const CountChip({super.key, required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: '$count',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: selected ? cs.onPrimary.withValues(alpha: AppOpacity.muted) : cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [CountChip]s that scrolls sideways when it does not fit.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: padding,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) AppGap.h8, children[i]],
      ],
    ),
  );
}

/// The search field at the top of a list page.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged, this.controller});
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(prefixIcon: const Icon(AppIcons.search), hintText: hint),
  );
}
