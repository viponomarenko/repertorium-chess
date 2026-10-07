import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/common.dart';

/// A label inside a segment must never wrap mid-word (e.g. «Звичайни/й»):
/// the widget drops the check mark or falls back to chips instead.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required double scale,
    required List<String> labels,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ChoiceSegments<int>(
                options: [for (var i = 0; i < labels.length; i++) ChoiceOption(i, labels[i])],
                selected: 1,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void expectSingleLineLabels(WidgetTester tester, List<String> labels) {
    for (final l in labels) {
      for (final e in find.text(l).evaluate()) {
        final para = e.renderObject! as RenderParagraph;
        expect(para.didExceedMaxLines, isFalse, reason: l);
        final lines = para.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: l.length));
        final tops = {for (final b in lines) b.top.round()};
        expect(tops.length, 1, reason: '"$l" wraps');
      }
    }
  }

  const sizes = ['Малий', 'Звичайний', 'Великий'];

  testWidgets('short labels on a wide screen: segments with a check mark', (tester) async {
    await pump(tester, width: 700, scale: 1, labels: sizes);
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(tester.widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>)).showSelectedIcon, isTrue);
    expectSingleLineLabels(tester, sizes);
  });

  for (final width in [320.0, 360.0, 400.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no wrapped labels at ${width.round()} px, ${scale}x', (tester) async {
        await pump(tester, width: width, scale: scale, labels: sizes);
        expectSingleLineLabels(tester, sizes);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('long labels fall back to chips', (tester) async {
    const labels = ['Залишити старі', 'Замінити', 'Обʼєднати'];
    await pump(tester, width: 320, scale: 2, labels: labels);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
  });

  // Regression: inside an AlertDialog (IntrinsicWidth) the LayoutBuilder threw
  // and the "New repertoire" dialog never appeared.
  testWidgets('works inside an AlertDialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('New'),
                    content: ChoiceSegments<int>(
                      options: const [ChoiceOption(0, 'Білі'), ChoiceOption(1, 'Чорні')],
                      selected: 0,
                      onChanged: (_) {},
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Чорні'), findsOneWidget);
  });
}
