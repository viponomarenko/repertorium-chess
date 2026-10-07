import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/data/settings/app_settings.dart';
import 'package:tabiya/presentation/app/providers.dart';
import 'package:tabiya/presentation/theme/app_theme.dart';
import 'package:tabiya/presentation/widgets/san_text.dart';

/// A long engine line in one row (maxLines 1, ellipsis) must show its
/// moves in every notation language, figurines included.
void main() {
  const line = '5... e5 6. dxe5 Ng4 7. Nc3 Nxe5 8. Bf4 Nbc6 9. Qd2 Bb4 10. O-O-O O-O 11. a3 Bxc3';
  for (final lang in ['english', 'ukrainian', 'figurine']) {
    testWidgets('engine-style line visible ($lang)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [initialSettingsProvider.overrideWithValue(AppSettings(notationLanguage: lang))],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SizedBox(
                width: 360,
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text('−0,53')),
                    Expanded(child: MovesText(line, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final para = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byType(MovesText), matching: find.byType(RichText)).first,
      );
      // Something of the line must be laid out on the first line.
      final boxes = para.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 6));
      expect(boxes, isNotEmpty, reason: 'first move not painted');
      expect(boxes.first.right - boxes.first.left, greaterThan(10));
    });
  }
}
