@Tags(['golden'])
library;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart' show PieceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/l10n/gen/app_localizations.dart';
import 'package:tabiya/presentation/about/typography_preview_screen.dart';
import 'package:tabiya/presentation/app/providers.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';

/// Typography acceptance (T-21, T-22): the preview in light/dark themes at
/// 100 % and 200 % text size. Update with `flutter test --update-goldens
/// --tags golden`.
Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
  }

  await family('GoogleSans', ['assets/fonts/google_sans/GoogleSans[GRAD,opsz,wght].ttf']);
  await family('GoogleSansCode', ['assets/fonts/google_sans_code/GoogleSansCode[wght].ttf']);
  await family('TabiyaSymbols', ['assets/fonts/noto_sans_math/TabiyaSymbols-Regular.ttf']);
  // App icons (a package font: family and asset carry the package prefix).
  await family('packages/bootstrap_icons/BootstrapIcons', ['packages/bootstrap_icons/fonts/BootstrapIcons.ttf']);
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      final name = '${dark ? 'dark' : 'light'}_${(scale * 100).round()}';
      testWidgets('typography preview $name', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [initialSettingsProvider.overrideWithValue(const AppSettings(notationLanguage: 'figurine'))],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              locale: const Locale('uk'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const TypographyPreviewScreen(),
            ),
          ),
        );
        // Figurines are images: decode them before taking the picture.
        final element = tester.element(find.byType(TypographyPreviewScreen));
        await tester.runAsync(() async {
          for (final k in PieceKind.values) {
            await precacheImage(PieceSet.cburnett.assets[k]!, element);
          }
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'no overflow at ${scale}x');
        await expectLater(find.byType(TypographyPreviewScreen), matchesGoldenFile('goldens/typography_$name.png'));
      });
    }
  }
}
