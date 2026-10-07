import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tile(IconData icon, String title, String subtitle, String route) =>
        NavTile(icon: icon, title: title, subtitle: subtitle, onTap: () => context.push(route));
    return Scaffold(
      appBar: AppBar(title: Text(l.navMore)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
        children: [
          // Three named groups instead of one long list (D-069).
          SectionHeader(l.moreYourGames),
          SettingsGroup(
            children: [
              tile(AppIcons.myGames, l.myGames, l.myGamesSubtitle, '/my-games'),
              tile(AppIcons.link, l.accountsTitle, l.accountsSubtitle, '/accounts'),
            ],
          ),
          SectionHeader(l.moreTools),
          SettingsGroup(
            children: [
              tile(AppIcons.stats, l.statsTitle, l.statsSubtitle, '/stats'),
              tile(AppIcons.analysis, l.analysisBoard, l.analysisBoardSubtitle, '/analysis'),
              tile(AppIcons.editPosition, l.positionEditor, l.positionEditorSubtitle, '/position-editor'),
              tile(AppIcons.openings, l.openingsTitle, l.openingsSubtitle, '/openings'),
            ],
          ),
          SectionHeader(l.moreApp),
          SettingsGroup(
            children: [
              tile(AppIcons.settings, l.settingsTitle, l.settingsSubtitle, '/settings'),
              tile(AppIcons.backup, l.backupTitle, l.backupSubtitle, '/backup'),
              tile(AppIcons.info, l.aboutTitle, l.aboutSubtitle, '/about'),
            ],
          ),
        ],
      ),
    );
  }
}
