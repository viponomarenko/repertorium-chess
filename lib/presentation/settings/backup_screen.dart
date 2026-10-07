import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/backup/backup_service.dart';
import '../accounts/accounts_providers.dart';
import '../app/providers.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/export_sheet.dart';

/// Bytes of a backup opened from outside (e.g. "Open in Tabiya").
class BackupRestoreRequest {
  const BackupRestoreRequest(this.bytes);
  final Uint8List bytes;
}

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider), appVersion: ref.watch(appVersionProvider)),
);

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key, this.request});
  final BackupRestoreRequest? request;

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.request != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restore(widget.request!.bytes));
    }
  }

  Future<void> _export({required bool share}) async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final bytes = Uint8List.fromList(await ref.read(backupServiceProvider).export());
      final name = 'tabiya-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.tabiya';
      if (!mounted) return;
      if (share) {
        await shareBytes(context, bytes, name, 'application/zip');
      } else {
        final ok = await saveBytes(bytes, name, 'application/zip');
        if (ok && mounted) showSnack(context, l.saved);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndRestore() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final bytes = await files.first.xFile.readAsBytes();
    await _restore(bytes);
  }

  Future<void> _restore(Uint8List bytes) async {
    final l = context.l10n;
    final svc = ref.read(backupServiceProvider);
    BackupInfo info;
    try {
      info = svc.inspect(bytes);
    } catch (e) {
      if (mounted) showSnack(context, l.notABackup);
      return;
    }
    if (!mounted) return;
    final c = info.counts;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreTitle),
        content: Text(
          '${l.restoreSummary(ctx.fmtDateTime(info.createdAt.toLocal()), c['repertoires'] ?? 0, c['games'] ?? 0, c['cards'] ?? 0)}'
          '\n\n${l.restoreMergeHint}',
        ),
        // One row when it fits, else a column in the same order: cancel,
        // the safe choice (add what is missing), the destructive one.
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, RestoreMode.merge), child: Text(l.restoreMerge)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, RestoreMode.replace),
            child: Text(l.restoreReplace),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    if (mode == RestoreMode.replace) {
      final ok = await confirm(
        context,
        title: l.restoreReplaceConfirm,
        message: l.restoreReplaceWarning,
        confirmLabel: l.restoreReplace,
        destructive: true,
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    // Taken before the work starts: the steps after the restore must run
    // even if the screen is gone by then (they used to be skipped, and the
    // old in-memory settings then overwrote the restored ones).
    final settings = ref.read(settingsProvider.notifier);
    final tokens = ref.read(tokenStoreProvider);
    final refresh = ref.read(refreshTickProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final summary = await svc.restore(bytes, mode);
      if (mode == RestoreMode.replace) {
        await settings.reloadFromDb();
        // The restored accounts may belong to someone else: never keep using
        // this device's Lichess token for them (a new login is required).
        await tokens.delete();
        container.invalidate(lichessLoggedInProvider);
      }
      refresh.bump();
      if (mounted) {
        showSnack(
          context,
          mode == RestoreMode.replace
              ? l.restoreDone
              : summary.added == 0
              ? l.restoreNothingNew
              : l.restoreMerged(summary.added, summary.skipped),
        );
        context.go('/today');
      }
    } catch (e) {
      if (mounted) showSnack(context, l.restoreFailed(friendlyError(e, l)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      // The database is being rewritten: stay until it is done.
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.backupTitle)),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
            children: [
              if (_busy) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.lg),
                child: Text(l.backupExplanation),
              ),
              SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(AppIcons.share),
                    title: Text(l.backupShare),
                    onTap: () => _export(share: true),
                  ),
                  ListTile(
                    leading: const Icon(AppIcons.download),
                    title: Text(l.backupSave),
                    onTap: () => _export(share: false),
                  ),
                ],
              ),
              AppGap.v12,
              SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(AppIcons.reset),
                    title: Text(l.restoreFromFile),
                    subtitle: Text(l.restoreHint),
                    onTap: _pickAndRestore,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.page, top: AppSpacing.md, right: AppSpacing.page),
                child: Text(l.backupPrivacy, style: context.tt.meta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
