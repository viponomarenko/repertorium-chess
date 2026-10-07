import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/core/l10n.dart';
import 'package:tabiya/data/db/database.dart';
import 'package:tabiya/data/engine/engine_network.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/accounts/accounts_providers.dart';
import 'package:tabiya/presentation/app/providers.dart';
import 'package:tabiya/presentation/widgets/engine_model_sheet.dart';

import '../e2e/harness.dart';

class FakeNetwork extends EngineNetwork {
  FakeNetwork() {
    value = const EngineNetworkState(NetworkPhase.missing);
  }
  Completer<bool>? pending;
  int downloads = 0;
  int cancellations = 0;
  VoidCallback? onRemove;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> download() {
    downloads++;
    value = const EngineNetworkState(NetworkPhase.downloading, received: 1024);
    return (pending = Completer<bool>()).future;
  }

  @override
  void cancel() {
    if (pending != null && !pending!.isCompleted) {
      cancellations++;
      pending!.complete(false);
      value = const EngineNetworkState(NetworkPhase.missing);
    }
  }

  void complete() {
    value = const EngineNetworkState(NetworkPhase.ready);
    pending!.complete(true);
  }

  @override
  Future<void> remove() async {
    onRemove?.call();
    value = const EngineNetworkState(NetworkPhase.missing);
  }
}

class SheetEngine extends FakeEngine {
  VoidCallback? onShutdown;
  @override
  Future<void> shutdown() async => onShutdown?.call();
}

void main() {
  late AppDatabase db;
  late FakeNetwork network;
  late ProviderContainer container;
  late SheetEngine engine;
  Future<void> pump(WidgetTester tester, {bool downloaded = false}) async {
    db = AppDatabase(NativeDatabase.memory());
    network = FakeNetwork();
    engine = SheetEngine();
    if (downloaded) network.value = const EngineNetworkState(NetworkPhase.ready);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialSettingsProvider.overrideWithValue(AppSettings(engineModel: downloaded ? 'full' : 'light')),
          soundServiceProvider.overrideWithValue(SilentSound()),
          engineNetworkProvider.overrideWithValue(network),
          engineServiceProvider.overrideWithValue(engine),
        ],
        child: MaterialApp(
          locale: const Locale('uk'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () => showEngineModelSheet(context), child: const Text('Open')),
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(tester.element(find.text('Open')));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  tearDown(() async {
    network.dispose();
    await db.close();
  });

  testWidgets('removal stops full engine before selecting Light so the new search survives', (tester) async {
    await pump(tester, downloaded: true);
    final events = <String>[];
    engine.onShutdown = () => events.add('stop:${container.read(settingsProvider).engineModel}');
    network.onRemove = () => events.add('remove:${container.read(settingsProvider).engineModel}');
    final subscription = container.listen(settingsProvider, (_, next) => events.add(next.engineModel));
    await tester.tap(find.text('Видалити дані повного рушія'));
    await tester.pumpAndSettle();
    expect(events, ['stop:full', 'remove:full', 'light']);
    expect(find.text('Завантажити й увімкнути'), findsOneWidget);
    subscription.close();
  });

  testWidgets('opening model choice does not download; full selection waits for verification', (tester) async {
    await pump(tester);
    expect(network.downloads, 0);
    await tester.tap(find.text('Завантажити й увімкнути'));
    await tester.pump();
    expect(container.read(settingsProvider).engineModel, 'light');
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    network.complete();
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).engineModel, 'full');
    expect(find.byType(EngineModelSheet), findsNothing);
  });

  testWidgets('closing sheet cancels download and retains Light', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Завантажити й увімкнути'));
    await tester.pump();
    Navigator.of(tester.element(find.byType(EngineModelSheet))).pop();
    await tester.pumpAndSettle();
    expect(network.cancellations, 1);
    expect(container.read(settingsProvider).engineModel, 'light');
  });

  testWidgets('cancel allows retry without changing engine choice', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Завантажити й увімкнути'));
    await tester.pump();
    await tester.tap(find.text('Скасувати'));
    await tester.pumpAndSettle();
    expect(find.text('Завантажити й увімкнути'), findsOneWidget);
    expect(container.read(settingsProvider).engineModel, 'light');
    expect(network.cancellations, 1);
  });
}
