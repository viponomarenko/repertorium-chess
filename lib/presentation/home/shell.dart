import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/haptics.dart';
import '../../core/l10n.dart';
import '../app/leave_guard.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  Future<void> _go(int i) async {
    final reset = i == shell.currentIndex;
    // Tapping the current tab returns to its first screen: moves that are
    // not added to the repertoire yet would be dropped without a word.
    if (reset && !await LeaveGuard.canLeave()) return;
    if (!reset) Haptics.selection();
    shell.goBranch(i, initialLocation: reset);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      (AppIcons.today, AppIcons.todaySelected, l.navToday),
      (AppIcons.repertoire, AppIcons.repertoireSelected, l.navRepertoires),
      (AppIcons.library, AppIcons.librarySelected, l.navLibrary),
      (AppIcons.more, AppIcons.more, l.navMore),
    ];
    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.wide) {
      // A tablet: the same buttons in a column at the side, where both
      // hands rest, and the whole height left to the page (D-084).
      return Scaffold(
        body: Row(
          children: [
            _SideRail(
              children: [
                for (var i = 0; i < items.length; i++)
                  BarButton(
                    icon: items[i].$1,
                    selectedIcon: items[i].$2,
                    label: items[i].$3,
                    selected: shell.currentIndex == i,
                    onTap: () => _go(i),
                  ),
              ],
            ),
            const VerticalDivider(width: AppSizes.hairline),
            Expanded(
              child: PageScope.measured(
                child: FadeOnChange(trigger: shell.currentIndex, child: shell),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      // The tab that opens fades in; its state is kept.
      body: FadeOnChange(trigger: shell.currentIndex, child: shell),
      // Same bar as in the analysis: big labelled buttons, the current tab
      // as a black rounded square.
      bottomNavigationBar: ThumbBar(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: BarButton(
                icon: items[i].$1,
                selectedIcon: items[i].$2,
                label: items[i].$3,
                selected: shell.currentIndex == i,
                onTap: () => _go(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// The main navigation of a wide screen: the buttons of the bottom bar,
/// one under another.
class _SideRail extends StatelessWidget {
  const _SideRail({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: SafeArea(
      right: false,
      child: SizedBox(
        width: AppSizes.railWidth,
        height: double.infinity,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: c,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
