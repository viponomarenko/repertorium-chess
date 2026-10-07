import 'dart:async';

import 'package:chessground/chessground.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'data/db/database.dart';
import 'presentation/accounts/accounts_providers.dart';
import 'presentation/app/app.dart';
import 'presentation/app/providers.dart';
import 'presentation/widgets/board_view.dart';

/// Bundled fonts and their licenses (T-05), shown on the licenses page.
const _fontLicenses = {
  'Google Sans': 'assets/fonts/google_sans/OFL.txt',
  'Google Sans Code': 'assets/fonts/google_sans_code/OFL.txt',
  'Noto Sans Math (TabiyaSymbols subset)': 'assets/fonts/noto_sans_math/OFL.txt',
};

Stream<LicenseEntry> _fontLicenseEntries() async* {
  for (final MapEntry(key: name, value: path) in _fontLicenses.entries) {
    yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(path));
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenseEntries);
  final db = AppDatabase();
  final settings = await SettingsNotifier.load(db);
  var version = '1.0.0';
  try {
    version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      initialSettingsProvider.overrideWithValue(settings),
      appVersionProvider.overrideWithValue(version),
    ],
    retry: (_, _) => null,
  );
  // Portrait on phones, both orientations on tablets (9.4).
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortest = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortest < 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  unawaited(container.read(soundServiceProvider).init());
  unawaited(ChessgroundImages.instance.loadAll(BoardAppearance.pieceSet(settings.pieceSet).assets));
  unawaited(container.read(openingBookProvider.future));
  runApp(UncontrolledProviderScope(container: container, child: const TabiyaApp()));
}
