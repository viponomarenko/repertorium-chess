import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabiya/presentation/widgets/common.dart';

/// A choice whose value is null ("All", "All time") must still be chosen:
/// the popup menu reads a null result as "closed without a choice" (D-099).
void main() {
  testWidgets('a null choice reaches onSelected', (tester) async {
    final picked = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: FilterPill<String?>(
              label: 'Lichess',
              items: const [(null, 'All'), ('lichess', 'Lichess')],
              onSelected: picked.add,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lichess'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    expect(picked, [null]);
  });
}
