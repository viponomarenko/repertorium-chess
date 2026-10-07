import 'package:dartchess/dartchess.dart' show Side;
import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../widgets/common.dart';

/// Debug screen `/design`: the tokens and the shared widgets in one place,
/// to check a change of the standard in both themes (D-076).
class DesignPreviewScreen extends StatefulWidget {
  const DesignPreviewScreen({super.key});

  @override
  State<DesignPreviewScreen> createState() => _DesignPreviewScreenState();
}

class _DesignPreviewScreenState extends State<DesignPreviewScreen> {
  int _view = 0;
  bool _panel = true;
  double _progress = 0.4;
  int _shake = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = context.tt;
    Widget swatch(String name, Color c) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.controlMd,
          height: AppSizes.controlMd,
          decoration: BoxDecoration(
            color: c,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: cs.outlineVariant),
          ),
        ),
        AppGap.v4,
        Text(name, style: tt.meta),
      ],
    );
    Widget radius(String name, BorderRadius r) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.controlLg,
          height: AppSizes.controlMd,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: r),
        ),
        AppGap.v4,
        Text(name, style: tt.meta),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design'),
        actions: [AppBarAction(icon: AppIcons.add, label: 'Action', tooltip: 'Action', onPressed: () {})],
      ),
      body: AppPage(
        padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
        children: [
          const SectionHeader('Colour'),
          Padding(
            padding: AppInsets.pageH,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                swatch('primary', cs.primary),
                swatch('surface', cs.surface),
                swatch('card', cs.surfaceContainerLow),
                swatch('high', cs.surfaceContainerHigh),
                swatch('outline', cs.outline),
                swatch('success', cs.success),
                swatch('warning', cs.warning),
                swatch('error', cs.error),
                swatch('flame', cs.flame),
                swatch('white', cs.sideWhite),
                swatch('draw', cs.sideDraw),
                swatch('black', cs.sideBlack),
              ],
            ),
          ),
          const SectionHeader('Shape'),
          Padding(
            padding: AppInsets.pageH,
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                radius('xs 6', AppRadius.xsAll),
                radius('sm 8', AppRadius.smAll),
                radius('md 12', AppRadius.mdAll),
                radius('lg 20', AppRadius.lgAll),
                radius('xl 28', AppRadius.xlAll),
                radius('full', AppRadius.full),
              ],
            ),
          ),
          const SectionHeader('Buttons'),
          Padding(
            padding: AppInsets.pageH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: AppButtonSize.large,
                  onPressed: () {},
                  icon: const Icon(AppIcons.drill),
                  label: const Text('Main action, large'),
                ),
                AppGap.v8,
                OutlinedButton(style: AppButtonSize.wide, onPressed: () {}, child: const Text('Secondary, wide')),
                AppGap.v8,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton(onPressed: () {}, child: const Text('Filled')),
                    FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
                    OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
                    TextButton(onPressed: () {}, child: const Text('Text')),
                    const FilledButton(onPressed: null, child: Text('Disabled')),
                  ],
                ),
                AppGap.v8,
                Row(
                  children: [
                    Expanded(
                      child: ToolButton(icon: AppIcons.drill, label: 'Tool', onTap: () {}),
                    ),
                    AppGap.h8,
                    const Expanded(
                      child: ToolButton(icon: AppIcons.analysis, label: 'Disabled', onTap: null),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader('Choices'),
          Padding(
            padding: AppInsets.pageH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PillSwitch(
                  labels: const ['Moves', 'Tree'],
                  selected: _view,
                  onChanged: (i) => setState(() => _view = i),
                ),
                ChoiceSegments<int>(
                  options: const [ChoiceOption(0, 'One'), ChoiceOption(1, 'Two'), ChoiceOption(2, 'Three')],
                  selected: _view,
                  onChanged: (i) => setState(() => _view = i.clamp(0, 1)),
                ),
                AppGap.v8,
                FilterPill<int>(label: 'Filter', items: const [(0, 'All'), (1, 'Some')], onSelected: (_) {}),
              ],
            ),
          ),
          const SectionHeader('Messages'),
          Padding(
            padding: AppInsets.pageH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const InfoStrip(icon: AppIcons.ok, text: 'A neutral note.'),
                AppGap.v8,
                const InfoStrip(icon: AppIcons.ok, text: 'Done.', tone: Tone.success),
                AppGap.v8,
                const InfoStrip(icon: AppIcons.warning, text: 'Mind this.', tone: Tone.warning),
                AppGap.v8,
                InfoStrip(
                  icon: AppIcons.error,
                  title: 'Failed',
                  text: 'Something went wrong.',
                  tone: Tone.error,
                  action: TextButton(onPressed: () {}, child: const Text('Retry')),
                ),
                AppGap.v12,
                const StatusLine(icon: AppIcons.ok, text: 'In your repertoire', tone: Tone.success),
                AppGap.v4,
                const StatusLine(icon: AppIcons.warning, text: 'Out of book', tone: Tone.warning),
                AppGap.v4,
                const StatusLine(icon: AppIcons.ok, text: 'Goal reached', tone: Tone.success, strong: true),
              ],
            ),
          ),
          const SectionHeader('Data'),
          Padding(
            padding: AppInsets.pageH,
            child: SectionCard(
              title: 'Section card',
              subtitle: 'A heading, a line, the content',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      SideBadge(side: Side.white),
                      AppGap.h8,
                      SideBadge(side: Side.black),
                      AppGap.h8,
                      AppAvatar(icon: AppIcons.library),
                      AppGap.h8,
                      AppAvatar(text: 'B12'),
                      AppGap.h8,
                      AppAvatar(text: '3', tone: Tone.error),
                    ],
                  ),
                  AppGap.v16,
                  const Row(
                    children: [
                      Expanded(
                        child: StatTile(value: '128', label: 'Learned'),
                      ),
                      Expanded(
                        child: StatTile(value: '92 %', label: 'Retention'),
                      ),
                    ],
                  ),
                  AppGap.v16,
                  AppProgressBar(value: _progress),
                  AppGap.v12,
                  ResultBar.score(context, wins: 5, draws: 2, losses: 3),
                  AppGap.v12,
                  ResultBar.sides(context, white: 40, draws: 35, black: 25),
                ],
              ),
            ),
          ),
          const SectionHeader('Motion'),
          Padding(
            padding: AppInsets.pageH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(onPressed: () => setState(() => _panel = !_panel), child: const Text('Reveal')),
                    OutlinedButton(
                      onPressed: () => setState(() => _progress = _progress > 0.5 ? 0.2 : 0.9),
                      child: const Text('Progress'),
                    ),
                    OutlinedButton(onPressed: () => setState(() => _shake++), child: const Text('Shake')),
                  ],
                ),
                Reveal(
                  visible: _panel,
                  child: const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.sm),
                    child: InfoStrip(text: 'A panel that opens and closes.'),
                  ),
                ),
                AppGap.v8,
                Shake(
                  trigger: _shake == 0 ? null : _shake,
                  child: AppSwitcher(
                    child: InfoStrip(
                      key: ValueKey(_shake.isEven),
                      icon: _shake.isEven ? AppIcons.ok : AppIcons.error,
                      text: _shake.isEven ? 'Right' : 'Wrong',
                      tone: _shake.isEven ? Tone.success : Tone.error,
                    ),
                  ),
                ),
                AppGap.v8,
                AnimatedCount(value: _progress * 100, format: (v) => '${v.round()} %', style: tt.value),
              ],
            ),
          ),
          const SectionHeader('Group'),
          SettingsGroup(
            children: [
              NavTile(
                icon: AppIcons.settings,
                title: 'Navigation tile',
                subtitle: 'With a line of explanation',
                onTap: () {},
              ),
              NavTile(
                icon: AppIcons.library,
                title: 'Bottom sheet',
                onTap: () => showAppSheet<void>(
                  context,
                  title: 'Sheet title',
                  subtitle: 'An optional line',
                  builder: (_) => const Padding(padding: AppInsets.sheet, child: Text('Content of the sheet.')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
