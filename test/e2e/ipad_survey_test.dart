// Pictures of every screen at iPad sizes, to look at while working on the
// wide layout: `flutter test test/e2e/ipad_survey_test.dart --run-skipped
// --update-goldens` writes them to build/ipad_survey.
@Tags(['survey'])
library;

import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/domain/training/training_engine.dart';
import 'package:tabiya/presentation/training/training_args.dart';

import 'audit_regression_test.dart' show loadAuditFonts;
import 'harness.dart';
import 'screens_guidelines_test.dart' show seedRepertoire, deepKey;

const sizes = {
  'p11': Size(834, 1210),
  'l11': Size(1210, 834),
  'p13': Size(1032, 1376),
  'l13': Size(1376, 1032),
  'split': Size(507, 1032),
};

void main() {
  setUpAll(() async {
    await loadAuditFonts();
    await rootBundle.loadString('assets/openings/openings.tsv');
  });
  const only = String.fromEnvironment('ONLY');
  final routes = <String, (String, Object?)>{
    'today': ('/today', null),
    'repertoires': ('/repertoires', null),
    'rep': ('/repertoires/1', null),
    'rep_deep': ('/repertoires/1?key=${deepKey()}', null),
    'build': ('/build/1?key=${deepKey()}', null),
    'library': ('/library', null),
    'more': ('/more', null),
    'settings': ('/settings', null),
    'analysis': ('/analysis', null),
    'stats': ('/stats', null),
    'my_games': ('/my-games', null),
    'my_openings': ('/my-openings', null),
    'accounts': ('/accounts', null),
    'about': ('/about', null),
    'openings': ('/openings', null),
    'backup': ('/backup', null),
    'editor': ('/position-editor', null),
    'import': ('/import', null),
    'train': ('/train', const TrainingArgs(repertoireIds: [1], mode: TrainingMode.learn)),
    'welcome': ('/welcome', null),
  };
  for (final s in sizes.entries) {
    for (final r in routes.entries) {
      if (only.isNotEmpty && !only.split(',').contains(r.key)) continue;
      testWidgets('${r.key} ${s.key}', (tester) async {
        final app = await pumpApp(
          tester,
          seed: seedRepertoire,
          size: s.value,
          pixelRatio: 1,
          settings: AppSettings(
            onboardingDone: r.key != 'welcome',
            localeCode: 'uk',
            animationMs: 0,
            opponentDelayMs: 0,
            sound: false,
            haptics: false,
            engineCloudFirst: false,
          ),
        );
        final element = tester.element(find.byType(Navigator).first);
        await tester.runAsync(() async {
          for (final a in PieceSet.cburnett.assets.values) {
            await precacheImage(a, element);
          }
        });
        if (r.key != 'welcome' && r.key != 'today') await goTo(tester, r.value.$1, extra: r.value.$2);
        await settle(tester, frames: 30);
        final e = tester.takeException();
        if (e != null) debugPrint('!! ${r.key} ${s.key}: ${'$e'.split('\n').first}');
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../build/ipad_survey/${r.key}_${s.key}.png'));
        await app.close(tester);
      });
    }
  }
}
