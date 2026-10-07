import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/l10n.dart';
import '../../data/incoming/incoming_files.dart';
import '../../data/notifications/reminder_service.dart';
import '../accounts/accounts_providers.dart';
import '../theme/app_theme.dart';
import 'providers.dart';
import 'router.dart';

class TabiyaApp extends ConsumerStatefulWidget {
  const TabiyaApp({super.key});

  @override
  ConsumerState<TabiyaApp> createState() => _TabiyaAppState();
}

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _TabiyaAppState extends ConsumerState<TabiyaApp> with WidgetsBindingObserver {
  StreamSubscription<Duration>? _rateLimit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incomingFilesProvider).start();
      unawaited(ref.read(libraryRepositoryProvider).mergeAnalysisCollections().catchError((Object _) {}));
    });
    // Lichess answered 429: tell the user that requests are paused (ТЗ 6.1).
    _rateLimit = ref.read(lichessClientProvider).rateLimitEvents.listen((_) {
      final messenger = scaffoldMessengerKey.currentState;
      if (messenger == null || !messenger.mounted) return;
      final text = AppLocalizations.of(messenger.context).lichessRateLimited;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rateLimit?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(refreshTickProvider.notifier).bump();
    }
  }

  /// Keeps the daily reminder in line with the settings: on/off, time and
  /// language (also after a backup restore).
  Future<void> _syncReminder() async {
    final s = ref.read(settingsProvider);
    final r = ref.read(reminderServiceProvider);
    try {
      if (!s.notificationsEnabled) {
        await r.cancel();
        return;
      }
      final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final code = s.localeCode ?? (device == 'uk' ? 'uk' : 'en');
      final l = lookupAppLocalizations(Locale(code));
      await r.schedule(
        hour: s.notificationHour,
        minute: s.notificationMinute,
        title: AppInfo.name,
        body: l.reminderBody,
        channelName: l.dailyReminder,
      );
    } catch (e) {
      debugPrint('reminder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => (s.notificationsEnabled, s.notificationHour, s.notificationMinute, s.localeCode)),
      (_, _) => unawaited(_syncReminder()),
    );
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final locale = ref.watch(settingsProvider.select((s) => s.locale));
    final router = ref.watch(routerProvider);
    final notation = NotationSize.fromName(ref.watch(settingsProvider.select((s) => s.notationSize)));
    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: AppTheme.light(notation: notation),
      darkTheme: AppTheme.dark(notation: notation),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (device, supported) {
        if (device != null) {
          for (final l in supported) {
            if (l.languageCode == device.languageCode) return l;
          }
        }
        return const Locale('en');
      },
      routerConfig: router,
    );
  }
}
