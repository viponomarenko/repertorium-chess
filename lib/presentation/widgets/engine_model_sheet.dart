import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/engine/engine_network.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../theme/tokens.dart';

Future<bool?> showEngineModelSheet(BuildContext context) => showModalBottomSheet<bool>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const EngineModelSheet(),
);

class EngineModelSheet extends ConsumerStatefulWidget {
  const EngineModelSheet({super.key});
  @override
  ConsumerState<EngineModelSheet> createState() => _EngineModelSheetState();
}

class _EngineModelSheetState extends ConsumerState<EngineModelSheet> {
  late final EngineNetwork _network;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _network = ref.read(engineNetworkProvider);
    unawaited(_network.initialize());
  }

  @override
  void dispose() {
    _network.cancel();
    super.dispose();
  }

  Future<void> _select(String model) async {
    _network.cancel();
    await ref.read(settingsProvider.notifier).update((s) => s.copyWith(engineModel: model));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _download() async {
    final success = await _network.download();
    if (mounted && success) await _select('full');
  }

  Future<void> _remove() async {
    final settings = ref.read(settingsProvider.notifier);
    final engine = ref.read(engineServiceProvider);
    setState(() => _removing = true);
    try {
      await engine.shutdown();
      await _network.remove();
      await settings.update((s) => s.copyWith(engineModel: 'light'));
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final selected = ref.watch(settingsProvider.select((s) => s.engineModel));
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: ValueListenableBuilder<EngineNetworkState>(
          valueListenable: _network,
          builder: (context, state, _) {
            final ready = state.phase == NetworkPhase.ready;
            final checking = state.phase == NetworkPhase.checking;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppInsets.sheetTitle,
                  child: Text(l.engineLocalModel, style: Theme.of(context).textTheme.titleLarge),
                ),
                ListTile(
                  title: const Text('Stockfish 19 Light'),
                  subtitle: Text(l.engineLightHint),
                  selected: selected == 'light',
                  trailing: selected == 'light' ? const Icon(AppIcons.check) : null,
                  onTap: _removing ? null : () => _select('light'),
                ),
                ListTile(
                  title: const Text('Stockfish 19'),
                  subtitle: Text(ready ? l.engineNetworkReady : l.engineFullHint),
                  selected: selected == 'full' && ready,
                  trailing: selected == 'full' && ready ? const Icon(AppIcons.check) : null,
                  onTap: ready && !_removing ? () => _select('full') : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (checking || state.busy || _removing) ...[
                        LinearProgressIndicator(
                          value: state.phase == NetworkPhase.downloading
                              ? (state.received / state.total).clamp(0.0, 1.0)
                              : null,
                        ),
                        AppGap.v12,
                        Text(
                          state.phase == NetworkPhase.downloading
                              ? l.unitMb(
                                  '${context.fmtDecimal(double.parse((state.received / 1048576).toStringAsFixed(1)))} / '
                                  '${(state.total / 1048576).ceil()}',
                                )
                              : state.phase == NetworkPhase.verifying
                              ? l.engineNetworkVerifying
                              : l.engineNetworkChecking,
                        ),
                        if (state.busy) TextButton(onPressed: _network.cancel, child: Text(l.cancel)),
                      ] else if (!ready) ...[
                        if (state.phase == NetworkPhase.failed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Text(l.engineNetworkFailed),
                          ),
                        FilledButton(onPressed: _download, child: Text(l.engineDownloadFull)),
                      ] else ...[
                        TextButton(onPressed: _remove, child: Text(l.engineNetworkDelete)),
                        Text(l.engineNetworkDeleteHint, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
