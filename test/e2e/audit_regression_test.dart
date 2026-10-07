// Regression coverage for the UX and reliability audit of 2026-09-28.
import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tabiya/core/now.dart';
import 'package:tabiya/data/backup/backup_service.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/repositories/library_repository.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/domain/pgn/pgn_parser.dart';
import 'package:tabiya/presentation/app/app.dart';
import 'package:tabiya/presentation/game/game_controller.dart';
import 'package:tabiya/presentation/library/import_flow.dart';
import 'package:tabiya/presentation/repertoire/create_repertoire_dialog.dart';
import 'package:tabiya/presentation/repertoire/import_wizard_screen.dart';
import 'package:tabiya/presentation/widgets/common.dart' show AppAvatar;

import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire;

Future<void> loadAuditFonts() async {
  final families = {
    'Roboto': ['assets/fonts/google_sans/GoogleSans[GRAD,opsz,wght].ttf'],
    'GoogleSans': ['assets/fonts/google_sans/GoogleSans[GRAD,opsz,wght].ttf'],
    'GoogleSansCode': ['assets/fonts/google_sans_code/GoogleSansCode[wght].ttf'],
    'TabiyaSymbols': ['assets/fonts/noto_sans_math/TabiyaSymbols-Regular.ttf'],
    'packages/bootstrap_icons/BootstrapIcons': ['packages/bootstrap_icons/fonts/BootstrapIcons.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(rootBundle.load(file));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(() async {
    await loadAuditFonts();
    await rootBundle.loadString('assets/openings/openings.tsv');
  });

  Future<void> readyOpenings(WidgetTester tester) async {
    await settle(tester, frames: 200);
    expect(find.byType(TextField), findsOneWidget);
  }

  for (final dark in [false, true]) {
    testWidgets('B09 ECO codes have contrast in ${dark ? "dark" : "light"} theme', (tester) async {
      final app = await pumpApp(
        tester,
        settings: AppSettings(
          onboardingDone: true,
          localeCode: 'uk',
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          sound: false,
          haptics: false,
        ),
      );
      try {
        await goTo(tester, '/openings');
        await readyOpenings(tester);
        final label = find.text('A00').first;
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final cs = Theme.of(tester.element(label)).colorScheme;
        final avatar = tester.widget<Container>(
          find.descendant(
            of: find.ancestor(of: label, matching: find.byType(AppAvatar)),
            matching: find.byType(Container),
          ),
        );
        final background = (avatar.decoration! as BoxDecoration).color ?? cs.surfaceContainerHighest;
        expect(
          paragraph.text.style?.color,
          isNot(background),
          reason: 'ECO code foreground equals the badge background',
        );
        final foregroundLuminance = paragraph.text.style!.color!.computeLuminance();
        final backgroundLuminance = background.computeLuminance();
        final contrast = foregroundLuminance > backgroundLuminance
            ? (foregroundLuminance + 0.05) / (backgroundLuminance + 0.05)
            : (backgroundLuminance + 0.05) / (foregroundLuminance + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5));
        expectClean(tester);
      } finally {
        await app.close(tester);
      }
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('opening detail sheet at 320x640 text $scale', (tester) async {
      final app = await pumpApp(tester, size: const Size(320, 640), textScale: scale);
      try {
        await goTo(tester, '/openings');
        await readyOpenings(tester);
        await tester.tap(find.byType(ListTile).first);
        await settle(tester);
        await expectLater(
          find.byType(TabiyaApp),
          matchesGoldenFile('../../docs/audit-2026-09-28/fixed-screenshots/opening_detail_${scale}x.png'),
        );
        await tapText(tester, 'Новий репертуар звідси');
        expect(find.byType(TextField), findsWidgets);
        expectClean(tester);
      } finally {
        await app.close(tester);
      }
    });
    testWidgets('starter picker at 320x640 text $scale', (tester) async {
      final app = await pumpApp(tester, size: const Size(320, 640), textScale: scale);
      try {
        final context = tester.element(find.byType(Navigator).first);
        final container = ProviderScope.containerOf(context);
        await tester.runAsync(() async {
          final starters = await container.read(starterListProvider.future).timeout(const Duration(seconds: 10));
          for (final starter in starters) {
            await rootBundle.loadString('assets/starter/${starter.file}');
          }
        });
        unawaited(showStarterPicker(context));
        await settle(tester);
        await expectLater(
          find.byType(TabiyaApp),
          matchesGoldenFile('../../docs/audit-2026-09-28/fixed-screenshots/starter_${scale}x.png'),
        );
        final install = find.byType(FilledButton).last;
        await tester.ensureVisible(install);
        await settle(tester);
        await tester.tap(install);
        await settle(tester, frames: 80);
        final installed = await tester.runAsync(() => app.db.select(app.db.repertoires).get());
        expect(installed, hasLength(1), reason: visibleTexts(tester).join(' | '));
        expectClean(tester);
      } finally {
        await app.close(tester);
      }
    });
  }

  test('B01 failed autosave retains pending changes for retry', () async {
    var calls = 0;
    final controller = GameController(
      game: PgnParser.parseOne('*'),
      autosaveDelay: const Duration(days: 1),
      onSave: (_) async {
        calls++;
        throw StateError('simulated disk error');
      },
    );
    controller.playMove(Move.parse('e2e4')!);
    await expectLater(controller.flush(), throwsStateError);
    final pending = controller.dirty;
    controller.onSave = (_) async {
      calls++;
    };
    await controller.flush();
    controller.dispose();
    expect(pending, isTrue, reason: 'failed writes must remain pending');
    expect(calls, 2);
  });

  test('B02 incomplete backup is rejected before replacing existing data', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await LibraryRepository(db).createCollection('Existing user data');
    final manifest = utf8.encode(
      jsonEncode({
        'format': BackupService.format,
        'formatVersion': 1,
        'schema': 1,
        'createdAt': '2026-09-28T00:00:00Z',
        'counts': {'collections': 1, 'games': 5},
      }),
    );
    final archive = Archive()..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    Object? error;
    try {
      await BackupService(db, appVersion: 'audit').restore(ZipEncoder().encode(archive), RestoreMode.replace);
    } catch (e) {
      error = e;
    }
    final remaining = await db.select(db.collections).get();
    expect(remaining, hasLength(1), reason: 'incomplete backup must preserve existing data; error=$error');
    expect(error, isNotNull, reason: 'missing payload files must reject the backup');
  });

  testWidgets('B03 select all refreshes import preview', (tester) async {
    final app = await pumpApp(tester);
    try {
      await goTo(
        tester,
        '/rep-import',
        extra: RepImportRequest(
          games: [PgnParser.parseOne('[Event "A"]\n1. e4 e5 *'), PgnParser.parseOne('[Event "B"]\n1. d4 d5 *')],
        ),
      );
      await tapText(tester, 'Партій: 2 з 2');
      await tester.tap(find.byType(CheckboxListTile).first);
      await settle(tester);
      await tester.tap(find.byType(CheckboxListTile).last);
      await settle(tester);
      await tapText(tester, 'Вибрати все');
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Імпортувати'));
      expect(button.onPressed, isNotNull, reason: 'selected games must enable Import again');
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  testWidgets('B04 invalid pasted FEN does not throw', (tester) async {
    final app = await pumpApp(tester);
    try {
      await goTo(tester, '/position-editor');
      final before = tester.widget<ChessboardEditor>(find.byType(ChessboardEditor)).pieces;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': 'x/8/8/8/8/8/8/8 w - - 0 1'};
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // The FEN actions live in the "More" menu of the editor.
      await tester.tap(find.byTooltip('Ще'));
      await settle(tester);
      await tapText(tester, 'Вставити FEN');
      expect(tester.widget<ChessboardEditor>(find.byType(ChessboardEditor)).pieces, before);
      expectClean(tester);
    } finally {
      await app.close(tester);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('import result with encoding controls text $scale', (tester) async {
      final app = await pumpApp(tester, size: const Size(320, 640), textScale: scale);
      try {
        await goTo(
          tester,
          '/import',
          extra: ImportInput(
            bytes: Uint8List.fromList(utf8.encode('[Event "Audit"]\n1. e4 e5 2. Nf3 *')),
            fileName: 'audit.pgn',
          ),
        );
        await settle(tester);
        await tapText(tester, 'Текст виглядає некоректно? Змінити кодування');
        await expectLater(
          find.byType(TabiyaApp),
          matchesGoldenFile('../../docs/audit-2026-09-28/fixed-screenshots/encoding_${scale}x.png'),
        );
        expectClean(tester);
      } finally {
        await app.close(tester);
      }
    });
  }

  for (final scale in [1.0, 2.0]) {
    for (final route in [
      '/welcome',
      '/position-editor',
      '/import',
      '/backup',
      '/accounts',
      '/my-games',
      '/gaps',
      '/openings',
      '/about',
      '/lichess-studies',
    ]) {
      testWidgets('layout $route 320x640 text $scale', (tester) async {
        final app = await pumpApp(tester, size: const Size(320, 640), textScale: scale);
        try {
          await goTo(tester, route);
          if (route == '/openings') await readyOpenings(tester);
          expectClean(tester);
          if (scale == 1) {
            await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          }
        } finally {
          await app.close(tester);
        }
      });
    }
  }

  for (final dark in [false, true]) {
    for (final route in [
      '/today',
      '/repertoires/1',
      '/analysis',
      '/more',
      '/settings',
      '/position-editor',
      '/import',
      '/stats',
      '/openings',
    ]) {
      testWidgets('visual ${dark ? 'dark' : 'light'} $route', (tester) async {
        // The week chart and the forecast show dates: pin "today" to the
        // day the screenshots were recorded.
        appNow = () => DateTime(2026, 9, 29, 12);
        addTearDown(() => appNow = DateTime.now);
        final app = await pumpApp(
          tester,
          seed: seedRepertoire,
          settings: AppSettings(
            onboardingDone: true,
            localeCode: 'uk',
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            animationMs: 0,
            opponentDelayMs: 0,
            sound: false,
            haptics: false,
            engineCloudFirst: false,
          ),
        );
        try {
          if (route == '/today' || route == '/more' || route.startsWith('/repertoires')) {
            GoRouter.of(tester.element(find.byType(Navigator).first)).go(route);
            await settle(tester);
          } else {
            await goTo(tester, route);
          }
          if (route == '/openings') await readyOpenings(tester);
          expectClean(tester);
          final name = route.replaceAll('/', '_');
          await expectLater(
            find.byType(TabiyaApp),
            matchesGoldenFile('../../docs/audit-2026-09-28/fixed-screenshots/${dark ? 'dark' : 'light'}$name.png'),
          );
        } finally {
          await app.close(tester);
        }
      });
    }
  }
}
