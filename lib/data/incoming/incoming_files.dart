/// Files and text shared with the app: "Open in Tabiya", "Share" (F-IMP-02).
/// Native side: MainActivity.kt (Android intents), AppDelegate.swift (iOS
/// document types / scene URL contexts).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/app/providers.dart';
import '../../presentation/app/router.dart';
import '../../presentation/library/import_flow.dart';

final incomingFilesProvider = Provider<IncomingFiles>(IncomingFiles.new);

class IncomingFiles {
  IncomingFiles(this.ref);
  final Ref ref;
  static const _channel = MethodChannel('app.tabiya/incoming');
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'incoming') _handle(call.arguments);
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<List<Object?>>('getInitial');
      for (final p in initial ?? const []) {
        _handle(p);
      }
    } on MissingPluginException {
      // Tests / unsupported platform.
    } catch (e) {
      debugPrint('incoming: $e');
    }
  }

  void _handle(Object? payload) {
    if (payload is! Map) return;
    final bytes = payload['bytes'];
    final text = payload['text'] as String?;
    final name = payload['name'] as String?;
    final input = ImportInput(
      bytes: bytes is Uint8List ? bytes : (bytes is List ? Uint8List.fromList(bytes.cast<int>()) : null),
      text: text,
      fileName: name,
    );
    if (input.bytes == null && (input.text == null || input.text!.trim().isEmpty)) return;
    final router = ref.read(routerProvider);
    // Opening a file with Tabiya counts as starting to use it: finish the
    // onboarding so it does not come back, and import on top of Today.
    if (!ref.read(settingsProvider).onboardingDone) {
      unawaited(ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true)));
      router.go('/today');
    }
    unawaited(router.push('/import', extra: input));
  }
}
