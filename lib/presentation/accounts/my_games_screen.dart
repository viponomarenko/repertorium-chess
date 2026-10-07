import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../../data/sync/accounts_service.dart';
import '../game/game_screen.dart';
import '../settings/settings_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import 'accounts_providers.dart';

final _importedProvider = StreamProvider.autoDispose<List<ImportedGameRow>>(
  (ref) => ref.watch(accountsServiceProvider).watchImportedGames(),
);

/// Downloading the user's games from Lichess / Chess.com (F-LI-08, F-CC-02)
/// and starting the analysis against the repertoires (F-GAP).
class MyGamesScreen extends ConsumerStatefulWidget {
  const MyGamesScreen({super.key, this.embedded = false, this.onTab});

  /// Shown as a tab of the "My games" screen: no app bar of its own.
  final bool embedded;

  /// Switches the tab of that screen (2 – differences from the repertoire).
  final void Function(int tab)? onTab;

  @override
  ConsumerState<MyGamesScreen> createState() => _MyGamesScreenState();
}

class _MyGamesScreenState extends ConsumerState<MyGamesScreen> {
  StreamSubscription<SyncProgress>? _sub;
  String? _syncing;
  SyncProgress? _progress;
  bool _cancel = false;
  String _filter = 'all';

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _sync(String provider) async {
    final l = context.l10n;
    final f = await showAppSheet<GamesFilter>(context, title: l.downloadGames, builder: (_) => const _FilterSheet());
    if (f == null || !mounted) return;
    final svc = ref.read(accountsServiceProvider);
    _cancel = false;
    setState(() {
      _syncing = provider;
      _progress = const SyncProgress(downloaded: 0, added: 0);
    });
    final stream = provider == 'lichess'
        ? svc.syncLichess(f, cancelled: () => _cancel)
        : svc.syncChessCom(f, cancelled: () => _cancel);
    _sub = stream.listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.done) {
          setState(() => _syncing = null);
          showSnack(context, p.error == null ? l.syncDone(p.added) : l.syncFailed(p.added, friendlyError(p.error!, l)));
        }
      },
      onDone: () {
        if (mounted) setState(() => _syncing = null);
      },
    );
  }

  Future<void> _analyze() async {
    final l = context.l10n;
    final h = showProgress(context, l.analyzingGames);
    try {
      final summary = await ref.read(gapServiceProvider).analyzeAll();
      h.close();
      if (!mounted) return;
      showSnack(context, l.analysisDone(summary.events));
      if (widget.onTab != null) {
        widget.onTab!(2);
      } else {
        unawaited(context.push('/gaps'));
      }
    } catch (e) {
      h.close();
      if (mounted) showSnack(context, friendlyError(e, context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accounts = ref.watch(linkedAccountsProvider).value;
    final li = accountOf(accounts, 'lichess');
    final cc = accountOf(accounts, 'chesscom');
    final imported = ref.watch(_importedProvider);
    final games = imported.value ?? const <ImportedGameRow>[];
    final shown = _filter == 'all' ? games : games.where((g) => g.provider == _filter).toList();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(l.myGames),
              actions: [
                IconButton(
                  tooltip: l.myOpeningsTitle,
                  onPressed: () => context.push('/my-openings'),
                  icon: const Icon(AppIcons.myOpenings),
                ),
                PopupMenuButton<String>(
                  constraints: appMenuConstraints,
                  icon: const Icon(AppIcons.more),
                  tooltip: l.more,
                  onSelected: (v) async {
                    if (v == 'clear') {
                      final ok = await confirm(
                        context,
                        title: l.clearDownloadedQ,
                        confirmLabel: l.delete,
                        destructive: true,
                      );
                      if (ok) await ref.read(accountsServiceProvider).deleteImportedGames();
                    }
                  },
                  itemBuilder: (_) => [appMenuItem(value: 'clear', label: l.clearDownloaded)],
                ),
              ],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (li != null)
                  FilledButton.tonalIcon(
                    onPressed: _syncing == null ? () => _sync('lichess') : null,
                    icon: const Icon(AppIcons.download),
                    label: Text(l.downloadFrom('Lichess')),
                  ),
                if (cc != null)
                  FilledButton.tonalIcon(
                    onPressed: _syncing == null ? () => _sync('chesscom') : null,
                    icon: const Icon(AppIcons.download),
                    label: Text(l.downloadFrom('Chess.com')),
                  ),
                if (li == null && cc == null)
                  OutlinedButton(onPressed: () => context.push('/accounts'), child: Text(l.connectAccountFirst)),
                // Next to the downloads, not floating over the list.
                if (games.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(AppIcons.gaps),
                    label: Text(l.analyzeVsRepertoire),
                  ),
              ],
            ),
          ),
          if (_syncing != null)
            ListTile(
              leading: const InlineSpinner(),
              title: Text(l.downloading(_progress?.downloaded ?? 0, _progress?.added ?? 0)),
              subtitle: _progress?.message == null ? null : Text(_progress!.message!),
              trailing: TextButton(onPressed: () => setState(() => _cancel = true), child: Text(l.stop)),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: AppInsets.pageH,
            child: Row(
              children: [
                for (final (v, label) in [('all', l.all), ('lichess', 'Lichess'), ('chesscom', 'Chess.com')])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == v,
                      onSelected: (_) => setState(() => _filter = v),
                    ),
                  ),
                Text(l.gamesCount(shown.length), style: context.tt.meta),
              ],
            ),
          ),
          Expanded(
            // Not the empty state before the first answer of the database.
            child: imported.isLoading && !imported.hasValue
                ? const LoadingView()
                : shown.isEmpty
                ? EmptyState(icon: AppIcons.myGames, title: l.noDownloadedGames, message: l.noDownloadedGamesHint)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.listBottom),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final g = shown[i];
                      final outcome = switch (userOutcome(g)) {
                        '+' => l.outcomeWin,
                        '−' => l.outcomeLoss,
                        '=' => l.outcomeDraw,
                        _ => l.outcomeUnknown,
                      };
                      final white = g.userColor == 'white';
                      return ListTile(
                        leading: Tooltip(
                          message: '$outcome · ${l.playedAs(white ? l.white : l.black)}',
                          // The side the user played, with the result on it.
                          child: Container(
                            width: AppSizes.avatar,
                            height: AppSizes.avatar,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: white ? cs.sideWhite : cs.sideBlack,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.outline),
                            ),
                            child: Text(
                              userOutcome(g),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: white ? cs.onSideWhite : cs.onSideBlack,
                              ),
                            ),
                          ),
                        ),
                        title: Text(l.vsOpponent(g.opponent.isEmpty ? '?' : g.opponent)),
                        subtitle: Text(
                          // The result in words: the sign in the circle alone needed a legend.
                          '$outcome · ${context.fmtShortDate(g.playedAt)} · ${speedName(g.speed, l)} · ${timeControlText(g.timeControl, l)} · ${g.provider == 'lichess' ? 'Lichess' : 'Chess.com'}',
                        ),
                        onTap: () => context.push('/analysis', extra: GameScreenArgs(pgn: g.pgn)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _period = 'new';
  final Set<String> _speeds = {};
  bool _rated = false;
  String? _color;
  double _max = 300;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = context.tt.title;
    DateTime? since() => switch (_period) {
      'month' => DateTime.now().subtract(const Duration(days: 31)),
      '3months' => DateTime.now().subtract(const Duration(days: 92)),
      'year' => DateTime.now().subtract(const Duration(days: 365)),
      _ => null,
    };
    return Padding(
      padding: AppInsets.sheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.period, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (v, label) in [
                ('new', l.periodNew),
                ('month', l.periodMonth),
                ('3months', l.period3Months),
                ('year', l.periodYear),
              ])
                ChoiceChip(label: Text(label), selected: _period == v, onSelected: (_) => setState(() => _period = v)),
            ],
          ),
          AppGap.v12,
          Text(l.timeControl, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final sp in const ['bullet', 'blitz', 'rapid', 'classical', 'daily'])
                FilterChip(
                  label: Text(speedName(sp, l)),
                  selected: _speeds.contains(sp),
                  onSelected: (v) => setState(() => v ? _speeds.add(sp) : _speeds.remove(sp)),
                ),
            ],
          ),
          AppGap.v12,
          Text(l.color, style: label),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (v, label) in [(null, l.any), ('white', l.white), ('black', l.black)])
                ChoiceChip(label: Text(label), selected: _color == v, onSelected: (_) => setState(() => _color = v)),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _rated,
            title: Text(l.ratedOnly),
            onChanged: (v) => setState(() => _rated = v),
          ),
          Text(l.maxGames(_max.round()), style: label),
          Slider(
            value: _max,
            min: 50,
            max: 2000,
            divisions: 39,
            label: '${_max.round()}',
            onChanged: (v) => setState(() => _max = v),
          ),
          AppGap.v8,
          FilledButton(
            style: AppButtonSize.large,
            onPressed: () => Navigator.pop(
              context,
              GamesFilter(since: since(), max: _max.round(), speeds: _speeds, ratedOnly: _rated, color: _color),
            ),
            child: Text(l.download),
          ),
        ],
      ),
    );
  }
}

/// "+" win, "−" loss, "=" draw from the user's point of view.
String userOutcome(ImportedGameRow g) => switch (g.result) {
  '1-0' => g.userColor == 'white' ? '+' : '−',
  '0-1' => g.userColor == 'black' ? '+' : '−',
  '1/2-1/2' => '=',
  _ => '?',
};

/// "300" (seconds) -> "5 хв", "180+2" -> "3+2", "1/259200" (daily) -> "3 дні".
String timeControlText(String tc, AppLocalizations l) {
  if (tc.isEmpty || tc == '-') return '';
  if (tc.contains('/')) {
    final secs = int.tryParse(tc.split('/').last);
    return secs == null ? tc : l.daysPerMove(secs ~/ 86400);
  }
  final parts = tc.split('+');
  final base = int.tryParse(parts.first);
  if (base == null) return tc;
  // The decimal mark follows the app language ("2.5 min" / "2,5 хв").
  final minutes = base % 60 == 0 ? '${base ~/ 60}' : NumberFormat('0.#', l.localeName).format(base / 60);
  final inc = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return inc == 0 ? l.minutesShort(minutes) : '$minutes+$inc';
}
