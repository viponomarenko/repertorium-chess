import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../gap/gap_report_screen.dart';
import '../stats/my_openings_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import 'accounts_providers.dart';
import 'my_games_screen.dart';

/// Everything about the user's own games in one place (D-069): the
/// downloaded games, the openings played in them, and where they left the
/// repertoire. These used to be three screens linked by icons.
class MyGamesHubScreen extends ConsumerStatefulWidget {
  const MyGamesHubScreen({super.key, this.initialTab = 0});

  /// 0 – games, 1 – openings, 2 – differences from the repertoire.
  final int initialTab;

  @override
  ConsumerState<MyGamesHubScreen> createState() => _MyGamesHubScreenState();
}

class _MyGamesHubScreenState extends ConsumerState<MyGamesHubScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _show(int tab) => _tabs.animateTo(tab);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.myGames),
        actions: [
          // Belongs to the list of games only.
          if (_tabs.index == 0)
            PopupMenuButton<String>(
              constraints: appMenuConstraints,
              icon: const Icon(AppIcons.more),
              tooltip: l.more,
              onSelected: (v) async {
                final ok = await confirm(context, title: l.clearDownloadedQ, confirmLabel: l.delete, destructive: true);
                if (ok) await ref.read(accountsServiceProvider).deleteImportedGames();
              },
              itemBuilder: (_) => [appMenuItem(value: 'clear', label: l.clearDownloaded)],
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.tabGames),
            Tab(text: l.tabOpenings),
            Tab(text: l.tabGaps),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        // The tabs hold boards and horizontal chips: no swiping between them.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          MyGamesScreen(embedded: true, onTab: _show),
          MyOpeningsScreen(embedded: true, onTab: _show),
          GapReportScreen(embedded: true, onTab: _show),
        ],
      ),
    );
  }
}
