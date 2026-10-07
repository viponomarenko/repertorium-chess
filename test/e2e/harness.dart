/// End-to-end harness: the real app (router, screens, repositories) on an
/// in-memory database, with fakes for everything that needs the platform
/// (sound, Stockfish, network, secure storage).
library;

import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tabiya/core/sound_service.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/engine/engine_service.dart';
import 'package:tabiya/data/lichess/lichess_auth.dart';
import 'package:tabiya/data/lichess/lichess_client.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/domain/chess/chess_utils.dart';
import 'package:tabiya/presentation/accounts/accounts_providers.dart';
import 'package:tabiya/presentation/app/app.dart';
import 'package:tabiya/presentation/app/providers.dart';

class SilentSound extends SoundService {
  @override
  Future<void> init() async {}
  @override
  Future<void> play(GameSound s) async {}
}

class MemoryTokens implements TokenStore {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String t) async => token = t;
  @override
  Future<void> delete() async => token = null;
}

/// Answers with the first legal moves of the position, instantly.
class FakeEngine implements EngineService {
  int starts = 0;
  @override
  String get name => 'fake';

  EngineEval _eval(String fen) {
    final pos = tryPositionFromFen(fen)!;
    final moves = <String>[];
    var p = pos;
    for (var i = 0; i < 6 && p.legalMoves.values.any((v) => v.isNotEmpty); i++) {
      final m = p.legalMoves.entries.firstWhere((e) => e.value.isNotEmpty);
      final mv = NormalMove(from: m.key, to: m.value.squares.first);
      moves.add(mv.uci);
      p = p.play(mv);
    }
    return EngineEval(
      fen: fen,
      depth: 12,
      done: true,
      lines: [PvLine(multipv: 1, moves: moves, cp: 25)],
    );
  }

  @override
  Stream<EngineEval> analyze(String fen, EngineOptions options) {
    starts++;
    return Stream.value(_eval(fen));
  }

  @override
  Future<EngineEval> evaluate(String fen, {int depth = 14, int multiPv = 1}) async => _eval(fen);
  @override
  Future<void> stop() async {}
  @override
  Future<void> shutdown() async {}
}

/// No network: every request is a 404.
http.Client offline() => MockClient((_) async => http.Response('', 404));

class TestApp {
  TestApp(this.db, this.engine);
  final AppDatabase db;
  final FakeEngine engine;

  /// Call at the end of every test: unmounts the app, lets drift's stream
  /// timers run out and closes the database.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Pumps the whole app. [settings] default to an onboarded user with no
/// animations or delays, so tests run quickly.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  AppSettings? settings,
  Future<void> Function(AppDatabase db)? seed,
  LibraryRepository Function(AppDatabase db)? libraryRepository,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final db = AppDatabase(NativeDatabase.memory());
  if (seed != null) await tester.runAsync(() => seed(db));
  final engine = FakeEngine();
  final tokens = MemoryTokens();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (libraryRepository != null) libraryRepositoryProvider.overrideWithValue(libraryRepository(db)),
        initialSettingsProvider.overrideWithValue(
          settings ??
              const AppSettings(
                onboardingDone: true,
                localeCode: 'uk',
                animationMs: 0,
                opponentDelayMs: 0,
                sound: false,
                haptics: false,
                engineCloudFirst: false,
              ),
        ),
        soundServiceProvider.overrideWithValue(SilentSound()),
        engineServiceProvider.overrideWithValue(engine),
        tokenStoreProvider.overrideWithValue(tokens),
        lichessClientProvider.overrideWithValue(
          LichessClient(client: offline(), userAgent: 'test', tokenProvider: tokens.read),
        ),
      ],
      child: const TabiyaApp(),
    ),
  );
  await settle(tester);
  return TestApp(db, engine);
}

/// pumpAndSettle that tolerates endless animations (progress indicators).
Future<void> settle(WidgetTester tester, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
  }
}

/// No overflow stripes, no exceptions.
void expectClean(WidgetTester tester) {
  final e = tester.takeException();
  if (e == null) return;
  // Include which widget overflowed / failed.
  final details = e is FlutterError ? e.toStringDeep() : '$e';
  fail(details.split('\n').take(40).join('\n'));
}

/// Taps the first widget with [text] (scrolling it into view if needed).
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Taps the first text containing [part].
Future<void> tapContaining(WidgetTester tester, String part) async {
  final f = find.textContaining(part).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// All visible texts (for debugging a failing test).
List<String> visibleTexts(WidgetTester tester) => [
  for (final e in find.byType(Text).evaluate())
    if ((e.widget as Text).data != null) (e.widget as Text).data!,
];

/// Navigates like a deep link (go_router) inside the running app.
Future<void> goTo(WidgetTester tester, String location, {Object? extra}) async {
  final context = tester.element(find.byType(Navigator).first);
  unawaited(GoRouter.of(context).push(location, extra: extra));
  await settle(tester);
}
