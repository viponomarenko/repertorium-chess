import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../accounts/accounts_providers.dart';
import '../theme/app_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

/// Third-party components shown on the About screen (full list: NOTICE).
const kComponents = <(String, String, String)>[
  ('Stockfish 19 / Light (multistockfish)', 'GPL-3.0', 'https://stockfishchess.org'),
  ('dartchess', 'GPL-3.0', 'https://github.com/lichess-org/dartchess'),
  ('chessground', 'GPL-3.0', 'https://github.com/lichess-org/flutter-chessground'),
  ('Piece sets: cburnett, merida', 'GPL-2.0-or-later', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece set: mpchess', 'GPL-3.0-or-later', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece set: chessnut', 'Apache-2.0', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece sets: fantasy, spatial, celtic', 'MIT', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece set: rhosgfx', 'CC0-1.0', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece set: firi', 'CC BY 4.0', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Piece set: shapes', 'CC BY-SA 4.0', 'https://github.com/lichess-org/lila/blob/master/COPYING.md'),
  ('Opening names (lichess-org/chess-openings)', 'CC0-1.0', 'https://github.com/lichess-org/chess-openings'),
  ('FSRS algorithm (own implementation)', 'MIT (reference)', 'https://github.com/open-spaced-repetition'),
  ('Icons: Bootstrap Icons (bootstrap_icons package)', 'MIT', 'https://icons.getbootstrap.com'),
  ('Move and capture sounds: Impact Sounds by Kenney', 'CC0 1.0', 'https://kenney.nl/assets/impact-sounds'),
  ('Other sounds (original, synthesized)', 'GPL-3.0', AppInfo.repositoryUrl),
  ('drift / sqlite3', 'MIT', 'https://drift.simonbinder.eu'),
  ('Riverpod', 'MIT', 'https://riverpod.dev'),
  ('go_router, http, path_provider, share_plus, url_launcher, package_info_plus', 'BSD-3-Clause', 'https://pub.dev'),
  ('flutter_appauth', 'BSD-3-Clause', 'https://pub.dev/packages/flutter_appauth'),
  (
    'flutter_secure_storage, audioplayers, archive, wakelock_plus, fast_immutable_collections',
    'BSD / MIT',
    'https://pub.dev',
  ),
  ('file_picker, flutter_local_notifications, timezone', 'MIT / BSD', 'https://pub.dev'),
  ('flutter_timezone', 'Apache-2.0', 'https://pub.dev/packages/flutter_timezone'),
  ('Font: Google Sans, Google Sans Code', 'SIL OFL 1.1', 'https://github.com/googlefonts/googlesans'),
  ('Font: Noto Sans Math (subset "TabiyaSymbols")', 'SIL OFL 1.1', 'https://github.com/notofonts/math'),
];

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const double _logoSize = 80;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.listBottom),
        children: [
          const Center(child: AppLogo(size: _logoSize)),
          AppGap.v8,
          Center(child: Text(AppInfo.name, style: theme.textTheme.headlineMedium)),
          Center(child: Text(l.versionN(version), style: context.tt.meta)),
          AppGap.v16,
          Padding(padding: AppInsets.pageH, child: Text(l.aboutText)),
          AppGap.v16,
          SettingsGroup(
            children: [
              ListTile(
                leading: const Icon(AppIcons.license),
                title: Text(l.licenseGpl),
                subtitle: Text(l.licenseGplHint),
              ),
              ListTile(
                leading: const Icon(AppIcons.code),
                title: Text(l.sourceCode),
                subtitle: const Text(AppInfo.repositoryUrl),
                onTap: () => launchUrl(Uri.parse(AppInfo.repositoryUrl), mode: LaunchMode.externalApplication),
              ),
              ListTile(
                leading: const Icon(AppIcons.privacy),
                title: Text(l.privacyPolicy),
                subtitle: Text(l.privacySummary),
              ),
              ListTile(
                leading: const Icon(AppIcons.document),
                title: Text(l.allLicenses),
                onTap: () =>
                    showLicensePage(context: context, applicationName: AppInfo.name, applicationVersion: version),
              ),
            ],
          ),
          SectionHeader(l.thirdParty),
          SettingsGroup(
            children: [
              for (final (name, license, url) in kComponents)
                ListTile(
                  title: Text(name),
                  subtitle: Text(license),
                  onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.page, top: AppSpacing.lg, right: AppSpacing.page),
            child: Text(l.notAffiliated, style: context.tt.meta),
          ),
          if (kDebugMode) ...[
            AppGap.v16,
            SettingsGroup(
              children: [
                NavTile(icon: AppIcons.font, title: l.typographyPreview, onTap: () => context.push('/typography')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
