import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/repositories/library_repository.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import 'import_flow.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

/// Sources told apart by the filter of a wide Library.
enum _SourceFilter { lichess, chesscom, files }

_SourceFilter? _filterOf(String source) => switch (source) {
  'lichess' => _SourceFilter.lichess,
  'chesscom' => _SourceFilter.chesscom,
  'file' || 'clipboard' => _SourceFilter.files,
  _ => null,
};

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Text this large leaves no room for a labelled button in the bar.
  static const double _largeText = 1.5;

  /// A caption inside the page margin, in line with the text in cards.
  static const _captionPadding = EdgeInsets.only(left: AppSpacing.card, top: AppSpacing.xl, bottom: AppSpacing.sm);

  String _query = '';
  _SourceFilter? _source;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cols = ref.watch(collectionsProvider);
    // A tablet gets search, import tiles and a grid (D-104); a phone keeps
    // its list, which works well as it is.
    final wide = isWideLayout(context);
    final hasAny = !(cols.value?.isEmpty ?? true);
    return Scaffold(
      appBar: PageBar(
        width: wide ? AppSizes.dashboardWidth : AppSizes.maxContentWidth,
        bar: AppBar(
          title: Text(l.navLibrary),
          actions: [
            // Import has its own tiles on the page. The words fit unless
            // the text is very large; then the icon alone, as on a phone.
            if (wide && hasAny && MediaQuery.textScalerOf(context).scale(1) < _largeText)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: OutlinedButton.icon(
                  style: AppButtonSize.compact,
                  onPressed: () => createCollectionDialog(context, ref),
                  icon: const Icon(AppIcons.newCollection, size: AppSizes.iconMd),
                  label: Text(l.newCollection),
                ),
              )
            else if (wide && hasAny)
              IconButton(
                tooltip: l.newCollection,
                icon: const Icon(AppIcons.newCollection),
                onPressed: () => createCollectionDialog(context, ref),
              )
            else ...[
              // Import sits in the bar: no button floating over the list (an
              // empty library has its own big button in the middle).
              IconButton(
                tooltip: l.newCollection,
                icon: const Icon(AppIcons.newCollection),
                onPressed: () => createCollectionDialog(context, ref),
              ),
              if (hasAny)
                AppBarAction(
                  icon: AppIcons.add,
                  label: l.importShort,
                  tooltip: l.importAction,
                  onPressed: () => context.push('/import'),
                ),
            ],
          ],
        ),
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
            : wide
            ? _wide(list)
            : ListView(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.listBottom).inPage(context),
                children: [
                  SettingsGroup(children: [for (final c in list) _CollectionTile(c)]),
                ],
              ),
      ),
    );
  }

  Widget _wide(List<CollectionSummary> list) {
    final l = context.l10n;
    final q = _query.trim().toLowerCase();
    final counts = <_SourceFilter, int>{};
    for (final c in list) {
      final f = _filterOf(c.row.source);
      if (f != null) counts[f] = (counts[f] ?? 0) + 1;
    }
    final shown = [
      for (final c in list)
        if ((_source == null || _filterOf(c.row.source) == _source) &&
            (q.isEmpty || c.row.name.toLowerCase().contains(q)))
          c,
    ];
    final games = list.fold<int>(0, (a, c) => a + c.gameCount);
    String label(_SourceFilter f) => switch (f) {
      _SourceFilter.lichess => 'Lichess',
      _SourceFilter.chesscom => 'Chess.com',
      _SourceFilter.files => l.srcFilesClipboard,
    };
    return ListView(
      padding: AppInsets.page.inPage(context, width: AppSizes.dashboardWidth),
      children: [
        SearchField(hint: l.librarySearchHint, onChanged: (v) => setState(() => _query = v)),
        SectionHeader(l.importShort, padding: _captionPadding),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ImportTile(
                  icon: AppIcons.openFile,
                  title: l.importFileTitle,
                  subtitle: l.importFileSub,
                  main: true,
                  start: ImportStart.file,
                ),
              ),
              AppGap.h12,
              Expanded(
                child: _ImportTile(
                  icon: AppIcons.paste,
                  title: l.importClipboardTitle,
                  subtitle: l.importClipboardSub,
                  start: ImportStart.clipboard,
                ),
              ),
              AppGap.h12,
              Expanded(
                child: _ImportTile(
                  icon: AppIcons.link,
                  title: l.importLinkTitle,
                  subtitle: l.importLinkSub,
                  start: ImportStart.link,
                ),
              ),
            ],
          ),
        ),
        SectionHeader(
          l.collectionsTitle,
          padding: _captionPadding,
          trailing: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.card),
            child: Text('${list.length} · ${l.gamesCount(games)}', style: context.tt.meta),
          ),
        ),
        // The source filter only when there is more than one source.
        if (counts.length > 1 || (counts.length == 1 && counts.values.first < list.length)) ...[
          ChipRow(
            children: [
              CountChip(
                label: l.all,
                count: list.length,
                selected: _source == null,
                onTap: () => setState(() => _source = null),
              ),
              for (final f in _SourceFilter.values)
                if ((counts[f] ?? 0) > 0)
                  CountChip(
                    label: label(f),
                    count: counts[f]!,
                    selected: _source == f,
                    onTap: () => setState(() => _source = _source == f ? null : f),
                  ),
            ],
          ),
          AppGap.v12,
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(
              q.isEmpty ? l.nothingFound : l.nothingFoundFor(_query.trim()),
              textAlign: TextAlign.center,
              style: context.tt.meta,
            ),
          )
        else
          CardGrid(children: [for (final c in shown) _CollectionCard(c)]),
      ],
    );
  }
}

/// A way to import, as a tile on a wide Library page.
class _ImportTile extends StatelessWidget {
  const _ImportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.start,
    this.main = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ImportStart start;

  /// The usual way in: its badge is inverted.
  final bool main;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/import', extra: ImportInput(start: start)),
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (main)
                Container(
                  width: AppSizes.avatar,
                  height: AppSizes.avatar,
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Icon(icon, size: AppSizes.iconMd, color: cs.onPrimary),
                )
              else
                AppAvatar(icon: icon),
              AppGap.v12,
              Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              AppGap.v2,
              Text(subtitle, style: context.tt.meta, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name of a collection's source, as on its card.
String sourceLabel(BuildContext context, String source) {
  final l = context.l10n;
  return switch (source) {
    'lichess' => 'Lichess',
    'chesscom' => 'Chess.com',
    'file' => l.srcFile,
    'clipboard' => l.srcClipboard,
    'analysis' => l.srcAnalysis,
    _ => l.srcManual,
  };
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
      trailing: _CollectionMenu(c),
    );
  }
}

/// Rename or delete a collection.
class _CollectionMenu extends ConsumerWidget {
  const _CollectionMenu(this.c);
  final CollectionSummary c;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return AppMenuButton<String>(
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
    );
  }
}

/// A collection in the grid of a wide Library page (D-104).
class _CollectionCard extends StatelessWidget {
  const _CollectionCard(this.c);
  final CollectionSummary c;

  /// Room for two lines of a name, so the cards of a row line up.
  static const double _nameMinHeight = 40;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/library/${c.row.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.card, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      AppAvatar(icon: sourceIcon(c.row.source)),
                      const Spacer(),
                      _CollectionMenu(c),
                    ],
                  ),
                  AppGap.v8,
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: _nameMinHeight),
                      child: Text(
                        c.row.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const CardHairline(),
            Padding(
              padding: AppInsets.card,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l.gamesCount(c.gameCount),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AppGap.h8,
                  Expanded(
                    child: Text(
                      '${sourceLabel(context, c.row.source)} · ${context.fmtDayMonth(c.row.updatedAt)}',
                      style: context.tt.meta,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
