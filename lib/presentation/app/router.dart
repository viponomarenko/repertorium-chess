import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../about/about_screen.dart';
import '../about/design_preview_screen.dart';
import '../about/typography_preview_screen.dart';
import '../accounts/accounts_screen.dart';
import '../accounts/lichess_studies_screen.dart';
import '../accounts/my_games_hub_screen.dart';
import '../game/game_screen.dart';
import '../game/position_editor_screen.dart';
import '../home/more_screen.dart';
import '../home/onboarding_screen.dart';
import '../home/shell.dart';
import '../home/today_screen.dart';
import '../library/collection_screen.dart';
import '../library/import_flow.dart';
import '../library/library_screen.dart';
import '../openings/openings_screen.dart';
import '../repertoire/import_wizard_screen.dart';
import '../repertoire/repertoire_list_screen.dart';
import '../repertoire/repertoire_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../training/training_args.dart';
import '../training/training_screen.dart';
import 'providers.dart';
import 'route_observer.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(settingsProvider).onboardingDone;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [pageRouteObserver],
    initialLocation: onboarded ? '/today' : '/welcome',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/today'),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/today', builder: (_, _) => const TodayScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/repertoires',
                builder: (_, _) => const RepertoireListScreen(),
                routes: [
                  GoRoute(
                    // Over the main navigation: the screen has its own
                    // bottom bar with the tools of the position (D-078).
                    parentNavigatorKey: rootNavigatorKey,
                    path: ':id',
                    builder: (_, s) => RepertoireScreen(
                      // A different mode is a different screen state.
                      key: ValueKey('rep-${s.pathParameters['id']}-${s.uri.queryParameters['edit']}'),
                      id: int.tryParse(s.pathParameters['id']!) ?? -1,
                      initialKey: s.uri.queryParameters['key'],
                      edit: s.uri.queryParameters['edit'] == '1',
                      action: s.uri.queryParameters['action'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
                routes: [
                  GoRoute(
                    path: ':cid',
                    builder: (_, s) => CollectionScreen(id: int.tryParse(s.pathParameters['cid']!) ?? -1),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/game/:id',
        builder: (_, s) => GameScreen(
          gameId: int.tryParse(s.pathParameters['id']!),
          args: s.extra is GameScreenArgs ? s.extra! as GameScreenArgs : const GameScreenArgs(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/analysis',
        builder: (_, s) => GameScreen(
          gameId: null,
          args: s.extra is GameScreenArgs
              ? s.extra! as GameScreenArgs
              : GameScreenArgs(fen: s.uri.queryParameters['fen']),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/position-editor',
        builder: (_, s) => PositionEditorScreen(
          initialFen: s.uri.queryParameters['fen'],
          pickMode: s.uri.queryParameters['pick'] == '1',
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/build/:id',
        // The repertoire screen itself, in the editing mode, over whatever
        // asked for it (a report, a link): there is no separate line editor.
        builder: (_, s) => RepertoireScreen(
          id: int.tryParse(s.pathParameters['id']!) ?? -1,
          initialKey: s.uri.queryParameters['key'],
          startFen: s.uri.queryParameters['fen'],
          playUci: s.uri.queryParameters['play'],
          edit: true,
          standalone: true,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/rep-import',
        // Opened without its data (e.g. restored navigation): go home.
        redirect: (_, s) => s.extra is RepImportRequest ? null : '/today',
        builder: (_, s) => ImportWizardScreen(request: s.extra! as RepImportRequest),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/train',
        redirect: (_, s) => s.extra is TrainingArgs ? null : '/today',
        builder: (_, s) => TrainingScreen(args: s.extra! as TrainingArgs),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/import',
        builder: (_, s) =>
            ImportFlowScreen(input: s.extra is ImportInput ? s.extra! as ImportInput : const ImportInput()),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/stats',
        builder: (_, s) => StatsScreen(repertoireId: int.tryParse(s.uri.queryParameters['rep'] ?? '')),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/backup',
        builder: (_, s) =>
            BackupScreen(request: s.extra is BackupRestoreRequest ? s.extra! as BackupRestoreRequest : null),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/accounts', builder: (_, _) => const AccountsScreen()),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/lichess-studies',
        builder: (_, _) => const LichessStudiesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/my-games',
        builder: (_, s) => MyGamesHubScreen(initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/gaps',
        builder: (_, _) => const MyGamesHubScreen(initialTab: 2),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '/my-openings',
        builder: (_, _) => const MyGamesHubScreen(initialTab: 1),
      ),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/openings', builder: (_, _) => const OpeningsScreen()),
      GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/about', builder: (_, _) => const AboutScreen()),
      if (kDebugMode)
        GoRoute(parentNavigatorKey: rootNavigatorKey, path: '/design', builder: (_, _) => const DesignPreviewScreen()),
      if (kDebugMode)
        GoRoute(
          parentNavigatorKey: rootNavigatorKey,
          path: '/typography',
          builder: (_, _) => const TypographyPreviewScreen(),
        ),
    ],
  );
});
