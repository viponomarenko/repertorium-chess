import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/chesscom/chesscom_client.dart';
import '../../data/db/database.dart';
import '../../data/engine/engine_network.dart';
import '../../data/engine/engine_service.dart';
import '../../data/lichess/explorer_service.dart';
import '../../data/lichess/lichess_auth.dart';
import '../../data/lichess/lichess_client.dart';
import '../../data/sync/accounts_service.dart';
import '../../data/sync/gap_service.dart';
import '../app/providers.dart';

/// App version (overridden in main from package info).
final appVersionProvider = Provider<String>((ref) => '1.0.1');

/// Lichess: `Tabiya/<version> (+<repository>)` (ТЗ 6.1).
final userAgentProvider = Provider<String>(
  (ref) => '${AppInfo.userAgentName}/${ref.watch(appVersionProvider)} (+${AppInfo.repositoryUrl})',
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final lichessClientProvider = Provider<LichessClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final c = LichessClient(userAgent: ref.watch(userAgentProvider), tokenProvider: tokens.read);
  ref.onDispose(c.close);
  return c;
});

final chessComClientProvider = Provider<ChessComClient>((ref) {
  final c = ChessComClient(
    userAgent: '${AppInfo.userAgentName}/${ref.watch(appVersionProvider)} (contact: ${AppInfo.supportUrl})',
  );
  ref.onDispose(c.close);
  return c;
});

final accountsServiceProvider = Provider<AccountsService>(
  (ref) => AccountsService(
    db: ref.watch(databaseProvider),
    lichess: ref.watch(lichessClientProvider),
    chessCom: ref.watch(chessComClientProvider),
    tokens: ref.watch(tokenStoreProvider),
  ),
);

final linkedAccountsProvider = StreamProvider<List<LinkedAccountRow>>(
  (ref) => ref.watch(accountsServiceProvider).watchAccounts(),
);

LinkedAccountRow? accountOf(List<LinkedAccountRow>? list, String provider) {
  for (final a in list ?? const <LinkedAccountRow>[]) {
    if (a.provider == provider) return a;
  }
  return null;
}

/// True if a Lichess token is available (explorer, private studies).
final lichessLoggedInProvider = FutureProvider<bool>((ref) async {
  ref.watch(linkedAccountsProvider);
  return ref.watch(accountsServiceProvider).hasLichessToken();
});

final explorerServiceProvider = Provider<ExplorerService>(
  (ref) => ExplorerService(ref.watch(databaseProvider), ref.watch(lichessClientProvider)),
);

final engineNetworkProvider = Provider<EngineNetwork>((ref) {
  final network = EngineNetwork();
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      if (state != AppLifecycleState.resumed) network.cancel();
    },
  );
  ref.onDispose(lifecycle.dispose);
  ref.onDispose(network.dispose);
  return network;
});

class EngineNetworkUnavailable implements Exception {
  const EngineNetworkUnavailable();
}

final engineServiceProvider = Provider<EngineService>((ref) {
  final e = StockfishEngine(
    configuration: () async {
      if (ref.read(settingsProvider).engineModel != 'full') return const EngineConfiguration();
      final path = await ref.read(engineNetworkProvider).readyPath();
      if (path == null) throw const EngineNetworkUnavailable();
      return EngineConfiguration(model: EngineModel.full, nnuePath: path);
    },
  );
  ref.listen(settingsProvider.select((s) => s.engineModel), (previous, next) {
    if (previous != next) unawaited(e.shutdown());
  });
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      e.setForeground(state == AppLifecycleState.resumed);
    },
  );
  final state = WidgetsBinding.instance.lifecycleState;
  e.setForeground(state == null || state == AppLifecycleState.resumed);
  ref.onDispose(lifecycle.dispose);
  ref.onDispose(e.shutdown);
  return e;
});

final gapServiceProvider = Provider<GapService>(
  (ref) => GapService(ref.watch(databaseProvider), ref.watch(repertoireRepositoryProvider)),
);
