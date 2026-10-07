import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n.dart';
import '../../data/db/database.dart';
import '../theme/app_icons.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import 'accounts_providers.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _busy = false;
  final _ccName = TextEditingController();

  @override
  void dispose() {
    _ccName.dispose();
    super.dispose();
  }

  Future<void> _connectLichess() async {
    final l = context.l10n;
    setState(() => _busy = true);
    try {
      final acc = await ref.read(accountsServiceProvider).connectLichess();
      if (mounted) showSnack(context, l.connectedAs(acc.username));
    } on PlatformException catch (e) {
      // Closing the system sign-in sheet is not an error. AppAuth reports
      // it as code -3 of its "general" domain, in the system language.
      final text = '${e.code} ${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();
      final cancelled =
          text.contains('cancel') ||
          '${e.runtimeType}'.contains('Cancel') ||
          (text.contains('org.openid.appauth.general') && RegExp(r'-3\b').hasMatch(text));
      // Never the raw platform text: it is technical and half-translated.
      if (mounted && !cancelled) showSnack(context, l.loginFailedGeneric);
    } catch (e) {
      if (mounted) showSnack(context, l.loginFailed(friendlyError(e, l)));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(lichessLoggedInProvider);
      }
    }
  }

  Future<void> _disconnectLichess() async {
    final l = context.l10n;
    final ok = await confirm(
      context,
      title: l.disconnectQ('Lichess'),
      message: l.disconnectLichessMessage,
      confirmLabel: l.disconnect,
      destructive: true,
    );
    if (!ok || !mounted || _busy) return;
    // Revoking the token is a network call: no second tap meanwhile.
    setState(() => _busy = true);
    try {
      await ref.read(accountsServiceProvider).disconnectLichess();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(lichessLoggedInProvider);
      }
    }
  }

  Future<void> _connectChessCom() async {
    final l = context.l10n;
    final name = _ccName.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final p = await ref.read(accountsServiceProvider).connectChessCom(name);
      if (!mounted) return;
      showSnack(context, p == null ? l.chessComNotFound(name) : l.connectedAs(p.username));
    } catch (e) {
      if (mounted) showSnack(context, l.downloadFailed(friendlyError(e, l)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final tt = context.tt;
    final destructiveText = TextButton.styleFrom(foregroundColor: theme.colorScheme.error);
    final accounts = ref.watch(linkedAccountsProvider).value;
    final li = accountOf(accounts, 'lichess');
    final cc = accountOf(accounts, 'chesscom');
    final loggedIn = ref.watch(lichessLoggedInProvider).value ?? false;
    final df = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm();

    return Scaffold(
      appBar: AppBar(title: Text(l.accountsTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: AppPage(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Text(l.accountsIntro, style: theme.textTheme.bodyMedium),
            AppGap.v16,
            SectionCard(
              title: 'Lichess',
              leading: const Icon(AppIcons.online),
              trailing: li == null ? null : Chip(label: Text(loggedIn ? l.connected : l.sessionExpired)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (li == null) ...[
                    Text(l.lichessBenefits),
                    AppGap.v12,
                    FilledButton.icon(
                      onPressed: _connectLichess,
                      icon: const Icon(AppIcons.login),
                      label: Text(l.loginWithLichess),
                    ),
                    AppGap.v8,
                    Text(l.lichessScopesInfo, style: tt.meta),
                  ] else ...[
                    Text(l.connectedAs(li.username), style: theme.textTheme.titleMedium),
                    Text(l.connectedSince(df.format(li.connectedAt)), style: tt.meta),
                    if (li.lastSyncAt != null) Text(l.lastSync(df.format(li.lastSyncAt!)), style: tt.meta),
                    AppGap.v12,
                    if (!loggedIn) ...[
                      FilledButton.icon(
                        onPressed: _connectLichess,
                        icon: const Icon(AppIcons.login),
                        label: Text(l.loginAgain),
                      ),
                      AppGap.v8,
                    ],
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/lichess-studies'),
                          icon: const Icon(AppIcons.openings),
                          label: Text(l.myStudies),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/my-games'),
                          icon: const Icon(AppIcons.myGames),
                          label: Text(l.myGames),
                        ),
                        TextButton(style: destructiveText, onPressed: _disconnectLichess, child: Text(l.disconnect)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            AppGap.v12,
            SectionCard(
              title: 'Chess.com',
              leading: const Icon(AppIcons.online),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cc == null) ...[
                    Text(l.chessComInfo),
                    AppGap.v12,
                    TextField(
                      controller: _ccName,
                      autocorrect: false,
                      enableSuggestions: false,
                      // Nicknames are Latin letters, digits, - and _.
                      keyboardType: TextInputType.visiblePassword,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_-]'))],
                      decoration: InputDecoration(labelText: l.chessComUsername),
                      onSubmitted: (_) => _connectChessCom(),
                    ),
                    AppGap.v12,
                    FilledButton(onPressed: _connectChessCom, child: Text(l.connect)),
                  ] else ...[
                    Text(l.connectedAs(cc.username), style: theme.textTheme.titleMedium),
                    if (cc.lastSyncAt != null) Text(l.lastSync(df.format(cc.lastSyncAt!)), style: tt.meta),
                    AppGap.v12,
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push('/my-games'),
                          icon: const Icon(AppIcons.myGames),
                          label: Text(l.myGames),
                        ),
                        TextButton(
                          style: destructiveText,
                          onPressed: () async {
                            final ok = await confirm(
                              context,
                              title: l.disconnectQ('Chess.com'),
                              message: l.disconnectChessComMessage,
                              confirmLabel: l.disconnect,
                              destructive: true,
                            );
                            if (ok) await ref.read(accountsServiceProvider).disconnectChessCom();
                          },
                          child: Text(l.disconnect),
                        ),
                      ],
                    ),
                    AppGap.v8,
                    Text(l.chessComStudiesNote, style: tt.meta),
                  ],
                ],
              ),
            ),
            AppGap.v16,
            Text(l.notAffiliated, style: tt.meta),
          ],
        ),
      ),
    );
  }
}

extension LinkedAccountX on LinkedAccountRow {
  bool get hasWrite => scopes.split(' ').contains('study:write');
}
