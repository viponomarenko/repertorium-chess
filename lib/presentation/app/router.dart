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
import '../puzzles/puzzle_screen.dart';
import '../puzzles/puzzles_screen.dart';
import '../repertoire/import_wizard_screen.dart';
import '../repertoire/repertoire_list_screen.dart';
import '../repertoire/repertoire_screen.dart';
import '../settings/backup_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';
import '../training/training_args.dart';
import '../training/training_screen.dart';
import 'app_page.dart';
import 'providers.dart';
import 'route_observer.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// A route whose page is always an [AppPage] (D-101). go_router 18 looks
/// for the `MaterialApp` of the `material_ui` package; ours is Flutter's,
/// so it fell back to pages without a transition: screens appeared at
/// once and the iOS swipe back from the left edge did nothing.
GoRoute _route({
  required String path,
  required Widget Function(BuildContext context, GoRouterState state) builder,
  GlobalKey<NavigatorState>? parentNavigatorKey,
  GoRouterRedirect? redirect,
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  parentNavigatorKey: parentNavigatorKey,
  redirect: redirect,
  routes: routes,
  pageBuilder: (context, state) => AppPage<void>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: <String, String>{...state.pathParameters, ...state.uri.queryParameters},
    restorationId: state.pageKey.value,
    child: builder(context, state),
  ),
);

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(settingsProvider).onboardingDone;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [pageRouteObserver],
    initialLocation: onboarded ? '/today' : '/welcome',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/today'),
      _route(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [_route(path: '/today', builder: (_, _) => const TodayScreen())],
          ),
          StatefulShellBranch(
            routes: [
              _route(
                path: '/repertoires',
                builder: (_, _) => const RepertoireListScreen(),
                routes: [
                  _route(
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
              _route(
                path: '/library',
                builder: (_, _) => const LibraryScreen(),
                routes: [
                  _route(
                    path: ':cid',
                    builder: (_, s) => CollectionScreen(id: int.tryParse(s.pathParameters['cid']!) ?? -1),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_route(path: '/more', builder: (_, _) => const MoreScreen())],
          ),
        ],
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/game/:id',
        builder: (_, s) => GameScreen(
          gameId: int.tryParse(s.pathParameters['id']!),
          args: s.extra is GameScreenArgs ? s.extra! as GameScreenArgs : const GameScreenArgs(),
        ),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/analysis',
        builder: (_, s) => GameScreen(
          gameId: null,
          args: s.extra is GameScreenArgs
              ? s.extra! as GameScreenArgs
              : GameScreenArgs(fen: s.uri.queryParameters['fen']),
        ),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/position-editor',
        builder: (_, s) => PositionEditorScreen(
          initialFen: s.uri.queryParameters['fen'],
          pickMode: s.uri.queryParameters['pick'] == '1',
        ),
      ),
      _route(
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
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/rep-import',
        // Opened without its data (e.g. restored navigation): go home.
        redirect: (_, s) => s.extra is RepImportRequest ? null : '/today',
        builder: (_, s) => ImportWizardScreen(request: s.extra! as RepImportRequest),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/train',
        redirect: (_, s) => s.extra is TrainingArgs ? null : '/today',
        builder: (_, s) => TrainingScreen(args: s.extra! as TrainingArgs),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/import',
        builder: (_, s) =>
            ImportFlowScreen(input: s.extra is ImportInput ? s.extra! as ImportInput : const ImportInput()),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/stats',
        builder: (_, s) => StatsScreen(repertoireId: int.tryParse(s.uri.queryParameters['rep'] ?? '')),
      ),
      _route(parentNavigatorKey: rootNavigatorKey, path: '/settings', builder: (_, _) => const SettingsScreen()),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/backup',
        builder: (_, s) =>
            BackupScreen(request: s.extra is BackupRestoreRequest ? s.extra! as BackupRestoreRequest : null),
      ),
      _route(parentNavigatorKey: rootNavigatorKey, path: '/accounts', builder: (_, _) => const AccountsScreen()),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/lichess-studies',
        builder: (_, _) => const LichessStudiesScreen(),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/my-games',
        builder: (_, s) => MyGamesHubScreen(
          initialTab: int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
          downloadOnOpen: s.uri.queryParameters['download'],
        ),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/gaps',
        builder: (_, _) => const MyGamesHubScreen(initialTab: 2),
      ),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/my-openings',
        builder: (_, _) => const MyGamesHubScreen(initialTab: 1),
      ),
      _route(parentNavigatorKey: rootNavigatorKey, path: '/openings', builder: (_, _) => const OpeningsScreen()),
      _route(
        parentNavigatorKey: rootNavigatorKey,
        path: '/puzzles',
        builder: (_, _) => const PuzzlesScreen(),
        routes: [
          _route(
            parentNavigatorKey: rootNavigatorKey,
            path: ':angle',
            builder: (_, s) => PuzzleScreen(angle: s.pathParameters['angle']!),
          ),
        ],
      ),
      _route(parentNavigatorKey: rootNavigatorKey, path: '/about', builder: (_, _) => const AboutScreen()),
      if (kDebugMode)
        _route(parentNavigatorKey: rootNavigatorKey, path: '/design', builder: (_, _) => const DesignPreviewScreen()),
      if (kDebugMode)
        _route(
          parentNavigatorKey: rootNavigatorKey,
          path: '/typography',
          builder: (_, _) => const TypographyPreviewScreen(),
        ),
    ],
  );
});
