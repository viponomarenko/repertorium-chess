import 'dart:async';
import 'dart:io';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/notifications/reminder_service.dart';
import '../../data/settings/app_settings.dart';
import '../../domain/training/opponent_strategy.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../repertoire/repertoire_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/board_view.dart';
import '../widgets/common.dart';
import '../widgets/engine_model_sheet.dart';
import '../widgets/san_text.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    void set(AppSettings Function(AppSettings) f) => n.update(f);

    Widget slider(
      String title,
      num value,
      double min,
      double max,
      int divisions,
      String Function(num) label,
      void Function(double) onChanged,
    ) => ListTile(
      title: Text(title),
      subtitle: Slider(
        value: value.toDouble().clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label(value),
        onChanged: onChanged,
      ),
      // The value column grows with long labels and large text (T-20, T-21).
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _valueColumn),
        child: Text(label(value), textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodyMedium?.tabular),
      ),
    );

    /// Dropdown with preset values; the current value is kept even when it
    /// is not a preset.
    Widget presets(String title, int value, List<int> options, void Function(int) onChanged, {String? subtitle}) {
      final values = {...options, value}.toList()..sort();
      return ChoiceTile<int>(
        title: title,
        hint: subtitle,
        value: value,
        options: [for (final v in values) ChoiceOption(v, context.fmtInt(v))],
        onChanged: onChanged,
      );
    }

    String ms(num v) => v == 0 ? l.off : l.unitMs(context.fmtInt(v.round()));
    String sec(num v) => l.unitSec(context.fmtInt(v.round()));
    final notationSize = NotationSize.fromName(s.notationSize);
    final notationLanguage = NotationLanguage.fromName(s.notationLanguage);

    final cores = Platform.numberOfProcessors;

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        children: groupIntoCards([
          SectionHeader(l.general),
          ChoiceTile<String?>(
            leading: const Icon(AppIcons.language),
            title: l.language,
            value: s.localeCode,
            options: [
              ChoiceOption(null, l.systemDefault),
              const ChoiceOption('uk', 'Українська'),
              const ChoiceOption('en', 'English'),
            ],
            onChanged: (v) => set((x) => v == null ? x.copyWith(clearLocale: true) : x.copyWith(localeCode: v)),
          ),
          ChoiceTile<ThemeMode>(
            leading: const Icon(AppIcons.theme),
            title: l.theme,
            value: s.themeMode,
            options: [
              ChoiceOption(ThemeMode.system, l.systemDefault),
              ChoiceOption(ThemeMode.light, l.themeLight),
              ChoiceOption(ThemeMode.dark, l.themeDark),
            ],
            onChanged: (v) => set((x) => x.copyWith(themeMode: v)),
          ),

          SectionHeader(l.notation),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.card, AppSpacing.card, AppSpacing.sm),
            child: Container(
              padding: AppInsets.strip,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: AppRadius.mdAll,
              ),
              child: MovesText('1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 5. O-O Be7', style: context.tt.moveMain),
            ),
          ),
          ListTile(
            title: Text(l.notationSize),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: ChoiceSegments<NotationSize>(
                options: [
                  ChoiceOption(NotationSize.small, l.sizeSmall),
                  ChoiceOption(NotationSize.normal, l.sizeNormal),
                  ChoiceOption(NotationSize.large, l.sizeLarge),
                ],
                selected: notationSize,
                onChanged: (v) => set((x) => x.copyWith(notationSize: v.name)),
              ),
            ),
          ),
          RadioGroup<NotationLanguage>(
            groupValue: notationLanguage,
            onChanged: (v) {
              if (v != null) set((x) => x.copyWith(notationLanguage: v.name));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(title: Text(l.notationLanguage), subtitle: Text(l.notationExportHint)),
                RadioListTile(value: NotationLanguage.english, title: Text(l.notationEnglish)),
                RadioListTile(value: NotationLanguage.ukrainian, title: Text(l.notationUkrainian)),
                RadioListTile(value: NotationLanguage.figurine, title: Text(l.notationFigurine)),
              ],
            ),
          ),

          SectionHeader(l.board),
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.card, top: AppSpacing.card, right: AppSpacing.card),
            child: Center(
              child: MiniBoard(
                fen: 'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
                size: _previewBoard,
              ),
            ),
          ),
          ListTile(
            title: Text(l.boardTheme),
            subtitle: SizedBox(
              height: _swatchRow,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final t in BoardAppearance.boardThemes)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.sm),
                      child: InkWell(
                        onTap: () => set((x) => x.copyWith(boardTheme: t)),
                        child: Tooltip(
                          message: boardThemeName(t, l),
                          child: _ThemeSwatch(name: t, label: boardThemeName(t, l), selected: s.boardTheme == t),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            title: Text(l.pieceSet),
            subtitle: SizedBox(
              height: _swatchRow,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in BoardAppearance.pieceSets)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm, top: AppSpacing.sm),
                      child: Tooltip(
                        message: p.label,
                        child: InkWell(
                          onTap: () {
                            set((x) => x.copyWith(pieceSet: p.name));
                            ChessgroundImages.instance.loadAll(p.assets);
                          },
                          child: _Swatch(
                            label: p.label,
                            selected: s.pieceSet == p.name,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: Image(image: p.assets[PieceKind.whiteKnight]!, excludeFromSemantics: true),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            value: s.showCoordinates,
            title: Text(l.coordinates),
            onChanged: (v) => set((x) => x.copyWith(showCoordinates: v)),
          ),
          SwitchListTile(
            value: s.showLegalMoves,
            title: Text(l.showLegalMoves),
            onChanged: (v) => set((x) => x.copyWith(showLegalMoves: v)),
          ),
          ChoiceTile<String>(
            title: l.moveMethod,
            value: s.moveMethod,
            options: [
              ChoiceOption('either', l.moveMethodEither),
              ChoiceOption('drag', l.moveMethodDrag),
              ChoiceOption('tapTwoSquares', l.moveMethodTap),
            ],
            onChanged: (v) => set((x) => x.copyWith(moveMethod: v)),
          ),
          slider(l.animationSpeed, s.animationMs, 0, 600, 6, ms, (v) => set((x) => x.copyWith(animationMs: v.round()))),
          SwitchListTile(
            value: s.sound,
            title: Text(l.sound),
            onChanged: (v) => set((x) => x.copyWith(sound: v)),
          ),
          SwitchListTile(
            value: s.haptics,
            title: Text(l.haptics),
            onChanged: (v) => set((x) => x.copyWith(haptics: v)),
          ),

          SectionHeader(l.training),
          presets(l.dailyGoal, s.dailyGoal, const [10, 20, 30, 50, 100, 200], (v) {
            set((x) => x.copyWith(dailyGoal: v));
          }),
          SwitchListTile(
            value: s.showComments,
            title: Text(l.showComments),
            onChanged: (v) => set((x) => x.copyWith(showComments: v)),
          ),
          AppExpansionTile(
            title: Text(l.advancedSettings),
            subtitle: Text(l.advancedTrainingHint),
            children: [
              // Daily amounts and the finer rules of a session: sensible by
              // default, here for those who want to tune them (D-031).
              presets(l.newPerDay, s.newPerDay, const [0, 5, 10, 15, 20, 30, 50, 100], (v) {
                set((x) => x.copyWith(newPerDay: v));
              }),
              presets(l.reviewsPerDay, s.reviewsPerDay, const [50, 100, 200, 300, 500, 1000], (v) {
                set((x) => x.copyWith(reviewsPerDay: v));
              }),
              SwitchListTile(
                value: s.acceptAlternatives,
                title: Text(l.acceptAlternatives),
                subtitle: Text(l.acceptAlternativesHint),
                onChanged: (v) => set((x) => x.copyWith(acceptAlternatives: v)),
              ),
              SwitchListTile(
                value: s.autoplayToDue,
                title: Text(l.autoplayToDue),
                subtitle: Text(l.autoplayToDueHint),
                onChanged: (v) => set((x) => x.copyWith(autoplayToDue: v)),
              ),
              SwitchListTile(
                value: s.timedGrading,
                title: Text(l.timedGrading),
                subtitle: Text(l.timedGradingHint),
                onChanged: (v) => set((x) => x.copyWith(timedGrading: v)),
              ),
              if (s.timedGrading)
                slider(
                  l.goodThreshold,
                  s.goodSeconds,
                  3,
                  30,
                  27,
                  sec,
                  (v) => set((x) => x.copyWith(goodSeconds: v.round())),
                ),
              if (s.timedGrading)
                SwitchListTile(
                  value: s.easyEnabled,
                  title: Text(l.easyEnabled),
                  subtitle: Text(l.easyEnabledHint),
                  onChanged: (v) => set((x) => x.copyWith(easyEnabled: v)),
                ),
              if (s.timedGrading && s.easyEnabled)
                slider(
                  l.easyThreshold,
                  s.easySeconds,
                  1,
                  10,
                  9,
                  sec,
                  (v) => set((x) => x.copyWith(easySeconds: v.round())),
                ),
              slider(
                l.mistakesBeforeReveal,
                s.mistakesBeforeReveal,
                1,
                5,
                4,
                (v) => context.fmtInt(v),
                (v) => set((x) => x.copyWith(mistakesBeforeReveal: v.round())),
              ),
              SwitchListTile(
                value: s.drillAffectsSchedule,
                title: Text(l.drillAffectsSchedule),
                subtitle: Text(l.drillAffectsScheduleHint),
                onChanged: (v) => set((x) => x.copyWith(drillAffectsSchedule: v)),
              ),
              slider(
                l.opponentDelay,
                s.opponentDelayMs,
                0,
                1500,
                15,
                ms,
                (v) => set((x) => x.copyWith(opponentDelayMs: v.round())),
              ),
              slider(
                l.desiredRetention,
                s.desiredRetention * 100,
                80,
                97,
                17,
                (v) => context.fmtPercent(v / 100),
                (v) => set((x) => x.copyWith(desiredRetention: v.round() / 100)),
              ),
              ChoiceTile<OpponentStrategy>(
                title: l.opponentStrategy,
                hint: strategyHint(s.defaultStrategy, l),
                value: s.defaultStrategy,
                options: [for (final st in OpponentStrategy.values) ChoiceOption(st, strategyName(st, l))],
                onChanged: (v) => set((x) => x.copyWith(defaultStrategy: v)),
              ),
            ],
          ),

          SectionHeader(l.reminder),
          SwitchListTile(
            value: s.notificationsEnabled,
            title: Text(l.dailyReminder),
            subtitle: Text(l.dailyReminderHint),
            onChanged: (v) async {
              // The app keeps the notification in sync with these settings
              // (TabiyaApp); here only the permission is asked.
              if (v) {
                var ok = false;
                try {
                  ok = await ref.read(reminderServiceProvider).requestPermission();
                } catch (_) {}
                if (!ok) {
                  // The system asks only once: afterwards the way back is
                  // the app's page in the system settings.
                  if (context.mounted) {
                    showSnack(
                      context,
                      l.notificationsDenied,
                      action: SnackBarAction(
                        label: l.openSystemSettings,
                        onPressed: () => unawaited(launchUrl(Uri.parse('app-settings:'))),
                      ),
                    );
                  }
                  return;
                }
              }
              set((x) => x.copyWith(notificationsEnabled: v));
            },
          ),
          if (s.notificationsEnabled)
            ListTile(
              title: Text(l.reminderTime),
              trailing: Text(TimeOfDay(hour: s.notificationHour, minute: s.notificationMinute).format(context)),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: s.notificationHour, minute: s.notificationMinute),
                );
                if (t == null) return;
                set((x) => x.copyWith(notificationHour: t.hour, notificationMinute: t.minute));
              },
            ),

          SectionHeader(l.engine),
          ListTile(
            title: Text(l.engineLocalModel),
            subtitle: Text(s.engineModel == 'full' ? 'Stockfish 19' : 'Stockfish 19 Light'),
            trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
            onTap: () => showEngineModelSheet(context),
          ),
          slider(
            l.engineLines,
            s.engineLines,
            1,
            5,
            4,
            (v) => context.fmtInt(v),
            (v) => set((x) => x.copyWith(engineLines: v.round())),
          ),
          SwitchListTile(
            value: s.enginePowerSaving,
            title: Text(l.enginePowerSaving),
            subtitle: Text(l.enginePowerSavingHint),
            onChanged: (v) => set((x) => x.copyWith(enginePowerSaving: v)),
          ),
          SwitchListTile(
            value: s.engineCloudFirst,
            title: Text(l.engineCloudFirst),
            subtitle: Text(l.engineCloudFirstHint),
            onChanged: (v) => set((x) => x.copyWith(engineCloudFirst: v)),
          ),
          SwitchListTile(
            value: s.engineInTraining,
            title: Text(l.engineInTraining),
            subtitle: Text(l.engineInTrainingHint),
            onChanged: (v) => set((x) => x.copyWith(engineInTraining: v)),
          ),
          AppExpansionTile(
            title: Text(l.advancedSettings),
            subtitle: Text(l.advancedEngineHint),
            children: [
              slider(
                l.engineThreads,
                s.engineThreads,
                0,
                cores.toDouble(),
                cores,
                (v) => v == 0 ? l.auto : context.fmtInt(v),
                (v) => set((x) => x.copyWith(engineThreads: v.round())),
              ),
              slider(
                l.engineHash,
                s.engineHashMb,
                0,
                512,
                16,
                (v) => v == 0 ? l.auto : l.unitMb(context.fmtInt(v.round())),
                (v) => set((x) => x.copyWith(engineHashMb: v.round())),
              ),
              slider(
                l.engineDepthLimit,
                s.engineDepth,
                0,
                40,
                40,
                (v) => v == 0 ? l.unlimited : context.fmtInt(v),
                (v) => set((x) => x.copyWith(engineDepth: v.round())),
              ),
              slider(
                l.engineThreshold,
                s.engineCheckThresholdCp,
                20,
                300,
                28,
                (v) => l.unitPawns(context.fmtDecimal(v / 100)),
                (v) => set((x) => x.copyWith(engineCheckThresholdCp: v.round())),
              ),
            ],
          ),

          SectionHeader(l.integrations),
          ListTile(
            leading: const Icon(AppIcons.link),
            title: Text(l.accountsTitle),
            trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
            onTap: () => context.push('/accounts'),
          ),
          AppExpansionTile(
            title: Text(l.advancedSettings),
            subtitle: Text(l.advancedIntegrationsHint),
            children: [
              ListTile(
                title: Text(l.explorerRatings),
                subtitle: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final r in const [0, 1000, 1200, 1400, 1600, 1800, 2000, 2200, 2500])
                      FilterChip(
                        label: Text(r == 0 ? '0+' : context.fmtInt(r)),
                        selected: s.explorerRatings.contains(r),
                        onSelected: (v) => set(
                          (x) => x.copyWith(
                            explorerRatings: v
                                ? ([...x.explorerRatings, r]..sort())
                                : x.explorerRatings.where((e) => e != r).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                title: Text(l.explorerSpeeds),
                subtitle: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final sp in const ['bullet', 'blitz', 'rapid', 'classical', 'correspondence'])
                      FilterChip(
                        label: Text(speedName(sp, l)),
                        selected: s.explorerSpeeds.contains(sp),
                        onSelected: (v) => set(
                          (x) => x.copyWith(
                            explorerSpeeds: v
                                ? [...x.explorerSpeeds, sp]
                                : x.explorerSpeeds.where((e) => e != sp).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              slider(
                l.coverageThreshold,
                s.gapCoveragePercent,
                1,
                20,
                19,
                (v) => context.fmtPercent(v / 100),
                (v) => set((x) => x.copyWith(gapCoveragePercent: v.round())),
              ),
              ListTile(
                leading: const Icon(AppIcons.clean),
                title: Text(l.clearExplorerCache),
                onTap: () async {
                  await ref.read(explorerServiceProvider).clearCache();
                  if (context.mounted) showSnack(context, l.done);
                },
              ),
            ],
          ),

          SectionHeader(l.data),
          ListTile(
            leading: const Icon(AppIcons.backup),
            title: Text(l.backupTitle),
            subtitle: Text(l.backupSubtitle),
            trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
            onTap: () => context.push('/backup'),
          ),
          ListTile(
            leading: const Icon(AppIcons.info),
            title: Text(l.aboutTitle),
            trailing: const Icon(AppIcons.chevronRight, size: AppSizes.iconMd),
            onTap: () => context.push('/about'),
          ),
          AppGap.v32,
        ]),
      ),
    );
  }
}

String boardThemeName(String name, AppLocalizations l) => switch (name) {
  'brown' => l.boardThemeBrown,
  'blue' => l.boardThemeBlue,
  'green' => l.boardThemeGreen,
  'ic' => l.boardThemeIc,
  'grey' => l.boardThemeGrey,
  'purple' => l.boardThemePurple,
  'tabiya' => l.boardThemeTabiya,
  _ => name,
};

String speedName(String s, AppLocalizations l) => switch (s) {
  'ultraBullet' => l.speedUltraBullet,
  'bullet' => l.speedBullet,
  'blitz' => l.speedBlitz,
  'rapid' => l.speedRapid,
  'classical' => l.speedClassical,
  'correspondence' || 'daily' => l.speedCorrespondence,
  _ => s,
};

/// Width of the value beside a slider.
const double _valueColumn = 56;

/// The board that shows the chosen theme and pieces.
const double _previewBoard = 200;

/// A swatch and the row of swatches (the swatch and the air above it).
const double _swatchSize = AppSizes.controlLg;
const double _swatchRow = _swatchSize + AppSpacing.lg;

/// Frame of a swatch: thin, thick when chosen.
const double _swatchBorder = AppSizes.hairline;
const double _swatchBorderSelected = 3;

/// A square choice in a row (board theme, piece set): the chosen one has
/// a thick frame in the primary colour.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.label, required this.selected, required this.child});
  final String label;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Container(
        width: _swatchSize,
        height: _swatchSize,
        decoration: BoxDecoration(
          border: Border.all(
            width: selected ? _swatchBorderSelected : _swatchBorder,
            color: selected ? cs.primary : cs.outlineVariant,
          ),
          borderRadius: AppRadius.smAll,
        ),
        child: ClipRRect(borderRadius: AppRadius.xsAll, child: child),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.name, required this.label, required this.selected});
  final String name;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final sc = BoardAppearance.scheme(name);
    return _Swatch(
      label: label,
      selected: selected,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ColoredBox(color: sc.lightSquare),
          ColoredBox(color: sc.darkSquare),
          ColoredBox(color: sc.darkSquare),
          ColoredBox(color: sc.lightSquare),
        ],
      ),
    );
  }
}
