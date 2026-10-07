import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/repositories/library_repository.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cols = ref.watch(collectionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navLibrary),
        actions: [
          // Import sits in the bar: no button floating over the list (an
          // empty library has its own big button in the middle).
          IconButton(
            tooltip: l.newCollection,
            icon: const Icon(AppIcons.newCollection),
            onPressed: () => createCollectionDialog(context, ref),
          ),
          if (!(cols.value?.isEmpty ?? true))
            AppBarAction(
              icon: AppIcons.add,
              label: l.importShort,
              tooltip: l.importAction,
              onPressed: () => context.push('/import'),
            ),
        ],
      ),
      body: cols.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(
          message: l.somethingWentWrong,
          details: '$e',
          onRetry: () => ref.invalidate(collectionsProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: AppIcons.library,
                title: l.libraryEmptyTitle,
                message: l.libraryEmptyMessage,
                actions: [
                  FilledButton.icon(
                    onPressed: () => context.push('/import'),
                    icon: const Icon(AppIcons.openFile),
                    label: Text(l.importAction),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.listBottom),
                children: [
                  SettingsGroup(children: [for (final c in list) _CollectionTile(c)]),
                ],
              ),
      ),
    );
  }
}

Future<int?> createCollectionDialog(BuildContext context, WidgetRef ref, {String initial = ''}) async {
  final l = context.l10n;
  final name = await promptText(
    context,
    title: l.newCollection,
    label: l.name,
    initial: initial,
    confirmLabel: l.create,
  );
  if (name == null || name.trim().isEmpty) return null;
  return ref.read(libraryRepositoryProvider).createCollection(name.trim());
}

IconData sourceIcon(String source) => switch (source) {
  'lichess' => AppIcons.online,
  'chesscom' => AppIcons.online,
  'file' => AppIcons.document,
  'clipboard' => AppIcons.paste,
  _ => AppIcons.folder,
};

class _CollectionTile extends ConsumerWidget {
  const _CollectionTile(this.c);
  final CollectionSummary c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final date = context.fmtShortDate(c.row.updatedAt);
    return ListTile(
      leading: AppAvatar(icon: sourceIcon(c.row.source)),
      title: Text(c.row.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('${l.gamesCount(c.gameCount)} · $date'),
      onTap: () => context.go('/library/${c.row.id}'),
      trailing: PopupMenuButton<String>(
        constraints: appMenuConstraints,
        icon: const Icon(AppIcons.more),
        tooltip: l.more,
        onSelected: (v) async {
          final repo = ref.read(libraryRepositoryProvider);
          if (v == 'rename') {
            final name = await promptText(context, title: l.rename, initial: c.row.name);
            if (name != null && name.trim().isNotEmpty) await repo.renameCollection(c.row.id, name.trim());
          } else if (v == 'delete') {
            if (!context.mounted) return;
            final ok = await confirm(
              context,
              title: l.deleteCollectionQ(c.row.name),
              message: l.deleteCollectionMessage(c.gameCount),
              confirmLabel: l.delete,
              destructive: true,
            );
            if (ok) await repo.deleteCollection(c.row.id);
          }
        },
        itemBuilder: (_) => [
          appMenuItem(value: 'rename', icon: AppIcons.edit, label: l.rename),
          appMenuDivider(),
          appMenuItem(value: 'delete', icon: AppIcons.delete, label: l.delete, destructive: true),
        ],
      ),
    );
  }
}
