/// Puzzles (D-123): the player's rating and every Lichess theme, grouped
/// as on lichess.org; a theme opens a run of its puzzles.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../core/l10n.dart';
import '../../domain/puzzles/puzzle_profile.dart';
import '../../domain/puzzles/puzzle_themes.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import 'puzzle_providers.dart';
import 'puzzle_theme_names.dart';

class PuzzlesScreen extends ConsumerStatefulWidget {
  const PuzzlesScreen({super.key});

  @override
  ConsumerState<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends ConsumerState<PuzzlesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_sendPending());
  }

  /// Results played offline go to Lichess as soon as the list opens.
  Future<void> _sendPending() async {
    final user = puzzleUser(await ref.read(puzzleAccountProvider.future));
    if (user == null || !mounted) return;
    final profile = await ref.read(puzzleRepositoryProvider).load();
    if (profile.pending.isEmpty) return;
    try {
      await ref.read(puzzleSyncProvider).send(user);
      if (mounted) ref.invalidate(puzzleProfileProvider);
    } catch (_) {
      // Still offline or limited: they wait for the next time.
    }
  }

  Future<void> _reconnect() async {
    try {
      await reconnectForPuzzles(ref);
    } catch (_) {
      // Cancelled on the Lichess page.
    }
    if (mounted) ref.invalidate(puzzleAccountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(puzzleProfileProvider).value ?? const PuzzleProfile();
    final account = ref.watch(puzzleAccountProvider).value;
    final user = puzzleUser(account);
    return Scaffold(
      appBar: PageBar(bar: AppBar(title: Text(l.puzzlesTitle))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.listBottom).inPage(context),
        children: [
          AppGap.v8,
          _RatingCard(profile: profile, user: user),
          Padding(
            padding: AppInsets.pageH.add(const EdgeInsets.only(top: AppSpacing.sm)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user == null ? l.puzzlesNoteLocal : l.puzzlesNoteLichess(user), style: context.tt.meta),
                if (user != null && profile.pending.isNotEmpty)
                  Text(l.puzzlesPending(profile.pending.length), style: context.tt.meta),
              ],
            ),
          ),
          // An account connected before puzzles: its token cannot count them.
          if (account != null && !account.canWrite)
            Padding(
              padding: AppInsets.pageH.add(const EdgeInsets.only(top: AppSpacing.md)),
              child: InfoStrip(
                icon: AppIcons.link,
                text: l.puzzlesReconnect,
                action: TextButton(onPressed: _reconnect, child: Text(l.puzzlesReconnectAction)),
              ),
            ),
          for (final e in kPuzzleThemes.entries) ...[
            SectionHeader(puzzleCategoryName(l, e.key)),
            SettingsGroup(
              children: [
                for (final key in e.value)
                  _ThemeTile(
                    title: puzzleThemeName(l, key),
                    subtitle: puzzleThemeDescription(l, key),
                    score: profile.byAngle[key],
                    onTap: () => context.push('/puzzles/$key'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.profile, required this.user});
  final PuzzleProfile profile;

  /// The Lichess account the rating is of; null: the device's rating.
  final String? user;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = profile;
    final g = p.shown(user);
    return Padding(
      padding: AppInsets.pageH,
      child: Card(
        child: Padding(
          padding: AppInsets.card,
          // Three numbers in one row; with a large text size they shrink
          // instead of running over.
          child: Row(
            children: [
              for (final tile in [
                Semantics(
                  label: g.provisional ? l.puzzleRatingProvisional(g.rating.round()) : null,
                  child: StatTile(
                    value: puzzleRatingText(g),
                    label: user == null ? l.puzzleRating : l.puzzleRatingLichess,
                  ),
                ),
                StatTile(value: context.fmtInt(p.played), label: l.puzzleStatPlayed),
                StatTile(
                  value: l.percentValue(p.played == 0 ? 0 : (p.won * 100 / p.played).round()),
                  label: l.puzzleStatSolved,
                ),
              ])
                Expanded(
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: tile),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A theme: name, what it is, and the results so far in it.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.title, required this.subtitle, required this.score, required this.onTap});
  final String title;
  final String? subtitle;
  final ThemeScore? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = score;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s != null)
            Semantics(
              label: l.puzzleThemeScoreLabel(s.won, s.played),
              excludeSemantics: true,
              child: Text(l.puzzleThemeScore(s.won, s.played), style: context.tt.meta.tabular),
            ),
          const ListChevron(),
        ],
      ),
      onTap: onTap,
    );
  }
}
