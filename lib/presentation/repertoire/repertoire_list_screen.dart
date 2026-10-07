import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../app/providers.dart';
import '../home/today_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import 'create_repertoire_dialog.dart';

class RepertoireListScreen extends ConsumerWidget {
  const RepertoireListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reps = ref.watch(repertoiresProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navRepertoires),
        actions: [
          // Creating a repertoire sits in the bar with the other actions:
          // no button floating over the list. An empty list has its own
          // big button in the middle, so there is no duplicate here.
          if (!(reps.value?.isEmpty ?? true))
            AppBarAction(
              icon: AppIcons.add,
              label: l.newShort,
              tooltip: l.createRepertoire,
              onPressed: () => showCreateRepertoire(context),
            ),
        ],
      ),
      body: reps.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorState(message: l.somethingWentWrong, details: e, onRetry: () => ref.invalidate(repertoiresProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: AppIcons.repertoire,
                title: l.noRepertoires,
                message: l.noRepertoiresHint,
                actions: [
                  FilledButton.icon(
                    onPressed: () => showCreateRepertoire(context),
                    icon: const Icon(AppIcons.add),
                    label: Text(l.createRepertoire),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showStarterPicker(context),
                    icon: const Icon(AppIcons.starter),
                    label: Text(l.installStarter),
                  ),
                ],
              )
            : ListView.separated(
                padding: AppInsets.page,
                itemCount: list.length,
                separatorBuilder: (_, _) => AppGap.v12,
                itemBuilder: (_, i) => RepertoireCard(summary: list[i]),
              ),
      ),
    );
  }
}
