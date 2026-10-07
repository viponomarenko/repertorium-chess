import 'package:flutter/services.dart';

/// Touch feedback for controls (D-077), switched by the "Haptics" setting.
/// Board moves and training results get theirs from the sound service.
abstract final class Haptics {
  static bool enabled = true;

  /// A choice changed: a tab, a pill, a segment.
  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Something was done: added, saved.
  static void confirm() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Something was refused.
  static void error() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
