/// The window buttons of iPadOS 26+ (close, minimise, tile) sit over the
/// app's top-left corner when it runs in a window; Flutter's safe area does
/// not cover them. Native side: `WindowControlsPlugin` in AppDelegate.swift.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class WindowControls {
  WindowControls._();

  static const _channel = MethodChannel('app.tabiya/window');

  /// How far below the safe area the window buttons reach; 0 full screen.
  static final extraTop = ValueNotifier<double>(0);

  static Future<void> start() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'controls') extraTop.value = (call.arguments as num).toDouble();
      return null;
    });
    try {
      await _channel.invokeMethod<void>('start');
    } on MissingPluginException {
      // Tests.
    } catch (e) {
      debugPrint('window controls: $e');
    }
  }
}

/// Moves every screen below the window buttons: the safe area of the app
/// grows at the top by their height, as under a title bar.
class WindowControlsInset extends StatelessWidget {
  const WindowControlsInset({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: WindowControls.extraTop,
    child: child,
    builder: (context, extra, child) {
      if (extra <= 0) return child!;
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(top: mq.padding.top + extra),
          viewPadding: mq.viewPadding.copyWith(top: mq.viewPadding.top + extra),
        ),
        child: child!,
      );
    },
  );
}

/// A page beside the side rail: the window buttons sit over the rail, not
/// over the page, so the page keeps its top.
class BesideWindowControls extends StatelessWidget {
  const BesideWindowControls({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: WindowControls.extraTop,
    child: child,
    builder: (context, extra, child) {
      if (extra <= 0) return child!;
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          padding: mq.padding.copyWith(top: (mq.padding.top - extra).clamp(0, double.infinity)),
          viewPadding: mq.viewPadding.copyWith(top: (mq.viewPadding.top - extra).clamp(0, double.infinity)),
        ),
        child: child!,
      );
    },
  );
}
