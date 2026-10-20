import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../core/now.dart';
import '../../data/db/database.dart';
import '../../data/sync/accounts_service.dart';
import '../settings/settings_screen.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import 'accounts_providers.dart';
import 'game_meta.dart';
import 'imported_game_args.dart';

final _importedProvider = StreamProvider.autoDispose<List<ImportedGameRow>>(
  (ref) => ref.watch(accountsServiceProvider).watchImportedGames(),
);

/// Downloading the user's games from Lichess / Chess.com (F-LI-08, F-CC-02)
/// and comparing them with the repertoires (F-GAP) after every download.
class MyGamesScreen extends ConsumerStatefulWidget {
  const MyGamesScreen({super.key, this.embedded = false, this.onTab, this.downloadOnOpen});

  /// Shown as a tab of the "My games" screen: no app bar of its own.
  final bool embedded;

  /// lichess | chesscom: download its games at once (an account just
  /// connected, "Update now" on the Accounts screen).
  final String? downloadOnOpen;

  /// Switches the tab of that screen (2 – differences from the repertoire).
  final void Function(int tab)? onTab;

  @override
  ConsumerState<MyGamesScreen> createState() => _MyGamesScreenState();
}

/// A day's header sits close to its games: the list is long.
const _dayHeaderPadding = EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, AppSpacing.xxs);

class _MyGamesScreenState extends ConsumerState<MyGamesScreen> {
  StreamSubscription<SyncProgress>? _sub;
  String? _syncing;
  SyncProgress? _progress;
  bool _cancel = false;
  bool _comparing = false;

  /// Filters of the list: provider, the user's colour, the result.
  String _provider = 'all';
  String _color = 'all';
  String _result = 'all';

  /// Search by opponent or opening; null – the field is closed.
  String? _query;

  /// New games since the last download, at most this many at a time.
  static const GamesFilter _newGames = GamesFilter(newOnly: true, max: _FilterSheetState.defaultMax);

  /// Games are fetched by themselves when the screen opens and the last
  /// download is older than this.
  static const Duration _staleAfter = Duration(hours: 6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _downloadOnOpen());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// An account asked for ([MyGamesScreen.downloadOnOpen]) is downloaded
  /// with a report; otherwise every account last downloaded long ago, quietly
  /// (only new games are announced).
  Future<void> _downloadOnOpen() async {
    final asked = widget.downloadOnOpen;
    if (asked != null) {
      await _run(asked, _newGames);
      return;
    }
    final accounts = await ref.read(accountsServiceProvider).watchAccounts().first;
    final now = DateTime.now();
    for (final a in accounts) {
      if (!mounted) return;
      final last = a.lastSyncAt;
      if (last != null && now.difference(last) < _staleAfter) continue;
      await _run(a.provider, _newGames, quiet: true);
    }
  }

  /// Pull to refresh: new games of every connected account.
  Future<void> _refresh() async {
    final accounts = await ref.read(accountsServiceProvider).watchAccounts().first;
    for (final a in accounts) {
      if (!mounted) return;
      await _run(a.provider, _newGames);
    }
  }

  Future<void> _sync(String provider) async {
    final l = context.l10n;
    final f = await showAppSheet<GamesFilter>(
      context,
      title: l.downloadGames,
      builder: (_) => _FilterSheet(provider: provider),
    );
    if (f == null || !mounted) return;
    await _run(provider, f);
  }

  /// Downloads with [f] and then compares the new games with the
  /// repertoires. [quiet]: no report unless new games came in.
  Future<void> _run(String provider, GamesFilter f, {bool quiet = false}) async {
    if (_syncing != null || !mounted) return;
    final l = context.l10n;
    final svc = ref.read(accountsServiceProvider);
    _cancel = false;
    setState(() {
      _syncing = provider;
      _progress = const SyncProgress(downloaded: 0, added: 0);
    });
    final stream = provider == 'lichess'
        ? svc.syncLichess(f, cancelled: () => _cancel)
        : svc.syncChessCom(f, cancelled: () => _cancel);
    final done = Completer<void>();
    _sub = stream.listen(
      (p) {
        if (!mounted) return;
        setState(() => _progress = p);
        if (p.done) {
          setState(() => _syncing = null);
          if (!quiet || p.added > 0) {
            showSnack(
              context,
              p.error != null
                  ? l.syncFailed(p.added, friendlyError(p.error!, l))
                  : p.more
                  ? l.syncDoneMore(p.added)
                  : l.syncDone(p.added),
            );
          }
          if (p.added > 0) unawaited(_compare());
        }
      },
      onDone: () {
        if (mounted) setState(() => _syncing = null);
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
  }

  /// New games are compared with the repertoires at once: the report is
  /// never out of date and needs no button of its own.
  Future<void> _compare() async {
    setState(() => _comparing = true);
    try {
      await ref.read(gapServiceProvider).analyzeAll();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e, context.l10n));
    } finally {
      if (mounted) setState(() => _comparing = false);
    }
  }

  bool _accepts(ImportedGameRow g, GameMeta? meta) {
    if (_provider != 'all' && g.provider != _provider) return false;
    if (_color != 'all' && g.userColor != _color) return false;
    if (_result != 'all' && userOutcome(g) != _result) return false;
    final q = _query?.trim().toLowerCase() ?? '';
    if (q.isEmpty) return true;
    return g.opponent.toLowerCase().contains(q) || (meta?.opening?.toLowerCase().contains(q) ?? false);
  }

  /// "Today", "Yesterday", "16 October" (with the year when not this one).
  String _dayTitle(DateTime day, DateTime today) {
    final l = context.l10n;
    final tag = Localizations.localeOf(context).toLanguageTag();
    final diff = DateTime(today.year, today.month, today.day).difference(day).inDays;
    if (diff == 0) return l.todayHeadline;
    if (diff == 1) return l.yesterday;
    return (day.year == today.year ? DateFormat.MMMMd(tag) : DateFormat.yMMMMd(tag)).format(day);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final accounts = ref.watch(linkedAccountsProvider).value;
    final li = accountOf(accounts, 'lichess');
    final cc = accountOf(accounts, 'chesscom');
    final imported = ref.watch(_importedProvider);
    final games = imported.value ?? const <ImportedGameRow>[];
    final meta = ref.watch(gameMetaProvider).value ?? const <int, GameMeta>{};
    final exits = ref.watch(gameExitsProvider).value ?? const <int, (int, String)>{};
    final shown = [
      for (final g in games)
        if (_accepts(g, meta[g.id])) g,
    ];
    // The service is named on a row only when games come from both.
    final mixed = games.any((g) => g.provider == 'lichess') && games.any((g) => g.provider == 'chesscom');
    final tag = Localizations.localeOf(context).toLanguageTag();
    final today = appNow();
    // Rows with a header before every new day.
    final items = <Object>[];
    DateTime? day;
    for (final g in shown) {
      final d = DateTime(g.playedAt.year, g.playedAt.month, g.playedAt.day);
      if (d != day) items.add(d);
      day = d;
      items.add(g);
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : PageBar(
              bar: AppBar(
                title: Text(l.myGames),
                actions: [
                  IconButton(
                    tooltip: l.myOpeningsTitle,
                    onPressed: () => context.push('/my-openings'),
                    icon: const Icon(AppIcons.myOpenings),
                  ),
                  AppMenuButton<String>(
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
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xs,
            ).inPage(context),
            child: Row(
              children: [
                Expanded(
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
                    ],
                  ),
                ),
                if (games.isNotEmpty) ...[AppGap.h8, Text(l.gamesCount(shown.length), style: context.tt.meta)],
              ],
            ),
          ),
          if (_syncing != null)
            PageColumn(
              child: ListTile(
                leading: const InlineSpinner(),
                title: Text(l.downloading(_progress?.downloaded ?? 0, _progress?.added ?? 0)),
                subtitle: _progress?.month == null ? null : Text(DateFormat('LLLL y', tag).format(_progress!.month!)),
                trailing: TextButton(onPressed: () => setState(() => _cancel = true), child: Text(l.stop)),
              ),
            )
          else if (_comparing)
            PageColumn(
              child: ListTile(leading: const InlineSpinner(), title: Text(l.analyzingGames)),
            ),
          if (games.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: AppInsets.pageH.inPage(context),
              child: Row(
                children: [
                  FilterPill<String>(
                    label: switch (_color) {
                      'white' => l.asWhite,
                      'black' => l.asBlack,
                      _ => l.bothColors,
                    },
                    items: [('all', l.bothColors), ('white', l.asWhite), ('black', l.asBlack)],
                    onSelected: (v) => setState(() => _color = v),
                  ),
                  AppGap.h8,
                  FilterPill<String>(
                    label: switch (_result) {
                      '+' => l.resultWins,
                      '−' => l.resultLosses,
                      '=' => l.resultDraws,
                      _ => l.allResults,
                    },
                    items: [('all', l.allResults), ('+', l.resultWins), ('−', l.resultLosses), ('=', l.resultDraws)],
                    onSelected: (v) => setState(() => _result = v),
                  ),
                  if (mixed) ...[
                    AppGap.h8,
                    FilterPill<String>(
                      label: switch (_provider) {
                        'lichess' => 'Lichess',
                        'chesscom' => 'Chess.com',
                        _ => l.all,
                      },
                      items: [('all', l.all), ('lichess', 'Lichess'), ('chesscom', 'Chess.com')],
                      onSelected: (v) => setState(() => _provider = v),
                    ),
                  ],
                  IconButton(
                    tooltip: l.search,
                    isSelected: _query != null,
                    onPressed: () => setState(() => _query = _query == null ? '' : null),
                    icon: const Icon(AppIcons.search),
                  ),
                ],
              ),
            ),
          if (_query != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xs).inPage(context),
              child: TextField(
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.gamesSearchHint,
                  prefixIcon: const Icon(AppIcons.search),
                  suffixIcon: IconButton(
                    tooltip: l.close,
                    onPressed: () => setState(() => _query = null),
                    icon: const Icon(AppIcons.close),
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            // Not the empty state before the first answer of the database.
            child: imported.isLoading && !imported.hasValue
                ? const LoadingView()
                : games.isEmpty
                ? EmptyState(icon: AppIcons.myGames, title: l.noDownloadedGames, message: l.noDownloadedGamesHint)
                : shown.isEmpty
                ? EmptyState(icon: AppIcons.search, title: l.nothingFound)
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpacing.listBottom).inPage(context),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        if (item is DateTime) return SectionHeader(_dayTitle(item, today), padding: _dayHeaderPadding);
                        final g = item as ImportedGameRow;
                        return _GameRow(
                          game: g,
                          meta: meta[g.id],
                          showProvider: mixed,
                          onTap: () => context.push(
                            '/analysis',
                            extra: importedGameArgs(
                              context,
                              g,
                              meta: meta[g.id],
                              exit: exits[g.id],
                              order: [for (final x in shown) x.id],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A downloaded game in one line and a line of facts: the opponent and
/// their rating, then the result, the time control and the opening.
class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.meta, required this.showProvider, required this.onTap});
  final ImportedGameRow game;
  final GameMeta? meta;
  final bool showProvider;

  /// Opens the game from the user's side, where it left the repertoire.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final g = game;
    final outcome = switch (userOutcome(g)) {
      '+' => l.outcomeWin,
      '−' => l.outcomeLoss,
      '=' => l.outcomeDraw,
      _ => l.outcomeUnknown,
    };
    final white = g.userColor == 'white';
    final elo = meta?.opponentElo;
    final facts = [
      outcome,
      timeControlText(g.timeControl, l),
      if (showProvider) g.provider == 'lichess' ? 'Lichess' : 'Chess.com',
      ?meta?.opening,
    ].where((t) => t.isNotEmpty).join(' · ');
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
            style: theme.textTheme.titleMedium?.copyWith(color: white ? cs.onSideWhite : cs.onSideBlack),
          ),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: g.opponent.isEmpty ? '?' : g.opponent),
            if (elo != null) TextSpan(text: '  $elo', style: context.tt.meta),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.provider});

  /// lichess | chesscom: the time controls it has.
  final String provider;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String _period = 'new';
  final Set<String> _speeds = {};
  bool _rated = false;
  String? _color;

  /// At most this many new games at a time, unless the user moves it.
  static const int defaultMax = 1000;

  double _max = defaultMax.toDouble();

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
                ('all', l.periodAll),
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
              // Chess.com has no classical games: bullet, blitz, rapid, daily.
              for (final sp
                  in widget.provider == 'chesscom'
                      ? const ['bullet', 'blitz', 'rapid', 'daily']
                      : const ['bullet', 'blitz', 'rapid', 'classical', 'daily'])
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
              GamesFilter(
                since: since(),
                max: _max.round(),
                speeds: _speeds,
                ratedOnly: _rated,
                color: _color,
                newOnly: _period == 'new',
              ),
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
