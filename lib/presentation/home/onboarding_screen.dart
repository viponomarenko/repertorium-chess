import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/app_logo.dart';
import '../widgets/common.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  /// The column of the welcome page and the logo on top of it.
  static const double _width = 560;
  static const double _logoSize = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    Widget feature(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(icon: icon),
          AppGap.h16,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                AppGap.v2,
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _width),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xl,
                AppSpacing.page,
                AppSpacing.listBottom,
              ),
              children: [
                const Center(child: AppLogo(size: _logoSize)),
                AppGap.v16,
                Text(AppInfo.name, textAlign: TextAlign.center, style: theme.textTheme.displaySmall),
                AppGap.v8,
                Text(l.tagline, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                AppGap.v24,
                feature(AppIcons.repertoire, l.onbRepTitle, l.onbRepText),
                feature(AppIcons.hint, l.onbTrainTitle, l.onbTrainText),
                feature(AppIcons.openings, l.onbPgnTitle, l.onbPgnText),
                feature(AppIcons.cloudOff, l.onbOfflineTitle, l.onbOfflineText),
                AppGap.v24,
                Text(l.language, style: context.tt.title),
                AppGap.v8,
                ChoiceSegments<String>(
                  options: const [ChoiceOption('uk', 'Українська'), ChoiceOption('en', 'English')],
                  selected: lang == 'uk' ? 'uk' : 'en',
                  onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(localeCode: v)),
                ),
              ],
            ),
          ),
        ),
      ),
      // The primary action is always visible (not at the end of the scroll).
      bottomNavigationBar: StickyActionBar(
        children: [
          MaxWidth(
            width: _width - 2 * AppSpacing.page,
            child: FilledButton(
              style: AppButtonSize.large,
              onPressed: () async {
                await ref.read(settingsProvider.notifier).update((x) => x.copyWith(onboardingDone: true));
                if (context.mounted) context.go('/today');
              },
              child: Text(l.getStarted),
            ),
          ),
        ],
      ),
    );
  }
}
