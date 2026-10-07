import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';

/// T-22: WCAG AA (4.5:1) for all text used in notation and feedback, in
/// both themes and for every notation size.
void main() {
  for (final (name, build) in [('light', AppTheme.light), ('dark', AppTheme.dark)]) {
    for (final size in NotationSize.values) {
      test('$name theme, ${size.name} notation meets AA', () {
        final theme = build(notation: size);
        final cs = theme.colorScheme;
        final tt = theme.extension<TabiyaText>()!;
        void aa(String what, Color fg, Color bg) =>
            expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: '$what on $name');

        aa('main move', tt.moveMain.color!, cs.surface);
        aa('move number', tt.moveNumber.color!, cs.surface);
        aa('comment', tt.comment.color!, cs.surface);
        for (var d = 1; d <= TabiyaText.maxIndentDepth; d++) {
          aa('variation depth $d', tt.variation(d).color!, cs.surface);
        }
        aa('current move', tt.currentMoveForeground, tt.currentMoveBackground);
        aa('NAG good', tt.nag.good, cs.surface);
        aa('NAG mistake', tt.nag.mistake, cs.surface);
        aa('NAG inaccuracy', tt.nag.inaccuracy, cs.surface);
        aa('NAG interesting', tt.nag.interesting, cs.surface);
        aa('success text', cs.success, cs.surface);
        aa('warning text', cs.warning, cs.surface);
        aa('success container', cs.onSuccessContainer, cs.successContainer);
        aa('warning container', cs.onWarningContainer, cs.warningContainer);
        aa('error container', cs.onErrorContainer, cs.errorContainer);
        aa('secondary container', cs.onSecondaryContainer, cs.secondaryContainer);
        aa('on surface variant', cs.onSurfaceVariant, cs.surfaceContainerHigh);
      });
    }
  }

  test('variation tones get lighter with depth but never below AA', () {
    final tt = AppTheme.light().extension<TabiyaText>()!;
    final cs = AppTheme.light().colorScheme;
    final ratios = [for (var d = 1; d <= 4; d++) contrastRatio(tt.variation(d).color!, cs.surface)];
    for (var i = 1; i < ratios.length; i++) {
      expect(ratios[i], lessThanOrEqualTo(ratios[i - 1]));
    }
  });
}
