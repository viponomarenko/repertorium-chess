import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../data/lichess/lichess_client.dart';
import '../library/import_flow.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import 'accounts_providers.dart';

final _studiesProvider = FutureProvider.autoDispose<List<StudyMeta>>((ref) async {
  final acc = accountOf(await ref.watch(linkedAccountsProvider.future), 'lichess');
  if (acc == null) return const [];
  final list = await ref.read(lichessClientProvider).studiesByUser(acc.username).toList();
  list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return list;
});

/// The user's Lichess studies with import (F-LI-07).
class LichessStudiesScreen extends ConsumerWidget {
  const LichessStudiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final studies = ref.watch(_studiesProvider);
    final df = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag());
    return Scaffold(
      appBar: AppBar(
        title: Text(l.myStudies),
        actions: [
          IconButton(
            tooltip: l.refresh,
            onPressed: () => ref.invalidate(_studiesProvider),
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: studies.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorState(
          message: e is LichessException && e.isUnauthorized
              ? l.lichessSessionExpired
              : l.downloadFailed(friendlyError(e, l)),
          onRetry: () => ref.invalidate(_studiesProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(icon: AppIcons.openings, title: l.noStudies)
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: const Icon(AppIcons.openings),
                    title: Text(s.name),
                    subtitle: Text(l.updatedOn(df.format(s.updatedAt))),
                    trailing: const Icon(AppIcons.download),
                    onTap: () => context.push('/import', extra: ImportInput(url: 'https://lichess.org/study/${s.id}')),
                  );
                },
              ),
      ),
    );
  }
}
